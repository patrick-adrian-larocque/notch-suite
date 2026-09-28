import Testing

@testable import NotchCore

@Suite struct NowPlayingStreamParserTests {
    private func envelope(diff: Bool, _ payload: String) -> String {
        #"{"type":"data","diff":\#(diff),"payload":\#(payload)}"#
    }

    private let song =
        #"{"bundleIdentifier":"com.apple.Music","playing":true,"title":"Song","artist":"Artist"}"#

    // MARK: Full payloads

    @Test func fullPayloadProducesNowPlaying() throws {
        var parser = NowPlayingStreamParser()
        let result = try parser.ingest(line: envelope(diff: false, song))
        #expect(
            result
                == NowPlaying(
                    bundleIdentifier: "com.apple.Music", playing: true, title: "Song",
                    artist: "Artist"))
        #expect(parser.nowPlaying == result)
    }

    @Test func fullPayloadReplacesEarlierState() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let next = #"{"bundleIdentifier":"com.spotify.client","playing":false,"title":"Other"}"#
        let result = try parser.ingest(line: envelope(diff: false, next))
        #expect(
            result
                == NowPlaying(
                    bundleIdentifier: "com.spotify.client", playing: false, title: "Other")
        )
        #expect(parser.state["artist"] == nil)
    }

    @Test func fullPayloadDropsKeysThatAreNull() throws {
        var parser = NowPlayingStreamParser()
        let payload =
            #"{"bundleIdentifier":"com.apple.Music","playing":true,"title":"Song","album":null}"#
        try parser.ingest(line: envelope(diff: false, payload))
        #expect(parser.state["album"] == nil)
    }

    // MARK: Diffs

    @Test func diffMergesIntoTheLastFullState() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(
            line: envelope(diff: true, #"{"playing":false,"elapsedTime":42.5}"#))
        #expect(
            result
                == NowPlaying(
                    bundleIdentifier: "com.apple.Music", playing: false, title: "Song",
                    artist: "Artist", elapsedTime: 42.5))
    }

    @Test func diffCanStackOnEarlierDiffs() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        try parser.ingest(line: envelope(diff: true, #"{"album":"First"}"#))
        let result = try parser.ingest(line: envelope(diff: true, #"{"album":"Second"}"#))
        #expect(result?.album == "Second")
        #expect(result?.artist == "Artist")
    }

    @Test func nullKeyInADiffRemovesThatValue() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: true, #"{"artist":null}"#))
        #expect(result?.artist == nil)
        #expect(result?.title == "Song")
        #expect(parser.state["artist"] == nil)
    }

    @Test func nullingAMandatoryKeyClearsNowPlaying() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: true, #"{"title":null}"#))
        #expect(result == nil)
    }

    @Test func nullingAKeyThatWasNeverSetIsHarmless() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: true, #"{"genre":null}"#))
        #expect(result?.title == "Song")
    }

    @Test func diffBeforeAnyFullStateMergesIntoEmptyState() throws {
        var parser = NowPlayingStreamParser()
        let result = try parser.ingest(line: envelope(diff: true, #"{"title":"Song"}"#))
        #expect(result == nil)
        #expect(parser.state["title"] == .string("Song"))
    }

    // MARK: Empty and null payloads

    @Test func emptyFullPayloadMeansNothingIsPlaying() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: false, "{}"))
        #expect(result == nil)
        #expect(parser.state.isEmpty)
    }

    @Test func emptyDiffPayloadChangesNothing() throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        let after = try parser.ingest(line: envelope(diff: true, "{}"))
        #expect(after == before)
    }

    @Test func nullPayloadIsRejectedAndKeepsState() throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        #expect(throws: NowPlayingStreamError.self) {
            try parser.ingest(line: envelope(diff: false, "null"))
        }
        #expect(parser.nowPlaying == before)
    }

    @Test func missingPayloadIsRejected() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("\"payload\" must be an object")) {
            try parser.ingest(line: #"{"type":"data","diff":false}"#)
        }
    }

    // MARK: Malformed input

    @Test func malformedJSONIsRejectedAndKeepsState() throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        #expect(throws: NowPlayingStreamError.malformedJSON) {
            try parser.ingest(line: #"{"type":"data","diff":fal"#)
        }
        #expect(parser.nowPlaying == before)
    }

    @Test func plainTextIsMalformedJSON() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.malformedJSON) {
            try parser.ingest(line: "adapter started")
        }
    }

    @Test func nonObjectJSONIsAnInvalidEnvelope() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("expected a JSON object")) {
            try parser.ingest(line: "[1,2,3]")
        }
    }

    @Test func unexpectedTypeIsRejected() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("\"type\" must be \"data\"")) {
            try parser.ingest(line: #"{"type":"error","diff":false,"payload":{}}"#)
        }
    }

    @Test func missingDiffFlagIsRejected() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("\"diff\" must be a boolean")) {
            try parser.ingest(line: #"{"type":"data","payload":{}}"#)
        }
    }

    // MARK: Line handling

    @Test(arguments: ["", "   ", "\n", "\r\n"])
    func blankLinesAreIgnored(blank: String) throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        #expect(try parser.ingest(line: blank) == before)
    }

    @Test func toleratesTrailingNewlineAndCRLF() throws {
        var parser = NowPlayingStreamParser()
        let result = try parser.ingest(line: envelope(diff: false, song) + "\r\n")
        #expect(result?.title == "Song")
    }

    @Test func keepsUnicodeAndEscapedTitles() throws {
        var parser = NowPlayingStreamParser()
        let payload =
            #"{"bundleIdentifier":"b","playing":true,"title":"夜に駆ける \"Yoru\" é"}"#
        let result = try parser.ingest(line: envelope(diff: false, payload))
        #expect(result?.title == "夜に駆ける \"Yoru\" é")
    }

    // MARK: Realistic streams

    @Test func recoversAfterABadLine() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        #expect(throws: NowPlayingStreamError.malformedJSON) {
            try parser.ingest(line: "not json")
        }
        let result = try parser.ingest(line: envelope(diff: true, #"{"playing":false}"#))
        #expect(result?.playing == false)
        #expect(result?.title == "Song")
    }

    @Test func handlesAnArtworkSizedLineAndRemovesItAgain() throws {
        var parser = NowPlayingStreamParser()
        let artwork = String(repeating: "QUJD", count: 250_000)
        let payload = """
            {"bundleIdentifier":"b","playing":true,"title":"Song","artworkData":"\(artwork)"}
            """
        try parser.ingest(line: envelope(diff: false, payload))
        #expect(parser.state["artworkData"]?.stringValue?.count == 1_000_000)
        let result = try parser.ingest(line: envelope(diff: true, #"{"artworkData":null}"#))
        #expect(parser.state["artworkData"] == nil)
        #expect(result?.title == "Song")
    }

    @Test func microsKeysAreKeptButDoNotBreakNowPlaying() throws {
        var parser = NowPlayingStreamParser()
        let payload = """
            {"bundleIdentifier":"b","playing":true,"title":"Song",\
            "durationMicros":215000000,"elapsedTimeMicros":1000000}
            """
        let result = try parser.ingest(line: envelope(diff: false, payload))
        #expect(result?.title == "Song")
        #expect(result?.duration == nil)
        #expect(parser.state["durationMicros"] == .number(215_000_000))
    }

    // MARK: Review follow-ups

    /// Ingests `line` and returns the error it was rejected with, or `nil` if it was accepted.
    private func rejection(
        of line: String, on parser: inout NowPlayingStreamParser
    ) -> NowPlayingStreamError? {
        do {
            try parser.ingest(line: line)
            return nil
        } catch {
            return error as? NowPlayingStreamError
        }
    }

    @Test(
        arguments: [false, true],
        [#"{"title":5}"#, #"{"playing":"yes"}"#, #"{"bundleIdentifier":1}"#])
    func wrongTypedMandatoryKeyIsRejectedAndKeepsState(diff: Bool, payload: String) throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let before = parser.state
        let error = rejection(of: envelope(diff: diff, payload), on: &parser)
        guard case .invalidEnvelope? = error else {
            Issue.record("expected invalidEnvelope, got \(String(describing: error))")
            return
        }
        #expect(parser.state == before)
    }

    @Test func nullingAKeyThatWasNeverSetLeavesStateUnchanged() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let before = parser.state
        try parser.ingest(line: envelope(diff: true, #"{"genre":null}"#))
        #expect(parser.state == before)
        #expect(parser.state.keys.contains("genre") == false)
    }

    @Test func nullingAMandatoryKeyRemovesItFromState() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        try parser.ingest(line: envelope(diff: true, #"{"title":null}"#))
        #expect(parser.state["title"] == nil)
    }

    @Test(arguments: [false, true])
    func nullPayloadIsAnInvalidEnvelopeNotMalformedJSON(diff: Bool) throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let before = parser.state
        let error = rejection(of: envelope(diff: diff, "null"), on: &parser)
        guard case .invalidEnvelope? = error else {
            Issue.record("expected invalidEnvelope, got \(String(describing: error))")
            return
        }
        #expect(parser.state == before)
    }

    @Test(arguments: [#""text""#, "[]", "7", "true"])
    func nonObjectPayloadIsRejectedAndKeepsState(payload: String) throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let before = parser.state
        let error = rejection(of: envelope(diff: true, payload), on: &parser)
        guard case .invalidEnvelope? = error else {
            Issue.record("expected invalidEnvelope, got \(String(describing: error))")
            return
        }
        #expect(parser.state == before)
    }

    @Test(arguments: [
        #"{"diff":false,"payload":{}}"#,
        #"{"type":"Data","diff":false,"payload":{}}"#,
        #"{"type":null,"diff":false,"payload":{}}"#,
    ])
    func missingOrWrongCaseTypeIsRejected(line: String) {
        var parser = NowPlayingStreamParser()
        guard case .invalidEnvelope? = rejection(of: line, on: &parser) else {
            Issue.record("expected invalidEnvelope for \(line)")
            return
        }
    }

    @Test(arguments: [#""true""#, "1", "0", "null"])
    func nonBooleanDiffIsRejected(diff: String) {
        var parser = NowPlayingStreamParser()
        let line = #"{"type":"data","diff":\#(diff),"payload":{}}"#
        guard case .invalidEnvelope? = rejection(of: line, on: &parser) else {
            Issue.record("expected invalidEnvelope for \(line)")
            return
        }
    }
}
