import Foundation
import Testing

struct ResumeNapTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)
    private var resumeAt: Date { now.addingTimeInterval(60 * 60) }
    private var waiting: Activity { .awake(.awaitingResume(.t3Code, at: resumeAt)) }

    private func presence(lidClosed: Bool = false, externalDisplay: Bool = false, idle: TimeInterval = 0) -> Presence {
        Presence(isLidClosed: lidClosed, hasExternalDisplay: externalDisplay, idleTime: idle)
    }

    @Test
    func napsUntilAMinuteBeforeTheResumeOnceTheUserIsIdle() {
        #expect(
            ResumeNap.wake(for: waiting, presence: presence(idle: ResumeNap.awayAfter), at: now)
                == resumeAt.addingTimeInterval(-ResumeNap.wakeLead)
        )
    }

    @Test
    func aClosedLidWithoutAnExternalDisplayCountsAsAwayAtOnce() {
        #expect(ResumeNap.wake(for: waiting, presence: presence(lidClosed: true), at: now) != nil)
    }

    @Test
    func aClosedLidWithAnExternalDisplayIsAWorkstation() {
        let workstation = presence(lidClosed: true, externalDisplay: true)
        #expect(ResumeNap.wake(for: waiting, presence: workstation, at: now) == nil)
    }

    @Test
    func anActiveUserKeepsTheMacAwake() {
        #expect(ResumeNap.wake(for: waiting, presence: presence(idle: ResumeNap.awayAfter - 1), at: now) == nil)
    }

    @Test
    func noNapCloseToTheResume() {
        let soon = Activity.awake(.awaitingResume(.t3Code, at: now.addingTimeInterval(ResumeNap.wakeLead + 60)))
        #expect(ResumeNap.wake(for: soon, presence: presence(lidClosed: true), at: now) == nil)
    }

    @Test(arguments: [
        Activity.awake(.integration(.t3Code, summary: "1 thread running")),
        .awake(.manual(.never)),
        .idle(.nothingActive(nextScheduledStart: nil))
    ])
    func onlyAnAwaitedResumeNaps(activity: Activity) {
        #expect(ResumeNap.wake(for: activity, presence: presence(lidClosed: true), at: now) == nil)
        #expect(ResumeNap.nextCheck(for: activity, presence: presence(), at: now) == nil)
    }

    @Test
    func checksAgainWhenTheUserWillCountAsAway() {
        #expect(
            ResumeNap.nextCheck(for: waiting, presence: presence(idle: 60), at: now)
                == now.addingTimeInterval(ResumeNap.awayAfter - 60)
        )
        #expect(ResumeNap.nextCheck(for: waiting, presence: presence(lidClosed: true), at: now) == nil)
    }
}
