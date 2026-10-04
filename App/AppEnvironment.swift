import NotchCore

/// Builds and owns the app's long-lived objects, and connects them.
///
/// `AppDelegate` creates one at launch and keeps it for the app's lifetime. Objects get
/// what they need through their initializers; nothing reads this type globally.
///
/// Where upcoming pieces plug in:
/// - Media (#24): a `MediaRemoteNowPlayingSource` (`App/Media`) is created and started
///   here, and its presentation model feeds `stateMachine`. `appIdentityResolver` names
///   and icons its player. Stop its process on termination, and keep an engine failure
///   distinct from `NowPlayingReport.noSession`.
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

    /// Shows the island. Call once, after launch.
    func start() {
        panelController.show()
    }
}
