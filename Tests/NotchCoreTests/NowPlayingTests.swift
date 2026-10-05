import Testing

@testable import NotchCore

@Suite struct NowPlayingTests {
    private let mandatory: [String: JSONValue] = [
        "bundleIdentifier": .string("com.apple.Music"),
        "processIdentifier": .number(812),
        "playing": .bool(true),
        "title": .string("Song"),
    ]

    @Test func readsMandatoryKeysOnly() {
        let nowPlaying = NowPlaying(state: mandatory)
        #expect(
            nowPlaying
                == NowPlaying(
                    app: AppIdentity(bundleIdentifier: "com.apple.Music", processIdentifier: 812),
                    playing: true, title: "Song"))
    }

    @Test func readsOptionalKeys() {
        var state = mandatory
        state["parentApplicationBundleIdentifier"] = .string("com.parent")
        state["artist"] = .string("Artist")
        state["album"] = .string("Album")
        state["duration"] = .number(215.5)
        state["elapsedTime"] = .number(12)
        state["playbackRate"] = .number(1)
        #expect(
            NowPlaying(state: state)
                == NowPlaying(
                    app: AppIdentity(bundleIdentifier: "com.apple.Music", processIdentifier: 812),
                    parentApplicationBundleIdentifier: "com.parent",
                    playing: true,
                    title: "Song",
                    artist: "Artist",
                    album: "Album",
                    duration: 215.5,
                    elapsedTime: 12,
                    playbackRate: 1))
    }

    @Test(arguments: ["playing", "title"])
    func isNilWhenARequiredKeyIsMissing(missing: String) {
        var state = mandatory
        state[missing] = nil
        #expect(NowPlaying(state: state) == nil)
    }

    // MARK: App identity

    @Test func processIdentifierWithoutBundleIdentifierIsASession() {
        var state = mandatory
        state["bundleIdentifier"] = nil
        let nowPlaying = NowPlaying(state: state)
        #expect(nowPlaying?.title == "Song")
        #expect(nowPlaying?.app == AppIdentity(processIdentifier: 812))
    }

    @Test func bundleIdentifierWithoutProcessIdentifierIsASession() {
        var state = mandatory
        state["processIdentifier"] = nil
        #expect(NowPlaying(state: state)?.app == AppIdentity(bundleIdentifier: "com.apple.Music"))
    }

    /// The adapter always sends a process identifier, but a session is shown and
    /// controlled the same way without any identity, so missing identity isn't malformed.
    @Test func noIdentityAtAllIsASessionWithUnknownApp() {
        var state = mandatory
        state["bundleIdentifier"] = nil
        state["processIdentifier"] = nil
        let nowPlaying = NowPlaying(state: state)
        #expect(nowPlaying?.title == "Song")
        #expect(nowPlaying?.app == .unknown)
        #expect(nowPlaying?.app.isUnknown == true)
    }

    @Test(arguments: [
        JSONValue.number(0), .number(-3), .number(1.5), .number(4_294_967_296), .string("812"),
    ])
    func unusableProcessIdentifierReadsAsAbsent(value: JSONValue) {
        var state = mandatory
        state["processIdentifier"] = value
        let nowPlaying = NowPlaying(state: state)
        #expect(nowPlaying?.app == AppIdentity(bundleIdentifier: "com.apple.Music"))
    }

    @Test func wronglyTypedBundleIdentifierReadsAsAbsent() {
        var state = mandatory
        state["bundleIdentifier"] = .number(1)
        #expect(NowPlaying(state: state)?.app == AppIdentity(processIdentifier: 812))
    }

    @Test func isNilWhenAMandatoryKeyHasTheWrongType() {
        var state = mandatory
        state["title"] = .number(7)
        #expect(NowPlaying(state: state) == nil)
    }

    @Test func ignoresAnOptionalKeyWithTheWrongType() {
        var state = mandatory
        state["artist"] = .number(5)
        #expect(NowPlaying(state: state)?.artist == nil)
        #expect(NowPlaying(state: state)?.title == "Song")
    }

    @Test func isNilForEmptyState() {
        #expect(NowPlaying(state: [:]) == nil)
    }

    @Test(arguments: [
        ("playing", JSONValue.number(1)),
        ("playing", JSONValue.string("true")),
        ("title", JSONValue.bool(false)),
    ])
    func isNilWhenARequiredKeyHasTheWrongType(key: String, value: JSONValue) {
        var state = mandatory
        state[key] = value
        #expect(NowPlaying(state: state) == nil)
    }
}
