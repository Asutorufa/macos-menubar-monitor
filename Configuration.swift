import Foundation
import Security

private struct StoredCredentials: Codable {
    let yuhaiinToken: String
    let awsAccessKey: String
    let awsSecretKey: String
    let awsSessionToken: String
}

private final class SecureStore {
    private let service = "com.local.statusbar"

    private func getData(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    private func setData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            _ = SecItemAdd(item as CFDictionary, nil)
        }
    }

    func loadCredentials() -> StoredCredentials? {
        guard let data = getData("credentials") else { return nil }
        return try? JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    // Keep all secrets in one Keychain item so saving settings requires one
    // authorization instead of one authorization per field.
    func saveCredentials(_ credentials: StoredCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        setData(data, account: "credentials")
    }

    // Compatibility with the pre-aggregate storage format. Query all legacy
    // accounts in one Keychain operation so migration does not prompt once per
    // field.
    func loadLegacyCredentials() -> StoredCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return nil }
        var values: [String: String] = [:]
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data,
                  let value = String(data: data, encoding: .utf8) else { continue }
            values[account] = value
        }
        guard values.values.contains(where: { !$0.isEmpty }) else { return nil }
        return StoredCredentials(
            yuhaiinToken: values["yuhaiinToken"] ?? "",
            awsAccessKey: values["awsAccessKey"] ?? "",
            awsSecretKey: values["awsSecretKey"] ?? "",
            awsSessionToken: values["awsSessionToken"] ?? ""
        )
    }
}

final class SettingsStore {
    private let secureStore = SecureStore()
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("StatusBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("settings.json")
    }

    func load() -> AppSettings {
        var settings = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
        if settings.credentialsConfigured {
            if let credentials = secureStore.loadCredentials() {
                settings.yuhaiinToken = credentials.yuhaiinToken
                settings.awsAccessKey = credentials.awsAccessKey
                settings.awsSecretKey = credentials.awsSecretKey
                settings.awsSessionToken = credentials.awsSessionToken
            } else if let credentials = secureStore.loadLegacyCredentials() {
                settings.yuhaiinToken = credentials.yuhaiinToken
                settings.awsAccessKey = credentials.awsAccessKey
                settings.awsSecretKey = credentials.awsSecretKey
                settings.awsSessionToken = credentials.awsSessionToken
            }
            if !settings.hasCredentials {
                // An older settings file had no marker. Persist the empty
                // state after its one compatibility probe so future launches
                // do not touch Keychain again.
                settings.credentialsConfigured = false
                save(settings)
            }
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        var persisted = settings
        persisted.credentialsConfigured = settings.hasCredentials
        if let data = try? JSONEncoder.pretty.encode(persisted) {
            try? data.write(to: fileURL, options: .atomic)
        }
        if settings.hasCredentials {
            secureStore.saveCredentials(StoredCredentials(
                yuhaiinToken: settings.yuhaiinToken,
                awsAccessKey: settings.awsAccessKey,
                awsSecretKey: settings.awsSecretKey,
                awsSessionToken: settings.awsSessionToken
            ))
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
