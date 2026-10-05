import Foundation

/// One observation of the media source: a session and the artwork reported with it.
///
/// A source yields the two together, so a consumer never has to work out which track a
/// cover belongs to from the order two separate events arrived in. `NowPlaying` stays the
/// session's metadata and track identity; artwork never takes part in it
/// (`NowPlaying.isSameTrack(as:)` ignores it).
///
/// Deliberately not `Equatable`: comparing two snapshots would compare their artwork
/// bytes, which can be large. A source that suppresses duplicates decides for itself what
/// counts as one.
public struct NowPlayingSnapshot: Sendable {
    public let nowPlaying: NowPlaying
    /// The artwork image bytes as the player supplied them, or `nil` when it has none
    /// (yet). A later snapshot for the same track can add it.
    public let artwork: Data?

    public init(nowPlaying: NowPlaying, artwork: Data? = nil) {
        self.nowPlaying = nowPlaying
        self.artwork = artwork
    }
}
