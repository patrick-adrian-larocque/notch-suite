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
    /// `NowPlaying` so that core type stays small; see `onArtworkChange`.
    private(set) var artwork: Data?
    /// Called when ``artwork`` changes. Artwork arrives once per track, often a moment
    /// after the track's first update.
    var onArtworkChange: (Data?) -> Void = { _ in }
    /// Called when the engine's status changes, so callers can show "unavailable"
    /// rather than an idle island while it is down.
    var onEngineStatusChange: (MediaRemoteEngine.Status) -> Void = { _ in }
    /// The engine's status, for showing that the source is down rather than idle.
    var engineStatus: MediaRemoteEngine.Status { engine.status }

    private let engine: MediaRemoteEngine
    private var parser = NowPlayingStreamParser()
    private var linesSinceStart = 0
    private var pendingNoSession: Task<Void, Never>?
    private var observers: [UUID: AsyncStream<NowPlaying?>.Continuation] = [:]

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
    }

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
        onArtworkChange(data)
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
        onEngineStatusChange(status)
    }

    private func addObserver(_ continuation: AsyncStream<NowPlaying?>.Continuation) {
        let id = UUID()
        observers[id] = continuation
        continuation.yield(current)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.observers[id] = nil }
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

    nonisolated func send(_ command: MediaCommand) async throws {
        try await engine.send(commandID: Self.commandID(for: command))
    }
}
