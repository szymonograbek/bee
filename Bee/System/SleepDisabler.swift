import Foundation
import Observation

/// Whether sudo lets Bee run `pmset disablesleep` without a password. Sudoers is the source of truth, so it is
/// never persisted.
enum LidSleepPermission: Equatable {
    case checking
    case installing
    case granted
    case missing
    case failed(String)
}

/// Disables sleep system-wide with `pmset disablesleep`, which, unlike a power assertion, also holds with the
/// lid closed. The setting outlives Bee, so Bee records that it turned it on and only turns off what it turned on.
@MainActor
@Observable
final class SleepDisabler {
    private(set) var permission: LidSleepPermission = .checking

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var requested = SystemSleep.allowed
    /// Nil until the first write attempt, so the first one always converges, which turns off a setting left
    /// behind by a crash.
    @ObservationIgnored private var target: SystemSleep?
    @ObservationIgnored private var worker: Task<Void, Never>?

    private static let ownershipKey = "bee.ownsSleepDisabled"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private var ownsSleepDisabled: Bool {
        get { defaults.bool(forKey: Self.ownershipKey) }
        set { defaults.set(newValue, forKey: Self.ownershipKey) }
    }

    /// Idempotent. Takes effect once permission is granted.
    func hold(_ sleep: SystemSleep) {
        requested = sleep
        converge()
    }

    /// Quitting must never leave sleep disabled, so this blocks until pmset finishes, for at most two seconds.
    func releaseBeforeExit() {
        worker?.cancel()
        guard ownsSleepDisabled else { return }
        let released = DispatchSemaphore(value: 0)
        Task.detached {
            if await Self.write(.allowed) { released.signal() }
        }
        if released.wait(timeout: .now() + 2) == .success { ownsSleepDisabled = false }
    }

    /// One pmset write runs at a time and the latest target wins.
    private func converge() {
        // Waiting for the first check avoids briefly turning off a setting that should stay on.
        guard permission != .checking else { return }
        let next = permission == .granted ? requested : .allowed
        guard next != target else { return }
        target = next
        guard worker == nil else { return }
        worker = Task {
            var current = next
            while !Task.isCancelled {
                // A failed attempt is forgotten so the next `hold` retries it.
                if await !apply(current), target == current { target = nil }
                guard let latest = target, latest != current else { break }
                current = latest
            }
            worker = nil
        }
    }

    /// Works from what pmset reports rather than from what Bee last asked for. Returns false on failure.
    private func apply(_ sleep: SystemSleep) async -> Bool {
        guard sleep == .disabled || ownsSleepDisabled else { return true }
        guard let reported = await Self.read() else { return false }
        guard !Task.isCancelled else { return true }
        if reported == sleep {
            if sleep == .allowed { ownsSleepDisabled = false }
            return true
        }
        // Claimed before writing, so quitting mid-write still turns it back off.
        if sleep == .disabled { ownsSleepDisabled = true }
        guard await Self.write(sleep) else { return false }
        if sleep == .allowed { ownsSleepDisabled = false }
        return true
    }

    nonisolated private static func read() async -> SystemSleep? {
        guard
            let output = try? await ProcessRunner.run(LidSleepCommands.pmset, arguments: ["-g"], timeout: .seconds(5)),
            let text = String(bytes: output, encoding: .utf8)
        else { return nil }
        return LidSleepCommands.systemSleep(fromPmsetOutput: text)
    }

    nonisolated private static func write(_ sleep: SystemSleep) async -> Bool {
        let result = try? await ProcessRunner.run(
            LidSleepCommands.sudo,
            arguments: ["-n"] + LidSleepCommands.pmsetArguments(for: sleep),
            timeout: .seconds(2)
        )
        return result != nil
    }

    // MARK: Permission

    func refreshPermission() {
        Task {
            let checked = await Self.checkPermission()
            // An install in flight checks again when it finishes.
            guard permission != .installing else { return }
            permission = checked
            converge()
        }
    }

    /// Asks for the admin password once if the sudoers rule is missing. Returns whether permission is granted.
    func requestPermission() async -> Bool {
        switch permission {
        case .granted: return true
        case .checking, .installing: return false
        case .missing, .failed: break
        }
        permission = .installing
        let install = await Self.installPermission()
        let checked = await Self.checkPermission()
        if case let .failed(message) = install, checked != .granted {
            permission = .failed(message)
        } else {
            permission = checked
        }
        converge()
        return checked == .granted
    }

    /// Granted only when sudo allows both commands without a password, which also recognizes a rule another
    /// app installed.
    nonisolated private static func checkPermission() async -> LidSleepPermission {
        do throws(ProcessFailure) {
            for sleep in [SystemSleep.disabled, .allowed] {
                _ = try await ProcessRunner.run(
                    LidSleepCommands.sudo,
                    arguments: ["-n", "-l"] + LidSleepCommands.pmsetArguments(for: sleep),
                    timeout: .seconds(5)
                )
            }
            return .granted
        } catch {
            if case .exited = error { return .missing }
            return .failed("Couldn't check the sleep permission: \(error)")
        }
    }

    private enum Install {
        case installed
        case cancelled
        case failed(String)
    }

    nonisolated private static func installPermission() async -> Install {
        guard let user = SudoersUser(NSUserName()) else {
            return .failed("Your account name can't be used in a sudoers rule.")
        }
        do throws(ProcessFailure) {
            _ = try await ProcessRunner.run(
                LidSleepCommands.osascript,
                arguments: ["-e", LidSleepCommands.installScript(for: user)],
                timeout: .seconds(300)
            )
            return .installed
        } catch {
            guard case let .exited(_, stderr) = error else {
                return .failed("Couldn't install the sleep permission: \(error)")
            }
            // osascript reports a dismissed password prompt as error -128.
            if stderr.contains("-128") { return .cancelled }
            return .failed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
