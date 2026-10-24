import Foundation

/// Recurring weekly windows during which Bee keeps the Mac awake.
struct Schedule: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var rules: [ScheduleRule]

    static let workHours = Self(isEnabled: true, rules: [.workHours])

    /// The end of the scheduled window covering `now`, or nil when no window is active.
    func activeWindowEnd(at now: Date, calendar: Calendar) -> Date? {
        occurrences(around: now, calendar: calendar)
            .filter { $0.start <= now && now < $0.end }
            .map(\.end)
            .max()
    }

    /// The start of the first scheduled window after `now`, looking one week ahead.
    func nextWindowStart(after now: Date, calendar: Calendar) -> Date? {
        occurrences(around: now, calendar: calendar)
            .map(\.start)
            .filter { $0 > now }
            .min()
    }

    /// Concrete windows starting from yesterday (overnight windows may still be running) through next week.
    private func occurrences(around now: Date, calendar: Calendar) -> [DateInterval] {
        guard isEnabled else { return [] }
        let today = calendar.startOfDay(for: now)
        return (-1...7).flatMap { offset -> [DateInterval] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return [] }
            return rules.compactMap { $0.occurrence(onDayStarting: day, calendar: calendar) }
        }
    }
}

/// One recurring window, e.g. weekdays 08:00–16:00.
struct ScheduleRule: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var weekdays: Set<Weekday>
    var start: TimeOfDay
    /// When `end` is not after `start`, the window ends on the following day.
    var end: TimeOfDay

    static var workHours: Self {
        Self(
            id: UUID(),
            weekdays: Weekday.workdays,
            start: TimeOfDay(minutesSinceMidnight: 8 * 60),
            end: TimeOfDay(minutesSinceMidnight: 16 * 60)
        )
    }

    var endsNextDay: Bool { end <= start }

    /// The minutes of `day` this rule covers. An overnight window is split: the evening on its own weekday,
    /// the early hours on the next one.
    func minuteRanges(on day: Weekday) -> [Range<Int>] {
        guard endsNextDay else {
            return weekdays.contains(day) ? [start.minutesSinceMidnight..<end.minutesSinceMidnight] : []
        }
        var ranges: [Range<Int>] = []
        if weekdays.contains(day.previous), end.minutesSinceMidnight > 0 {
            ranges.append(0..<end.minutesSinceMidnight)
        }
        if weekdays.contains(day) {
            ranges.append(start.minutesSinceMidnight..<TimeOfDay.minutesPerDay)
        }
        return ranges
    }

    func occurrence(onDayStarting day: Date, calendar: Calendar) -> DateInterval? {
        guard
            let weekday = Weekday(of: day, in: calendar),
            weekdays.contains(weekday),
            let startDate = start.date(onDayStarting: day, in: calendar),
            let endDay = endsNextDay ? calendar.date(byAdding: .day, value: 1, to: day) : day,
            let endDate = end.date(onDayStarting: endDay, in: calendar)
        else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }
}
