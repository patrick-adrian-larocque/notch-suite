import Foundation
import NotchCore

/// The macOS `NowPlayingSource`: mediaremote-adapter through `MediaRemoteEngine`.
///
/// Each engine line goes through `NowPlayingStreamParser`, and only real changes reach
/// observers:
/// - `.session` yields the `NowPlaying`, with whatever app identity it has.
/// - `.noSession` yields `nil`.
/// - `.incomplete` and rejected lines yield nothing and are logged, so the last session
///   stays current. Neither is "nothing playing".
///
/// When the engine restarts, a fresh parser starts with it; the new `stream` reports the
/// full state first. Every `stream` prints an empty payload before that (upstream issue
/// #23), so a first-line `.noSession` waits ``firstEmptyPayloadGrace`` and is dropped if
/// any other line follows; otherwise nothing is playing after all.
@MainActor
final class MediaRemoteNowPlayingSource {
    /// How long a stream's first empty payload waits for the real state.
    static let firstEmptyPayloadGrace: Duration = .milliseconds(500)

    /// The adapter's `send` IDs for each command (see its README).
    static func commandID(for command: MediaCommand) -> Int {
        switch command {
        case .play: 0
        case .pause: 1
        case .togglePlayPause: 2
        case .nextTrack: 4
        case .previousTrack: 5
        }
    }

    /// The last update observers got. `nil` means no session, or none reported yet.
    private(set) var current: NowPlaying?
    /// The current artwork bytes, or `nil` when there is none. Kept apart from
    /// `NowPlaying` so that core type stays small; see ``artworkUpdates()``.
    private(set) var artwork: Data?
    /// The engine's status, for showing that the source is down rather than idle.
    var engineStatus: MediaRemoteEngine.Status { engine.status }

    private let engine: MediaRemoteEngine
    private var parser = NowPlayingStreamParser()
    private var linesSinceStart = 0
    private var pendingNoSession: Task<Void, Never>?
    private var observers: [UUID: AsyncStream<NowPlaying?>.Continuation] = [:]
    private var artworkObservers: [UUID: AsyncStream<Data?>.Continuation] = [:]
    private var healthObservers: [UUID: AsyncStream<NowPlayingSourceHealth>.Continuation] = [:]

    init(engine: MediaRemoteEngine = MediaRemoteEngine()) {
        self.engine = engine
        engine.onLine = { [weak self] line in self?.ingest(line) }
        engine.onStatusChange = { [weak self] status in self?.engineStatusChanged(status) }
    }

    /// Starts the adapter. Call once, after launch.
    func start() { engine.start() }

    /// Stops the adapter and finishes every observer's stream.
    func stop() {
        pendingNoSession?.cancel()
        pendingNoSession = nil
        engine.stop()
        for continuation in observers.values { continuation.finish() }
        observers.removeAll()
        for continuation in artworkObservers.values { continuation.finish() }
        artworkObservers.removeAll()
        for continuation in healthObservers.values { continuation.finish() }
        healthObservers.removeAll()
    }

    /// Ends the adapter for system sleep but keeps observers subscribed, unlike ``stop()``.
    /// The engine resets the parser when ``resume()`` brings it back.
    func suspend() {
        pendingNoSession?.cancel()
        pendingNoSession = nil
        engine.stop()
    }

    /// Restarts the adapter after ``suspend()``.
    func resume() { engine.start() }

    /// Applies one line of adapter output. Internal so tests and probes can feed lines.
    func ingest(_ line: String) {
        linesSinceStart += 1
        pendingNoSession?.cancel()
        pendingNoSession = nil
        let report: NowPlayingReport
        do {
            report = try parser.ingest(line: line)
        } catch {
            mediaRemoteLog.error(
                "rejected adapter line: \(String(describing: error), privacy: .public)")
            return
        }
        switch report {
        case .session(let nowPlaying):
            updateArtwork(parser.artworkData)
            publish(nowPlaying)
        case .noSession:
            if linesSinceStart == 1 {
                pendingNoSession = Task { [weak self] in
                    try? await Task.sleep(for: Self.firstEmptyPayloadGrace)
                    guard !Task.isCancelled else { return }
                    self?.updateArtwork(nil)
                    self?.publish(nil)
                }
            } else {
                updateArtwork(nil)
                publish(nil)
            }
        case .incomplete(let missingKeys):
            mediaRemoteLog.debug(
                "incomplete adapter state, missing \(missingKeys.joined(separator: ", "), privacy: .public)"
            )
        }
    }

    private func updateArtwork(_ data: Data?) {
        guard data != artwork else { return }
        artwork = data
        for continuation in artworkObservers.values { continuation.yield(data) }
    }

    private func publish(_ nowPlaying: NowPlaying?) {
        guard nowPlaying != current else { return }
        current = nowPlaying
        if let nowPlaying {
            let app = nowPlaying.app
            mediaRemoteLog.info(
                "session: playing=\(nowPlaying.playing, privacy: .public) bundle=\(app.bundleIdentifier ?? "-", privacy: .public) pid=\(app.processIdentifier.map(String.init) ?? "-", privacy: .public) title=\(nowPlaying.title, privacy: .private)"
            )
        } else {
            mediaRemoteLog.info("no session")
        }
        for continuation in observers.values { continuation.yield(nowPlaying) }
    }

    private func engineStatusChanged(_ status: MediaRemoteEngine.Status) {
        if case .running = status {
            parser = NowPlayingStreamParser()
            linesSinceStart = 0
        }
        switch status {
        case .failed, .unavailable:
            // A crash isn't "nothing playing": don't let a pending empty payload say so.
            pendingNoSession?.cancel()
            pendingNoSession = nil
        case .running, .stopped:
            break
        }
        if let health = Self.health(of: status) {
            for continuation in healthObservers.values { continuation.yield(health) }
        }
    }

    /// What observers are told about `status`, or `nil` when it says nothing new.
    private static func health(of status: MediaRemoteEngine.Status) -> NowPlayingSourceHealth? {
        switch status {
        case .running: .ready
        case .failed, .unavailable: .down
        case .stopped: nil
        }
    }

    private func addObserver(_ continuation: AsyncStream<NowPlaying?>.Continuation) {
        let id = UUID()
        observers[id] = continuation
        continuation.yield(current)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.observers[id] = nil }
        }
    }

    private func addArtworkObserver(_ continuation: AsyncStream<Data?>.Continuation) {
        let id = UUID()
        artworkObservers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.artworkObservers[id] = nil }
        }
    }

    private func addHealthObserver(_ continuation: AsyncStream<NowPlayingSourceHealth>.Continuation)
    {
        let id = UUID()
        healthObservers[id] = continuation
        // Replay, like `addObserver` does: the engine can fail before this registers.
        if let health = Self.health(of: engine.status) { continuation.yield(health) }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.healthObservers[id] = nil }
        }
    }
}

extension MediaRemoteNowPlayingSource: NowPlayingSource {
    /// Safe to call from any thread: the stream registers on the main actor, then yields
    /// the current state first. Before the adapter reports anything, that is `nil`.
    nonisolated func nowPlayingUpdates() -> AsyncStream<NowPlaying?> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: NowPlaying?.self, bufferingPolicy: .bufferingNewest(1))
        Task { @MainActor in self.addObserver(continuation) }
        return stream
    }

    nonisolated func artworkUpdates() -> AsyncStream<Data?> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Data?.self, bufferingPolicy: .bufferingNewest(1))
        Task { @MainActor in self.addArtworkObserver(continuation) }
        return stream
    }

    nonisolated func healthUpdates() -> AsyncStream<NowPlayingSourceHealth> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: NowPlayingSourceHealth.self, bufferingPolicy: .bufferingNewest(1))
        Task { @MainActor in self.addHealthObserver(continuation) }
        return stream
    }

    nonisolated func send(_ command: MediaCommand) async throws {
        try await engine.send(commandID: Self.commandID(for: command))
    }
}
