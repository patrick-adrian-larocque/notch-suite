import AppKit
import NotchCore

/// Reads notch metrics from `NSScreen`.
///
/// The island goes on the built-in display when there is one, because that is the only
/// screen with a notch. With the lid closed, or on a Mac without a built-in display, it
/// uses the main screen, where `NotchGeometry` falls back to the virtual notch.
@MainActor
struct ScreenNotchGeometryProvider: NotchGeometryProvider {
    /// The screen the island is shown on, or `nil` when no screen is attached.
    var screen: NSScreen? {
        NSScreen.screens.first(where: \.isBuiltIn) ?? NSScreen.main ?? NSScreen.screens.first
    }

    func screenMetrics() -> ScreenMetrics? {
        screen.map(ScreenMetrics.init(screen:))
    }
}

extension ScreenMetrics {
    /// The metrics of `screen`, in points.
    ///
    /// `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` are the menu bar strips beside
    /// the notch, and are `nil` on a screen without one.
    @MainActor
    init(screen: NSScreen) {
        self.init(
            screenWidth: Double(screen.frame.width),
            topInset: Double(screen.safeAreaInsets.top),
            auxiliaryTopLeftWidth: screen.auxiliaryTopLeftArea.map { Double($0.width) },
            auxiliaryTopRightWidth: screen.auxiliaryTopRightArea.map { Double($0.width) })
    }
}

extension NSScreen {
    /// Whether this is the Mac's own display rather than an external one.
    var isBuiltIn: Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber else { return false }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }
}
