import AppKit
import NotchCore
import Observation

/// What the Now Playing views read, kept current from `MediaRemoteNowPlayingSource`.
///
/// It turns source updates into `PlaybackState`, a `PlaybackProgress` sample, an
/// `ArtworkState` and the player's resolved name and icon, and moves the island into
/// and out of `.nowPlaying`:
/// - A session starts (playing or paused) while the island is idle: show Now Playing.
/// - The session ends while Now Playing shows: back to idle.
/// Other modes (an alert, a timer) are left alone.
@MainActor
@Observable
final class NowPlayingPresentation {
    /// Playing, paused, or stopped with the last track.
    private(set) var playback: PlaybackState = .idle
    /// The last progress sample, or `nil` when the source reports no elapsed time.
    private(set) var progress: PlaybackProgress?
    /// What to show in the artwork slot.
    private(set) var artwork: ArtworkState = .missing
    /// The artwork as an image, decoded off the main actor. `nil` until it arrives.
    private(set) var artworkImage: NSImage?
    /// The player's name and icon, or `nil` when there is no session.
    private(set) var app: ResolvedAppIdentity?
    /// Whether the engine is down, so the view can say so instead of looking idle.
    private(set) var isEngineDown = false
    /// The last command that couldn't be delivered, for accessibility announcements.
    private(set) var lastCommandError: String?

    /// The track to show: the current one, or `nil` when stopped.
    var nowPlaying: NowPlaying? { playback.nowPlaying }

    @ObservationIgnored private let source: MediaRemoteNowPlayingSource
    @ObservationIgnored private let stateMachine: IslandStateMachine
    @ObservationIgnored private let resolver: AppIdentityResolver
    @ObservationIgnored private var tracker = ArtworkTracker()
    @ObservationIgnored private var artworkBytes: Data?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var artworkDeadlineTask: Task<Void, Never>?
    @ObservationIgnored private var decodeTask: Task<Void, Never>?

    init(
        source: MediaRemoteNowPlayingSource, stateMachine: IslandStateMachine,
        resolver: AppIdentityResolver
    ) {
        self.source = source
        self.stateMachine = stateMachine
        self.resolver = resolver
    }

    /// Starts following the source. Call once, after the source starts.
    func start() {
        source.onArtworkChange = { [weak self] data in self?.artworkChanged(data) }
        source.onEngineStatusChange = { [weak self] status in
            if case .failed = status { self?.isEngineDown = true }
            if case .unavailable = status { self?.isEngineDown = true }
            if case .running = status { self?.isEngineDown = false }
        }
        let updates = source.nowPlayingUpdates()
        updatesTask = Task { [weak self] in
            for await update in updates {
                self?.apply(update)
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        artworkDeadlineTask?.cancel()
        decodeTask?.cancel()
    }

    // MARK: Commands

    func togglePlayPause() { send(.togglePlayPause) }
    func nextTrack() { send(.nextTrack) }
    func previousTrack() { send(.previousTrack) }

    private func send(_ command: MediaCommand) {
        Task {
            do {
                try await source.send(command)
                lastCommandError = nil
            } catch {
                lastCommandError = "Couldn't reach the player"
                mediaRemoteLog.error(
                    "command \(String(describing: command), privacy: .public) failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    // MARK: Updates

    private func apply(_ update: NowPlaying?) {
        let previous = playback.nowPlaying
        playback = playback.updated(with: update)
        progress = update.flatMap { PlaybackProgress(nowPlaying: $0, sampledAt: .now) }
        if let update {
            if previous.map({ !$0.isSameTrack(as: update) }) ?? true
                || previous?.app != update.app
            {
                app = resolver.resolve(update)
            }
        } else {
            app = nil
        }
        refreshArtwork()
        followSession(started: previous == nil && update != nil, ended: update == nil)
    }

    private func artworkChanged(_ data: Data?) {
        artworkBytes = data
        refreshArtwork()
    }

    /// Feeds the tracker and decodes new artwork, then schedules the next re-read while
    /// the artwork is still loading.
    private func refreshArtwork() {
        tracker.update(nowPlaying: playback.nowPlaying, artwork: artworkBytes, at: .now)
        let state = tracker.state(at: .now)
        if state != artwork {
            artwork = state
            decodeArtwork(state)
        }
        artworkDeadlineTask?.cancel()
        if let deadline = tracker.loadingDeadline {
            artworkDeadlineTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                self?.refreshArtwork()
            }
        }
    }

    /// Decodes artwork off the main actor; a result for older bytes is dropped.
    private func decodeArtwork(_ state: ArtworkState) {
        decodeTask?.cancel()
        guard case .loaded(let data) = state else {
            artworkImage = nil
            return
        }
        decodeTask = Task { [weak self] in
            let image = await Task.detached(priority: .userInitiated) { NSImage(data: data) }
                .value
            guard !Task.isCancelled, let self, self.artwork == .loaded(data) else { return }
            self.artworkImage = image
        }
    }

    /// Shows Now Playing when a session starts on an idle island, and goes back to idle
    /// when the session ends while Now Playing shows.
    private func followSession(started: Bool, ended: Bool) {
        if started, stateMachine.mode == .idle, stateMachine.level == .compact {
            stateMachine.selectMode(.nowPlaying)
        } else if ended, stateMachine.mode == .nowPlaying {
            stateMachine.selectMode(.idle)
        }
    }
}

#if DEBUG
    extension NowPlayingPresentation {
        /// A presentation with fixed sample data, for Xcode previews.
        ///
        /// Never touches the real media engine or the adapter process: it only sets the
        /// published properties a preview needs, the same way `apply(_:)` would from a
        /// real update.
        static func preview(
            title: String, artist: String? = nil, album: String? = nil, playing: Bool = true,
            duration: Double? = 237, elapsedTime: Double? = 65, artwork: ArtworkState = .missing,
            isEngineDown: Bool = false
        ) -> NowPlayingPresentation {
            let nowPlaying = NowPlaying(
                app: AppIdentity(bundleIdentifier: "com.apple.Music"),
                playing: playing, title: title, artist: artist, album: album,
                duration: duration, elapsedTime: elapsedTime, playbackRate: playing ? 1 : 0)
            let presentation = NowPlayingPresentation(
                source: MediaRemoteNowPlayingSource(),
                stateMachine: IslandStateMachine(scheduler: TaskDelayScheduler()),
                resolver: AppIdentityResolver())
            presentation.playback = playing ? .playing(nowPlaying) : .paused(nowPlaying)
            presentation.progress = PlaybackProgress(nowPlaying: nowPlaying, sampledAt: .now)
            presentation.artwork = artwork
            presentation.app = AppIdentityResolver().resolve(nowPlaying)
            presentation.isEngineDown = isEngineDown
            return presentation
        }
    }
#endif
