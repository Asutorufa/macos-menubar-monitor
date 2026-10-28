import Foundation

func decode(_ data: Data) throws -> CodexUsageResponse {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(CodexUsageResponse.self, from: data)
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: codex-usage-decode <exhausted-quota-fixture.json>")
}

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let usage = try decode(data)
check(usage.rateLimit?.allowed == false, "quota should not be allowed")
check(usage.rateLimit?.limitReached == true, "quota should be exhausted")
check(usage.rateLimit?.primaryWindow?.usedPercent == 100, "5-hour window should be at 100%")
check(usage.rateLimit?.secondaryWindow?.usedPercent == 16, "7-day window should be at 16%")
check(usage.credits?.balance == "0", "credit balance should remain readable")
check(usage.rateLimitResetCredits?.availableCount == 1, "reset credits should be readable")

// The exhaustion reason was previously modeled as String?, which broke
// parsing when the endpoint returned an object. Neither representation is
// needed to display quota, so both must be safe to ignore.
for reason in ["legacy", NSNull()] as [Any] {
    guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fatalError("Expected fixture to contain a JSON object")
    }
    object["rate_limit_reached_type"] = reason
    let variant = try JSONSerialization.data(withJSONObject: object)
    let parsed = try decode(variant)
    check(parsed.rateLimit?.limitReached == true, "reason shape must not break quota decoding")
}

let minimal: [String: Any] = [
    "rate_limit": ["allowed": true, "limit_reached": false],
    "credits": NSNull(),
    "rate_limit_reset_credits": NSNull(),
    "promo": ["unexpected": "object"]
]
let missingOptionalData = try JSONSerialization.data(withJSONObject: minimal)
let minimalUsage = try decode(missingOptionalData)
check(minimalUsage.rateLimit?.limitReached == false, "nullable and missing optional fields must decode")

print("Codex usage decoding: all checks passed")
