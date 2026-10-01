/// Runs an action once after a delay.
///
/// `IslandStateMachine` gets its timing from this protocol instead of `Timer`, a run
/// loop or Dispatch, so tests can drive time by hand and the logic runs on Linux. The
/// app target supplies the real implementation, for example a `Task` that sleeps on a
/// `ContinuousClock`.
@MainActor
public protocol DelayScheduler {
    /// Schedules `action` to run once, `delay` from now, on the main actor.
    ///
    /// Returns a handle that stops the action from running if it is cancelled first.
    /// A delay of zero still runs the action later, never inside this call.
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void)
        -> any ScheduledDelay
}

/// A pending action returned by ``DelayScheduler/schedule(after:_:)``.
@MainActor
public protocol ScheduledDelay {
    /// Stops the action from running.
    ///
    /// Once this returns, the action must never run, even if its delay has already
    /// elapsed. Cancelling after the action ran, or twice, does nothing.
    func cancel()
}
