import SwiftUI

struct MenuContent: View {
    let bee: BeeController
    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
        Text(bee.activity.headline(now: .now, calendar: .autoupdatingCurrent))
        Divider()
        Menu("Keep Awake") {
            ForEach(KeepAwakeDuration.allCases, id: \.self) { duration in
                Button(duration.title) { bee.perform(.keepAwake(duration)) }
            }
        }
        Menu("Pause") {
            ForEach(PauseLength.allCases, id: \.self) { length in
                Button(length.title) { bee.perform(.pause(length)) }
            }
        }
        if let title = bee.state.mode.resumeTitle {
            Button(title) { bee.perform(.resumeAutomatic) }
        }
        ForEach(IntegrationID.allCases.filter(bee.isEnabled), id: \.self) { id in
            Text("\(id.displayName): \(bee.state.integrations[id, default: .disabled].statusText)")
        }
        Divider()
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Button("Quit Bee") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

extension Activity {
    func headline(now: Date, calendar: Calendar) -> String {
        switch self {
        case .awake(.manual(.never)):
            "Awake until you turn it off"
        case let .awake(.manual(.at(end))):
            "Awake until \(end.moment(relativeTo: now, calendar: calendar))"
        case let .awake(.schedule(until)):
            "Awake until \(until.moment(relativeTo: now, calendar: calendar)) (schedule)"
        case let .awake(.integration(id, summary)):
            "Awake: \(id.displayName), \(summary)"
        case let .idle(.paused(until)):
            "Paused until \(until.moment(relativeTo: now, calendar: calendar))"
        case let .idle(.nothingActive(nextScheduledStart?)):
            "Idle · next \(nextScheduledStart.moment(relativeTo: now, calendar: calendar))"
        case .idle(.nothingActive(nil)):
            "Idle"
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
        case let .reported(.unavailable(reason)): reason
        }
    }
}

extension Mode {
    /// nil when there is nothing to resume from.
    var resumeTitle: String? {
        switch self {
        case .automatic: nil
        case .keepAwake: "Stop Keeping Awake"
        case .paused: "Resume Schedule"
        }
    }
}

extension KeepAwakeDuration {
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
