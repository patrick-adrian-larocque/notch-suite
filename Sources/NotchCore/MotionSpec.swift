/// A cubic Bézier timing curve, with the same four numbers as CSS
/// `cubic-bezier(x1, y1, x2, y2)`.
///
/// The curve runs from (0, 0) to (1, 1) through the control points
/// (`x1`, `y1`) and (`x2`, `y2`). A `y` above 1 overshoots, which is what gives
/// `bouncy` and `snappy` their bounce. The UI layer turns this into a platform
/// timing curve.
public struct TimingCurve: Sendable, Hashable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// The island morph for `MotionCurve.bouncy`: `cubic-bezier(.34, 1.56, .64, 1)`.
    public static let bouncy = TimingCurve(0.34, 1.56, 0.64, 1)
    /// The island morph for `MotionCurve.snappy`: `cubic-bezier(.2, 1.25, .4, 1)`.
    public static let snappy = TimingCurve(0.2, 1.25, 0.4, 1)
    /// The island morph for `MotionCurve.smooth`: `cubic-bezier(.4, 0, .2, 1)`.
    public static let smooth = TimingCurve(0.4, 0, 0.2, 1)
    /// The content reveal, for the island and the HUD: `cubic-bezier(.2, .8, .2, 1)`.
    public static let reveal = TimingCurve(0.2, 0.8, 0.2, 1)
    /// The system HUD morph: `cubic-bezier(.34, 1.4, .64, 1)`.
    public static let hudMorph = TimingCurve(0.34, 1.4, 0.64, 1)
    /// CSS `ease-out`, used for every reduce-motion fade: `cubic-bezier(0, 0, .58, 1)`.
    public static let easeOut = TimingCurve(0, 0, 0.58, 1)
}

extension IslandSettings.MotionCurve {
    /// How long an island morph with this curve takes at speed 1, in seconds.
    public var baseDuration: Double {
        switch self {
        case .bouncy: 0.62
        case .snappy: 0.38
        case .smooth: 0.50
        }
    }

    /// The timing curve for an island morph with this curve.
    public var timingCurve: TimingCurve {
        switch self {
        case .bouncy: .bouncy
        case .snappy: .snappy
        case .smooth: .smooth
        }
    }
}

/// Every animation timing the island uses, worked out from the settings and
/// the system reduce-motion flag.
///
/// Durations and delays are in seconds. With motion on, each one is the
/// design canvas's value divided by `IslandSettings.speed`. With reduce motion
/// on, every transition becomes a short `easeOut` fade that ignores the speed,
/// content appears without blur or scale, and the looping equalizer and pulse
/// animations stop.
public struct MotionSpec: Sendable, Equatable {
    /// A change of size or shape: how long it takes and how it eases.
    public struct Transition: Sendable, Equatable {
        /// In seconds.
        public var duration: Double
        public var curve: TimingCurve

        public init(duration: Double, curve: TimingCurve) {
            self.duration = duration
            self.curve = curve
        }
    }

    /// How content fades in once the island or HUD has started changing.
    ///
    /// The content starts at opacity 0, blurred by `initialBlurRadius` and
    /// scaled by `initialScale`, and settles at opacity 1, no blur and scale 1.
    public struct Reveal: Sendable, Equatable {
        /// In seconds.
        public var duration: Double
        /// How long after the transition starts the reveal begins, in seconds.
        public var delay: Double
        public var curve: TimingCurve
        /// The starting blur radius, in points. 0 means no blur.
        public var initialBlurRadius: Double
        /// The starting scale. 1 means no scaling.
        public var initialScale: Double

        public init(
            duration: Double, delay: Double, curve: TimingCurve, initialBlurRadius: Double,
            initialScale: Double
        ) {
            self.duration = duration
            self.delay = delay
            self.curve = curve
            self.initialBlurRadius = initialBlurRadius
            self.initialScale = initialScale
        }
    }

    // MARK: Design canvas values

    /// The reduce-motion fade's duration, in seconds. Not scaled by speed.
    public static let reducedFadeDuration: Double = 0.2

    /// The island content reveal at speed 1: 0.38 s, starting 0.16 s in, from
    /// 6 pt of blur and 96% scale.
    public static let baseContentReveal = Reveal(
        duration: 0.38, delay: 0.16, curve: .reveal, initialBlurRadius: 6, initialScale: 0.96)

    /// The system HUD morph at speed 1: 0.45 s.
    public static let baseHUDMorph = Transition(duration: 0.45, curve: .hudMorph)

    /// The system HUD content reveal at speed 1: 0.3 s, starting 0.1 s in, from
    /// 5 pt of blur and 96% scale.
    public static let baseHUDReveal = Reveal(
        duration: 0.3, delay: 0.1, curve: .reveal, initialBlurRadius: 5, initialScale: 0.96)

    /// The transition every reduce-motion change uses.
    public static let reducedTransition = Transition(
        duration: reducedFadeDuration, curve: .easeOut)

    /// The reveal every reduce-motion change uses: a plain fade, starting at once.
    public static let reducedReveal = Reveal(
        duration: reducedFadeDuration, delay: 0, curve: .easeOut, initialBlurRadius: 0,
        initialScale: 1)

    // MARK: Output

    /// Whether reduce motion is on, from either the in-app toggle or the system.
    public let reducesMotion: Bool
    /// The island changing size between compact, peek and open.
    public let islandMorph: Transition
    /// The island's content appearing after a size change.
    public let contentReveal: Reveal
    /// The island changing size to show or hide a system HUD.
    public let hudMorph: Transition
    /// The HUD's content appearing.
    public let hudReveal: Reveal
    /// Whether the now-playing equalizer bars animate while music plays.
    public let animatesEqualizer: Bool
    /// Whether status icons, such as the charging bolt, pulse.
    public let animatesPulse: Bool

    /// Works out the motion for `settings`.
    ///
    /// - Parameters:
    ///   - settings: Supplies the curve, the speed and the in-app reduce-motion toggle.
    ///   - systemReduceMotion: The system reduce-motion setting, usually from a
    ///     `ReduceMotionProvider`.
    public init(settings: IslandSettings, systemReduceMotion: Bool) {
        let reduces = Self.reducesMotion(settings: settings, systemReduceMotion: systemReduceMotion)
        reducesMotion = reduces
        animatesEqualizer = !reduces
        animatesPulse = !reduces

        if reduces {
            islandMorph = Self.reducedTransition
            contentReveal = Self.reducedReveal
            hudMorph = Self.reducedTransition
            hudReveal = Self.reducedReveal
            return
        }

        // `IslandSettings` keeps speed within 0.5...2.0, so the division is safe.
        let speed = settings.speed
        let curve = settings.motionCurve
        islandMorph = Transition(duration: curve.baseDuration / speed, curve: curve.timingCurve)
        contentReveal = Self.baseContentReveal.scaled(by: speed)
        hudMorph = Transition(
            duration: Self.baseHUDMorph.duration / speed, curve: Self.baseHUDMorph.curve)
        hudReveal = Self.baseHUDReveal.scaled(by: speed)
    }

    /// Whether reduce motion is on: true when the in-app toggle or the system
    /// setting is on.
    public static func reducesMotion(settings: IslandSettings, systemReduceMotion: Bool) -> Bool {
        settings.reduceMotion || systemReduceMotion
    }
}

extension MotionSpec.Reveal {
    /// This reveal played `speed` times as fast: duration and delay divided by it.
    fileprivate func scaled(by speed: Double) -> Self {
        var copy = self
        copy.duration /= speed
        copy.delay /= speed
        return copy
    }
}
