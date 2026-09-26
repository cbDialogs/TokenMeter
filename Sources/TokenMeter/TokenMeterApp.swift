import AppKit
import SwiftUI

@main
struct TokenMeterApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var usage = UsageService()

    var body: some Scene {
        Window("TokenMeter", id: "meter") {
            ContentView()
                .environment(usage)
                .background(.regularMaterial)
        }
        .windowLevel(.floating)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 300, height: 330)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") { usage.refresh() }
                    .keyboardShortcut("r")
            }
        }

        Settings {
            SettingsView()
                .environment(usage)
        }
        // Same level as the meter, or it would open behind it.
        .windowLevel(.floating)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` (no bundle), harmless in the .app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
