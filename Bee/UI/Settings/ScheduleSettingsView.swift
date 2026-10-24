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
                Toggle("Use schedule", isOn: schedule.isEnabled)
            }
            Section {
                ForEach(schedule.rules) { $rule in
                    ScheduleRuleRow(rule: $rule, calendar: calendar) {
                        schedule.wrappedValue.rules.removeAll { $0.id == rule.id }
                    }
                }
                Button("Add Rule") { schedule.wrappedValue.rules.append(.workHours) }
            }
            .disabled(!schedule.wrappedValue.isEnabled)
        }
        .formStyle(.grouped)
    }
}

private struct ScheduleRuleRow: View {
    @Binding var rule: ScheduleRule
    let calendar: Calendar
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Weekday.ordered(for: calendar), id: \.self) { day in
                    Toggle(calendar.shortWeekdaySymbols[day.rawValue - 1], isOn: isScheduled(day))
                        .toggleStyle(.button)
                }
                Spacer()
                Button("Delete Rule", systemImage: "trash", role: .destructive, action: delete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            HStack {
                DatePicker("From", selection: time(\.start), displayedComponents: .hourAndMinute)
                DatePicker("To", selection: time(\.end), displayedComponents: .hourAndMinute)
                if rule.endsNextDay {
                    Text("ends next day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
