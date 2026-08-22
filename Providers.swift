import Foundation

struct CodexUsageResponse: Decodable {
    let userId: String?
    let accountId: String?
    let email: String?
    let planType: String?
    let rateLimit: CodexRateLimit?
    let codeReviewRateLimit: CodexRateLimit?
    let credits: CodexCredits?
    let spendControl: CodexSpendControl?
    let rateLimitReachedType: String?
    let promo: String?
    let rateLimitResetCredits: CodexResetCredits?
}

struct CodexRateLimit: Decodable {
    let allowed: Bool?
    let limitReached: Bool?
    let primaryWindow: CodexWindow?
    let secondaryWindow: CodexWindow?
}

struct CodexWindow: Decodable {
    let usedPercent: Int?
    let limitWindowSeconds: Int?
    let resetAfterSeconds: Int?
    let resetAt: TimeInterval?
}

struct CodexCredits: Decodable {
    let hasCredits: Bool?
    let balance: String?
    let unlimited: Bool?
    let overageLimitReached: Bool?
    let approxLocalMessages: [Int]?
    let approxCloudMessages: [Int]?
}

struct CodexSpendControl: Decodable {
    let reached: Bool?
}

struct CodexResetCredits: Decodable {
    let availableCount: Int?
    let applicableAvailableCount: Int?
}

struct CodexAuthFile: Decodable {
    struct Tokens: Decodable {
        let accessToken: String?
        let accountId: String?
    }
    let tokens: Tokens?
}

final class CodexProvider: MetricProvider {
    let id = StatusMetricID.codex.rawValue
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func update(settings: AppSettings) {}

    func load(language: AppLanguage) async throws -> MetricSnapshot {
        guard let auth = loadAuth() else { throw ProviderError.notConfigured }
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { throw ProviderError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.message("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let usage = try decoder.decode(CodexUsageResponse.self, from: data)
        let window = usage.rateLimit?.primaryWindow
        let used = window?.usedPercent
        let remaining = used.map { max(0, 100 - $0) }
        let reset = window?.resetAfterSeconds.map { L10n.duration($0, language) } ?? "—"
        let credits = usage.credits?.unlimited == true ? "∞" : (usage.credits?.balance ?? "—")

        var quotaRows = [
            MetricRow(label: L10n.text(.primaryWindow, language), value: L10n.window(window?.limitWindowSeconds, language)),
            MetricRow(label: L10n.text(.used, language), value: used.map { "\($0)%" } ?? "—"),
            MetricRow(label: L10n.text(.remaining, language), value: remaining.map { "\($0)%" } ?? "—"),
            MetricRow(label: L10n.text(.reset, language), value: window?.resetAt.map { Fmt.date($0, language: language) } ?? "—"),
            MetricRow(label: L10n.text(.resetIn, language), value: reset),
        ]
        if let secondary = usage.rateLimit?.secondaryWindow {
            quotaRows.append(MetricRow(label: L10n.text(.secondaryWindow, language), value: L10n.window(secondary.limitWindowSeconds, language)))
            quotaRows.append(MetricRow(label: "\(L10n.text(.secondaryWindow, language)) \(L10n.text(.used, language))", value: secondary.usedPercent.map { "\($0)%" } ?? "—"))
            quotaRows.append(MetricRow(label: "\(L10n.text(.secondaryWindow, language)) \(L10n.text(.resetIn, language))", value: secondary.resetAfterSeconds.map { L10n.duration($0, language) } ?? "—"))
        }

        let creditRows = [
            MetricRow(label: L10n.text(.credits, language), value: credits),
            MetricRow(label: L10n.text(.local, language), value: Fmt.range(usage.credits?.approxLocalMessages)),
            MetricRow(label: L10n.text(.cloud, language), value: Fmt.range(usage.credits?.approxCloudMessages)),
        ]
        let resetCreditRows = [
            MetricRow(label: L10n.text(.available, language), value: "\(usage.rateLimitResetCredits?.availableCount ?? 0)"),
            MetricRow(label: L10n.text(.applicable, language), value: "\(usage.rateLimitResetCredits?.applicableAvailableCount ?? 0)"),
        ]
        let accountRows = [
            MetricRow(label: L10n.text(.plan, language), value: usage.planType ?? "—"),
            MetricRow(label: L10n.text(.email, language), value: usage.email ?? "—"),
            MetricRow(label: L10n.text(.accountID, language), value: usage.accountId ?? "—"),
            MetricRow(label: L10n.text(.userID, language), value: usage.userId ?? "—"),
            MetricRow(label: L10n.text(.status, language), value: usage.rateLimit?.limitReached == true ? L10n.text(.limited, language) : L10n.text(.ok, language)),
        ]

        return MetricSnapshot(
            id: id,
            value: remaining.map { "\($0)%" } ?? "—",
            subtitle: [L10n.window(window?.limitWindowSeconds, language), "\(L10n.text(.resetIn, language)) \(reset)"].joined(separator: " · "),
            rows: [
                MetricRow(label: L10n.text(.plan, language), value: usage.planType ?? "—"),
                MetricRow(label: L10n.text(.used, language), value: used.map { "\($0)%" } ?? "—"),
                MetricRow(label: L10n.text(.credits, language), value: credits),
                MetricRow(label: L10n.text(.reset, language), value: window?.resetAt.map { Fmt.date($0, language: language) } ?? "—"),
            ],
            detailSections: [
                MetricDetailSection(id: "quota", title: L10n.text(.rateLimit, language), rows: quotaRows),
                MetricDetailSection(id: "credits", title: L10n.text(.credits, language), rows: creditRows),
                MetricDetailSection(id: "resetCredits", title: L10n.text(.resetCredits, language), rows: resetCreditRows),
                MetricDetailSection(id: "account", title: L10n.text(.account, language), rows: accountRows),
            ],
            detailStyle: .codexQuota,
            accent: .indigo,
            state: .ready,
            progress: remaining.map(Double.init),
            updatedAt: Date(),
            errorMessage: nil
        )
    }

    private func loadAuth() -> (token: String, accountID: String)? {
        let environment = ProcessInfo.processInfo.environment
        if let token = environment["CODEX_TOKEN"], let accountID = environment["CODEX_ACCOUNT"], !token.isEmpty, !accountID.isEmpty {
            return (token, accountID)
        }

        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = try? Data(contentsOf: url),
              let auth = try? decoder.decode(CodexAuthFile.self, from: data),
              let token = auth.tokens?.accessToken,
              let accountID = auth.tokens?.accountId,
              !token.isEmpty, !accountID.isEmpty else { return nil }
        return (token, accountID)
    }
}

struct YuhaiinTotalFlow: Decodable {
    let download: String?
    let upload: String?
}

final class YuhaiinProvider: MetricProvider {
    let id = StatusMetricID.yuhaiin.rawValue
    private let session: URLSession
    private var settings: AppSettings
    private let lock = NSLock()
    private var previous: (download: Double, upload: Double, at: Date)?

    init(settings: AppSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func update(settings: AppSettings) {
        lock.lock()
        self.settings = settings
        lock.unlock()
    }

    func load(language: AppLanguage) async throws -> MetricSnapshot {
        let currentSettings = currentSettingsValue()

        let base = currentSettings.yuhaiinURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty, let url = URL(string: "\(base)/api/v2/rpc/connections.total") else { throw ProviderError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.httpBody = Data("{}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !currentSettings.yuhaiinToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let token = currentSettings.yuhaiinToken.hasPrefix("Basic ") ? currentSettings.yuhaiinToken : "Basic \(currentSettings.yuhaiinToken)"
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.message("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let flow = try JSONDecoder().decode(YuhaiinTotalFlow.self, from: data)
        guard let download = Double(flow.download ?? ""), let upload = Double(flow.upload ?? "") else { throw ProviderError.invalidResponse }
        let now = Date()
        let old = record(download: download, upload: upload, at: now)

        let downloadRate: Double
        let uploadRate: Double
        if let old, now.timeIntervalSince(old.at) > 0 {
            let interval = now.timeIntervalSince(old.at)
            downloadRate = max(0, (download - old.download) / interval)
            uploadRate = max(0, (upload - old.upload) / interval)
        } else {
            downloadRate = 0
            uploadRate = 0
        }

        return MetricSnapshot(
            id: id,
            value: "↓ \(Fmt.rate(downloadRate))",
            subtitle: "↑ \(Fmt.rate(uploadRate)) · \(L10n.text(.live, language))",
            rows: [
                MetricRow(label: L10n.text(.download, language), value: Fmt.rate(downloadRate)),
                MetricRow(label: L10n.text(.upload, language), value: Fmt.rate(uploadRate)),
                MetricRow(label: "\(L10n.text(.download, language)) \(L10n.text(.total, language))", value: Fmt.bytes(download)),
                MetricRow(label: "\(L10n.text(.upload, language)) \(L10n.text(.total, language))", value: Fmt.bytes(upload)),
            ],
            detailSections: [
                MetricDetailSection(id: "live", title: L10n.text(.summary, language), rows: [
                    MetricRow(label: L10n.text(.download, language), value: Fmt.rate(downloadRate)),
                    MetricRow(label: L10n.text(.upload, language), value: Fmt.rate(uploadRate)),
                    MetricRow(label: "\(L10n.text(.download, language)) \(L10n.text(.total, language))", value: Fmt.bytes(download)),
                    MetricRow(label: "\(L10n.text(.upload, language)) \(L10n.text(.total, language))", value: Fmt.bytes(upload)),
                ]),
                MetricDetailSection(id: "source", title: L10n.text(.endpoint, language), rows: [
                    MetricRow(label: L10n.text(.endpoint, language), value: url.absoluteString),
                    MetricRow(label: L10n.text(.updated, language), value: Fmt.clock(now)),
                ]),
            ],
            detailStyle: .standard,
            accent: .cyan,
            state: .ready,
            progress: nil,
            updatedAt: now,
            errorMessage: nil
        )
    }

    private func currentSettingsValue() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    private func record(download: Double, upload: Double, at: Date) -> (download: Double, upload: Double, at: Date)? {
        lock.lock()
        defer { lock.unlock() }
        let old = previous
        previous = (download, upload, at)
        return old
    }
}
