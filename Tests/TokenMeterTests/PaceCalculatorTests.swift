import Foundation
import Testing
@testable import TokenMeter

struct PaceCalculatorTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        return cal
    }()

    /// 2026-09-21 is a Monday.
    func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func expected(_ d: Date) -> Double { PaceCalculator.expectedPercent(at: d, calendar: calendar) }

    @Test func mondayStartIsZero() { #expect(expected(date(day: 21, hour: 8)) == 0) }
    @Test func mondayEarlyMorningIsZero() { #expect(expected(date(day: 21, hour: 3)) == 0) }
    @Test func wednesdayMiddayIsHalf() { #expect(expected(date(day: 23, hour: 12, minute: 30)) == 50) }
    @Test func fridayEndIsFull() { #expect(expected(date(day: 25, hour: 17)) == 100) }
    @Test func saturdayIsFull() { #expect(expected(date(day: 26, hour: 12)) == 100) }
    @Test func sundayIsFull() { #expect(expected(date(day: 27, hour: 12)) == 100) }

    @Test func overnightHoldsPreviousDayEnd() {
        #expect(expected(date(day: 22, hour: 3)) == 20)
        #expect(expected(date(day: 21, hour: 17)) == 20)
        #expect(expected(date(day: 21, hour: 22)) == 20)
    }

    @Test func thursdayBeforeWorkIsSixty() { #expect(expected(date(day: 24, hour: 7, minute: 28)) == 60) }
}
