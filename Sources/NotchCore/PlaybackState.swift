/// Whether something is playing, paused, or stopped, remembering the last track.
///
/// The media source only says what is current; once a player quits or clears its
/// session, the update is simply empty. The player view still wants to show
/// "Last played: <title>" with a Resume button, so this keeps that track around.
public enum PlaybackState: Sendable, Equatable {
    /// A track is playing.
    case playing(NowPlaying)
    /// A track is loaded but paused.
    case paused(NowPlaying)
    /// Nothing is loaded. `lastPlayed` is the track that was current before, if any.
    case stopped(lastPlayed: NowPlaying?)

    /// Nothing has played yet.
    public static let idle = PlaybackState.stopped(lastPlayed: nil)

    /// The state after a media source update.
    ///
    /// A non-`nil` update is playing or paused according to its `playing` flag. A `nil`
    /// update means the source reports no session (not an incomplete or malformed
    /// report, which the source must not pass on as `nil`). It stops playback and keeps
    /// whichever track was current (or was already the last played) as `lastPlayed`.
    public func updated(with nowPlaying: NowPlaying?) -> PlaybackState {
        if let nowPlaying {
            return nowPlaying.playing ? .playing(nowPlaying) : .paused(nowPlaying)
        }
        switch self {
        case .playing(let track), .paused(let track):
            return .stopped(lastPlayed: track)
        case .stopped:
            return self
        }
    }

    /// The loaded track, playing or paused. `nil` when stopped.
    public var nowPlaying: NowPlaying? {
        switch self {
        case .playing(let track), .paused(let track): track
        case .stopped: nil
        }
    }

    /// The track to offer for resuming. Only set when stopped.
    public var lastPlayed: NowPlaying? {
        switch self {
        case .playing, .paused: nil
        case .stopped(let lastPlayed): lastPlayed
        }
    }

    /// Whether a track is playing right now.
    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
}

extension NowPlaying {
    /// Whether `other` is the same track, ignoring playback position, rate and play state.
    ///
    /// Compares title, artist and album, and the application when that can be decided.
    /// Identities that disagree on a known part are different applications, so different
    /// tracks. Identities that can't be compared (for example, both unknown) don't prove
    /// the same application either; the metadata is then the only evidence and decides
    /// alone. Duration is left out because some players only report it a moment after
    /// the track starts.
    public func isSameTrack(as other: NowPlaying) -> Bool {
        app.isSameApplication(as: other.app) != false
            && title == other.title
            && artist == other.artist
            && album == other.album
    }
}
