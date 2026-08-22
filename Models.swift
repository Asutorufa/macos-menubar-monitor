import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    static var detected: AppLanguage {
        let identifier = Locale.preferredLanguages.first?.lowercased() ?? ""
        if identifier.hasPrefix("ja") { return .japanese }
        if identifier.hasPrefix("ko") { return .korean }
        if identifier.hasPrefix("zh") { return .traditionalChinese }
        return .english
    }
}

enum StatusMetricID: String, CaseIterable, Identifiable {
    case codex
    case lightsail
    case yuhaiin
    case cycle

    var id: String { rawValue }
}

enum MetricAccent {
    case indigo
    case amber
    case cyan
    case neutral
    case warning
}

enum MetricState {
    case ready
    case loading
    case unavailable
    case failed
}

struct MetricRow: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

struct MetricDetailSection: Identifiable {
    let id: String
    let title: String
    let rows: [MetricRow]
}

enum MetricDetailStyle: Equatable {
    case standard
    case codexQuota
}

struct MetricSnapshot: Identifiable {
    let id: String
    let value: String
    let subtitle: String
    let rows: [MetricRow]
    let detailSections: [MetricDetailSection]
    let detailStyle: MetricDetailStyle
    let accent: MetricAccent
    let state: MetricState
    let progress: Double?
    let updatedAt: Date?
    let errorMessage: String?
}

protocol MetricProvider: AnyObject {
    var id: String { get }
    func update(settings: AppSettings)
    func load(language: AppLanguage) async throws -> MetricSnapshot
}

enum ProviderError: LocalizedError {
    case notConfigured
    case invalidResponse
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Provider is not configured."
        case .invalidResponse: return "The provider returned an invalid response."
        case .message(let message): return message
        }
    }
}

struct AppSettings: Codable, Equatable {
    var language: AppLanguage = .detected
    var statusMetricID: String = StatusMetricID.codex.rawValue
    var codexRefreshInterval: Double = 300
    var lightsailRefreshInterval: Double = 600
    var yuhaiinRefreshInterval: Double = 5
    var cycleDisplayInterval: Double = 8

    var yuhaiinURL: String = "http://127.0.0.1:50051"

    var awsRegion: String = ""
    var awsProfile: String = "default"

    // Secrets are loaded from Keychain by SettingsStore and intentionally
    // omitted from the JSON settings file.
    var yuhaiinToken: String = ""
    var awsAccessKey: String = ""
    var awsSecretKey: String = ""
    var awsSessionToken: String = ""
    var credentialsConfigured: Bool = false

    enum CodingKeys: String, CodingKey {
        case language
        case statusMetricID
        case codexRefreshInterval
        case lightsailRefreshInterval
        case yuhaiinRefreshInterval
        case cycleDisplayInterval
        case yuhaiinURL
        case awsRegion
        case awsProfile
        case credentialsConfigured
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case refreshInterval
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .detected
        statusMetricID = try container.decodeIfPresent(String.self, forKey: .statusMetricID) ?? StatusMetricID.codex.rawValue

        // Migrate the original single refresh interval when loading an older file.
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let legacyInterval = try legacyContainer.decodeIfPresent(Double.self, forKey: .refreshInterval)
        codexRefreshInterval = try container.decodeIfPresent(Double.self, forKey: .codexRefreshInterval) ?? legacyInterval ?? 300
        lightsailRefreshInterval = try container.decodeIfPresent(Double.self, forKey: .lightsailRefreshInterval) ?? legacyInterval ?? 600
        yuhaiinRefreshInterval = try container.decodeIfPresent(Double.self, forKey: .yuhaiinRefreshInterval) ?? legacyInterval ?? 5
        cycleDisplayInterval = try container.decodeIfPresent(Double.self, forKey: .cycleDisplayInterval) ?? 8

        yuhaiinURL = try container.decodeIfPresent(String.self, forKey: .yuhaiinURL) ?? "http://127.0.0.1:50051"
        awsRegion = try container.decodeIfPresent(String.self, forKey: .awsRegion) ?? ""
        awsProfile = try container.decodeIfPresent(String.self, forKey: .awsProfile) ?? "default"
        // Older settings files may already have Keychain entries. Treat the
        // missing marker as configured once so they can be migrated.
        credentialsConfigured = try container.decodeIfPresent(Bool.self, forKey: .credentialsConfigured) ?? true
    }

    var hasCredentials: Bool {
        !yuhaiinToken.isEmpty || !awsAccessKey.isEmpty || !awsSecretKey.isEmpty || !awsSessionToken.isEmpty
    }

    var selectedMetric: StatusMetricID {
        get { StatusMetricID(rawValue: statusMetricID) ?? .codex }
        set { statusMetricID = newValue.rawValue }
    }
}
