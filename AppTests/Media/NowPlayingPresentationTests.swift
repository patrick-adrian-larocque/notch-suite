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

    @Test func artworkArrivingAfterTheTrackLoads() async {
        let (presentation, source, _) = makeSUT()
        source.emit(NowPlaying(playing: true, title: "Song"))
        await waitUntil { presentation.artwork == .loading }
        #expect(presentation.artwork == .loading)

        let bytes = Data([0x01, 0x02, 0x03])
        source.emitArtwork(bytes)
        await waitUntil { presentation.artwork == .loaded(bytes) }

        #expect(presentation.artwork == .loaded(bytes))
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
