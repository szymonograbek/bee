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
        .frame(width: 460, height: 360)
        .onAppear { bee.refreshLoginItem() }
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
                    HStack {
                        Text("Allow Bee in System Settings to finish.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                case let .failed(message):
                    Text(message)
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
                    Text("Also prevent display sleep")
                    Text("Otherwise the display can turn off while the Mac stays awake.")
                }
            }
        }
        .formStyle(.grouped)
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
                    LabeledContent("Status", value: bee.state.integrations[id, default: .disabled].statusText)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private extension IntegrationID {
    var explanation: String {
        switch self {
        case .t3Code: "Keeps your Mac awake while any T3 Code thread is running. Checked every 30 seconds."
        }
    }
}
