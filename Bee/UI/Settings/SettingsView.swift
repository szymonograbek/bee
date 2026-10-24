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
        .background(BringWindowForward())
        .onAppear { bee.refreshLoginItem() }
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
                    set: { bee.perform(.setLaunchAtLogin($0)) }
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
                    set: { bee.perform(.setPreventsDisplaySleep($0)) }
                )) {
                    Text("Keep the display on")
                    Text("By default only the Mac stays awake, and the display can still turn off.")
                }
            }
        }
        .settingsPane()
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
                        set: { bee.perform(.setIntegration(id, enabled: $0)) }
                    )) {
                        Text(id.displayName)
                        Text(id.explanation)
                    }
                    if bee.isEnabled(id) {
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
        case .reported(.active):
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
        case .t3Code: "Keeps your Mac awake while any T3 Code thread is running. Checked every 30 seconds."
        }
    }
}
