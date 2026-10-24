import SwiftUI

@main
struct BeeApp: App {
    @State private var bee = BeeController.live()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(bee: bee)
                .labelStyle(.titleAndIcon)
        } label: {
            Image(nsImage: BeeGlyph.menuBarImage(awake: bee.activity.isAwake))
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(bee: bee)
        }
    }
}
