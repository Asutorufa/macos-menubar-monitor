import Foundation

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

final class AntigravityProvider: MetricProvider {
    let id = StatusMetricID.antigravity.rawValue
    private var settings: AppSettings
    private let lock = NSLock()

    init(settings: AppSettings) {
        self.settings = settings
    }

    func update(settings: AppSettings) {
        lock.lock()
        self.settings = settings
        lock.unlock()
    }

    func load(language: AppLanguage) async throws -> MetricSnapshot {
        let currentSettings = currentSettingsValue()
        let executablePath = try resolveExecutablePath(settings: currentSettings)
        let output = try await runUsageCommand(executablePath: executablePath, timeout: 25)

        if output.exitCode != 0 {
            if !output.stdout.isEmpty {
                do {
                    _ = try AntigravityUsageParser.parse(data: output.stdout)
                } catch let decodeError as AntigravityUsageDecodeError {
                    throw ProviderError.message(decodeError.localizedDescription)
                } catch {
                    // Fall through to stderr/stdout error message below.
                }
            }
            let message = Self.commandFailureMessage(stdout: output.stdout, stderr: output.stderr, exitCode: output.exitCode)
            throw ProviderError.message(message)
        }

        let parsed: AntigravityParsedUsage
        do {
            parsed = try AntigravityUsageParser.parse(data: output.stdout)
        } catch let decodeError as AntigravityUsageDecodeError {
            switch decodeError {
            case .commandFailed(let message):
                throw ProviderError.message(message)
            case .emptyQuota:
                throw ProviderError.invalidResponse
            }
        }

        let now = Date()
        let lowestGroup = parsed.lowestGroup
        let lowestBucket = parsed.lowestBucket
        let lowestShortWindow = L10n.antigravityShortWindow(lowestBucket.window, fallbackName: lowestBucket.name, language)
        let lowestLabel = "\(lowestGroup.shortName) \(lowestShortWindow)"
        let lowestResetAt = lowestBucket.resetDate.map { Fmt.date($0.timeIntervalSince1970, language: language) } ?? "—"
        let lowestResetIn = lowestBucket.resetAfterSeconds(relativeTo: now).map { L10n.duration($0, language) } ?? "—"

        let subtitle: String
        if lowestBucket.resetDate != nil {
            subtitle = "\(lowestLabel) · \(L10n.text(.resetIn, language)) \(lowestResetIn)"
        } else {
            subtitle = lowestLabel
        }

        var summaryRows: [MetricRow] = []
        var usedLabels = Set<String>()
        for group in parsed.groups.prefix(2) {
            let label = Self.uniqueLabel(group.shortName, used: &usedLabels)
            let value = group.buckets.map { "\($0.remainingPercent)%" }.joined(separator: " / ")
            summaryRows.append(MetricRow(label: label, value: value))
        }
        if parsed.groups.count > 2 {
            let thirdGroup = parsed.groups[2]
            let label = Self.uniqueLabel(thirdGroup.shortName, used: &usedLabels)
            let value = thirdGroup.buckets.map { "\($0.remainingPercent)%" }.joined(separator: " / ")
            summaryRows.append(MetricRow(label: label, value: value))
        } else {
            let resetLabel = Self.uniqueLabel(L10n.text(.reset, language), used: &usedLabels)
            summaryRows.append(MetricRow(label: resetLabel, value: lowestResetAt))
        }

        var groupDetails: [AntigravityGroupDetail] = []
        var detailSections: [MetricDetailSection] = []

        for (groupIndex, group) in parsed.groups.enumerated() {
            var sectionRows: [MetricRow] = []
            var sectionLabels = Set<String>()
            var bucketDetails: [AntigravityBucketDetail] = []

            for (bucketIndex, bucket) in group.buckets.enumerated() {
                let title = L10n.antigravityWindow(bucket.window, fallbackName: bucket.name, language)
                let resetAt = bucket.resetDate.map { Fmt.date($0.timeIntervalSince1970, language: language) } ?? "—"
                let resetIn = bucket.resetAfterSeconds(relativeTo: now).map { L10n.duration($0, language) } ?? "—"

                bucketDetails.append(AntigravityBucketDetail(
                    id: "\(groupIndex)-\(bucketIndex)-\(bucket.id)",
                    title: title,
                    window: bucket.window,
                    remainingPercent: bucket.remainingPercent,
                    remainingProgress: bucket.remainingProgress,
                    resetAt: resetAt,
                    resetIn: resetIn
                ))

                let rowLabel = Self.uniqueLabel(title, used: &sectionLabels)
                let rowValue = bucket.resetDate != nil
                    ? "\(bucket.remainingPercent)% (\(L10n.text(.resetIn, language)) \(resetIn))"
                    : "\(bucket.remainingPercent)%"
                sectionRows.append(MetricRow(label: rowLabel, value: rowValue))
            }

            groupDetails.append(AntigravityGroupDetail(
                id: "\(groupIndex)-\(group.name)",
                name: group.name,
                shortName: group.shortName,
                modelsDescription: group.description,
                lowestPercent: group.lowestBucket?.remainingPercent ?? 0,
                buckets: bucketDetails
            ))

            detailSections.append(MetricDetailSection(
                id: "group-\(groupIndex)",
                title: group.name,
                rows: sectionRows
            ))
        }

        detailSections.append(MetricDetailSection(
            id: "source",
            title: L10n.text(.cliPath, language),
            rows: [
                MetricRow(label: L10n.text(.cliPath, language), value: executablePath),
                MetricRow(label: L10n.text(.updated, language), value: Fmt.clock(now)),
            ]
        ))

        let detail = AntigravityDetail(
            lowestLabel: lowestLabel,
            lowestResetAt: lowestResetAt,
            lowestResetIn: lowestResetIn,
            summary: parsed.description,
            cliPath: executablePath,
            groups: groupDetails
        )

        return MetricSnapshot(
            id: id,
            value: "\(lowestBucket.remainingPercent)%",
            subtitle: subtitle,
            rows: summaryRows,
            detailSections: detailSections,
            detailStyle: .antigravityQuota,
            accent: .emerald,
            state: .ready,
            progress: lowestBucket.remainingProgress,
            updatedAt: now,
            errorMessage: nil,
            antigravityDetail: detail
        )
    }

    private func currentSettingsValue() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    private func resolveExecutablePath(settings: AppSettings) throws -> String {
        let configured = settings.antigravityCLIPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return try resolveExplicitPath(configured)
        }

        let environment = ProcessInfo.processInfo.environment
        for key in ["AGY_PATH", "ANTIGRAVITY_CLI"] {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return try resolveExplicitPath(value)
            }
        }

        if let discovered = findExecutable(named: "agy", in: searchDirectories()) {
            return discovered
        }

        throw ProviderError.notConfigured
    }

    private func resolveExplicitPath(_ raw: String) throws -> String {
        let expanded = (raw as NSString).expandingTildeInPath
        if expanded.contains("/") {
            guard FileManager.default.isExecutableFile(atPath: expanded) else {
                throw ProviderError.message("Antigravity CLI not found at \(expanded)")
            }
            return expanded
        }
        if let resolved = findExecutable(named: expanded, in: searchDirectories()) {
            return resolved
        }
        throw ProviderError.message("Antigravity CLI '\(expanded)' not found in PATH.")
    }

    private func searchDirectories() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let envPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let standardPaths = [
            "\(home)/.antigravity/antigravity/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/Applications/Antigravity.app/Contents/Resources/app/bin",
            "\(home)/Applications/Antigravity.app/Contents/Resources/app/bin",
            "/usr/bin",
            "/bin",
        ]
        var seen = Set<String>()
        var result: [String] = []
        for dir in envPaths + standardPaths where !dir.isEmpty {
            if seen.insert(dir).inserted {
                result.append(dir)
            }
        }
        return result
    }

    private func findExecutable(named name: String, in directories: [String]) -> String? {
        for directory in directories {
            let candidate = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent(name)
                .path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func augmentedEnvironment(for executablePath: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let executableDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        var seen = Set<String>()
        var pathParts: [String] = []
        for dir in [executableDir] + searchDirectories() + ["/usr/sbin", "/sbin"] where !dir.isEmpty {
            if seen.insert(dir).inserted {
                pathParts.append(dir)
            }
        }
        environment["PATH"] = pathParts.joined(separator: ":")
        return environment
    }

    private struct CommandOutput {
        let stdout: Data
        let stderr: Data
        let exitCode: Int32
    }

    private final class ProcessExecutionState: @unchecked Sendable {
        enum FinishOutcome {
            case cancelled
            case timedOut
            case completed
        }

        private let lock = NSLock()
        private let process: Process
        private var launched = false
        private var cancelled = false
        private var timedOut = false
        private var timeoutItem: DispatchWorkItem?

        init(process: Process) {
            self.process = process
        }

        func canLaunch() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return !cancelled
        }

        func markLaunched(timeout: TimeInterval) {
            var shouldTerminateNow = false
            let item = DispatchWorkItem { [weak self] in
                self?.triggerTimeout()
            }
            lock.lock()
            launched = true
            if cancelled {
                shouldTerminateNow = true
            } else {
                timeoutItem = item
            }
            lock.unlock()

            if shouldTerminateNow {
                terminateIfRunning()
            } else {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: item)
            }
        }

        func cancel() {
            var shouldTerminate = false
            lock.lock()
            cancelled = true
            timeoutItem?.cancel()
            timeoutItem = nil
            shouldTerminate = launched
            lock.unlock()

            if shouldTerminate {
                terminateIfRunning()
            }
        }

        func finish() -> FinishOutcome {
            lock.lock()
            timeoutItem?.cancel()
            timeoutItem = nil
            let outcome: FinishOutcome
            if cancelled {
                outcome = .cancelled
            } else if timedOut {
                outcome = .timedOut
            } else {
                outcome = .completed
            }
            lock.unlock()
            return outcome
        }

        private func triggerTimeout() {
            var shouldTerminate = false
            lock.lock()
            if !cancelled {
                timedOut = true
                shouldTerminate = launched
            }
            timeoutItem = nil
            lock.unlock()

            if shouldTerminate {
                terminateIfRunning()
            }
        }

        private func terminateIfRunning() {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    private func runUsageCommand(executablePath: String, timeout: TimeInterval) async throws -> CommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["-p", "/usage", "--output-format", "json"]
        process.environment = augmentedEnvironment(for: executablePath)
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let state = ProcessExecutionState(process: process)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    guard state.canLaunch() else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: ProviderError.message("Failed to run agy: \(error.localizedDescription)"))
                        return
                    }

                    state.markLaunched(timeout: timeout)

                    let readGroup = DispatchGroup()
                    let stderrBox = DataBox()
                    readGroup.enter()
                    DispatchQueue.global(qos: .utility).async {
                        stderrBox.data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        readGroup.leave()
                    }

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    readGroup.wait()
                    process.waitUntilExit()

                    switch state.finish() {
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    case .timedOut:
                        continuation.resume(throwing: ProviderError.message("Antigravity CLI timed out."))
                    case .completed:
                        continuation.resume(returning: CommandOutput(
                            stdout: stdoutData,
                            stderr: stderrBox.data,
                            exitCode: process.terminationStatus
                        ))
                    }
                }
            }
        } onCancel: {
            state.cancel()
        }
    }

    private static func commandFailureMessage(stdout: Data, stderr: Data, exitCode: Int32) -> String {
        for data in [stderr, stdout] {
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                let firstLine = text.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty } ?? text
                if firstLine.count > 240 {
                    return String(firstLine.prefix(240)) + "…"
                }
                return firstLine
            }
        }
        return "agy exited with status \(exitCode)."
    }

    private static func uniqueLabel(_ base: String, used: inout Set<String>) -> String {
        if used.insert(base).inserted { return base }
        var suffix = 2
        while !used.insert("\(base) \(suffix)").inserted {
            suffix += 1
        }
        return "\(base) \(suffix)"
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
        let credential = currentSettings.yuhaiinToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !credential.isEmpty {
            if credential.lowercased().hasPrefix("basic ") {
                throw ProviderError.message("Yuhaiin no longer supports Basic authentication. Use an API token with connections:read permission.")
            }
            let token = credential.lowercased().hasPrefix("bearer ")
                ? String(credential.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                : credential
            guard !token.isEmpty else { throw ProviderError.notConfigured }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw ProviderError.message("HTTP 401: Invalid or expired Yuhaiin API token.")
        case 403:
            throw ProviderError.message("HTTP 403: Check the connections:read scope and management endpoint access.")
        default:
            throw ProviderError.message("HTTP \(http.statusCode)")
        }

        let flow = try JSONDecoder().decode(YuhaiinTotalFlow.self, from: data)
        guard let download = Double(flow.download ?? ""), let upload = Double(flow.upload ?? "") else { throw ProviderError.invalidResponse }
        let now = Date()
        let old = record(download: download, upload: upload, at: now)

        let downloadRate: Double
        let uploadRate: Double
        let liveRate: LiveRate?
        if let old, now.timeIntervalSince(old.at) > 0 {
            let interval = now.timeIntervalSince(old.at)
            downloadRate = max(0, (download - old.download) / interval)
            uploadRate = max(0, (upload - old.upload) / interval)
            liveRate = LiveRate(download: downloadRate, upload: uploadRate, at: now)
        } else {
            downloadRate = 0
            uploadRate = 0
            liveRate = nil
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
            errorMessage: nil,
            liveRate: liveRate
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
