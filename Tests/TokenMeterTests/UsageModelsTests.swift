import Foundation
import Testing
@testable import TokenMeter

struct UsageModelsTests {
    // Trimmed from a real /api/oauth/usage response.
    let sample = """
    {
      "five_hour": {"utilization": 0.0, "resets_at": "2026-09-24T17:20:00.626791+00:00"},
      "seven_day_opus": null,
      "extra_usage": {"is_enabled": true},
      "limits": [
        {"kind": "session", "group": "session", "percent": 0, "severity": "normal",
         "resets_at": "2026-09-24T17:20:00.626791+00:00", "scope": null, "is_active": false},
        {"kind": "weekly_all", "group": "weekly", "percent": 32, "severity": "normal",
         "resets_at": "2026-09-27T14:00:00.626813+00:00", "scope": null, "is_active": false},
        {"kind": "weekly_scoped", "group": "weekly", "percent": 55, "severity": "normal",
         "resets_at": "2026-09-27T13:59:59.627029+00:00",
         "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}, "is_active": true}
      ]
    }
    """

    @Test func decodesLimits() throws {
        let usage = try JSONDecoder().decode(UsageResponse.self, from: Data(sample.utf8))
        #expect(usage.session?.percent == 0)
        #expect(usage.weeklyAll?.percent == 32)
        #expect(usage.weeklyScoped(model: "Fable")?.percent == 55)
        #expect(usage.weeklyScoped(model: "Opus") == nil)
        #expect(usage.session?.resetsAt == Date(timeIntervalSince1970: 1790270400))
    }

    @Test func toleratesMissingLimits() throws {
        let usage = try JSONDecoder().decode(UsageResponse.self, from: Data("{}".utf8))
        #expect(usage.session == nil)
    }
}
