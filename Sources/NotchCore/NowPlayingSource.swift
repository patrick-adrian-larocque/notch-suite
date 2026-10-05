import Foundation

/// A transport control the Now Playing island can send to the current player.
public enum MediaCommand: Sendable, Hashable, CaseIterable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
}

/// Whether the source's engine is running normally or down.
///
/// A generic stand-in for the app target's own, more detailed engine status (such as
/// `MediaRemoteEngine.Status`), so that `NotchCore` never depends on it.
public enum NowPlayingSourceHealth: Sendable, Equatable {
    /// The engine is running.
    case ready
    /// The engine exited or couldn't start, or its resources are missing. The media
    /// state is unknown until it recovers; this is not "nothing playing".
    case down
}

/// Reports what is playing and forwards transport controls to the player.
///
/// Implemented in the app target on top of mediaremote-adapter, so that `NotchCore`
/// stays free of macOS frameworks. `NowPlayingStreamParser` turns the adapter's
/// output into the values this source yields.
public protocol NowPlayingSource: Sendable {
    /// A new stream of now-playing updates.
    ///
    /// Each call returns its own stream, so several observers can listen at once.
    /// The stream yields the current state first, then one value per change. `nil`
    /// means no player reports a session (`NowPlayingReport.noSession`). An incomplete
    /// or malformed report is not `nil`: the source yields nothing for it, so the last
    /// session stays current.
    func nowPlayingUpdates() -> AsyncStream<NowPlaying?>

    /// A new stream of artwork changes. `nil` means the current track has none.
    ///
    /// Each call returns its own stream; the current artwork is not replayed to a new
    /// observer, and ``NowPlaying`` carries no artwork, so subscribe before the source
    /// starts to see a track's first cover. Artwork usually arrives once per track, a
    /// moment after its first update.
    func artworkUpdates() -> AsyncStream<Data?>

    /// A new stream of engine health changes.
    ///
    /// Each call returns its own stream. A source may yield its current health first, as
    /// the macOS source does when its engine is already running or down; otherwise a
    /// caller should assume ``NowPlayingSourceHealth/ready`` until told otherwise.
    func healthUpdates() -> AsyncStream<NowPlayingSourceHealth>

    /// Sends `command` to the current player.
    ///
    /// Throws when the command can't be delivered. Sending a command while nothing
    /// is playing is not an error; the player decides what it does.
    func send(_ command: MediaCommand) async throws
}
