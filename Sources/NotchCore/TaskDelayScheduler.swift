/// A ``DelayScheduler`` that waits on the continuous clock in a `Task`.
///
/// This is the scheduler the app runs with. It needs nothing from the platform, so it
/// lives here, where it can be tested. The continuous clock keeps counting while the Mac
/// sleeps, so a delay that spans a sleep ends on wake instead of running late.
@MainActor
public struct TaskDelayScheduler: DelayScheduler {
    public init() {}

    public func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void)
        -> any ScheduledDelay
    {
        let pending = PendingTask()
        // The task always suspends at least once, so the action never runs inside this
        // call, even for a zero delay.
        pending.task = Task { @MainActor in
            try? await Task.sleep(for: delay, clock: .continuous)
            // Don't rely on the sleep throwing: it can finish and queue this task before
            // a `cancel()` that gets the main actor first, and a finished sleep no longer
            // throws. `cancel()` sets this flag on the main actor, so checking it here,
            // also on the main actor, can't miss one.
            guard !pending.isCancelled else { return }
            pending.task = nil
            action()
        }
        return pending
    }
}

/// The handle ``TaskDelayScheduler`` returns.
@MainActor
private final class PendingTask: ScheduledDelay {
    var task: Task<Void, Never>?
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }
}
