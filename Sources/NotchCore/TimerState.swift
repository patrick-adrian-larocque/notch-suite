/// A countdown timer, advanced by its owner rather than by a clock.
///
/// `TimerState` never reads the time. Whoever owns it calls `tick(by:)` with the
/// seconds that passed since the last tick, which keeps every transition testable
/// without waiting. Stopping the timer is not a state: the owner drops the value.
///
/// Transitions:
/// - A new timer starts `running` with the whole duration remaining.
/// - `tick(by:)` counts down while `running`, and reaching zero makes it `done`.
/// - `pause()` works only while `running`; `resume()` only while `paused`.
/// - `restart()` refills `remainingSeconds` from `totalSeconds` and runs, from any phase.
/// - `addMinute()` adds `addedSeconds`. A `done` timer starts running again; a paused
///   one stays paused.
public struct TimerState: Sendable, Hashable {
    /// Where the timer is in its countdown.
    public enum Phase: Sendable, Hashable {
        /// Counting down.
        case running
        /// Holding its remaining time until resumed.
        case paused
        /// Reached zero.
        case done
    }

    /// How much `addMinute()` adds, in seconds.
    public static let addedSeconds: Double = 60

    /// The duration the countdown runs from, in seconds. Always positive, and never
    /// less than `remainingSeconds`.
    public private(set) var totalSeconds: Double
    /// Seconds left, from `0` up to `totalSeconds`.
    public private(set) var remainingSeconds: Double
    /// Whether the timer is running, paused or done.
    public private(set) var phase: Phase

    /// Creates a running timer with `totalSeconds` remaining.
    ///
    /// Returns `nil` when `totalSeconds` is not a positive, finite number.
    public init?(totalSeconds: Double) {
        guard totalSeconds.isFinite, totalSeconds > 0 else { return nil }
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
        self.phase = .running
    }

    /// Whether the timer is counting down.
    public var isRunning: Bool { phase == .running }

    /// Whether the timer has reached zero.
    public var isDone: Bool { phase == .done }

    /// Seconds counted down so far.
    public var elapsedSeconds: Double { totalSeconds - remainingSeconds }

    /// The share of the duration still left, from `1` for a fresh timer to `0` when
    /// done. The countdown ring draws this.
    public var fractionRemaining: Double { remainingSeconds / totalSeconds }

    /// Counts down by `seconds`, if the timer is running.
    ///
    /// A tick that would go below zero stops at zero and makes the timer `done`.
    /// Ticks while paused or done, and negative or non-finite ticks, change nothing.
    ///
    /// - Returns: `true` only for the tick that finishes the timer, so the owner can
    ///   raise the "timer done" alert exactly once.
    @discardableResult
    public mutating func tick(by seconds: Double) -> Bool {
        guard phase == .running, seconds.isFinite, seconds > 0 else { return false }
        remainingSeconds = max(remainingSeconds - seconds, 0)
        guard remainingSeconds == 0 else { return false }
        phase = .done
        return true
    }

    /// Pauses a running timer. Does nothing otherwise.
    public mutating func pause() {
        if phase == .running { phase = .paused }
    }

    /// Resumes a paused timer. Does nothing otherwise.
    public mutating func resume() {
        if phase == .paused { phase = .running }
    }

    /// Refills the timer to `totalSeconds` and runs it, whatever its phase.
    public mutating func restart() {
        remainingSeconds = totalSeconds
        phase = .running
    }

    /// Adds `addedSeconds` to the remaining time.
    ///
    /// `totalSeconds` grows only as far as needed to stay at least `remainingSeconds`,
    /// so the ring never shows more than full. A done timer starts running again; a
    /// paused timer stays paused.
    public mutating func addMinute() {
        remainingSeconds += Self.addedSeconds
        totalSeconds = max(totalSeconds, remainingSeconds)
        if phase == .done { phase = .running }
    }
}
