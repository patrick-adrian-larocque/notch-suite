import AppKit
import SwiftUI

/// Hosts `IslandView` in the notch panel and keeps the mouse to the island's area.
///
/// The panel is much bigger than the compact island, so that the island can grow
/// without the window resizing. Only the island's hit rect may take the mouse:
/// `NotchPanelController` turns the panel's `ignoresMouseEvents` off only while the
/// pointer is inside it, and `hitTest(_:)` here refuses everything else as a backstop.
/// So clicks on the menu bar beside the island still reach the menu bar.
final class IslandHostingView: NSHostingView<IslandView> {
    /// The island's hit rect in screen coordinates, or `nil` when there is none.
    var hitRectOnScreen: () -> NSRect? = { nil }
    /// Called whenever the pointer moves over, into or out of this view.
    var pointerDidMove: () -> Void = {}

    private var trackingArea: NSTrackingArea?

    /// The panel never becomes key, so without this the first click on the island would
    /// only be swallowed by the window instead of pressing the button under it.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window, let rect = hitRectOnScreen() else { return nil }
        // `point` is in the superview's coordinates.
        let inWindow = superview?.convert(point, to: nil) ?? point
        guard rect.contains(window.convertPoint(toScreen: inWindow)) else { return nil }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        // `.activeAlways`: the app is never active, since the panel doesn't activate it.
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        pointerDidMove()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        pointerDidMove()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        pointerDidMove()
    }
}
