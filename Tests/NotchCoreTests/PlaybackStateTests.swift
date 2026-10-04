import Testing

@testable import NotchCore

@Suite struct PlaybackStateTests {
    private let song = NowPlaying(
        app: AppIdentity(bundleIdentifier: "com.apple.Music"), playing: true, title: "Song",
        artist: "Artist")

    private var pausedSong: NowPlaying {
        var copy = song
        copy.playing = false
        return copy
    }

    @Test func startsIdle() {
        #expect(PlaybackState.idle == .stopped(lastPlayed: nil))
        #expect(PlaybackState.idle.nowPlaying == nil)
        #expect(PlaybackState.idle.lastPlayed == nil)
    }

    @Test func playingFlagPicksPlayingOrPaused() {
        #expect(PlaybackState.idle.updated(with: song) == .playing(song))
        #expect(PlaybackState.idle.updated(with: pausedSong) == .paused(pausedSong))
        #expect(PlaybackState.playing(song).updated(with: pausedSong) == .paused(pausedSong))
        #expect(PlaybackState.paused(pausedSong).updated(with: song) == .playing(song))
    }

    @Test func emptyUpdateRemembersTheLastTrack() {
        #expect(PlaybackState.playing(song).updated(with: nil) == .stopped(lastPlayed: song))
        #expect(
            PlaybackState.paused(pausedSong).updated(with: nil) == .stopped(lastPlayed: pausedSong))
    }

    @Test func repeatedEmptyUpdatesKeepTheLastTrack() {
        let stopped = PlaybackState.playing(song).updated(with: nil).updated(with: nil)
        #expect(stopped == .stopped(lastPlayed: song))
        #expect(stopped.lastPlayed == song)
        #expect(stopped.nowPlaying == nil)
        #expect(!stopped.isPlaying)
    }

    @Test func emptyUpdateWithNothingBeforeStaysIdle() {
        #expect(PlaybackState.idle.updated(with: nil) == .idle)
    }

    @Test func resumingAfterStopIsPlayingAgain() {
        let resumed = PlaybackState.stopped(lastPlayed: song).updated(with: song)
        #expect(resumed == .playing(song))
        #expect(resumed.isPlaying)
        #expect(resumed.nowPlaying == song)
        #expect(resumed.lastPlayed == nil)
    }

    @Test func sameTrackIgnoresPlaybackFields() {
        var later = pausedSong
        later.elapsedTime = 42
        later.playbackRate = 0
        later.duration = 200
        #expect(song.isSameTrack(as: later))
    }

    @Test func differentTitleArtistAlbumOrPlayerIsADifferentTrack() {
        var other = song
        other.title = "Other"
        #expect(!song.isSameTrack(as: other))
        other = song
        other.artist = nil
        #expect(!song.isSameTrack(as: other))
        other = song
        other.album = "Album"
        #expect(!song.isSameTrack(as: other))
        other = song
        other.app = AppIdentity(bundleIdentifier: "com.spotify.client")
        #expect(!song.isSameTrack(as: other))
    }

    // MARK: Partial identity

    private func song(_ app: AppIdentity) -> NowPlaying {
        var copy = song
        copy.app = app
        return copy
    }

    @Test func sameProcessIsTheSameTrackEvenWithoutABundleIdentifier() {
        let before = song(AppIdentity(processIdentifier: 812))
        let after = song(AppIdentity(bundleIdentifier: "com.apple.Music", processIdentifier: 812))
        #expect(before.isSameTrack(as: after))
    }

    @Test func differentProcessesAreDifferentTracks() {
        let first = song(AppIdentity(processIdentifier: 812))
        let second = song(AppIdentity(processIdentifier: 940))
        #expect(!first.isSameTrack(as: second))
    }

    @Test func reusedProcessIdentifierWithAnotherBundleIsADifferentTrack() {
        let first = song(AppIdentity(bundleIdentifier: "com.apple.Music", processIdentifier: 812))
        let second = song(
            AppIdentity(bundleIdentifier: "com.spotify.client", processIdentifier: 812))
        #expect(!first.isSameTrack(as: second))
    }

    @Test func relaunchedPlayerIsADifferentTrack() {
        let first = song(AppIdentity(bundleIdentifier: "com.apple.Music", processIdentifier: 812))
        let second = song(AppIdentity(bundleIdentifier: "com.apple.Music", processIdentifier: 940))
        #expect(!first.isSameTrack(as: second))
    }

    /// Unknown identities prove nothing either way, so the metadata decides.
    @Test func unknownIdentitiesFallBackToMetadata() {
        #expect(song(.unknown).isSameTrack(as: song(.unknown)))
        var other = song(.unknown)
        other.title = "Other"
        #expect(!song(.unknown).isSameTrack(as: other))
    }

    @Test func knownAndUnknownIdentityFallBackToMetadata() {
        let known = song(AppIdentity(processIdentifier: 812))
        #expect(known.isSameTrack(as: song(.unknown)))
    }

    @Test func partialIdentityUpdateKeepsPlaying() {
        let playing = PlaybackState.idle.updated(with: song(AppIdentity(processIdentifier: 812)))
        #expect(playing.isPlaying)
        #expect(playing.nowPlaying?.app == AppIdentity(processIdentifier: 812))
    }
}
