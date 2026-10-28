import Foundation

// Decode only the quota fields used by the menu bar. The usage endpoint may
// change the shape of unrelated fields (for example, rate_limit_reached_type
// is an object when the quota is exhausted), and those must not break refresh.
struct CodexUsageResponse: Decodable {
    let userId: String?
    let accountId: String?
    let email: String?
    let planType: String?
    let rateLimit: CodexRateLimit?
    let credits: CodexCredits?
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

struct CodexResetCredits: Decodable {
    let availableCount: Int?
    let applicableAvailableCount: Int?
}
