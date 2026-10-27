import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let bee: BeeController

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings(bee: bee)
            }
            Tab("Schedule", systemImage: "calendar") {
                ScheduleSettingsView(bee: bee)
            }
            Tab("Integrations", systemImage: "puzzlepiece.extension") {
                IntegrationSettings(bee: bee)
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background(BringWindowForward())
        .onAppear { bee.refreshSystemStatus() }
    }
}

/// macOS may refuse to activate a menu bar app, which would leave Settings behind the app the user came from.
/// Ordering the window front explicitly works either way.
private struct BringWindowForward: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ForwardingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ForwardingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            NSApp.activate()
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}

extension View {
    /// A grouped form at its natural height, so the Settings window resizes to fit each tab.
    func settingsPane() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 480)
    }
}

private struct GeneralSettings: View {
    let bee: BeeController

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { bee.loginItem == .enabled || bee.loginItem == .requiresApproval },
                    set: { bee.perform(.setOption(.launchAtLogin, $0)) }
                ))
                switch bee.loginItem {
                case .requiresApproval:
                    LabeledContent {
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    } label: {
                        Text("Needs your approval")
                        Text("Allow Bee in System Settings to finish.")
                    }
                case let .failed(message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                case .enabled, .disabled:
                    EmptyView()
                }
            }
            Section {
                Toggle(isOn: Binding(
                    get: { bee.preventsDisplaySleep },
                    set: { bee.perform(.setOption(.preventsDisplaySleep, $0)) }
                )) {
                    Text("Keep the display on")
                    Text("By default only the Mac stays awake, and the display can still turn off.")
                }
            }
            Section {
                Toggle(isOn: Binding(
                    get: { bee.keepsAwakeWithLidClosed },
                    set: { bee.perform(.setOption(.keepsAwakeWithLidClosed, $0)) }
                )) {
                    Text("Keep awake with the lid closed")
                    Text(
                        "While Bee is keeping your Mac awake, closing the lid won't put it to sleep. "
                            + "Bee asks for your password once to allow this."
                    )
                }
                .disabled(bee.lidSleepPermission.isBusy)
                PermissionFailure(permission: bee.lidSleepPermission)
            }
            LidBluetoothSettings(bee: bee)
            if bee.state.power.batteryCharge != nil {
                BatterySettings(bee: bee)
            }
        }
        .settingsPane()
    }
}

private struct BatterySettings: View {
    let bee: BeeController

    var body: some View {
        let limit = bee.state.batteryLimit
        Section {
            Toggle(isOn: binding(\.isEnabled)) {
                Text("Stop on low battery")
                Text(
                    "Lets your Mac sleep when the battery drops below the limit, "
                        + "even if you asked Bee to keep it awake."
                )
            }
            if limit.isEnabled {
                LabeledContent("Limit") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(limit.minimumCharge) },
                                set: { update(\.minimumCharge, Int($0)) }
                            ),
                            in: 5...95,
                            step: 5
                        )
                        Text("\(limit.minimumCharge)%")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .frame(width: 220)
                }
                Toggle("Ignore while plugged in", isOn: binding(\.ignoresWhilePluggedIn))
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<BatteryLimit, Bool>) -> Binding<Bool> {
        Binding(get: { bee.state.batteryLimit[keyPath: keyPath] }, set: { update(keyPath, $0) })
    }

    private func update<Value>(_ keyPath: WritableKeyPath<BatteryLimit, Value>, _ value: Value) {
        var limit = bee.state.batteryLimit
        limit[keyPath: keyPath] = value
        bee.perform(.setBatteryLimit(limit))
    }
}

private struct IntegrationSettings: View {
    let bee: BeeController

    var body: some View {
        Form {
            ForEach(IntegrationID.allCases, id: \.self) { id in
                Section {
                    Toggle(isOn: Binding(
                        get: { bee.isEnabled(id) },
                        set: { bee.perform(.setOption(.integration(id), $0)) }
                    )) {
                        Text(id.displayName)
                        Text(id.explanation)
                    }
                    if bee.isEnabled(id) {
                        IntegrationOptions(id: id, bee: bee)
                        LabeledContent("Status") {
                            IntegrationStatus(state: bee.state.integrations[id, default: .disabled])
                        }
                    }
                }
            }
        }
        .settingsPane()
    }
}

private struct IntegrationOptions: View {
    let id: IntegrationID
    let bee: BeeController

    var body: some View {
        switch id {
        case .t3Code:
            Toggle(isOn: Binding(
                get: { bee.keepsAwakeForT3AutoResume },
                set: { bee.perform(.setOption(.keepsAwakeForT3AutoResume, $0)) }
            )) {
                Text("Wait for auto-resume")
                Text("Stays awake while a thread that hit a usage limit waits to resume on its own.")
            }
            Toggle(isOn: Binding(
                get: { bee.sleepsUntilAutoResume },
                set: { bee.perform(.setOption(.sleepsUntilAutoResume, $0)) }
            )) {
                Text("Sleep until it resumes")
                Text(
                    "When you're away, lets your Mac sleep and wakes it a minute before the thread resumes. "
                        + "Bee asks for your password once to allow this."
                )
            }
            .disabled(!bee.keepsAwakeForT3AutoResume || bee.resumeNapPermission.isBusy)
            PermissionFailure(permission: bee.resumeNapPermission)
        case .claudeCode, .codex:
            EmptyView()
        }
    }
}

/// The last reading, with a symbol and color so a problem stands out from normal activity.
private struct IntegrationStatus: View {
    let state: IntegrationState

    var body: some View {
        switch state {
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(state.statusText)
            }
        case .reported(.active), .reported(.awaitingResume):
            symbol("circle.fill", .green)
        case .reported(.unavailable):
            symbol("exclamationmark.triangle.fill", .orange)
        case .disabled, .reported(.idle):
            symbol("circle", .secondary)
        }
    }

    private func symbol(_ name: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: name)
                .imageScale(.small)
                .foregroundStyle(tint)
            Text(state.statusText)
        }
    }
}

private extension IntegrationID {
    var explanation: String {
        switch self {
        case .t3Code:
            "Keeps your Mac awake while any T3 Code thread is running, or for up to 2 hours while it waits on you."
        case .claudeCode:
            "Keeps your Mac awake while a Claude Code session you started is working, "
                + "or for up to 2 hours while it waits on you."
        case .codex: "Keeps your Mac awake while a Codex session you started is working or waiting on you."
        }
    }
}

/// Shown under a setting whose sudo permission couldn't be granted.
private struct PermissionFailure: View {
    let permission: SudoPermission.State

    var body: some View {
        if case let .failed(message) = permission {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

private extension SudoPermission.State {
    /// Checking or installing, when the setting can't be changed yet.
    var isBusy: Bool {
        self == .checking || self == .installing
    }
}
