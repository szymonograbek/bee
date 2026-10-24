import Foundation
import Testing

struct T3ThreadListTests {
    private let alpha = T3Project(id: "a", title: "Alpha")
    private let beta = T3Project(id: "b", title: "Beta")

    // MARK: Project discovery

    @Test(arguments: ["", "\n"])
    func blankSQLiteOutputMeansNoProjects(output: String) throws {
        #expect(try T3ThreadList.projects(fromSQLiteJSON: Data(output.utf8)).isEmpty)
    }

    @Test
    func parsesSQLiteRows() throws {
        let output = #"[{"id":"a","title":"Alpha"},{"id":"b","title":"Beta"}]"#
        #expect(try T3ThreadList.projects(fromSQLiteJSON: Data(output.utf8)) == [alpha, beta])
    }

    // MARK: Thread list

    @Test
    func countsOnlyRunningThreadsAndIgnoresOtherFields() throws {
        let output = """
            [{"threadId":"1","status":"running","title":"x","settled":false},
             {"threadId":"2","status":"completed"},
             {"threadId":"3","status":"idle"},
             {"threadId":"4","status":"running","pullRequests":[]}]
            """
        #expect(try T3ThreadList.runningCount(fromThreadListJSON: Data(output.utf8)) == 2)
    }

    @Test
    func emptyThreadListHasNothingRunning() throws {
        #expect(try T3ThreadList.runningCount(fromThreadListJSON: Data("[]".utf8)) == 0)
    }

    @Test(arguments: ["", "{}", "not json", #"[{"threadId":"1"}]"#])
    func malformedThreadListThrows(output: String) {
        #expect(throws: (any Error).self) {
            try T3ThreadList.runningCount(fromThreadListJSON: Data(output.utf8))
        }
    }

    // MARK: Reading policy

    @Test
    func noProjectsIsIdle() {
        #expect(T3ThreadList.reading(from: []) == .idle)
    }

    @Test
    func everyProjectReadWithNothingRunningIsIdle() {
        let outcomes: [T3ProjectOutcome] = [.checked(alpha, runningThreads: 0), .checked(beta, runningThreads: 0)]
        #expect(T3ThreadList.reading(from: outcomes) == .idle)
    }

    @Test
    func singleRunningThread() {
        #expect(
            T3ThreadList.reading(from: [.checked(alpha, runningThreads: 1), .checked(beta, runningThreads: 0)])
                == .active(summary: "1 thread running")
        )
    }

    @Test
    func severalThreadsInOneProject() {
        #expect(
            T3ThreadList.reading(from: [.checked(alpha, runningThreads: 3)]) == .active(summary: "3 threads running")
        )
    }

    @Test
    func threadsAcrossProjects() {
        #expect(
            T3ThreadList.reading(from: [.checked(alpha, runningThreads: 2), .checked(beta, runningThreads: 1)])
                == .active(summary: "3 threads running in 2 projects")
        )
    }

    @Test
    func runningWorkWinsOverPartialFailure() {
        #expect(
            T3ThreadList.reading(from: [.checked(alpha, runningThreads: 1), .failed(beta, reason: "timed out")])
                == .active(summary: "1 thread running")
        )
    }

    @Test
    func failuresWithNothingRunningAreUnavailable() {
        let outcomes: [T3ProjectOutcome] = [
            .checked(alpha, runningThreads: 0),
            .failed(beta, reason: "timed out"),
            .failed(T3Project(id: "c", title: "Gamma"), reason: "exit 1"),
            .checked(T3Project(id: "d", title: "Delta"), runningThreads: 0)
        ]
        #expect(T3ThreadList.reading(from: outcomes) == .unavailable(reason: "Couldn't read 2 of 4 projects"))
    }
}
