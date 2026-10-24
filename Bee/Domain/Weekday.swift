import Foundation

/// A day of the week. Raw values match `Calendar`'s `.weekday` component.
enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    static let workdays: Set<Self> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Self> = [.saturday, .sunday]

    init?(of date: Date, in calendar: Calendar) {
        self.init(rawValue: calendar.component(.weekday, from: date))
    }

    /// All weekdays ordered as `calendar` presents a week (e.g. Monday first in most of Europe).
    static func ordered(for calendar: Calendar) -> [Self] {
        let all = allCases.sorted()
        let firstIndex = all.firstIndex { $0.rawValue == calendar.firstWeekday } ?? 0
        return Array(all[firstIndex...] + all[..<firstIndex])
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
