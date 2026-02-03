import Foundation

enum ResetSchedule {
    static func nextMidnight(after date: Date) -> Date? {
        let calendar = Calendar.current
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
    }

    static func nextWeekStart(after date: Date) -> Date? {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: 2),
            matchingPolicy: .nextTime
        )
    }
}
