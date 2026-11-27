import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: antigravity-usage-decode <usage-fixture.json>")
}

let fixtureData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let usage = try AntigravityUsageParser.parse(data: fixtureData)

check(usage.groups.count == 2, "expected 2 model groups")
check(usage.groups[0].name == "Gemini Models", "first group should be Gemini Models")
check(usage.groups[0].shortName == "Gemini", "Gemini Models should shorten to Gemini")
check(usage.groups[1].name == "Claude and GPT models", "second group should be Claude and GPT models")
check(usage.groups[1].shortName == "Claude & GPT", "Claude and GPT models should shorten to Claude & GPT")

// Buckets within each group should be sorted with 5h before weekly.
check(usage.groups[0].buckets.count == 2, "Gemini group should have 2 buckets")
check(usage.groups[0].buckets[0].id == "gemini-5h", "5h bucket should be ordered first")
check(usage.groups[0].buckets[0].remainingPercent == 39, "Gemini 5h remaining should round to 39%")
check(usage.groups[0].buckets[0].resetDate != nil, "Gemini 5h should have a valid reset date")
check(usage.groups[0].buckets[1].id == "gemini-weekly", "weekly bucket should be ordered second")
check(usage.groups[0].buckets[1].remainingPercent == 75, "Gemini weekly remaining should round to 75%")
check(usage.groups[0].buckets[1].resetDate != nil, "Gemini weekly should have a valid reset date")

// Lowest remaining across all groups/buckets should be Gemini 5h at 39%.
check(usage.lowestGroup.name == "Gemini Models", "lowest group should be Gemini Models")
check(usage.lowestBucket.id == "gemini-5h", "lowest bucket should be gemini-5h")
check(usage.lowestBucket.remainingPercent == 39, "lowest remaining percent should be 39")

// Epoch zero (1970-01-01T00:00:00Z) should be treated as no active reset countdown.
check(usage.groups[1].buckets[0].id == "3p-5h", "3p 5h bucket should be ordered first")
check(usage.groups[1].buckets[0].remainingPercent == 100, "3p 5h remaining should be 100%")
check(usage.groups[1].buckets[0].resetDate == nil, "epoch zero reset_time must decode as nil")
check(usage.groups[1].buckets[1].resetDate == nil, "epoch zero weekly reset_time must decode as nil")

// Relative reset countdown calculation.
let sampleNow = AntigravityUsageParser.parseResetDate("2026-11-27T07:25:35Z")!
check(usage.lowestBucket.resetAfterSeconds(relativeTo: sampleNow) == 1440, "expected 24 minutes (1440s) until reset")

// Fractional seconds ISO-8601 dates must also parse.
check(AntigravityUsageParser.parseResetDate("2026-11-27T07:49:35.123Z") != nil, "fractional ISO8601 date should parse")

// Tolerate leading or trailing non-JSON CLI log lines around the JSON object.
let noisyPayload = Data("info: refreshing quota\n".utf8) + fixtureData + Data("\ndone\n".utf8)
let noisyUsage = try AntigravityUsageParser.parse(data: noisyPayload)
check(noisyUsage.lowestBucket.remainingPercent == 39, "noisy stdout should still parse JSON payload")

// Tie-breaking when all buckets are at 100%: prefer first group's 5h window.
let fullQuotaJSON: [String: Any] = [
    "status": "SUCCESS",
    "extra_future_field": ["nested": true],
    "command": [
        "name": "usage",
        "data": [
            "groups": [
                [
                    "name": "Gemini Models",
                    "buckets": [
                        ["id": "gemini-weekly", "window": "weekly", "remaining_fraction": 1.0, "reset_time": "1970-01-01T00:00:00Z"],
                        ["id": "gemini-5h", "window": "5h", "remaining_fraction": 1.0, "reset_time": "1970-01-01T00:00:00Z"],
                    ],
                ],
                [
                    "name": "Claude and GPT models",
                    "buckets": [
                        ["id": "3p-5h", "window": "5h", "remaining_fraction": 1.0],
                    ],
                ],
            ],
        ],
    ],
]
let fullQuotaData = try JSONSerialization.data(withJSONObject: fullQuotaJSON)
let fullQuotaUsage = try AntigravityUsageParser.parse(data: fullQuotaData)
check(fullQuotaUsage.lowestBucket.id == "gemini-5h", "tie at 100% should prefer 5h bucket in first group")
check(fullQuotaUsage.lowestBucket.remainingPercent == 100, "full quota remaining should be 100%")

// Non-SUCCESS status should raise commandFailed with the message.
let errorJSON: [String: Any] = [
    "status": "ERROR",
    "error": "Not logged in",
]
let errorData = try JSONSerialization.data(withJSONObject: errorJSON)
do {
    _ = try AntigravityUsageParser.parse(data: errorData)
    check(false, "non-SUCCESS status should throw")
} catch let error as AntigravityUsageDecodeError {
    check(error == .commandFailed("Not logged in"), "expected commandFailed with error message")
}

// Empty groups should raise emptyQuota.
let emptyData = Data("{\"status\":\"SUCCESS\",\"command\":{\"name\":\"usage\",\"data\":{\"groups\":[]}}}".utf8)
do {
    _ = try AntigravityUsageParser.parse(data: emptyData)
    check(false, "empty groups should throw")
} catch let error as AntigravityUsageDecodeError {
    check(error == .emptyQuota, "expected emptyQuota error")
}

print("Antigravity usage decoding: all checks passed")
