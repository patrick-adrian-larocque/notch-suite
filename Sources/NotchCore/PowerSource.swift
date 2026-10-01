/// Reports the battery's charge.
///
/// Implemented in the app target on top of IOKit's power source notifications, so
/// that `NotchCore` stays free of macOS frameworks.
public protocol PowerSource: Sendable {
    /// A new stream of battery states.
    ///
    /// Each call returns its own stream, so several observers can listen at once.
    /// The stream yields the current state first, then one state per change. On a
    /// Mac without a battery it finishes without yielding anything.
    func batteryStates() -> AsyncStream<BatteryState>
}
