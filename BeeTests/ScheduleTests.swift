import Foundation
import Testing

struct ScheduleTests {
    private let workHours = Schedule.workHours

    @Test
    func activeDuringWorkHoursUntilTheEndOfTheWindow() throws {
        #expect(workHours.activeWindowEnd(at: try date(10, 26, 10), calendar: testCalendar) == (try date(10, 26, 16)))
    }

    @Test
    func windowEndIsExclusive() throws {
        #expect(workHours.activeWindowEnd(at: try date(10, 26, 16), calendar: testCalendar) == nil)
    }

    @Test
    func nextStartIsTheFollowingWorkday() throws {
        #expect(workHours.nextWindowStart(after: try date(10, 26, 16), calendar: testCalendar) == (try date(10, 27, 8)))
    }

    @Test
    func weekendIsSkipped() throws {
        let saturdayNoon = try date(10, 31, 12)
        #expect(workHours.activeWindowEnd(at: saturdayNoon, calendar: testCalendar) == nil)
        #expect(workHours.nextWindowStart(after: try date(10, 30, 17), calendar: testCalendar) == (try date(11, 2, 8)))
    }

    @Test
    func overnightRuleRunsPastMidnightOnTheFollowingDay() throws {
        let fridayNights = Schedule(
            isEnabled: true,
            rules: [ScheduleRule(id: UUID(), weekdays: [.friday], start: try time(22), end: try time(6))]
        )
        let fridayEvening = try date(10, 30, 21)
        #expect(fridayNights.nextWindowStart(after: fridayEvening, calendar: testCalendar) == (try date(10, 30, 22)))
        #expect(fridayNights.activeWindowEnd(at: try date(10, 31, 3), calendar: testCalendar) == (try date(10, 31, 6)))
        #expect(fridayNights.activeWindowEnd(at: try date(10, 31, 7), calendar: testCalendar) == nil)
    }

    @Test
    func overnightRuleOnlyStartsOnItsOwnWeekdays() throws {
        let fridayNights = Schedule(
            isEnabled: true,
            rules: [ScheduleRule(id: UUID(), weekdays: [.friday], start: try time(22), end: try time(6))]
        )
        #expect(fridayNights.activeWindowEnd(at: try date(10, 31, 23), calendar: testCalendar) == nil)
        let saturdayMorning = try date(10, 31, 7)
        #expect(fridayNights.nextWindowStart(after: saturdayMorning, calendar: testCalendar) == (try date(11, 6, 22)))
    }

    @Test
    func disabledScheduleIsNeverActive() throws {
        var schedule = workHours
        schedule.isEnabled = false
        #expect(schedule.activeWindowEnd(at: try date(10, 26, 10), calendar: testCalendar) == nil)
        #expect(schedule.nextWindowStart(after: try date(10, 26, 10), calendar: testCalendar) == nil)
    }
}

struct TimeOfDayTests {
    @Test
    func decodesValidTimes() throws {
        let decoded = try JSONDecoder().decode(TimeOfDay.self, from: Data(#"{"hour":23,"minute":59}"#.utf8))
        #expect(decoded == (try time(23, 59)))
    }

    @Test(arguments: [#"{"hour":24,"minute":0}"#, #"{"hour":8,"minute":60}"#, #"{"hour":-1,"minute":0}"#])
    func rejectsInvalidTimes(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeOfDay.self, from: Data(json.utf8))
        }
    }

    @Test
    func survivesAnEncodeDecodeRoundTrip() throws {
        let original = try time(7, 45)
        let decoded = try JSONDecoder().decode(TimeOfDay.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test
    func minutesWrapAroundMidnight() throws {
        #expect(TimeOfDay(minutesSinceMidnight: 25 * 60) == (try time(1)))
        #expect(TimeOfDay(minutesSinceMidnight: -60) == (try time(23)))
    }
}
