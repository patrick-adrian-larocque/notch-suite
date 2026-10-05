/// What a media player is playing right now.
///
/// `playing` and `title` define a session. The application's identity is optional,
/// because the media source can't always name the player; see `AppIdentity`. Everything
/// else is optional too, because players report it unevenly.
public struct NowPlaying: Sendable, Equatable {
    /// The application playing, as far as the media source could tell.
    public var app: AppIdentity
    /// The application that owns the player, such as a browser for a web player.
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
        app: AppIdentity = .unknown,
        parentApplicationBundleIdentifier: String? = nil,
        playing: Bool,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: Double? = nil,
        elapsedTime: Double? = nil,
        playbackRate: Double? = nil
    ) {
        self.app = app
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
    /// The keys a state must hold for it to describe a session.
    ///
    /// mediaremote-adapter also requires `processIdentifier`, but identity is optional
    /// here: a session is shown and controlled the same way without it, because commands
    /// always go to the system's current player.
    static let requiredKeys = ["playing", "title"]

    /// Reads a `NowPlaying` out of the adapter's raw key/value state.
    ///
    /// Returns `nil` when `playing` or `title` is missing or has the wrong type. Callers
    /// tell an empty state ("no session") apart from an incomplete one; see
    /// `NowPlayingReport`. An optional key with the wrong type is treated as absent, and
    /// so is a `processIdentifier` that isn't a positive whole number in range.
    init?(state: [String: JSONValue]) {
        guard
            let playing = state["playing"]?.boolValue,
            let title = state["title"]?.stringValue
        else {
            return nil
        }
        self.init(
            app: AppIdentity(
                bundleIdentifier: state["bundleIdentifier"]?.stringValue,
                processIdentifier: state["processIdentifier"].flatMap(Self.processIdentifier)),
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

    /// `value` as a process identifier: a whole number from 1 through `Int32.max`.
    static func processIdentifier(_ value: JSONValue) -> Int32? {
        guard let number = value.numberValue, number >= 1, number <= Double(Int32.max),
            number.rounded(.towardZero) == number
        else {
            return nil
        }
        return Int32(number)
    }
}
