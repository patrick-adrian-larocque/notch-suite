import Foundation

/// Where playback is within the current track, extrapolated between updates.
///
/// The media source only reports `elapsedTime` when something changes (play, pause, seek,
/// track change), so the player view extrapolates from the last sample:
/// `elapsedTime + (now - sampledAt) * playbackRate`. The result is clamped to
/// `0...duration`, so a track that runs over its reported length stops at the end
/// instead of counting past it.
///
/// Rebuild the value from each new `NowPlaying` update; it does not change on its own.
public struct PlaybackProgress: Sendable, Equatable {
    /// Elapsed time in seconds at `sampledAt`. Never negative.
    public let elapsedTime: Double
    /// Track length in seconds, or `nil` when the source didn't report a usable one.
    public let duration: Double?
    /// Seconds of media per second of wall-clock time. `0` while paused.
    public let playbackRate: Double
    /// The moment `elapsedTime` was true.
    public let sampledAt: Date

    /// Creates a progress sample. Values the source got wrong are made safe here:
    /// a negative or non-finite `elapsedTime` reads as `0`, a zero, negative or
    /// non-finite `duration` reads as unknown, and a non-finite `playbackRate` as `0`.
    public init(elapsedTime: Double, duration: Double?, playbackRate: Double, sampledAt: Date) {
        self.elapsedTime = elapsedTime.isFinite ? max(0, elapsedTime) : 0
        if let duration, duration.isFinite, duration > 0 {
            self.duration = duration
        } else {
            self.duration = nil
        }
        self.playbackRate = playbackRate.isFinite ? playbackRate : 0
        self.sampledAt = sampledAt
    }

    /// Reads the progress out of a now-playing update.
    ///
    /// A paused track has rate `0`. A playing track uses its reported `playbackRate`,
    /// or `1` when it reports none. Returns `nil` when the update has no `elapsedTime`,
    /// since there is nothing to extrapolate from.
    ///
    /// - Parameter sampledAt: When `nowPlaying.elapsedTime` was true. Pass the time the
    ///   update arrived; the adapter's own `timestamp` key only has whole-second precision.
    public init?(nowPlaying: NowPlaying, sampledAt: Date) {
        guard let elapsedTime = nowPlaying.elapsedTime else { return nil }
        self.init(
            elapsedTime: elapsedTime,
            duration: nowPlaying.duration,
            playbackRate: nowPlaying.playing ? (nowPlaying.playbackRate ?? 1) : 0,
            sampledAt: sampledAt
        )
    }

    /// Elapsed seconds at `now`, clamped to `0...duration` (or just `0...` when the
    /// duration is unknown). A `now` earlier than `sampledAt` returns `elapsedTime`.
    public func elapsed(at now: Date) -> Double {
        let wallClock = max(0, now.timeIntervalSince(sampledAt))
        let value = max(0, elapsedTime + wallClock * playbackRate)
        guard let duration else { return value }
        return min(value, duration)
    }

    /// Seconds left at `now`, or `nil` when the duration is unknown. Never negative.
    public func remaining(at now: Date) -> Double? {
        guard let duration else { return nil }
        return duration - elapsed(at: now)
    }

    /// How far through the track playback is at `now`, from `0` to `1`, or `nil` when the
    /// duration is unknown.
    public func fraction(at now: Date) -> Double? {
        guard let duration else { return nil }
        return elapsed(at: now) / duration
    }

    /// The elapsed label, such as `1:05`.
    public func elapsedText(at now: Date) -> String {
        PlaybackTimeFormat.elapsed(elapsed(at: now))
    }

    /// The remaining label, such as `-2:55`, or `nil` when the duration is unknown.
    public func remainingText(at now: Date) -> String? {
        remaining(at: now).map(PlaybackTimeFormat.remaining)
    }
}

/// Formats playback times for the player's progress row.
public enum PlaybackTimeFormat {
    /// `m:ss` below an hour and `h:mm:ss` from an hour up. Negative values read as `0`.
    public static func string(wholeSeconds: Int) -> String {
        let total = max(0, wholeSeconds)
        let hours = total / 3600
        let minutes = total / 60 % 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours):\(twoDigits(minutes)):\(twoDigits(seconds))"
        }
        return "\(minutes):\(twoDigits(seconds))"
    }

    /// An elapsed time, rounded down so the label only ticks once a second has fully passed.
    /// Negative and non-finite values read as `0:00`.
    public static func elapsed(_ seconds: Double) -> String {
        string(wholeSeconds: wholeSeconds(seconds, rule: .down))
    }

    /// A remaining time with a leading minus, rounded up so that it and the rounded-down
    /// elapsed label add up to the track length. Negative and non-finite values read as `-0:00`.
    public static func remaining(_ seconds: Double) -> String {
        "-" + string(wholeSeconds: wholeSeconds(seconds, rule: .up))
    }

    private static func wholeSeconds(_ seconds: Double, rule: FloatingPointRoundingRule) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        // Clamp before converting: Int(_:) traps on values it can't represent.
        return Int(min(seconds.rounded(rule), Double(Int32.max)))
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
