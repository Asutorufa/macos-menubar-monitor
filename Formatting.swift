import Foundation

enum Fmt {
    static func bytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = max(bytes, 0)
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        if index == 0 { return String(format: "%.0f %@", value, units[index]) }
        if index >= 3 { return String(format: "%.2f %@", value, units[index]) }
        if value >= 100 { return String(format: "%.0f %@", value, units[index]) }
        if value >= 10 { return String(format: "%.1f %@", value, units[index]) }
        return String(format: "%.2f %@", value, units[index])
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        bytes(bytesPerSecond) + "/s"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", max(0, min(100, value)))
    }

    static func range(_ values: [Int]?) -> String {
        guard let values, values.count >= 2 else { return "—" }
        return "\(values[0]) ~ \(values[1])"
    }

    static func clock(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func date(_ timestamp: TimeInterval, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}
