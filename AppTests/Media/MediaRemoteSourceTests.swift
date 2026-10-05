import Foundation
import NotchCore
import Testing

@testable import NotchSuite

/// `MediaRemoteNowPlayingSource` driven through its internal seams (`ingest`, and the
/// engine's `onStatusChange`), with an engine that has no bundled adapter, so no process
/// is started.
@MainActor
@Suite struct MediaRemoteSourceTests {
    private let session =
        #"{"type":"data","diff":false,"payload":{"playing":true,"title":"T","processIdentifier":1}}"#
    private let emptyPayload = #"{"type":"data","diff":false,"payload":{}}"#

    private func makeSource() -> (source: MediaRemoteNowPlayingSource, engine: MediaRemoteEngine) {
        let engine = MediaRemoteEngine(resources: nil)
        return (MediaRemoteNowPlayingSource(engine: engine), engine)
    }

    private func settle(_ duration: Duration = .milliseconds(300)) async {
        try? await Task.sleep(for: duration)
    }

    @MainActor private final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    @Test func anObserverRegisteringAfterTheEngineFailedStillLearnsItIsDown() async {
        let (source, _) = makeSource()
        source.start()  // no adapter bundled: the engine is `.unavailable` immediately
        let received = Box<[NowPlayingSourceHealth]>([])
        let health = source.healthUpdates()
        Task { @MainActor in
            for await value in health { received.value.append(value) }
        }
        await settle()

        #expect(received.value == [.down])
    }

    @Test func aCrashAfterAnEmptyFirstPayloadDoesNotBecomeNoSession() async {
        let (source, engine) = makeSource()
        let sawNoSession = Box(false)
        let updates = source.nowPlayingUpdates()
        Task { @MainActor in
            for await update in updates where update == nil { sawNoSession.value = true }
        }
        await settle()  // the initial `nil` replay
        sawNoSession.value = false

        source.ingest(session)
        engine.onStatusChange(.running)  // a restart: the new stream starts with an empty payload
        source.ingest(emptyPayload)  // waits out the grace period before saying "no session"
        engine.onStatusChange(.failed(reason: "exited", retryingIn: .seconds(1)))
        await settle(MediaRemoteNowPlayingSource.firstEmptyPayloadGrace + .milliseconds(300))

        #expect(source.current?.title == "T")
        #expect(!sawNoSession.value)
    }

    /// Recorded from the real adapter (Spotify, 2026-10-04): on every track change it sends a
    /// full payload with the new title and no `artworkData`, and the artwork follows later
    /// as a diff holding only `artworkData`. A full payload replaces the state, so the
    /// previous track's cover must not stay behind.
    @Test func aTrackChangeDropsThePreviousArtworkUntilTheNewOneArrives() {
        let (source, _) = makeSource()
        let old = Data([1, 2, 3])
        let new = Data([4, 5, 6])

        source.ingest(full("A", artwork: old))
        #expect(source.artwork == old)

        source.ingest(full("B"))  // title first, no artwork yet
        #expect(source.current?.title == "B")
        #expect(source.artwork == nil)

        source.ingest(
            #"{"type":"data","diff":true,"payload":{"artworkData":"\#(new.base64EncodedString())"}}"#
        )
        #expect(source.artwork == new)
    }

    /// A full payload as the adapter sends it, optionally with a cover.
    private func full(_ title: String, artwork: Data? = nil) -> String {
        let art = artwork.map { #","artworkData":"\#($0.base64EncodedString())""# } ?? ""
        return
            #"{"type":"data","diff":false,"payload":{"playing":true,"title":"\#(title)","processIdentifier":1\#(art)}}"#
    }

    /// The artwork and session streams are consumed by separate tasks, so the order in which
    /// the presentation sees "cover cleared" and "new track" is not guaranteed by the types.
    /// This drives the real source into the real presentation through many cover-to-artless
    /// transitions and checks the old cover never survives on the new track.
    @Test func aTrackChangeWithoutArtworkNeverKeepsThePreviousCover() async {
        let (source, _) = makeSource()
        let presentation = NowPlayingPresentation(
            source: source, stateMachine: IslandStateMachine(scheduler: TaskDelayScheduler()),
            resolver: AppIdentityResolver())
        presentation.start()
        await settle(.milliseconds(100))  // the streams register on the main actor
        let cover = Data([1, 2, 3, 4])
        var stale = 0

        for round in 0..<60 {
            source.ingest(full("A\(round)", artwork: cover))
            for _ in 0..<50 where presentation.artwork != .loaded(cover) {
                await settle(.milliseconds(2))
            }
            source.ingest(full("B\(round)"))  // new track, cover cleared, no new cover
            for _ in 0..<50 where presentation.nowPlaying?.title != "B\(round)" {
                await settle(.milliseconds(2))
            }
            await settle(.milliseconds(5))
            if presentation.artwork == .loaded(cover) {
                // Wait for any in-flight "cover cleared" event: only a cover still there
                // afterwards is stuck on the new track.
                await settle(.milliseconds(150))
                if presentation.artwork == .loaded(cover) { stale += 1 }
            }
        }

        #expect(stale == 0, "old cover stayed on the new track in \(stale) of 60 transitions")
        presentation.stop()
    }

    @Test func stopFinishesArtworkAndHealthObserversToo() async {
        let (source, _) = makeSource()
        let artworkFinished = Box(false)
        let healthFinished = Box(false)
        let artwork = source.artworkUpdates()
        let health = source.healthUpdates()
        Task { @MainActor in
            for await _ in artwork {}
            artworkFinished.value = true
        }
        Task { @MainActor in
            for await _ in health {}
            healthFinished.value = true
        }
        await settle()
        #expect(!artworkFinished.value && !healthFinished.value)

        source.stop()
        await settle()

        #expect(artworkFinished.value)
        #expect(healthFinished.value)
    }
}
