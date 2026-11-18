import Foundation

/// Keeps one `pmset` wake scheduled for `ScheduleWake`. The wake outlives Bee, so Bee records the one it scheduled,
/// which lets a relaunch keep it instead of adding a duplicate, and cancel it once it's no longer wanted.
@MainActor
final class ScheduleWaker {
    private let defaults: UserDefaults
    /// The wake Bee was last asked for.
    private var requested: Date?
    private var worker: Task<Void, Never>?

    private static let ownedWakeKey = "bee.scheduleWake"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        requested = ownedWake
    }

    private var ownedWake: Date? {
        get { defaults.data(forKey: Self.ownedWakeKey).flatMap { try? JSONDecoder().decode(Date.self, from: $0) } }
        set { defaults.set(try? newValue.map(JSONEncoder().encode), forKey: Self.ownedWakeKey) }
    }

    /// Idempotent. A date replaces Bee's wake with one at that time; nil cancels it.
    func hold(wakingAt next: Date?) {
        guard next != requested else { return }
        requested = next
        let running = worker
        worker = Task {
            await running?.value
            // A later `hold` superseded this one.
            guard next == requested else { return }
            if let owned = ownedWake, owned != next {
                if owned > Date() { _ = await Self.sudo(PmsetCommands.cancelWakeArguments(at: owned)) }
                ownedWake = nil
            }
            if let next, ownedWake == nil, await Self.sudo(PmsetCommands.scheduleWakeArguments(at: next)) {
                ownedWake = next
            }
        }
    }

    nonisolated private static func sudo(_ command: [String]) async -> Bool {
        (try? await ProcessRunner.run(PmsetCommands.sudo, arguments: ["-n"] + command, timeout: .seconds(5))) != nil
    }
}
