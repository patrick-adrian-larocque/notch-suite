/// A transport control the Now Playing island can send to the current player.
public enum MediaCommand: Sendable, Hashable, CaseIterable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
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

    /// Sends `command` to the current player.
    ///
    /// Throws when the command can't be delivered. Sending a command while nothing
    /// is playing is not an error; the player decides what it does.
    func send(_ command: MediaCommand) async throws
}
