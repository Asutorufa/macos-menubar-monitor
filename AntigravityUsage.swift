import Foundation

// Decode only the quota fields used by the menu bar. Unrelated CLI envelope
// fields may evolve across agy versions and must not break refresh.
struct AntigravityUsageResponse: Decodable {
    let status: String?
    let response: String?
    let error: String?
    let command: AntigravityUsageCommand?
}

struct AntigravityUsageCommand: Decodable {
    let name: String?
    let data: AntigravityUsageData?
}

struct AntigravityUsageData: Decodable {
    let description: String?
    let groups: [AntigravityModelGroup]?
}

struct AntigravityModelGroup: Decodable {
    let name: String?
    let description: String?
    let buckets: [AntigravityQuotaBucket]?
}

struct AntigravityQuotaBucket: Decodable {
    let id: String?
    let name: String?
    let description: String?
    let window: String?
    let remainingFraction: Double?
    let resetTime: String?
}

struct AntigravityParsedBucket: Equatable {
    let id: String
    let name: String
    let window: String
    let remainingFraction: Double
    let remainingPercent: Int
    let remainingProgress: Double
    let resetDate: Date?
    let description: String?

    func resetAfterSeconds(relativeTo now: Date = Date()) -> Int? {
        guard let resetDate else { return nil }
        return max(0, Int(resetDate.timeIntervalSince(now).rounded(.down)))
    }
}

struct AntigravityParsedGroup: Equatable {
    let name: String
    let shortName: String
    let description: String?
    let buckets: [AntigravityParsedBucket]

    var lowestBucket: AntigravityParsedBucket? {
        buckets.enumerated().min { lhs, rhs in
            AntigravityUsageParser.isHigherPriority(
                lhs.element,
                lhsIndex: lhs.offset,
                over: rhs.element,
                rhsIndex: rhs.offset
            )
        }?.element
    }
}

struct AntigravityParsedUsage: Equatable {
    let description: String?
    let groups: [AntigravityParsedGroup]
    let lowestGroup: AntigravityParsedGroup
    let lowestBucket: AntigravityParsedBucket
}

enum AntigravityUsageDecodeError: LocalizedError, Equatable {
    case commandFailed(String)
    case emptyQuota

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message): return message
        case .emptyQuota: return "Antigravity CLI returned no quota buckets."
        }
    }
}

enum AntigravityUsageParser {
    static func decodeResponse(from data: Data) throws -> AntigravityUsageResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(AntigravityUsageResponse.self, from: data)
        } catch let initialError {
            guard let text = String(data: data, encoding: .utf8),
                  let start = text.firstIndex(of: "{"),
                  let end = text.lastIndex(of: "}"),
                  start < end else {
                throw initialError
            }
            let slice = Data(text[start...end].utf8)
            return try decoder.decode(AntigravityUsageResponse.self, from: slice)
        }
    }

    static func parse(data: Data) throws -> AntigravityParsedUsage {
        let payload = try decodeResponse(from: data)
        if let rawStatus = payload.status?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawStatus.isEmpty,
           rawStatus.uppercased() != "SUCCESS" {
            let detail = [payload.error, payload.response]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
                ?? "Antigravity CLI returned status \(rawStatus)."
            throw AntigravityUsageDecodeError.commandFailed(detail)
        }

        let rawGroups = payload.command?.data?.groups ?? []
        var parsedGroups: [AntigravityParsedGroup] = []

        for (groupIndex, group) in rawGroups.enumerated() {
            let rawName = group.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let groupName = rawName.isEmpty ? "Group \(groupIndex + 1)" : rawName
            let rawBuckets = group.buckets ?? []

            let normalizedBuckets: [(index: Int, bucket: AntigravityParsedBucket)] = rawBuckets.enumerated().compactMap { bucketIndex, bucket in
                guard let rawFraction = bucket.remainingFraction, rawFraction.isFinite else { return nil }
                let clamped = max(0, min(1, rawFraction))
                let percent = Int((clamped * 100).rounded())
                let window = bucket.window?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let rawBucketName = bucket.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let bucketName = rawBucketName.isEmpty ? (window.isEmpty ? "Quota" : window) : rawBucketName
                let rawBucketID = bucket.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let bucketID = rawBucketID.isEmpty ? "\(groupIndex)-\(bucketIndex)-\(window)" : rawBucketID
                let note = bucket.description?.trimmingCharacters(in: .whitespacesAndNewlines)

                return (
                    index: bucketIndex,
                    bucket: AntigravityParsedBucket(
                        id: bucketID,
                        name: bucketName,
                        window: window,
                        remainingFraction: clamped,
                        remainingPercent: percent,
                        remainingProgress: clamped * 100,
                        resetDate: parseResetDate(bucket.resetTime),
                        description: note?.isEmpty == true ? nil : note
                    )
                )
            }

            guard !normalizedBuckets.isEmpty else { continue }

            let sortedBuckets = normalizedBuckets.sorted { lhs, rhs in
                let lhsRank = windowSortRank(lhs.bucket.window)
                let rhsRank = windowSortRank(rhs.bucket.window)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.index < rhs.index
            }.map(\.bucket)

            let groupDescription = group.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            parsedGroups.append(AntigravityParsedGroup(
                name: groupName,
                shortName: shortGroupName(groupName),
                description: groupDescription?.isEmpty == true ? nil : groupDescription,
                buckets: sortedBuckets
            ))
        }

        var candidate: (group: AntigravityParsedGroup, bucket: AntigravityParsedBucket, order: Int)?
        var order = 0
        for group in parsedGroups {
            for bucket in group.buckets {
                if let current = candidate {
                    if isHigherPriority(bucket, lhsIndex: order, over: current.bucket, rhsIndex: current.order) {
                        candidate = (group, bucket, order)
                    }
                } else {
                    candidate = (group, bucket, order)
                }
                order += 1
            }
        }

        guard let selected = candidate else {
            throw AntigravityUsageDecodeError.emptyQuota
        }

        let summary = payload.command?.data?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AntigravityParsedUsage(
            description: summary?.isEmpty == true ? nil : summary,
            groups: parsedGroups,
            lowestGroup: selected.group,
            lowestBucket: selected.bucket
        )
    }

    static func parseResetDate(_ raw: String?) -> Date? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        let date: Date?
        if let parsed = standard.date(from: trimmed) {
            date = parsed
        } else {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = fractional.date(from: trimmed)
        }
        guard let date, date.timeIntervalSince1970 > 0 else { return nil }
        return date
    }

    static func shortGroupName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return name }
        var result = trimmed
        let suffix = " models"
        if result.count > suffix.count, result.lowercased().hasSuffix(suffix) {
            result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        result = result.replacingOccurrences(of: " and ", with: " & ", options: [.caseInsensitive])
        return result.isEmpty ? trimmed : result
    }

    static func windowSortRank(_ window: String) -> Int {
        switch window.lowercased() {
        case "5h", "5-hour", "5hour": return 0
        case "daily", "1d", "24h": return 1
        case "weekly", "7d", "1w": return 2
        default: return 3
        }
    }

    static func isHigherPriority(
        _ lhs: AntigravityParsedBucket,
        lhsIndex: Int,
        over rhs: AntigravityParsedBucket,
        rhsIndex: Int
    ) -> Bool {
        if abs(lhs.remainingFraction - rhs.remainingFraction) > 0.000_001 {
            return lhs.remainingFraction < rhs.remainingFraction
        }
        let lhsRank = windowSortRank(lhs.window)
        let rhsRank = windowSortRank(rhs.window)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhsIndex < rhsIndex
    }
}
