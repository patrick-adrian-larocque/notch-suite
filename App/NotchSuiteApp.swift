import AppKit
import SwiftUI

/// The app's entry point.
///
/// `LSUIElement` keeps the app out of the Dock and the app switcher, so the status item
/// is the only way to reach it. The notch panel itself is AppKit, owned by `AppDelegate`.
@main
struct NotchSuiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Notch Suite", systemImage: "capsule.fill") {
            Button("Quit Notch Suite") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The app's object graph, created once at launch.
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let environment = AppEnvironment()
        environment.start()
        self.environment = environment
        #if DEBUG
            HUDSpikeController.startIfEnabled()  // #26 spike; off unless `-HUDSpike YES`
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.stop()
    }
}
