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
    private var panelController: NotchPanelController?

    // TODO(#24): Own the real media source/presentation model from App/Media here.
    // Start it once after launch and stop processes/observation on termination.
    // Inject its state into the island shell after #23 / PR #44 lands.
    // Keep startup failures visible separately from a valid "nothing playing" state.

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchPanelController()
        controller.show()
        panelController = controller
    }
}
