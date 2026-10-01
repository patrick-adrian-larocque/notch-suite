import AppKit

/// The borderless window that holds the island.
///
/// It never activates the app or takes key status, so showing it doesn't steal focus
/// from the frontmost app. It sits above the menu bar and its status items, on every
/// Space, and next to full-screen apps.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        // The placeholder has nothing to click. Hover and clicks arrive with the state
        // machine (#17), which turns mouse events back on.
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
