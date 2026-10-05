import Foundation
import NotchCore

/// A controllable `NowPlayingSource` for tests. Never touches a real process; tests
/// drive it by calling `emit` and `emitHealth` directly.
///
/// Registers each stream's continuation synchronously under a lock, instead of the
/// fire-and-forget `Task` hop `MediaRemoteNowPlayingSource` uses to reach its own main
/// actor state: on a test double, `emit` can run immediately after `nowPlayingUpdates()`,
/// with nothing in between to lose the race against that hop.
/// `MediaRemoteNowPlayingSource` never hits it in practice only because starting the
/// real adapter process takes far longer than the hop does.
final class FakeNowPlayingSource: NowPlayingSource, @unchecked Sendable {
    private let lock = NSLock()
    private var sentCommandsStorage: [MediaCommand] = []
    private var sendErrorStorage: (any Error)?
    private var nowPlayingContinuations: [UUID: AsyncStream<NowPlayingSnapshot?>.Continuation] = [:]
    private var healthContinuations: [UUID: AsyncStream<NowPlayingSourceHealth>.Continuation] = [:]

    var sentCommands: [MediaCommand] { lock.withLock { sentCommandsStorage } }

    func nowPlayingUpdates() -> AsyncStream<NowPlayingSnapshot?> {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingSnapshot?.self)
        lock.withLock { nowPlayingContinuations[UUID()] = continuation }
        return stream
    }

    func healthUpdates() -> AsyncStream<NowPlayingSourceHealth> {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingSourceHealth.self)
        lock.withLock { healthContinuations[UUID()] = continuation }
        return stream
    }

    func send(_ command: MediaCommand) async throws {
        let error = lock.withLock {
            sentCommandsStorage.append(command)
            return sendErrorStorage
        }
        if let error { throw error }
    }

    func set(sendError: any Error) {
        lock.withLock { sendErrorStorage = sendError }
    }

    func emit(_ update: NowPlayingSnapshot?) {
        for continuation in lock.withLock({ nowPlayingContinuations.values }) {
            continuation.yield(update)
        }
    }

    /// Emits `nowPlaying` with `artwork` as one snapshot.
    func emit(_ nowPlaying: NowPlaying, artwork: Data? = nil) {
        emit(NowPlayingSnapshot(nowPlaying: nowPlaying, artwork: artwork))
    }

    func emitHealth(_ health: NowPlayingSourceHealth) {
        for continuation in lock.withLock({ healthContinuations.values }) {
            continuation.yield(health)
        }
    }
}
