import SwiftUI

struct MenuContent: View {
    let bee: BeeController
    @Environment(\.openSettings)
    private var openSettings

    var body: some View {
        let status = bee.activity.status(now: .now, calendar: .autoupdatingCurrent)
        Section {
            Text(status.headline)
            Text(status.detail)
        }
        Menu {
            ForEach(KeepAwakeDuration.timed, id: \.self) { duration in
                Button(duration.title) { bee.perform(.keepAwake(duration)) }
            }
            Divider()
            Button(KeepAwakeDuration.indefinitely.title) { bee.perform(.keepAwake(.indefinitely)) }
        } label: {
            Label("Keep Awake", systemImage: "cup.and.heat.waves")
        }
        Menu {
            ForEach(PauseLength.allCases, id: \.self) { length in
                Button(length.title) { bee.perform(.pause(length)) }
            }
        } label: {
            Label("Pause", systemImage: "moon.zzz")
        }
        if let resume = bee.state.mode.resumeAction {
            Button { bee.perform(.resumeAutomatic) } label: {
                Label(resume.title, systemImage: resume.systemImage)
            }
        }
        // The integration keeping the Mac awake is already explained by the status above.
        let integrations = IntegrationID.allCases.filter { bee.isEnabled($0) && bee.activity.awakeIntegration != $0 }
        if !integrations.isEmpty {
            Section {
                ForEach(integrations, id: \.self) { id in
                    Text("\(id.displayName): \(bee.state.integrations[id, default: .disabled].statusText)")
                }
            }
        }
        Section {
            Button {
                // macOS refuses a plain activate() from a menu bar app, which leaves Settings behind other apps,
                // or on another workspace under a tiling window manager. Only the deprecated forced activation works.
                (NSApp as ForcedActivation).activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",")
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Bee", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
    }
}

/// What the top of the menu says: the state with its end time, then why.
struct ActivityStatus: Equatable {
    let headline: String
    let detail: String
}

extension Activity {
    func status(now: Date, calendar: Calendar) -> ActivityStatus {
        switch self {
        case let .awake(reason): reason.status(now: now, calendar: calendar)
        case let .idle(reason): reason.status(now: now, calendar: calendar)
        }
    }
}

private extension AwakeReason {
    func status(now: Date, calendar: Calendar) -> ActivityStatus {
        func moment(_ date: Date) -> String { date.moment(relativeTo: now, calendar: calendar) }
        return switch self {
        case .manual(.never):
            ActivityStatus(headline: "Awake until you turn it off", detail: "Kept awake from this menu")
        case let .manual(.at(end)):
            ActivityStatus(headline: "Awake until \(moment(end))", detail: "Kept awake from this menu")
        case let .schedule(until):
            ActivityStatus(headline: "Awake until \(moment(until))", detail: "Following your schedule")
        case let .integration(id, summary):
            ActivityStatus(headline: "Awake while \(id.displayName) works", detail: summary)
        case let .awaitingResume(id, resumeAt):
            ActivityStatus(headline: "Awake until \(id.displayName) resumes", detail: "Resumes at \(moment(resumeAt))")
        }
    }
}

private extension IdleReason {
    func status(now: Date, calendar: Calendar) -> ActivityStatus {
        func moment(_ date: Date) -> String { date.moment(relativeTo: now, calendar: calendar) }
        return switch self {
        case let .paused(until):
            ActivityStatus(headline: "Paused until \(moment(until))", detail: "Schedule and integrations are on hold")
        case let .lowBattery(charge, limit):
            ActivityStatus(headline: "Idle on low battery", detail: "Battery at \(charge)%, below your \(limit)% limit")
        case let .nothingActive(nextScheduledStart?):
            ActivityStatus(headline: "Idle", detail: "Schedule starts \(moment(nextScheduledStart))")
        case .nothingActive(nil):
            ActivityStatus(headline: "Idle", detail: "Your Mac sleeps as usual")
        }
    }
}

private extension Activity {
    var awakeIntegration: IntegrationID? {
        switch self {
        case let .awake(.integration(id, _)), let .awake(.awaitingResume(id, _)): id
        default: nil
        }
    }
}

extension IntegrationState {
    var statusText: String {
        switch self {
        case .disabled: "Off"
        case .checking: "Checking…"
        case .reported(.idle): "Nothing running"
        case let .reported(.active(summary)): summary
        case let .reported(.awaitingResume(at)): "Auto-resuming at \(at.formatted(date: .omitted, time: .shortened))"
        case let .reported(.unavailable(reason)): reason
        }
    }
}

/// The menu item that hands control back to the schedule and integrations.
struct ResumeAction {
    let title: String
    let systemImage: String
}

extension Mode {
    /// nil when there is nothing to resume from.
    var resumeAction: ResumeAction? {
        switch self {
        case .automatic: nil
        case .keepAwake: ResumeAction(title: "Stop Keeping Awake", systemImage: "stop.circle")
        case .paused: ResumeAction(title: "Resume", systemImage: "play.circle")
        }
    }
}

extension KeepAwakeDuration {
    static let timed = allCases.filter { $0 != .indefinitely }

    var title: String {
        switch self {
        case .minutes15: "15 Minutes"
        case .minutes30: "30 Minutes"
        case .hour1: "1 Hour"
        case .hours2: "2 Hours"
        case .hours4: "4 Hours"
        case .hours8: "8 Hours"
        case .indefinitely: "Indefinitely"
        }
    }
}

extension PauseLength {
    var title: String {
        switch self {
        case .hour1: "1 Hour"
        case .restOfToday: "Rest of Today"
        case .restOfWeek: "Rest of This Week"
        }
    }
}

private extension Date {
    /// "16:00" today, "tomorrow" or "Monday" at midnight, "tomorrow 08:00", otherwise "Mon 08:00".
    func moment(relativeTo now: Date, calendar: Calendar) -> String {
        let time = formatted(date: .omitted, time: .shortened)
        let isTomorrow = calendar.isDate(self, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        if self == calendar.startOfDay(for: self) {
            return isTomorrow ? "tomorrow" : formatted(.dateTime.weekday(.wide))
        }
        if calendar.isDate(self, inSameDayAs: now) { return time }
        if isTomorrow { return "tomorrow \(time)" }
        return "\(formatted(.dateTime.weekday(.abbreviated))) \(time)"
    }
}

/// Calls NSApplication's deprecated `activate(ignoringOtherApps:)` without a deprecation warning.
/// Apple has no replacement that can bring a menu bar app forward (FB23508310).
private protocol ForcedActivation {
    func activate(ignoringOtherApps: Bool)
}

extension NSApplication: @MainActor ForcedActivation {}
