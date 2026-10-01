import Foundation

/// What the player view should show in the artwork slot.
public enum ArtworkState: Sendable, Equatable {
    /// The track just started and its artwork hasn't arrived yet. Show a placeholder shimmer.
    case loading
    /// The artwork image bytes, as the media source supplied them.
    case loaded(Data)
    /// There is no artwork to wait for. Show the static placeholder.
    case missing
}

/// Decides the `ArtworkState` from now-playing updates and the time.
///
/// The rule:
/// - Nothing playing: `missing`.
/// - A new track with artwork: `loaded`.
/// - A new track without artwork: `loading` for `loadingTimeout` seconds, then `missing`.
///   Artwork that arrives later still moves it to `loaded`.
/// - Artwork that disappears while the same track is current is kept, since media
///   sources briefly drop it, for example while seeking.
///
/// Feed every update to `update(nowPlaying:artwork:at:)` and read `state(at:)`. While
/// the state is `loading`, `loadingDeadline` says when to read it again.
public struct ArtworkTracker: Sendable {
    /// How long a new track waits for artwork before falling back, in seconds.
    public static let defaultLoadingTimeout: TimeInterval = 3

    public let loadingTimeout: TimeInterval
    private var track: NowPlaying?
    private var trackStartedAt = Date.distantPast
    private var artwork: Data?

    public init(loadingTimeout: TimeInterval = ArtworkTracker.defaultLoadingTimeout) {
        self.loadingTimeout = loadingTimeout
    }

    /// Records a media source update that arrived at `now`.
    ///
    /// - Parameter artwork: The update's artwork bytes. Empty data counts as none.
    public mutating func update(nowPlaying: NowPlaying?, artwork: Data?, at now: Date) {
        let artwork = artwork?.isEmpty == false ? artwork : nil
        guard let nowPlaying else {
            track = nil
            self.artwork = nil
            return
        }
        if let track, track.isSameTrack(as: nowPlaying) {
            if let artwork { self.artwork = artwork }
        } else {
            trackStartedAt = now
            self.artwork = artwork
        }
        track = nowPlaying
    }

    /// The artwork state at `now`.
    public func state(at now: Date) -> ArtworkState {
        guard track != nil else { return .missing }
        if let artwork { return .loaded(artwork) }
        return now < giveUpTime ? .loading : .missing
    }

    /// When a `loading` state turns into `missing` unless artwork arrives first.
    /// `nil` when nothing is waiting for artwork.
    public var loadingDeadline: Date? {
        guard track != nil, artwork == nil else { return nil }
        return giveUpTime
    }

    private var giveUpTime: Date {
        trackStartedAt.addingTimeInterval(loadingTimeout)
    }
}

extension NowPlayingStreamParser {
    /// The current artwork bytes, decoded from the adapter's base64 `artworkData` key.
    /// `nil` when the key is absent or isn't valid base64.
    public var artworkData: Data? {
        state["artworkData"]?.stringValue.flatMap { Data(base64Encoded: $0) }
    }
}
