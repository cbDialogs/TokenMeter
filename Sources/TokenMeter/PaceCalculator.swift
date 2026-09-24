import Foundation

/// Computes how far through the work week we are, counting only work hours.
enum PaceCalculator {
    static let workdayStartHour = 8
    static let workdayEndHour = 17
    /// Calendar weekday numbers (1 = Sunday) that count as workdays, in order.
    static let workdays = [2, 3, 4, 5, 6]

    static var hoursPerDay: Double { Double(workdayEndHour - workdayStartHour) }
    static var hoursPerWeek: Double { hoursPerDay * Double(workdays.count) }

    /// Expected usage percentage (0–100) at `date`.
    static func expectedPercent(at date: Date, calendar: Calendar = .current) -> Double {
        let weekday = calendar.component(.weekday, from: date)
        guard let dayIndex = workdays.firstIndex(of: weekday) else {
            // Weekend: the work week is over, so hold at 100%.
            return 100
        }

        let startOfDay = calendar.startOfDay(for: date)
        let secondsIntoDay = date.timeIntervalSince(startOfDay)
        let hoursIntoDay = secondsIntoDay / 3600
        let todayHours = min(max(hoursIntoDay - Double(workdayStartHour), 0), hoursPerDay)

        let elapsed = Double(dayIndex) * hoursPerDay + todayHours
        return min(max(elapsed / hoursPerWeek * 100, 0), 100)
    }
}
