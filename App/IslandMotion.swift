import NotchCore
import SwiftUI

extension Animation {
    /// `curve` as a SwiftUI timing curve lasting `duration` seconds.
    init(_ curve: TimingCurve, duration: Double) {
        self = .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: duration)
    }
}

extension MotionSpec {
    /// The animation for the island changing size.
    ///
    /// A spring tuned by eye, from `islandSpring`. Under reduce motion there is no
    /// spring: the island fades between sizes over `islandMorph` instead.
    var islandAnimation: Animation {
        guard let spring = islandSpring else {
            return Animation(islandMorph.curve, duration: islandMorph.duration)
        }
        return .spring(duration: spring.duration, bounce: spring.bounce)
    }

    /// How content comes and goes when the island changes level or mode.
    ///
    /// New content fades in from blurred and slightly small, starting a moment after the
    /// island starts moving; under reduce motion `contentReveal` has no blur or scale, so
    /// it is a plain fade. Old content fades out quickly, so it never fights the new.
    var contentTransition: AnyTransition {
        let reveal = contentReveal
        let insertion = AnyTransition.modifier(
            active: RevealModifier(reveal: reveal, progress: 0),
            identity: RevealModifier(reveal: reveal, progress: 1)
        )
        .animation(Animation(reveal.curve, duration: reveal.duration).delay(reveal.delay))
        let removal = AnyTransition.opacity.animation(
            .easeOut(duration: min(0.12, reveal.duration)))
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

/// Content between hidden (`progress` 0) and shown (`progress` 1).
private struct RevealModifier: ViewModifier {
    let reveal: MotionSpec.Reveal
    let progress: Double

    func body(content: Content) -> some View {
        let hidden = 1 - progress
        content
            .opacity(progress)
            .blur(radius: reveal.initialBlurRadius * hidden)
            .scaleEffect(1 - (1 - reveal.initialScale) * hidden)
    }
}
