/// What is playing right now, as reported by mediaremote-adapter.
///
/// `bundleIdentifier`, `playing` and `title` are the adapter's mandatory keys.
/// Everything else is optional because players report them unevenly.
public struct NowPlaying: Sendable, Equatable {
    public var bundleIdentifier: String
    public var parentApplicationBundleIdentifier: String?
    public var playing: Bool
    public var title: String
    public var artist: String?
    public var album: String?
    /// Track length in seconds.
    public var duration: Double?
    /// Elapsed time in seconds, as of the adapter's `timestamp`.
    public var elapsedTime: Double?
    public var playbackRate: Double?

    public init(
        bundleIdentifier: String,
        parentApplicationBundleIdentifier: String? = nil,
        playing: Bool,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: Double? = nil,
        elapsedTime: Double? = nil,
        playbackRate: Double? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.parentApplicationBundleIdentifier = parentApplicationBundleIdentifier
        self.playing = playing
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
    }
}

extension NowPlaying {
    /// Reads a `NowPlaying` out of the adapter's raw key/value state.
    ///
    /// Returns `nil` when a mandatory key is missing or has the wrong type, which
    /// is how "nothing is playing" looks. An optional key with the wrong type is
    /// treated as absent rather than failing the whole state.
    init?(state: [String: JSONValue]) {
        guard
            let bundleIdentifier = state["bundleIdentifier"]?.stringValue,
            let playing = state["playing"]?.boolValue,
            let title = state["title"]?.stringValue
        else {
            return nil
        }
        self.init(
            bundleIdentifier: bundleIdentifier,
            parentApplicationBundleIdentifier: state["parentApplicationBundleIdentifier"]?
                .stringValue,
            playing: playing,
            title: title,
            artist: state["artist"]?.stringValue,
            album: state["album"]?.stringValue,
            duration: state["duration"]?.numberValue,
            elapsedTime: state["elapsedTime"]?.numberValue,
            playbackRate: state["playbackRate"]?.numberValue
        )
    }
}
