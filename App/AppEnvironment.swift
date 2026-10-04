import Foundation
import NotchCore

/// Builds and owns the app's long-lived objects, and connects them.
///
/// `AppDelegate` creates one at launch and keeps it for the app's lifetime. Objects get
/// what they need through their initializers; nothing reads this type globally.
///
/// Where upcoming pieces plug in:
/// - Media (#24): `nowPlayingSource` runs here from launch to termination. Its
///   presentation model (next) will feed `stateMachine`, with `appIdentityResolver`
///   naming and iconing the player. An engine failure stays distinct from "no session":
///   see `MediaRemoteEngine.Status`.
/// - Settings (#28): a `UserDefaultsSettingsStore` loads `IslandSettings` here and
///   assigns `stateMachine.settings` before the panel shows.
/// - Displays: `DisplayPlacement.placements` replaces the screen choice in
///   `ScreenNotchGeometryProvider`, with one `NotchPanelController` per placement.
/// - System HUD (#26): key events call `stateMachine.hudKeyPressed(_:)` on this state
///   machine, instead of the Debug spike's own panel and state machine.
@MainActor
final class AppEnvironment {
    /// Decides the island's mode, level, alerts and HUD.
    let stateMachine: IslandStateMachine
    /// What the island view reads: the state machine plus notch geometry and motion.
    let islandModel: IslandModel
    /// Names and icons for the applications behind activities, such as the media player.
    let appIdentityResolver = AppIdentityResolver()
    /// What is playing, from mediaremote-adapter.
    let nowPlayingSource = MediaRemoteNowPlayingSource()
    /// The notch panel and its pointer handling.
    let panelController: NotchPanelController

    init() {
        let geometryProvider = ScreenNotchGeometryProvider()
        stateMachine = IslandStateMachine(scheduler: TaskDelayScheduler())
        islandModel = IslandModel(
            stateMachine: stateMachine,
            geometry: geometryProvider.geometry()
                ?? NotchGeometry(metrics: ScreenMetrics(screenWidth: 0, topInset: 0)))
        panelController = NotchPanelController(
            model: islandModel,
            geometryProvider: geometryProvider,
            reduceMotionProvider: WorkspaceReduceMotionProvider())
    }

    /// Shows the island and starts the media source. Call once, after launch.
    func start() {
        panelController.show()
        nowPlayingSource.start()
        #if DEBUG
            logNowPlayingForProbe()
        #endif
    }

    /// Ends child processes. Call when the app terminates.
    func stop() {
        nowPlayingSource.stop()
    }

    #if DEBUG
        /// With `-NowPlayingProbe YES`, logs each source update and its resolved app, and
        /// sends `pause` on the first playing session, so the whole path can be checked
        /// before the Now Playing views exist. Off by default.
        private func logNowPlayingForProbe() {
            guard UserDefaults.standard.bool(forKey: "NowPlayingProbe") else { return }
            let updates = nowPlayingSource.nowPlayingUpdates()
            let source = nowPlayingSource
            let resolver = appIdentityResolver
            Task { @MainActor in
                var sentPause = false
                for await nowPlaying in updates {
                    guard let nowPlaying else {
                        mediaRemoteLog.notice("probe: update nil (no session)")
                        continue
                    }
                    let app = resolver.resolve(nowPlaying.app)
                    mediaRemoteLog.notice(
                        "probe: update playing=\(nowPlaying.playing, privacy: .public) app=\(app.displayName ?? "-", privacy: .public) icon=\(app.icon != nil, privacy: .public)"
                    )
                    if nowPlaying.playing, !sentPause {
                        sentPause = true
                        do {
                            try await source.send(.pause)
                            mediaRemoteLog.notice("probe: pause sent")
                        } catch {
                            mediaRemoteLog.error(
                                "probe: pause failed: \(String(describing: error), privacy: .public)"
                            )
                        }
                    }
                }
            }
        }
    #endif
}
