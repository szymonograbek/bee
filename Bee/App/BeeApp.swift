import SwiftUI

@main
struct BeeApp: App {
    @State private var bee = BeeController.live()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(bee: bee)
        } label: {
            Image(nsImage: BeeGlyph.menuBarImage(awake: bee.activity.isAwake))
        }
        .menuBarExtraStyle(.menu)

        // A plain Window: the Settings scene does not open reliably from an LSUIElement app.
        Window("Bee Settings", id: "settings") {
            SettingsView(bee: bee)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
