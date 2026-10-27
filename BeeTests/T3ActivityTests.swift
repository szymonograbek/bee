import Foundation
import Testing

struct T3ActivityTests {
    private let resumeAt = Date(timeIntervalSince1970: 1_792_787_400)

    // MARK: Parsing

    @Test
    func parsesActivityRow() throws {
        let output = #"[{"activeThreads":2,"activeProjects":1,"resumeAt":1792787400.0}]"#
        #expect(
            try T3Activity.parse(sqliteJSON: Data(output.utf8))
                == T3Activity(activeThreads: 2, activeProjects: 1, resumeAt: resumeAt)
        )
    }

    @Test
    func nullResumeMeansNothingArmed() throws {
        let output = #"[{"activeThreads":0,"activeProjects":0,"resumeAt":null}]"#
        #expect(
            try T3Activity.parse(sqliteJSON: Data(output.utf8))
                == T3Activity(activeThreads: 0, activeProjects: 0, resumeAt: nil)
        )
    }

    @Test(arguments: ["", "[]", "{}", "not json", #"[{"activeThreads":1}]"#])
    func malformedOutputThrows(output: String) {
        #expect(throws: (any Error).self) {
            try T3Activity.parse(sqliteJSON: Data(output.utf8))
        }
    }

    // MARK: Reading policy

    @Test(arguments: [true, false])
    func nothingActiveIsIdle(keepsAwakeForAutoResume: Bool) {
        let activity = T3Activity(activeThreads: 0, activeProjects: 0, resumeAt: nil)
        #expect(activity.reading(keepsAwakeForAutoResume: keepsAwakeForAutoResume) == .idle)
    }

    @Test
    func singleActiveThread() {
        let activity = T3Activity(activeThreads: 1, activeProjects: 1, resumeAt: nil)
        #expect(activity.reading(keepsAwakeForAutoResume: false) == .active(summary: "1 thread running"))
    }

    @Test
    func threadsAcrossProjects() {
        let activity = T3Activity(activeThreads: 3, activeProjects: 2, resumeAt: nil)
        #expect(
            activity.reading(keepsAwakeForAutoResume: false) == .active(summary: "3 threads running in 2 projects")
        )
    }

    @Test
    func pendingAutoResumeKeepsAwakeWhenOptedIn() {
        let activity = T3Activity(activeThreads: 0, activeProjects: 0, resumeAt: resumeAt)
        #expect(activity.reading(keepsAwakeForAutoResume: true) == .awaitingResume(at: resumeAt))
    }

    @Test
    func pendingAutoResumeIsIdleWhenOptedOut() {
        let activity = T3Activity(activeThreads: 0, activeProjects: 0, resumeAt: resumeAt)
        #expect(activity.reading(keepsAwakeForAutoResume: false) == .idle)
    }

    @Test
    func runningWorkWinsOverPendingAutoResume() {
        let activity = T3Activity(activeThreads: 1, activeProjects: 1, resumeAt: resumeAt)
        #expect(activity.reading(keepsAwakeForAutoResume: true) == .active(summary: "1 thread running"))
    }
}
