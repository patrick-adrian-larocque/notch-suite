import NotchCore
import SwiftUI

/// The island: a notch-shaped surface that morphs between compact, peek and open, with
/// each level's content revealed on top.
///
/// It fills the panel's fixed canvas and draws the island centred at the top, over the
/// notch. Sizes come from `IslandLayout` for the measured notch, the level and mode from
/// `IslandStateMachine`, and every timing from `MotionSpec`. Hover reaches the state
/// machine through `NotchPanelController`; clicks go through the buttons here.
struct IslandView: View {
    let model: IslandModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let machine = model.stateMachine
        let mode = machine.mode
        let level = machine.displayedLevel
        let size = model.islandSize
        let motion = model.motion
        let canvas = model.canvasSize
        let palette = IslandPalette(
            appearance: IslandAppearance(
                hasNotch: model.geometry.isPhysical,
                system: colorScheme == .dark ? .dark : .light,
                accent: machine.settings.accent))
        let shape = NotchShape(
            islandWidth: size.width, islandHeight: size.height, bottomRadius: size.cornerRadius)

        ZStack(alignment: .top) {
            surface(shape, size: size, isOpen: level == .open, palette: palette, motion: motion)

            content(mode: mode, level: level, size: size, palette: palette, motion: motion)
                .frame(width: canvas.width, height: canvas.height, alignment: .top)
                .modifier(ClipUnlessReducingMotion(shape: shape, motion: motion))

            if level != .open {
                openButton(mode: mode, size: size)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .animation(motion.islandAnimation, value: size)
    }

    /// The black (or, without a notch in light mode, light) island itself.
    ///
    /// With motion, the shape springs between sizes. Under reduce motion each size is a
    /// separate view, so changing size cross-fades instead of moving.
    @ViewBuilder
    private func surface(
        _ shape: NotchShape, size: IslandSize, isOpen: Bool, palette: IslandPalette,
        motion: MotionSpec
    ) -> some View {
        let island = shape.fill(palette.surface)
            .overlay {
                if let border = palette.border {
                    shape.stroke(border, lineWidth: 1)
                }
            }
            // The canvas drops a shadow only under the open island.
            .shadow(
                color: .black.opacity(isOpen && palette.castsShadow ? 0.45 : 0), radius: 22, y: 20
            )
            .accessibilityHidden(true)
        if motion.reducesMotion {
            island.id(size).transition(.opacity)
        } else {
            island
        }
    }

    /// What the island shows at this mode and level, sized to the island it fills.
    ///
    /// Each mode and level is its own view, so moving between them runs the reveal.
    private func content(
        mode: IslandMode, level: IslandLevel, size: IslandSize, palette: IslandPalette,
        motion: MotionSpec
    ) -> some View {
        ZStack(alignment: .top) {
            levelContent(mode: mode, level: level, palette: palette)
                .frame(width: size.width, height: size.height, alignment: .top)
                .id(ContentKey(mode: mode, level: level))
                .transition(motion.contentTransition)
        }
    }

    @ViewBuilder
    private func levelContent(mode: IslandMode, level: IslandLevel, palette: IslandPalette)
        -> some View
    {
        switch (mode, level) {
        case (.idle, .open):
            IdleOpenView(palette: palette, collapse: { model.stateMachine.collapse() })
        default:
            // Compact and peek idle are an empty pill. The other modes' views arrive with
            // their own issues.
            Color.clear
        }
    }

    /// The whole compact or peek island is one button that opens it.
    ///
    /// It is at least 44 pt tall, so on a short compact island it reaches a little below
    /// the black. `NotchPanelController` uses the same rect for hover and hit testing.
    private func openButton(mode: IslandMode, size: IslandSize) -> some View {
        Button {
            model.stateMachine.click()
        } label: {
            Color.clear
                .frame(width: size.hitTargetWidth, height: size.hitTargetHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(mode.spokenName)")
    }
}

/// Identifies one level of one mode's content.
private struct ContentKey: Hashable {
    let mode: IslandMode
    let level: IslandLevel
}

/// Clips content to the island while it morphs.
///
/// Under reduce motion the island cross-fades rather than morphing, and each level's
/// content already fits its own island, so a clip would only add a wipe.
private struct ClipUnlessReducingMotion: ViewModifier {
    let shape: NotchShape
    let motion: MotionSpec

    func body(content: Content) -> some View {
        if motion.reducesMotion {
            content
        } else {
            content.clipShape(shape)
        }
    }
}

extension IslandMode {
    /// What VoiceOver calls the island in this mode, as in "Open now playing".
    var spokenName: String {
        switch self {
        case .idle: "island"
        case .nowPlaying: "now playing"
        case .timer: "timer"
        case .message: "message"
        case .charging: "battery"
        case .shelf: "shelf"
        }
    }
}
