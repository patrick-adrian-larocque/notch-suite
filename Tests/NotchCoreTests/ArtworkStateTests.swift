import Foundation
import Testing

@testable import NotchCore

@Suite struct ArtworkTrackerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let image = Data([0x89, 0x50, 0x4E, 0x47])
    private let otherImage = Data([0xFF, 0xD8, 0xFF])

    private func track(_ title: String = "Song", playing: Bool = true) -> NowPlaying {
        NowPlaying(
            app: AppIdentity(bundleIdentifier: "com.apple.Music"), playing: playing, title: title)
    }

    @Test func nothingPlayingIsMissing() {
        let tracker = ArtworkTracker()
        #expect(tracker.state(at: start) == .missing)
        #expect(tracker.loadingDeadline == nil)
    }

    @Test func newTrackWithArtworkIsLoaded() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: image, at: start)
        #expect(tracker.state(at: start) == .loaded(image))
        #expect(tracker.loadingDeadline == nil)
    }

    @Test func newTrackWithoutArtworkLoadsThenFallsBack() {
        var tracker = ArtworkTracker(loadingTimeout: 3)
        tracker.update(nowPlaying: track(), artwork: nil, at: start)
        #expect(tracker.state(at: start) == .loading)
        #expect(tracker.state(at: start + 2.9) == .loading)
        #expect(tracker.loadingDeadline == start + 3)
        #expect(tracker.state(at: start + 3) == .missing)
    }

    @Test func artworkArrivingWhileLoadingIsLoaded() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: nil, at: start)
        tracker.update(nowPlaying: track(), artwork: image, at: start + 1)
        #expect(tracker.state(at: start + 1) == .loaded(image))
        #expect(tracker.loadingDeadline == nil)
    }

    @Test func lateArtworkAfterFallbackIsStillLoaded() {
        var tracker = ArtworkTracker(loadingTimeout: 3)
        tracker.update(nowPlaying: track(), artwork: nil, at: start)
        #expect(tracker.state(at: start + 10) == .missing)
        tracker.update(nowPlaying: track(), artwork: image, at: start + 10)
        #expect(tracker.state(at: start + 10) == .loaded(image))
    }

    @Test func updatesForTheSameTrackDoNotRestartTheWait() {
        var tracker = ArtworkTracker(loadingTimeout: 3)
        tracker.update(nowPlaying: track(), artwork: nil, at: start)
        tracker.update(nowPlaying: track(playing: false), artwork: nil, at: start + 2)
        #expect(tracker.state(at: start + 3) == .missing)
    }

    @Test func artworkThatBrieflyDisappearsIsKept() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: image, at: start)
        tracker.update(nowPlaying: track(), artwork: nil, at: start + 30)
        #expect(tracker.state(at: start + 60) == .loaded(image))
    }

    @Test func newArtworkForTheSameTrackReplacesTheOld() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: image, at: start)
        tracker.update(nowPlaying: track(), artwork: otherImage, at: start + 1)
        #expect(tracker.state(at: start + 1) == .loaded(otherImage))
    }

    @Test func trackChangeDropsTheOldArtworkAndWaitsAgain() {
        var tracker = ArtworkTracker(loadingTimeout: 3)
        tracker.update(nowPlaying: track("One"), artwork: image, at: start)
        tracker.update(nowPlaying: track("Two"), artwork: nil, at: start + 100)
        #expect(tracker.state(at: start + 100) == .loading)
        #expect(tracker.loadingDeadline == start + 103)
        #expect(tracker.state(at: start + 103) == .missing)
    }

    @Test func trackChangeWithArtworkIsLoaded() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track("One"), artwork: image, at: start)
        tracker.update(nowPlaying: track("Two"), artwork: otherImage, at: start + 100)
        #expect(tracker.state(at: start + 100) == .loaded(otherImage))
    }

    @Test func stoppingIsMissingAndTheNextTrackWaitsAgain() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: image, at: start)
        tracker.update(nowPlaying: nil, artwork: nil, at: start + 10)
        #expect(tracker.state(at: start + 10) == .missing)
        #expect(tracker.loadingDeadline == nil)
        // Even the same track starts over: the old artwork was dropped with it.
        tracker.update(nowPlaying: track(), artwork: nil, at: start + 20)
        #expect(tracker.state(at: start + 20) == .loading)
    }

    @Test func emptyDataCountsAsNoArtwork() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: Data(), at: start)
        #expect(tracker.state(at: start) == .loading)
    }

    @Test func defaultTimeoutIsUsed() {
        var tracker = ArtworkTracker()
        tracker.update(nowPlaying: track(), artwork: nil, at: start)
        #expect(tracker.loadingDeadline == start + ArtworkTracker.defaultLoadingTimeout)
    }
}

@Suite struct NowPlayingStreamParserArtworkTests {
    private func envelope(diff: Bool, _ payload: String) -> String {
        #"{"type":"data","diff":\#(diff),"payload":\#(payload)}"#
    }

    @Test func decodesBase64Artwork() throws {
        var parser = NowPlayingStreamParser()
        let base64 = Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        try parser.ingest(
            line: envelope(
                diff: false,
                #"{"bundleIdentifier":"b","playing":true,"title":"S","artworkData":"\#(base64)"}"#))
        #expect(parser.artworkData == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func absentOrInvalidArtworkIsNil() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(
            line: envelope(diff: false, #"{"bundleIdentifier":"b","playing":true,"title":"S"}"#))
        #expect(parser.artworkData == nil)
        try parser.ingest(line: envelope(diff: true, #"{"artworkData":"not base64!"}"#))
        #expect(parser.artworkData == nil)
        try parser.ingest(line: envelope(diff: true, #"{"artworkData":5}"#))
        #expect(parser.artworkData == nil)
    }
}
