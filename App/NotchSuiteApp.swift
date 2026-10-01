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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchPanelController()
        controller.show()
        panelController = controller
    }
}
