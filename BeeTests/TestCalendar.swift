import Foundation
import Testing

/// Gregorian, Monday-first, fixed UTC+1 with no DST, so expected dates never depend on the machine running the tests.
/// 2026-10-26 is a Monday.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 3600) ?? .gmt
    calendar.firstWeekday = 2
    return calendar
}()

func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
    let components = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
    return try #require(testCalendar.date(from: components))
}

func time(_ hour: Int, _ minute: Int = 0) throws -> TimeOfDay {
    try #require(TimeOfDay(hour: hour, minute: minute))
}
