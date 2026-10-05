import Foundation
import NotchCore
import Testing

@testable import NotchSuite

@MainActor
@Suite struct NowPlayingPresentationTests {
    /// Builds a presentation over a `FakeNowPlayingSource`, started and ready to drive.
    private func makeSUT() -> (
        presentation: NowPlayingPresentation, source: FakeNowPlayingSource,
        stateMachine: IslandStateMachine
    ) {
        let source = FakeNowPlayingSource()
        let stateMachine = IslandStateMachine(scheduler: TaskDelayScheduler())
        let presentation = NowPlayingPresentation(
            source: source, stateMachine: stateMachine, resolver: AppIdentityResolver())
        presentation.start()
        return (presentation, source, stateMachine)
    }

    /// Waits for `condition` to become true, polling instead of sleeping a fixed amount.
    ///
    /// `emit` only resumes the presentation's `for await` loop; that resumption is a
    /// queued job on the main actor, not something that happens inline, so there's
    /// still a real gap between emitting and the effect landing even though both sides
    /// share an actor. This polls until it lands, or gives up after `timeout` so a
    /// genuine failure still reports instead of hanging.
    private func waitUntil(
        timeout: Duration = .milliseconds(500), _ condition: () -> Bool
    ) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func aStartingSessionShowsNowPlaying() async {
        let (presentation, source, stateMachine) = makeSUT()
        source.emit(NowPlaying(playing: true, title: "Song", artist: "Artist"))
        await waitUntil { stateMachine.mode == .nowPlaying }

        #expect(stateMachine.mode == .nowPlaying)
        #expect(presentation.playback.isPlaying)
        #expect(presentation.nowPlaying?.title == "Song")
    }

    @Test func anEndingSessionReturnsToIdle() async {
        let (presentation, source, stateMachine) = makeSUT()
        source.emit(NowPlaying(playing: true, title: "Song"))
        await waitUntil { stateMachine.mode == .nowPlaying }
        #expect(stateMachine.mode == .nowPlaying)

        source.emit(nil)
        await waitUntil { stateMachine.mode == .idle }

        #expect(stateMachine.mode == .idle)
        #expect(presentation.nowPlaying == nil)
    }

    private func track(_ title: String) -> NowPlaying {
        NowPlaying(playing: true, title: title)
    }

    @Test func artworkArrivingAfterTheTrackLoads() async {
        let (presentation, source, _) = makeSUT()
        source.emit(track("Song"))
        await waitUntil { presentation.artwork == .loading }
        #expect(presentation.artwork == .loading)

        let bytes = Data([0x01, 0x02, 0x03])
        source.emit(track("Song"), artwork: bytes)  // the cover alone changes: same track
        await waitUntil { presentation.artwork == .loaded(bytes) }

        #expect(presentation.artwork == .loaded(bytes))
    }

    /// The old split streams could leave track A's cover on track B when B had none. A
    /// snapshot for B carries no cover, so B goes to `.loading` and never shows A's.
    /// The session's `elapsedTime` is as of the player's last report, so a cover-only
    /// snapshot must not re-sample it as if it were current.
    @Test func aCoverOnlySnapshotKeepsTheProgressSample() async {
        let (presentation, source, _) = makeSUT()
        let song = NowPlaying(
            playing: true, title: "Song", duration: 200, elapsedTime: 10, playbackRate: 1)
        source.emit(song)
        await waitUntil { presentation.progress != nil }
        let sampled = presentation.progress
        try? await Task.sleep(for: .milliseconds(50))

        let cover = Data([0x01])
        source.emit(song, artwork: cover)
        await waitUntil { presentation.artwork == .loaded(cover) }

        #expect(presentation.artwork == .loaded(cover))
        #expect(sampled != nil)
        #expect(presentation.progress == sampled)
    }

    @Test func aTrackWithoutArtworkNeverKeepsThePreviousCover() async {
        let (presentation, source, _) = makeSUT()
        let coverA = Data([0xA1])
        source.emit(track("A"), artwork: coverA)
        await waitUntil { presentation.artwork == .loaded(coverA) }
        #expect(presentation.artwork == .loaded(coverA))

        source.emit(track("B"))
        await waitUntil { presentation.nowPlaying?.title == "B" }

        #expect(presentation.nowPlaying?.title == "B")
        #expect(presentation.artwork == .loading)
        await waitUntil(timeout: .seconds(5)) { presentation.artwork == .missing }
        #expect(presentation.artwork == .missing)
    }

    @Test func lateArtworkForTheNewTrackReplacesTheFallbackAndNeverTheOldCover() async {
        let (presentation, source, _) = makeSUT()
        let coverA = Data([0xA1])
        let coverB = Data([0xB1])
        source.emit(track("A"), artwork: coverA)
        source.emit(track("B"))
        await waitUntil { presentation.nowPlaying?.title == "B" }
        #expect(presentation.artwork != .loaded(coverA))

        source.emit(track("B"), artwork: coverB)
        await waitUntil { presentation.artwork == .loaded(coverB) }

        #expect(presentation.artwork == .loaded(coverB))
    }

    @Test func rapidTrackChangesSettleOnTheLastTracksOwnState() async {
        let (presentation, source, _) = makeSUT()
        let coverA = Data([0xA1])
        let coverC = Data([0xC1])
        source.emit(track("A"), artwork: coverA)
        source.emit(track("B"))
        source.emit(track("C"), artwork: coverC)  // newest-value buffering may drop B
        await waitUntil { presentation.artwork == .loaded(coverC) }

        #expect(presentation.nowPlaying?.title == "C")
        #expect(presentation.artwork == .loaded(coverC))

        source.emit(track("D"))  // an artless track after a cover
        await waitUntil { presentation.nowPlaying?.title == "D" }
        #expect(presentation.artwork == .loading)
    }

    @Test func aTrackWithoutArtworkSettlesOnTheFallbackInsteadOfSpinning() async {
        let (presentation, source, _) = makeSUT()
        source.emit(NowPlaying(playing: true, title: "Song"))
        await waitUntil { presentation.artwork == .loading }  // `.missing` is also the start state
        #expect(presentation.artwork == .loading)
        await waitUntil(timeout: .seconds(5)) { presentation.artwork == .missing }
        #expect(presentation.artwork == .missing)

        // Once settled, nothing should keep the main actor busy. Process CPU time over a
        // second of waiting stays near zero; a refresh loop would use most of it.
        let before = clock()
        try? await Task.sleep(for: .seconds(1))
        let cpuSeconds = Double(clock() - before) / Double(CLOCKS_PER_SEC)

        #expect(cpuSeconds < 0.3, "used \(cpuSeconds)s of CPU while idle")
        #expect(presentation.nowPlaying?.title == "Song")  // keeps `presentation` alive
    }

    @Test func engineHealthDrivesIsEngineDown() async {
        let (presentation, source, _) = makeSUT()
        #expect(!presentation.isEngineDown)

        source.emitHealth(.down)
        await waitUntil { presentation.isEngineDown }
        #expect(presentation.isEngineDown)

        source.emitHealth(.ready)
        await waitUntil { !presentation.isEngineDown }
        #expect(!presentation.isEngineDown)
    }

    @Test func aSessionStartingOnAnOpenIdleIslandStillShowsNowPlaying() async {
        let (presentation, source, stateMachine) = makeSUT()
        stateMachine.click()
        #expect(stateMachine.mode == .idle)
        #expect(stateMachine.level == .open)

        source.emit(NowPlaying(playing: true, title: "Song"))
        await waitUntil { stateMachine.mode == .nowPlaying }

        #expect(stateMachine.mode == .nowPlaying)
        // Also keeps `presentation` alive: its tasks hold it weakly.
        #expect(presentation.nowPlaying?.title == "Song")
    }

    @Test func aParentAppAppearingLaterReplacesTheHelperProcessName() async {
        let (presentation, source, _) = makeSUT()
        let helper = AppIdentity(bundleIdentifier: "com.apple.WebKit.GPU")
        source.emit(NowPlaying(app: helper, playing: true, title: "Video"))
        await waitUntil { presentation.app != nil }
        let before = presentation.app?.displayName

        source.emit(
            NowPlaying(
                app: helper, parentApplicationBundleIdentifier: "com.apple.Safari",
                playing: true, title: "Video"))
        await waitUntil { presentation.app?.bundleIdentifier == "com.apple.Safari" }

        #expect(presentation.app?.bundleIdentifier == "com.apple.Safari")
        #expect(presentation.app?.displayName != before)
    }

    @Test func aFailedCommandSetsLastCommandError() async {
        struct SendFailure: Error {}
        let (presentation, source, _) = makeSUT()
        source.set(sendError: SendFailure())

        presentation.togglePlayPause()
        await waitUntil { presentation.lastCommandError != nil }

        #expect(presentation.lastCommandError != nil)
        #expect(source.sentCommands == [.togglePlayPause])
    }
}
