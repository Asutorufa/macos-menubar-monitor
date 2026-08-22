import Foundation
import CryptoKit

struct AWSCredentials {
    let accessKey: String
    let secretKey: String
    let sessionToken: String?
}

enum AWSClientError: LocalizedError {
    case credentialsMissing
    case invalidRegion
    case requestFailed(String)
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .credentialsMissing: return "AWS credentials are missing."
        case .invalidRegion: return "AWS region is invalid."
        case .requestFailed(let message): return message
        case .invalidJSON: return "AWS returned invalid JSON."
        }
    }
}

enum AWSCredentialsResolver {
    static func resolve(_ settings: AppSettings) -> AWSCredentials? {
        let access = settings.awsAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = settings.awsSecretKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !access.isEmpty, !secret.isEmpty {
            return AWSCredentials(accessKey: access, secretKey: secret, sessionToken: settings.awsSessionToken.nilIfEmpty)
        }

        let environment = ProcessInfo.processInfo.environment
        if let access = environment["AWS_ACCESS_KEY_ID"], let secret = environment["AWS_SECRET_ACCESS_KEY"], !access.isEmpty, !secret.isEmpty {
            return AWSCredentials(accessKey: access, secretKey: secret, sessionToken: environment["AWS_SESSION_TOKEN"]?.nilIfEmpty)
        }

        let profile = profileName(settings)
        let values = iniValues(file: "credentials", profile: profile)
        guard let access = values["aws_access_key_id"], let secret = values["aws_secret_access_key"], !access.isEmpty, !secret.isEmpty else { return nil }
        return AWSCredentials(accessKey: access, secretKey: secret, sessionToken: values["aws_session_token"]?.nilIfEmpty)
    }

    static func region(_ settings: AppSettings) -> String {
        if let explicit = settings.awsRegion.nilIfEmpty { return explicit }
        let environment = ProcessInfo.processInfo.environment
        if let value = environment["AWS_REGION"]?.nilIfEmpty { return value }
        if let value = environment["AWS_DEFAULT_REGION"]?.nilIfEmpty { return value }
        let profile = profileName(settings)
        return iniValues(file: "config", profile: profile)["region"]?.nilIfEmpty ?? "ap-northeast-1"
    }

    private static func profileName(_ settings: AppSettings) -> String {
        ProcessInfo.processInfo.environment["AWS_PROFILE"]?.nilIfEmpty ?? settings.awsProfile.nilIfEmpty ?? "default"
    }

    private static func iniValues(file: String, profile: String) -> [String: String] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws", isDirectory: true)
            .appendingPathComponent(file)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var current = ""
        var values: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                current = String(trimmed.dropFirst().dropLast())
                continue
            }
            let sectionMatches = current == profile || current == "profile \(profile)"
            guard sectionMatches, let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            values[String(key)] = String(value)
        }
        return values
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

final class AWSSignedJSONClient {
    private let credentials: AWSCredentials
    private let session: URLSession

    init(credentials: AWSCredentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    func query(service: String, region: String, action: String, targetPrefix: String? = nil, parameters: [String: Any]) async throws -> Data {
        guard !region.isEmpty else { throw AWSClientError.invalidRegion }
        let host = "\(service).\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/") else { throw AWSClientError.invalidRegion }
        let target = "\(targetPrefix ?? "Lightsail_20161128").\(action)"
        let body = try JSONSerialization.data(withJSONObject: parameters, options: [])
        let payloadHash = Self.sha256(body)
        let timestamp = Self.signingTimestamp(Date())
        let shortDate = String(timestamp.prefix(8))
        let scope = "\(shortDate)/\(region)/\(service)/aws4_request"
        let contentType = "application/x-amz-json-1.1"

        var signedHeaders = [
            "content-type": contentType,
            "host": host,
            "x-amz-target": target,
        ]
        if let token = credentials.sessionToken { signedHeaders["x-amz-security-token"] = token }
        let canonicalHeaders = signedHeaders.keys.sorted().map { "\($0):\((signedHeaders[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines))\n" }.joined()
        let signedHeaderNames = signedHeaders.keys.sorted().joined(separator: ";")
        let canonicalRequest = ["POST", "/", "", canonicalHeaders, signedHeaderNames, payloadHash].joined(separator: "\n")
        let stringToSign = ["AWS4-HMAC-SHA256", timestamp, scope, Self.sha256(Data(canonicalRequest.utf8))].joined(separator: "\n")
        let signingKey = Self.signingKey(secret: credentials.secretKey, date: shortDate, region: region, service: service)
        let signature = Self.hex(HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: SymmetricKey(data: signingKey)))
        let authorization = "AWS4-HMAC-SHA256 Credential=\(credentials.accessKey)/\(scope), SignedHeaders=\(signedHeaderNames), Signature=\(signature)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(target, forHTTPHeaderField: "X-Amz-Target")
        request.setValue(timestamp, forHTTPHeaderField: "X-Amz-Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        if let token = credentials.sessionToken { request.setValue(token, forHTTPHeaderField: "X-Amz-Security-Token") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AWSClientError.requestFailed("Invalid AWS response.") }
        guard (200..<300).contains(http.statusCode) else {
            throw AWSClientError.requestFailed(AWSJSON.errorMessage(data) ?? "AWS HTTP \(http.statusCode)")
        }
        return data
    }

    private static func signingTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func signingKey(secret: String, date: String, region: String, service: String) -> Data {
        let dateKey = HMAC<SHA256>.authenticationCode(for: Data(date.utf8), using: SymmetricKey(data: Data("AWS4\(secret)".utf8)))
        let regionKey = HMAC<SHA256>.authenticationCode(for: Data(region.utf8), using: SymmetricKey(data: Data(dateKey)))
        let serviceKey = HMAC<SHA256>.authenticationCode(for: Data(service.utf8), using: SymmetricKey(data: Data(regionKey)))
        let signingKey = HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: SymmetricKey(data: Data(serviceKey)))
        return Data(signingKey)
    }

    private static func sha256(_ data: Data) -> String { hex(SHA256.hash(data: data)) }

    private static func hex<T: Sequence>(_ bytes: T) -> String where T.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

private enum AWSJSON {
    static func errorMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["message"] as? String) ?? (object["Message"] as? String) ?? (object["__type"] as? String)
    }
}

struct LightsailInstance {
    let name: String
    let bundleID: String
    let blueprintID: String?
    let state: String?
    let publicIP: String?
}

struct LightsailBundle {
    let id: String
    let transferGB: Double
    let cpuCount: Int?
    let ramGB: Double?
    let diskGB: Double?
    let priceUSD: Double?
}

private struct LightsailInstancesResponse: Decodable { let instances: [LightsailInstanceJSON]? }

private struct LightsailInstanceJSON: Decodable {
    let name: String?
    let bundleID: String?
    let blueprintID: String?
    let state: LightsailStateJSON?
    let publicIP: String?
    enum CodingKeys: String, CodingKey {
        case name
        case bundleID = "bundleId"
        case blueprintID = "blueprintId"
        case state
        case publicIP = "publicIpAddress"
    }
}

private struct LightsailStateJSON: Decodable { let name: String? }

private struct LightsailBundlesResponse: Decodable { let bundles: [LightsailBundleJSON]? }

private struct LightsailBundleJSON: Decodable {
    let bundleID: String?
    let transferPerMonthInGB: Double?
    let cpuCount: Int?
    let ramSizeInGB: Double?
    let diskSizeInGB: Double?
    let price: Double?
    enum CodingKeys: String, CodingKey {
        case bundleID = "bundleId"
        case transferPerMonthInGB = "transferPerMonthInGb"
        case cpuCount
        case ramSizeInGB = "ramSizeInGb"
        case diskSizeInGB = "diskSizeInGb"
        case price
    }
}

private struct LightsailMetricResponse: Decodable { let metricData: [LightsailMetricPoint]? }
private struct LightsailMetricPoint: Decodable { let sum: Double? }

private struct LightsailUsageDetail {
    let instance: LightsailInstance
    let region: String
    let bundle: LightsailBundle?
    let networkIn: Double
    let networkOut: Double
    let error: String?
}

struct LightsailBillingUsage {
    let networkIn: Double
    let networkOut: Double
    let estimated: Bool
    let fetchedAt: Date

    var total: Double { networkIn + networkOut }
}

final class LightsailProvider: MetricProvider {
    let id = StatusMetricID.lightsail.rawValue
    private var settings: AppSettings
    private let lock = NSLock()
    private static let billingCacheLock = NSLock()
    private static var billingCache: [String: LightsailBillingUsage] = [:]
    private static let billingCacheTTL: TimeInterval = 86_400

    private static func cachedBilling(for key: String) -> LightsailBillingUsage? {
        billingCacheLock.lock()
        defer { billingCacheLock.unlock() }
        guard let value = billingCache[key], Date().timeIntervalSince(value.fetchedAt) < billingCacheTTL else { return nil }
        return value
    }

    private static func storeBilling(_ value: LightsailBillingUsage, for key: String) {
        billingCacheLock.lock()
        billingCache[key] = value
        billingCacheLock.unlock()
    }

    init(settings: AppSettings) { self.settings = settings }

    func update(settings: AppSettings) {
        lock.lock()
        self.settings = settings
        lock.unlock()
    }

    func load(language: AppLanguage) async throws -> MetricSnapshot {
        let currentSettings = currentSettingsValue()
        guard let credentials = AWSCredentialsResolver.resolve(currentSettings) else { throw AWSClientError.credentialsMissing }
        let regions = AWSCredentialsResolver.region(currentSettings).split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !regions.isEmpty else { throw AWSClientError.invalidRegion }
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let client = AWSSignedJSONClient(credentials: credentials)

        var instances: [(LightsailInstance, String, [String: LightsailBundle])] = []
        for region in regions {
            let found = try await getInstances(client: client, region: region)
            guard !found.isEmpty else { continue }
            let bundles = try await getBundles(client: client, region: region)
            instances.append(contentsOf: found.map { ($0, region, bundles) })
        }

        var allowance = 0.0
        var used = 0.0
        var errors: [String] = []
        var usageDetails: [LightsailUsageDetail] = []
        for (instance, region, bundles) in instances {
            let bundle = bundles[instance.bundleID]
            allowance += (bundle?.transferGB ?? 0) * 1024 * 1024 * 1024
            do {
                async let inputData = metric(client: client, region: region, instance: instance, name: "NetworkIn", start: start, end: now)
                async let outputData = metric(client: client, region: region, instance: instance, name: "NetworkOut", start: start, end: now)
                let (input, output) = try await (inputData, outputData)
                used += input + output
                usageDetails.append(LightsailUsageDetail(instance: instance, region: region, bundle: bundle, networkIn: input, networkOut: output, error: nil))
            } catch {
                errors.append(error.localizedDescription)
                usageDetails.append(LightsailUsageDetail(instance: instance, region: region, bundle: bundle, networkIn: 0, networkOut: 0, error: error.localizedDescription))
            }
        }

        let remaining = max(allowance - used, 0)
        let billing: LightsailBillingUsage?
        let billingError: String?
        do {
            billing = try await getBillingUsage(credentials: credentials, profile: currentSettings.awsProfile)
            billingError = nil
        } catch {
            billing = nil
            billingError = error.localizedDescription
        }
        // Billing data is useful context but may lag by roughly a day. The
        // primary status therefore always follows the near-real-time metrics.
        let percent = allowance > 0 ? remaining / allowance * 100 : nil
        let subtitle = "\(Fmt.percent(percent)) \(L10n.text(.remaining, language)) · \(instances.count) \(L10n.text(.instances, language))"
        let status = errors.count == instances.count && !instances.isEmpty ? MetricState.failed : .ready
        var summaryRows = [
            MetricRow(label: L10n.text(.used, language), value: Fmt.bytes(used)),
            MetricRow(label: L10n.text(.total, language), value: Fmt.bytes(allowance)),
            MetricRow(label: L10n.text(.remaining, language), value: Fmt.bytes(remaining)),
            MetricRow(label: L10n.text(.instances, language), value: "\(instances.count)"),
            MetricRow(label: L10n.text(.period, language), value: "\(Fmt.date(start.timeIntervalSince1970, language: language)) – \(Fmt.date(now.timeIntervalSince1970, language: language))"),
        ]
        var detailSections = [MetricDetailSection(id: "summary", title: L10n.text(.summary, language), rows: summaryRows)]
        if let billing {
            let billingRows = [
                MetricRow(label: L10n.text(.billingUsage, language), value: Fmt.bytes(billing.total)),
                MetricRow(label: L10n.text(.billingRemaining, language), value: Fmt.bytes(max(allowance - billing.total, 0))),
                MetricRow(label: L10n.text(.billingIn, language), value: Fmt.bytes(billing.networkIn)),
                MetricRow(label: L10n.text(.billingOut, language), value: Fmt.bytes(billing.networkOut)),
                MetricRow(label: L10n.text(.estimated, language), value: billing.estimated ? L10n.text(.yes, language) : L10n.text(.no, language)),
                MetricRow(label: L10n.text(.fetchedAt, language), value: Fmt.clock(billing.fetchedAt)),
            ]
            detailSections.append(MetricDetailSection(id: "billing", title: L10n.text(.billing, language), rows: billingRows))
            summaryRows.insert(MetricRow(label: L10n.text(.billingUsage, language), value: Fmt.bytes(billing.total)), at: 0)
            summaryRows.insert(MetricRow(label: L10n.text(.billingRemaining, language), value: Fmt.bytes(max(allowance - billing.total, 0))), at: 1)
            detailSections[0] = MetricDetailSection(id: "summary", title: L10n.text(.summary, language), rows: summaryRows)
        } else if let billingError {
            detailSections.append(MetricDetailSection(id: "billing", title: L10n.text(.billing, language), rows: [
                MetricRow(label: L10n.text(.status, language), value: L10n.text(.billingUnavailable, language)),
                MetricRow(label: L10n.text(.error, language), value: billingError),
            ]))
        }
        for detail in usageDetails {
            let instance = detail.instance
            let bundle = detail.bundle
            var specs: [String] = []
            if let cpu = bundle?.cpuCount { specs.append("\(cpu) vCPU") }
            if let ram = bundle?.ramGB { specs.append("\(ram) GB RAM") }
            if let disk = bundle?.diskGB { specs.append("\(disk) GB SSD") }
            if let price = bundle?.priceUSD { specs.append(String(format: "$%.2f/%@", price, L10n.text(.monthly, language))) }
            let instanceRows = [
                MetricRow(label: L10n.text(.awsRegion, language), value: detail.region),
                MetricRow(label: L10n.text(.state, language), value: instance.state ?? "—"),
                MetricRow(label: L10n.text(.publicIP, language), value: instance.publicIP ?? "—"),
                MetricRow(label: L10n.text(.bundle, language), value: instance.bundleID),
                MetricRow(label: L10n.text(.specification, language), value: specs.isEmpty ? "—" : specs.joined(separator: " · ")),
                MetricRow(label: L10n.text(.system, language), value: instance.blueprintID ?? "—"),
                MetricRow(label: L10n.text(.allowance, language), value: bundle.map { Fmt.bytes($0.transferGB * 1024 * 1024 * 1024) } ?? "—"),
                MetricRow(label: L10n.text(.networkIn, language), value: Fmt.bytes(detail.networkIn)),
                MetricRow(label: L10n.text(.networkOut, language), value: Fmt.bytes(detail.networkOut)),
                MetricRow(label: L10n.text(.total, language), value: Fmt.bytes(detail.networkIn + detail.networkOut)),
                MetricRow(label: L10n.text(.status, language), value: detail.error ?? L10n.text(.ready, language)),
            ]
            detailSections.append(MetricDetailSection(id: "instance-\(detail.region)-\(instance.name)", title: instance.name, rows: instanceRows))
        }
        return MetricSnapshot(
            id: id,
            value: allowance > 0 ? Fmt.bytes(remaining) : "—",
            subtitle: subtitle,
            rows: billing.map { [
                MetricRow(label: L10n.text(.used, language), value: Fmt.bytes(used)),
                MetricRow(label: L10n.text(.remaining, language), value: Fmt.bytes(remaining)),
                MetricRow(label: L10n.text(.billingUsage, language), value: Fmt.bytes($0.total)),
                MetricRow(label: L10n.text(.status, language), value: errors.isEmpty ? L10n.text(.ready, language) : errors[0]),
            ] } ?? [
                MetricRow(label: L10n.text(.used, language), value: Fmt.bytes(used)),
                MetricRow(label: L10n.text(.total, language), value: Fmt.bytes(allowance)),
                MetricRow(label: L10n.text(.observed, language), value: Fmt.bytes(used)),
                MetricRow(label: L10n.text(.status, language), value: errors.isEmpty ? L10n.text(.ready, language) : errors[0]),
            ],
            detailSections: detailSections,
            detailStyle: .standard,
            accent: .amber,
            state: status,
            progress: percent,
            updatedAt: Date(),
            errorMessage: errors.isEmpty ? billingError : errors.joined(separator: "\n")
        )
    }

    private func getBillingUsage(credentials: AWSCredentials, profile: String) async throws -> LightsailBillingUsage {
        let cacheKey = profile.isEmpty ? "default" : profile
        if let cached = Self.cachedBilling(for: cacheKey) { return cached }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let parameters: [String: Any] = [
            "TimePeriod": ["Start": formatter.string(from: monthStart), "End": formatter.string(from: end)],
            "Granularity": "MONTHLY",
            "Metrics": ["UsageQuantity"],
            "Filter": ["Dimensions": ["Key": "SERVICE", "Values": ["Amazon Lightsail"]]],
            "GroupBy": [["Type": "DIMENSION", "Key": "USAGE_TYPE"]],
        ]
        let client = AWSSignedJSONClient(credentials: credentials)
        let data = try await client.query(service: "ce", region: "us-east-1", action: "GetCostAndUsage", targetPrefix: "AWSInsightsIndexService", parameters: parameters)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AWSClientError.invalidJSON }
        let results = root["ResultsByTime"] as? [[String: Any]] ?? []
        var networkIn = 0.0
        var networkOut = 0.0
        var estimated = false
        for result in results {
            estimated = estimated || (result["Estimated"] as? Bool ?? false)
            for group in result["Groups"] as? [[String: Any]] ?? [] {
                guard let usageType = (group["Keys"] as? [String])?.first,
                      let metrics = group["Metrics"] as? [String: Any],
                      let usage = metrics["UsageQuantity"] as? [String: Any] else { continue }
                let amount: Double
                if let raw = usage["Amount"] as? String { amount = Double(raw) ?? 0 }
                else if let raw = usage["Amount"] as? NSNumber { amount = raw.doubleValue }
                else { amount = 0 }
                let bytes = billingAmountToBytes(amount, unit: usage["Unit"] as? String ?? "GB")
                let normalized = usageType.lowercased()
                if normalized.hasSuffix("-totaldataxfer-in-bytes") || normalized.contains("dataxfer-in") {
                    networkIn += bytes
                } else if normalized.hasSuffix("-totaldataxfer-out-bytes") || normalized.contains("dataxfer-out") {
                    networkOut += bytes
                }
            }
        }
        let billing = LightsailBillingUsage(networkIn: networkIn, networkOut: networkOut, estimated: estimated, fetchedAt: Date())
        Self.storeBilling(billing, for: cacheKey)
        return billing
    }

    private func billingAmountToBytes(_ amount: Double, unit: String) -> Double {
        switch unit.uppercased() {
        case "BYTES", "BYTE": return amount
        case "KB": return amount * 1024
        case "MB": return amount * 1024 * 1024
        case "GB": return amount * 1024 * 1024 * 1024
        case "TB": return amount * 1024 * 1024 * 1024 * 1024
        default: return amount * 1024 * 1024 * 1024
        }
    }

    private func currentSettingsValue() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    private func getInstances(client: AWSSignedJSONClient, region: String) async throws -> [LightsailInstance] {
        let data = try await client.query(service: "lightsail", region: region, action: "GetInstances", parameters: [:])
        guard let response = try? JSONDecoder().decode(LightsailInstancesResponse.self, from: data) else { throw AWSClientError.invalidJSON }
        return (response.instances ?? []).compactMap { item in
            guard let name = item.name, let bundleID = item.bundleID else { return nil }
            return LightsailInstance(name: name, bundleID: bundleID, blueprintID: item.blueprintID, state: item.state?.name, publicIP: item.publicIP)
        }
    }

    private func getBundles(client: AWSSignedJSONClient, region: String) async throws -> [String: LightsailBundle] {
        let data = try await client.query(service: "lightsail", region: region, action: "GetBundles", parameters: ["includeInactive": false])
        guard let response = try? JSONDecoder().decode(LightsailBundlesResponse.self, from: data) else { throw AWSClientError.invalidJSON }
        var result: [String: LightsailBundle] = [:]
        for item in response.bundles ?? [] {
            guard let id = item.bundleID, let transfer = item.transferPerMonthInGB else { continue }
            result[id] = LightsailBundle(id: id, transferGB: transfer, cpuCount: item.cpuCount, ramGB: item.ramSizeInGB, diskGB: item.diskSizeInGB, priceUSD: item.price)
        }
        return result
    }

    private func metric(client: AWSSignedJSONClient, region: String, instance: LightsailInstance, name: String, start: Date, end: Date) async throws -> Double {
        let parameters: [String: Any] = [
            "instanceName": instance.name,
            "metricName": name,
            "period": 3600,
            "startTime": Int(start.timeIntervalSince1970),
            "endTime": Int(end.timeIntervalSince1970),
            "unit": "Bytes",
            "statistics": ["Sum"],
        ]
        let data = try await client.query(service: "lightsail", region: region, action: "GetInstanceMetricData", parameters: parameters)
        guard let response = try? JSONDecoder().decode(LightsailMetricResponse.self, from: data) else { throw AWSClientError.invalidJSON }
        return (response.metricData ?? []).reduce(0) { $0 + ($1.sum ?? 0) }
    }
}
