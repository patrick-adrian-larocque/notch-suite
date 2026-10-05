import Foundation
import Testing

@testable import NotchCore

@Suite struct NowPlayingSnapshotTests {
    private let song = NowPlaying(
        app: AppIdentity(bundleIdentifier: "com.apple.Music"), playing: true, title: "Song")

    @Test func artworkDefaultsToNone() {
        #expect(NowPlayingSnapshot(nowPlaying: song).artwork == nil)
    }

    @Test func artworkTakesNoPartInTrackIdentity() {
        let early = NowPlayingSnapshot(nowPlaying: song)
        let late = NowPlayingSnapshot(nowPlaying: song, artwork: Data([1, 2, 3]))
        #expect(early.nowPlaying.isSameTrack(as: late.nowPlaying))
        #expect(early.nowPlaying == late.nowPlaying)
    }

    @Test func aTrackedSnapshotPairsEachTrackWithItsOwnCover() {
        var other = song
        other.title = "Other"
        var tracker = ArtworkTracker()
        let now = Date(timeIntervalSince1970: 1000)
        let first = NowPlayingSnapshot(nowPlaying: song, artwork: Data([1]))
        let second = NowPlayingSnapshot(nowPlaying: other)

        tracker.update(nowPlaying: first.nowPlaying, artwork: first.artwork, at: now)
        #expect(tracker.state(at: now) == .loaded(Data([1])))
        tracker.update(nowPlaying: second.nowPlaying, artwork: second.artwork, at: now)
        #expect(tracker.state(at: now) == .loading)
    }
}
