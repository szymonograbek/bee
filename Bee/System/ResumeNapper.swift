import Foundation

/// Puts the Mac to sleep with a wake scheduled, for `ResumeNap`. Scheduling a wake needs root, so it runs
/// `pmset schedule` through sudo once the user grants it.
@MainActor
final class ResumeNapper {
    /// Any time works for the check, since the rule allows every time.
    let permission = SudoPermission(commands: [
        PmsetCommands.scheduleWakeArguments(at: .distantFuture),
        PmsetCommands.cancelWakeArguments(at: .distantFuture)
    ])

    private let sleepDisabler: SleepDisabler
    /// The wake of the nap Bee was last asked for.
    private var wake: Date?
    private var worker: Task<Void, Never>?

    /// Waits for `sleepDisabler` to allow sleep before sleeping.
    init(sleepDisabler: SleepDisabler) {
        self.sleepDisabler = sleepDisabler
    }

    /// Idempotent. A date schedules that wake, then sleeps; nil cancels a wake that is still ahead. Never sleeps
    /// unless the wake is scheduled.
    func hold(wakingAt next: Date?) {
        guard next != wake else { return }
        let previous = wake
        wake = next
        let running = worker
        running?.cancel()
        worker = Task {
            await running?.value
            if let previous, previous > Date() {
                _ = await Self.sudo(PmsetCommands.cancelWakeArguments(at: previous))
            }
            guard let next, !Task.isCancelled else { return }
            await sleepDisabler.settled()
            guard !Task.isCancelled, await Self.sudo(PmsetCommands.scheduleWakeArguments(at: next)) else { return }
            _ = try? await ProcessRunner.run(
                PmsetCommands.pmset,
                arguments: PmsetCommands.sleepNowArguments,
                timeout: .seconds(5)
            )
        }
    }

    nonisolated private static func sudo(_ command: [String]) async -> Bool {
        (try? await ProcessRunner.run(PmsetCommands.sudo, arguments: ["-n"] + command, timeout: .seconds(5))) != nil
    }
}
