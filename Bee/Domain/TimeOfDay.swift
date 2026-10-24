import Foundation

/// A wall-clock time within a day, at minute precision.
struct TimeOfDay: Hashable, Comparable, Sendable {
    static let minutesPerDay = 24 * 60

    let minutesSinceMidnight: Int

    var hour: Int { minutesSinceMidnight / 60 }
    var minute: Int { minutesSinceMidnight % 60 }

    /// Wraps around midnight, so every value maps to a valid time (e.g. 1500 → 01:00).
    init(minutesSinceMidnight: Int) {
        let wrapped = minutesSinceMidnight % Self.minutesPerDay
        self.minutesSinceMidnight = wrapped < 0 ? wrapped + Self.minutesPerDay : wrapped
    }

    init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        minutesSinceMidnight = hour * 60 + minute
    }

    /// Reads the hour and minute of `date` in `calendar`'s time zone.
    init(of date: Date, in calendar: Calendar) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(minutesSinceMidnight: (components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    /// The moment this time occurs on the day that starts at `startOfDay`.
    func date(onDayStarting startOfDay: Date, in calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

extension TimeOfDay: Codable {
    private enum CodingKeys: String, CodingKey {
        case hour
        case minute
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)
        guard let time = Self(hour: hour, minute: minute) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hour,
                in: container,
                debugDescription: "Invalid time \(hour):\(minute)"
            )
        }
        self = time
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
    }
}
