import CoreGraphics
import NotchCore
import Observation

/// Everything the island view reads: the state machine, the notch it wraps, and the
/// system reduce-motion setting.
///
/// The state machine decides the mode and level. This adds the screen-dependent sizes
/// and the motion, so the view and the panel controller work from the same numbers.
@MainActor
@Observable
final class IslandModel {
    /// Room left around the largest island for its drop shadow, in points.
    ///
    /// The canvas shadow is `0 20px 44px`: 20 pt down with a 44 pt blur, so about 22 pt
    /// of spread on each side and 42 below.
    static let shadowMargin = (sides: 24.0, bottom: 44.0)

    let stateMachine: IslandStateMachine
    /// What is playing, for the Now Playing views. `nil` in previews without media.
    let nowPlaying: NowPlayingPresentation?
    /// The notch on the island's screen, measured or virtual.
    var geometry: NotchGeometry
    /// The system reduce-motion setting.
    var systemReduceMotion = false

    init(
        stateMachine: IslandStateMachine, geometry: NotchGeometry,
        nowPlaying: NowPlayingPresentation? = nil
    ) {
        self.stateMachine = stateMachine
        self.geometry = geometry
        self.nowPlaying = nowPlaying
    }

    var layout: IslandLayout { IslandLayout(geometry: geometry) }

    /// The island's size for what it shows now.
    var islandSize: IslandSize {
        layout.size(for: stateMachine.mode, at: stateMachine.displayedLevel)
    }

    var motion: MotionSpec {
        MotionSpec(settings: stateMachine.settings, systemReduceMotion: systemReduceMotion)
    }

    /// The fixed size of the window the island draws in: the largest island any mode
    /// reaches, plus room for its shadow.
    ///
    /// The window never resizes, so a morph only redraws; it never moves a window.
    var canvasSize: CGSize {
        let layout = layout
        return CGSize(
            width: layout.maximumWidth + 2 * Self.shadowMargin.sides,
            height: layout.maximumHeight + Self.shadowMargin.bottom)
    }
}
