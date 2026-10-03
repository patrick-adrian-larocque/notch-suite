import AppKit
import NotchCore

/// Reads the system reduce-motion setting (System Settings › Accessibility › Display ›
/// Reduce motion) from `NSWorkspace`.
@MainActor
struct WorkspaceReduceMotionProvider: ReduceMotionProvider {
    var isReduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func reduceMotionUpdates() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Bool.self, bufferingPolicy: .bufferingNewest(1))
        continuation.yield(isReduceMotionEnabled)
        // Any accessibility display option posts this, so it can repeat a value.
        let center = NSWorkspace.shared.notificationCenter
        let observer = center.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                _ = continuation.yield(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            }
        }
        let registration = ObserverRegistration(center: center, observer: observer)
        continuation.onTermination = { _ in registration.remove() }
        return stream
    }
}

/// Removes a block-based notification observer when the stream it feeds ends.
///
/// `@unchecked Sendable` because `onTermination` may run on any thread: both stored
/// properties are immutable after `init`, and `NotificationCenter.removeObserver(_:)` is
/// thread-safe.
private final class ObserverRegistration: @unchecked Sendable {
    private let center: NotificationCenter
    private let observer: any NSObjectProtocol

    init(center: NotificationCenter, observer: any NSObjectProtocol) {
        self.center = center
        self.observer = observer
    }

    func remove() {
        center.removeObserver(observer)
    }
}
