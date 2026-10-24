import SwiftUI

struct ScheduleSettingsView: View {
    let bee: BeeController
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        let schedule = Binding(
            get: { bee.state.schedule },
            set: { bee.perform(.setSchedule($0)) }
        )
        Form {
            Section {
                Toggle(isOn: schedule.isEnabled) {
                    Text("Keep awake on a schedule")
                    Text("Bee keeps your Mac awake during these hours every week.")
                }
            }
            Group {
                Section {
                    WeekPreview(rules: schedule.wrappedValue.rules, calendar: calendar)
                }
                Section("Hours") {
                    ForEach(schedule.rules) { $rule in
                        ScheduleRuleRow(rule: $rule, calendar: calendar) {
                            schedule.wrappedValue.rules.removeAll { $0.id == rule.id }
                        }
                    }
                    if schedule.wrappedValue.rules.isEmpty {
                        Text("No hours yet.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Add Hours", systemImage: "plus") { schedule.wrappedValue.rules.append(.workHours) }
                }
            }
            .disabled(!schedule.wrappedValue.isEnabled)
        }
        .settingsPane()
    }
}

/// The whole week at a glance: one 24-hour track per day, filled where Bee keeps the Mac awake.
private struct WeekPreview: View {
    let rules: [ScheduleRule]
    let calendar: Calendar
    @Environment(\.isEnabled)
    private var isEnabled

    private let labelWidth: CGFloat = 32

    var body: some View {
        TimelineView(.everyMinute) { context in
            let today = Weekday(of: context.date, in: calendar)
            let nowMinute = TimeOfDay(of: context.date, in: calendar).minutesSinceMidnight
            VStack(spacing: 2) {
                ForEach(Weekday.ordered(for: calendar), id: \.self) { day in
                    HStack(spacing: 8) {
                        Text(calendar.shortWeekdaySymbols[day.rawValue - 1])
                            .font(.caption)
                            .foregroundStyle(day == today ? .primary : .secondary)
                            .frame(width: labelWidth, alignment: .leading)
                        DayTrack(
                            ranges: rules.flatMap { $0.minuteRanges(on: day) },
                            nowMinute: day == today ? nowMinute : nil
                        )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityText(for: day))
                }
                HourAxis()
                    .padding(.leading, labelWidth + 8)
            }
            .padding(.vertical, 4)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }

    private func accessibilityText(for day: Weekday) -> String {
        let name = calendar.weekdaySymbols[day.rawValue - 1]
        let ranges = rules.flatMap { $0.minuteRanges(on: day) }
        guard !ranges.isEmpty else { return "\(name): no hours" }
        let spans = ranges.map { "\(Self.clock($0.lowerBound)) to \(Self.clock($0.upperBound))" }
        return "\(name): \(spans.joined(separator: ", "))"
    }

    private static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

private struct DayTrack: View {
    let ranges: [Range<Int>]
    /// Set on today's track only.
    let nowMinute: Int?

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / CGFloat(TimeOfDay.minutesPerDay)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 8)
                ForEach(ranges, id: \.self) { range in
                    Capsule()
                        .fill(.tint)
                        .frame(width: max(CGFloat(range.count) * scale, 4), height: 8)
                        .offset(x: CGFloat(range.lowerBound) * scale)
                }
                if let nowMinute {
                    Capsule()
                        .fill(.primary)
                        .frame(width: 2)
                        .offset(x: CGFloat(nowMinute) * scale - 1)
                }
            }
        }
        .frame(height: 14)
    }
}

private struct HourAxis: View {
    private let hours = [0, 6, 12, 18, 24]

    var body: some View {
        GeometryReader { geometry in
            ForEach(hours, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .fixedSize()
                    .position(x: geometry.size.width * CGFloat(hour) / 24, y: geometry.size.height / 2)
            }
        }
        .frame(height: 12)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
}

private struct ScheduleRuleRow: View {
    @Binding var rule: ScheduleRule
    let calendar: Calendar
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(Weekday.ordered(for: calendar), id: \.self) { day in
                        Toggle(calendar.veryShortWeekdaySymbols[day.rawValue - 1], isOn: isScheduled(day))
                            .toggleStyle(DayToggleStyle())
                            .help(calendar.weekdaySymbols[day.rawValue - 1])
                            .accessibilityLabel(calendar.weekdaySymbols[day.rawValue - 1])
                    }
                }
                if rule.weekdays.isEmpty {
                    Text("Pick at least one day")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    DatePicker("Start", selection: time(\.start), displayedComponents: .hourAndMinute)
                    Text("–")
                        .foregroundStyle(.secondary)
                    DatePicker("End", selection: time(\.end), displayedComponents: .hourAndMinute)
                }
                .labelsHidden()
                if rule.endsNextDay {
                    Text("Ends the next day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Remove Hours", systemImage: "minus.circle.fill", role: .destructive, action: delete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove these hours")
        }
        .padding(.vertical, 2)
    }

    private func isScheduled(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { rule.weekdays.contains(day) },
            set: { isOn in
                if isOn {
                    rule.weekdays.insert(day)
                } else {
                    rule.weekdays.remove(day)
                }
            }
        )
    }

    /// DatePicker edits a Date, so the time is shown on today's date and read back as a time of day.
    private func time(_ keyPath: WritableKeyPath<ScheduleRule, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { rule[keyPath: keyPath].date(onDayStarting: calendar.startOfDay(for: .now), in: calendar) ?? .now },
            set: { rule[keyPath: keyPath] = TimeOfDay(of: $0, in: calendar) }
        )
    }
}

/// A round day chip, filled with the accent color when the day is on, like the repeat days of an alarm.
private struct DayToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.caption.weight(.semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(configuration.isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .background(configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
