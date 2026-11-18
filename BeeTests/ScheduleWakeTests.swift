import Foundation
import Testing

struct ScheduleWakeTests {
    private func state(mode: Mode = .automatic, schedule: Schedule = .workHours) -> BeeState {
        BeeState(
            mode: mode,
            schedule: schedule,
            integrations: [:],
            batteryLimit: .off,
            power: PowerSource(isPluggedIn: true, batteryCharge: 100)
        )
    }

    @Test
    func wakesAMinuteBeforeTheNextWindow() throws {
        let mondayEvening = try date(10, 26, 20)
        #expect(
            ScheduleWake.next(for: state(), after: mondayEvening, calendar: testCalendar) == (try date(10, 27, 7, 59))
        )
    }

    @Test
    func aWakeAlreadyDueMovesOnToTheFollowingWindow() throws {
        let tuesdayJustBeforeEight = try date(10, 27, 7, 59)
        #expect(
            ScheduleWake.next(for: state(), after: tuesdayJustBeforeEight, calendar: testCalendar)
                == (try date(10, 28, 7, 59))
        )
    }

    @Test
    func skipsWindowsThatStartDuringAPause() throws {
        let paused = state(mode: .paused(until: try date(10, 28, 12)))
        #expect(
            ScheduleWake.next(for: paused, after: try date(10, 26, 20), calendar: testCalendar)
                == (try date(10, 29, 7, 59))
        )
    }

    @Test
    func aDisabledScheduleNeverWakes() throws {
        var schedule = Schedule.workHours
        schedule.isEnabled = false
        let mondayEvening = try date(10, 26, 20)
        #expect(ScheduleWake.next(for: state(schedule: schedule), after: mondayEvening, calendar: testCalendar) == nil)
    }
}
