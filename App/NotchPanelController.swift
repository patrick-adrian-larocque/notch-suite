import AppKit
import NotchCore
import SwiftUI

/// Owns the notch panel: places it on the notch, feeds the pointer into the island's
/// state machine, and keeps the panel's mouse handling to the island's area.
///
/// It receives the island model and providers from `AppEnvironment` and creates only
/// its window and hosting view.
///
/// The panel is a fixed canvas big enough for the largest island plus its shadow,
/// centred on the notch at the top edge. The island morphs inside it, so the window never
/// resizes. The mouse only reaches the panel while the pointer is inside the island's
/// hit rect; everywhere else, clicks fall through to the menu bar and apps below.
@MainActor
final class NotchPanelController: NSObject {
    private let geometryProvider: ScreenNotchGeometryProvider
    private let reduceMotionProvider: any ReduceMotionProvider
    private let panel = NotchPanel()
    private let model: IslandModel
    private let hostingView: IslandHostingView
    /// The frame of the screen the panel is on, in global screen coordinates.
    private var screenFrame: NSRect?
    private var mouseMonitors: [Any] = []
    private var reduceMotionTask: Task<Void, Never>?

    init(
        model: IslandModel,
        geometryProvider: ScreenNotchGeometryProvider,
        reduceMotionProvider: any ReduceMotionProvider
    ) {
        self.model = model
        self.geometryProvider = geometryProvider
        self.reduceMotionProvider = reduceMotionProvider
        hostingView = IslandHostingView(rootView: IslandView(model: model))
        super.init()

        // The panel sets its own frame, so the hosting view must not resize it.
        hostingView.sizingOptions = []
        hostingView.hitRectOnScreen = { [weak self] in self?.islandHitRect }
        hostingView.pointerDidMove = { [weak self] in self?.updatePointer() }
        panel.contentView = hostingView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        monitorMouse()
        followReduceMotion()
        followIsland()
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
        guard let screen = geometryProvider.screen, let geometry = geometryProvider.geometry()
        else {
            screenFrame = nil
            panel.orderOut(nil)
            return
        }
        model.geometry = geometry
        screenFrame = screen.frame
        let canvas = model.canvasSize
        let frame = NSRect(
            x: screen.frame.minX + geometry.notchMidX - canvas.width / 2,
            y: screen.frame.maxY - canvas.height,
            width: canvas.width,
            height: canvas.height)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        updatePointer()
    }

    /// The area that takes the mouse, in global screen coordinates: the island at its
    /// current size, centred on the notch at the top edge and at least 44 pt each way.
    private var islandHitRect: NSRect? {
        guard let screenFrame else { return nil }
        let size = model.islandSize
        let width = size.hitTargetWidth
        let height = size.hitTargetHeight
        // One extra point above the top edge, because `NSRect.contains` leaves out its
        // max-Y edge and a pointer pushed against the top of the screen sits right on it.
        return NSRect(
            x: screenFrame.minX + model.geometry.notchMidX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height + 1)
    }

    // MARK: Pointer

    /// Checks where the pointer is, lets the panel take the mouse only over the island,
    /// and tells the state machine whether the pointer is on it.
    private func updatePointer() {
        guard let rect = islandHitRect else { return }
        let isInside = rect.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == isInside {
            panel.ignoresMouseEvents = !isInside
        }
        if isInside {
            model.stateMachine.pointerEntered()
        } else {
            model.stateMachine.pointerLeft()
        }
    }

    /// Watches the pointer everywhere, not only over the panel.
    ///
    /// While the panel ignores the mouse, moves go to other apps, so a global monitor
    /// sees them; mouse monitors need no accessibility permission. While the panel takes
    /// the mouse, the local monitor and the hosting view's tracking area see them.
    private func monitorMouse() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: events,
            handler: { [weak self] _ in
                MainActor.assumeIsolated { self?.updatePointer() }
            })
        {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: events,
            handler: { [weak self] event in
                MainActor.assumeIsolated { self?.updatePointer() }
                return event
            })
        {
            mouseMonitors.append(local)
        }
    }

    /// Re-checks the pointer whenever the island changes size, since a pointer that
    /// hasn't moved can still end up inside or outside it, for example after collapse.
    private func followIsland() {
        withObservationTracking {
            _ = model.islandSize
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updatePointer()
                self?.followIsland()
            }
        }
    }

    private func followReduceMotion() {
        let updates = reduceMotionProvider.reduceMotionUpdates()
        reduceMotionTask = Task { [weak self] in
            for await isEnabled in updates {
                self?.model.systemReduceMotion = isEnabled
            }
        }
    }
}
