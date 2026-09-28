import Testing

@testable import NotchCore

@Suite struct NowPlayingTests {
    private let mandatory: [String: JSONValue] = [
        "bundleIdentifier": .string("com.apple.Music"),
        "playing": .bool(true),
        "title": .string("Song"),
    ]

    @Test func readsMandatoryKeysOnly() {
        let nowPlaying = NowPlaying(state: mandatory)
        #expect(
            nowPlaying
                == NowPlaying(bundleIdentifier: "com.apple.Music", playing: true, title: "Song"))
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
                    bundleIdentifier: "com.apple.Music",
                    parentApplicationBundleIdentifier: "com.parent",
                    playing: true,
                    title: "Song",
                    artist: "Artist",
                    album: "Album",
                    duration: 215.5,
                    elapsedTime: 12,
                    playbackRate: 1))
    }

    @Test(arguments: ["bundleIdentifier", "playing", "title"])
    func isNilWhenAMandatoryKeyIsMissing(missing: String) {
        var state = mandatory
        state[missing] = nil
        #expect(NowPlaying(state: state) == nil)
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
}
