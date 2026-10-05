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

        #expect(source.current?.nowPlaying.title == "T")
        #expect(!sawNoSession.value)
    }

    /// Recorded from the real adapter (Spotify, 2026-10-04): on every track change it sends a
    /// full payload with the new title and no `artworkData`, and the artwork follows later
    /// as a diff holding only `artworkData`. A full payload replaces the state, so the
    /// previous track's cover must not stay behind. Each step is one snapshot: the cover
    /// can't be separated from its track.
    @Test func aTrackChangeYieldsOneSnapshotWithoutThePreviousArtworkThenTheLateCover() async {
        let (source, _) = makeSource()
        let old = Data([1, 2, 3])
        let new = Data([4, 5, 6])
        let received = Box<[NowPlayingSnapshot?]>([])
        let updates = source.nowPlayingUpdates()
        Task { @MainActor in for await snapshot in updates { received.value.append(snapshot) } }
        await settle(.milliseconds(100))  // the stream registers on the main actor

        source.ingest(full("A", artwork: old))
        await settle(.milliseconds(50))  // streams keep only the newest value: let each land
        source.ingest(full("B"))  // title first, no artwork yet
        await settle(.milliseconds(50))
        source.ingest(
            #"{"type":"data","diff":true,"payload":{"artworkData":"\#(new.base64EncodedString())"}}"#
        )
        await settle(.milliseconds(100))

        let seen = received.value.map { ($0?.nowPlaying.title, $0?.artwork) }
        #expect(seen.count == 4)  // the replayed `nil`, A, B, B again with its cover
        #expect(seen.map(\.0) == [nil, "A", "B", "B"])
        #expect(seen.map(\.1) == [nil, old, nil, new])
    }

    @Test func aSubscriberAttachingLaterGetsTheCurrentTrackWithItsArtwork() async {
        let (source, _) = makeSource()
        let cover = Data([7, 8, 9])
        source.ingest(full("A", artwork: cover))

        var first: NowPlayingSnapshot??
        for await snapshot in source.nowPlayingUpdates() {
            first = .some(snapshot)
            break
        }

        #expect(first??.nowPlaying.title == "A")
        #expect(first??.artwork == cover)
    }

    @Test func aCoverOnlyChangeIsNotADuplicateButAnIdenticalLineIs() async {
        let (source, _) = makeSource()
        let received = Box(0)
        let updates = source.nowPlayingUpdates()
        Task { @MainActor in for await _ in updates { received.value += 1 } }
        await settle(.milliseconds(100))

        source.ingest(full("A"))
        await settle(.milliseconds(50))
        source.ingest(full("A"))  // identical: suppressed
        await settle(.milliseconds(50))
        source.ingest(full("A", artwork: Data([1])))  // same track, new cover
        await settle(.milliseconds(100))

        #expect(received.value == 3)  // the replayed `nil`, A, A with a cover
    }

    /// A full payload as the adapter sends it, optionally with a cover.
    private func full(_ title: String, artwork: Data? = nil) -> String {
        let art = artwork.map { #","artworkData":"\#($0.base64EncodedString())""# } ?? ""
        return
            #"{"type":"data","diff":false,"payload":{"playing":true,"title":"\#(title)","processIdentifier":1\#(art)}}"#
    }

    @Test func stopFinishesNowPlayingAndHealthObserversToo() async {
        let (source, _) = makeSource()
        let nowPlayingFinished = Box(false)
        let healthFinished = Box(false)
        let updates = source.nowPlayingUpdates()
        let health = source.healthUpdates()
        Task { @MainActor in
            for await _ in updates {}
            nowPlayingFinished.value = true
        }
        Task { @MainActor in
            for await _ in health {}
            healthFinished.value = true
        }
        await settle()
        #expect(!nowPlayingFinished.value && !healthFinished.value)

        source.stop()
        await settle()

        #expect(nowPlayingFinished.value)
        #expect(healthFinished.value)
    }
}
