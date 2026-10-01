/// Reports the system's reduce-motion accessibility setting.
///
/// The app target implements this on top of the macOS accessibility setting.
/// `MotionSpec` turns reduce motion on when this or the in-app toggle is on.
/// It is main-actor isolated because the app reads the setting from `NSWorkspace` on the
/// main thread, as `NotchGeometryProvider` does with `NSScreen`.
@MainActor
public protocol ReduceMotionProvider {
    /// Whether the system's reduce-motion setting is on right now.
    var isReduceMotionEnabled: Bool { get }

    /// A stream that yields the current value at once and then each change.
    ///
    /// Each call returns a new stream, so several observers can each have one.
    func reduceMotionUpdates() -> AsyncStream<Bool>
}

extension ReduceMotionProvider {
    /// The motion for `settings`, using this provider's current system setting.
    public func motionSpec(for settings: IslandSettings) -> MotionSpec {
        MotionSpec(settings: settings, systemReduceMotion: isReduceMotionEnabled)
    }
}
