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

struct RetryAfterTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func parsesSeconds() {
        #expect(UsageService.retryAfter("120", now: now) == now.addingTimeInterval(120))
    }

    @Test func parsesHTTPDate() {
        #expect(UsageService.retryAfter("Fri, 25 Sep 2026 13:00:00 GMT") == Date(timeIntervalSince1970: 1790341200))
    }

    @Test func ignoresMissing() {
        #expect(UsageService.retryAfter(nil) == nil)
        #expect(UsageService.retryAfter("soon") == nil)
    }
}

struct StaleMessageTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        return cal
    }()

    @Test func noPreviousData() {
        #expect(UsageService.staleMessage(since: nil) == "Claude Code login expired — open any `claude` session to refresh")
    }

    @Test func sameDayShowsTimeOnly() {
        let last = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 7, minute: 5))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 9))!
        let message = UsageService.staleMessage(since: last, now: now, calendar: calendar)
        #expect(message.hasPrefix("Stale since "))
        #expect(message.hasSuffix(" — open any `claude` session to refresh"))
        #expect(!message.contains("Fri"))
    }

    @Test func earlierDayIncludesWeekday() {
        let last = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 17, minute: 12))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 8))!
        #expect(UsageService.staleMessage(since: last, now: now, calendar: calendar).contains("Thu"))
    }
}
