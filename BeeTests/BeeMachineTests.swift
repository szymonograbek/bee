import Foundation
import Testing

struct BeeMachineTests {
    private func state(
        mode: Mode = .automatic,
        t3: IntegrationState = .reported(.idle),
        batteryLimit: BatteryLimit = .off,
        power: PowerSource = PowerSource(isPluggedIn: true, batteryCharge: 100)
    ) -> BeeState {
        BeeState(
            mode: mode,
            schedule: .workHours,
            integrations: [.t3Code: t3],
            batteryLimit: batteryLimit,
            power: power
        )
    }

    // MARK: Battery limit

    private let limit20 = BatteryLimit(isEnabled: true, minimumCharge: 20, ignoresWhilePluggedIn: true)

    @Test
    func lowBatteryBeatsManualKeepAwake() throws {
        let low = state(
            mode: .keepAwake(.never),
            batteryLimit: limit20,
            power: PowerSource(isPluggedIn: false, batteryCharge: 19)
        )
        #expect(
            low.activity(at: try date(10, 26, 10), calendar: testCalendar) == .idle(.lowBattery(charge: 19, limit: 20))
        )
    }

    @Test
    func pauseBeatsLowBattery() throws {
        let until = try date(10, 26, 12)
        let low = state(
            mode: .paused(until: until),
            batteryLimit: limit20,
            power: PowerSource(isPluggedIn: false, batteryCharge: 5)
        )
        #expect(low.activity(at: try date(10, 26, 10), calendar: testCalendar) == .idle(.paused(until: until)))
    }

    @Test(arguments: [
        PowerSource(isPluggedIn: false, batteryCharge: 20),
        PowerSource(isPluggedIn: true, batteryCharge: 5),
        PowerSource(isPluggedIn: false, batteryCharge: nil)
    ])
    func batteryLimitAllowsKeepingAwake(power: PowerSource) throws {
        let bee = state(mode: .keepAwake(.never), batteryLimit: limit20, power: power)
        #expect(bee.activity(at: try date(10, 26, 10), calendar: testCalendar) == .awake(.manual(.never)))
    }

    @Test
    func batteryLimitCanApplyWhilePluggedIn() throws {
        var limit = limit20
        limit.ignoresWhilePluggedIn = false
        let charging = PowerSource(isPluggedIn: true, batteryCharge: 5)
        let bee = state(mode: .keepAwake(.never), batteryLimit: limit, power: charging)
        #expect(
            bee.activity(at: try date(10, 26, 10), calendar: testCalendar) == .idle(.lowBattery(charge: 5, limit: 20))
        )
    }

    @Test
    func disabledBatteryLimitNeverApplies() throws {
        let bee = state(mode: .keepAwake(.never), power: PowerSource(isPluggedIn: false, batteryCharge: 1))
        #expect(bee.activity(at: try date(10, 26, 10), calendar: testCalendar).isAwake)
    }

    // MARK: Precedence: pause > manual > schedule > integration

    @Test
    func pauseBeatsScheduleAndIntegrations() throws {
        let until = try date(10, 26, 12)
        let paused = state(mode: .paused(until: until), t3: .reported(.active(summary: "1 thread running")))
        #expect(paused.activity(at: try date(10, 26, 10), calendar: testCalendar) == .idle(.paused(until: until)))
    }

    @Test
    func manualBeatsSchedule() throws {
        let manual = state(mode: .keepAwake(.never))
        #expect(manual.activity(at: try date(10, 26, 10), calendar: testCalendar) == .awake(.manual(.never)))
    }

    @Test
    func scheduleBeatsIntegrations() throws {
        let busy = state(t3: .reported(.active(summary: "1 thread running")))
        let workingHours = try date(10, 26, 10)
        let windowEnd = try date(10, 26, 16)
        #expect(busy.activity(at: workingHours, calendar: testCalendar) == .awake(.schedule(until: windowEnd)))
    }

    @Test
    func activeIntegrationKeepsAwakeOutsideTheSchedule() throws {
        let busy = state(t3: .reported(.active(summary: "2 threads running")))
        #expect(
            busy.activity(at: try date(10, 31, 12), calendar: testCalendar)
                == .awake(.integration(.t3Code, summary: "2 threads running"))
        )
    }

    @Test
    func awaitedResumeKeepsAwakeOutsideTheSchedule() throws {
        let resumeAt = try date(10, 31, 13)
        let waiting = state(t3: .reported(.awaitingResume(at: resumeAt)))
        #expect(
            waiting.activity(at: try date(10, 31, 12), calendar: testCalendar)
                == .awake(.awaitingResume(.t3Code, at: resumeAt))
        )
    }

    @Test
    func activeIntegrationBeatsAnotherIntegrationsAwaitedResume() throws {
        var bee = state(t3: .reported(.awaitingResume(at: try date(10, 31, 13))))
        bee.integrations[.claudeCode] = .reported(.active(summary: "1 session running"))
        #expect(
            bee.activity(at: try date(10, 31, 12), calendar: testCalendar)
                == .awake(.integration(.claudeCode, summary: "1 session running"))
        )
    }

    @Test(arguments: [IntegrationState.disabled, .checking, .reported(.idle), .reported(.unavailable(reason: "x"))])
    func inactiveIntegrationLeavesBeeIdleUntilTheNextWindow(t3: IntegrationState) throws {
        #expect(
            state(t3: t3).activity(at: try date(10, 31, 12), calendar: testCalendar)
                == .idle(.nothingActive(nextScheduledStart: try date(11, 2, 8)))
        )
    }

    // MARK: Mode expiry

    @Test
    func keepAwakeExpiresAtItsDeadline() throws {
        let start = try date(10, 31, 12)
        var bee = state()
        bee.handle(.keepAwake(KeepAwakeDuration.minutes15.expiry(from: start)), at: start)
        #expect(bee.activity(at: try date(10, 31, 12, 14), calendar: testCalendar).isAwake)
        #expect(!bee.activity(at: try date(10, 31, 12, 15), calendar: testCalendar).isAwake)
        bee.handle(.tick, at: try date(10, 31, 12, 15))
        #expect(bee.mode == .automatic)
    }

    @Test
    func indefiniteKeepAwakeNeverExpires() throws {
        var bee = state()
        let start = try date(10, 31, 12)
        bee.handle(.keepAwake(KeepAwakeDuration.indefinitely.expiry(from: start)), at: start)
        bee.handle(.tick, at: try date(12, 31, 12))
        #expect(bee.mode == .keepAwake(.never))
    }

    @Test
    func pauseInThePastResumesAutomatic() throws {
        var bee = state(mode: .keepAwake(.never))
        bee.handle(.pause(until: try date(10, 26, 9)), at: try date(10, 26, 10))
        #expect(bee.mode == .automatic)
    }

    @Test
    func resumeAutomaticClearsAPause() throws {
        var bee = state(mode: .paused(until: try date(10, 27, 0)))
        bee.handle(.resumeAutomatic, at: try date(10, 26, 10))
        let workingHours = try date(10, 26, 10)
        let windowEnd = try date(10, 26, 16)
        #expect(bee.activity(at: workingHours, calendar: testCalendar) == .awake(.schedule(until: windowEnd)))
    }

    // MARK: Next transition

    @Test
    func nextTransitionIsTheEarlierOfModeExpiryAndWindowEnd() throws {
        let now = try date(10, 26, 10)
        let keptAwake = state(mode: .keepAwake(.at(try date(10, 26, 11))))
        #expect(keptAwake.nextTransition(after: now, calendar: testCalendar) == (try date(10, 26, 11)))
        #expect(state().nextTransition(after: now, calendar: testCalendar) == (try date(10, 26, 16)))
    }

    @Test
    func nextTransitionOverTheWeekendIsMondayMorning() throws {
        #expect(state().nextTransition(after: try date(10, 31, 12), calendar: testCalendar) == (try date(11, 2, 8)))
    }

    @Test
    func nextTransitionIsNilWithNothingScheduled() throws {
        var bee = state()
        bee.schedule = Schedule(isEnabled: false, rules: [])
        #expect(bee.nextTransition(after: try date(10, 26, 10), calendar: testCalendar) == nil)
    }

    // MARK: Pause presets

    @Test
    func pauseLengthsEndAtTheExpectedMoments() throws {
        let wednesday = try date(10, 28, 14, 30)
        #expect(PauseLength.hour1.end(from: wednesday, calendar: testCalendar) == (try date(10, 28, 15, 30)))
        #expect(PauseLength.restOfToday.end(from: wednesday, calendar: testCalendar) == (try date(10, 29, 0)))
        #expect(PauseLength.restOfWeek.end(from: wednesday, calendar: testCalendar) == (try date(11, 2, 0)))
    }
}
