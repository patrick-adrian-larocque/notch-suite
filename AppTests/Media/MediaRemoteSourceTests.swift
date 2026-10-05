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
