import AppKit
import NotchCore
import SwiftUI

/// Places the notch panel and keeps it in place when displays change.
///
/// The panel is sized to the compact idle island from `IslandLayout`, using the notch
/// width measured on the current screen, and centred on the notch at the top edge.
@MainActor
final class NotchPanelController: NSObject {
    private let provider = ScreenNotchGeometryProvider()
    private let panel = NotchPanel()
    private let hostingView = NSHostingView(rootView: IslandPlaceholderView(cornerRadius: 0))

    override init() {
        super.init()
        // The panel sets its own frame, so the hosting view must not resize it.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    /// Positions the panel on the current screen and brings it on screen.
    func show() {
        reposition()
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        reposition()
    }

    private func reposition() {
        // Both reads pick the same screen: the screen list only changes between run loop
        // turns, and that change posts the notification that calls this again.
        guard let screen = provider.screen, let geometry = provider.geometry() else {
            panel.orderOut(nil)
            return
        }
        let size = IslandLayout(notchWidth: geometry.notchWidth).size(for: .idle, at: .compact)
        let frame = NSRect(
            x: screen.frame.minX + geometry.islandMinX(forIslandWidth: size.width),
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height)
        hostingView.rootView = IslandPlaceholderView(cornerRadius: size.cornerRadius)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }
}
