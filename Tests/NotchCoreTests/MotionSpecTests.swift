import Testing

@testable import NotchCore

/// A provider with a fixed system setting.
private struct FixedReduceMotionProvider: ReduceMotionProvider {
    let isReduceMotionEnabled: Bool

    func reduceMotionUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(isReduceMotionEnabled)
            continuation.finish()
        }
    }
}

private func isClose(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < 1e-9
}

@Suite struct MotionSpecTests {
    // MARK: Curves

    @Test(arguments: [
        (IslandSettings.MotionCurve.bouncy, 0.62, TimingCurve(0.34, 1.56, 0.64, 1)),
        (.snappy, 0.38, TimingCurve(0.2, 1.25, 0.4, 1)),
        (.smooth, 0.50, TimingCurve(0.4, 0, 0.2, 1)),
    ])
    func curveMatchesTheDesignCanvas(
        curve: IslandSettings.MotionCurve, duration: Double, timing: TimingCurve
    ) {
        #expect(curve.baseDuration == duration)
        #expect(curve.timingCurve == timing)
    }

    // MARK: Each curve at each speed

    struct Case: Sendable, CustomTestStringConvertible {
        let curve: IslandSettings.MotionCurve
        let speed: Double
        let morph: Double
        let revealDuration: Double
        let revealDelay: Double
        let hudMorph: Double
        let hudRevealDuration: Double
        let hudRevealDelay: Double

        var testDescription: String { "\(curve) at \(speed)x" }
    }

    static let cases: [Case] = [
        // Speed 1: the design canvas's values.
        Case(
            curve: .bouncy, speed: 1, morph: 0.62, revealDuration: 0.38, revealDelay: 0.16,
            hudMorph: 0.45, hudRevealDuration: 0.3, hudRevealDelay: 0.1),
        Case(
            curve: .snappy, speed: 1, morph: 0.38, revealDuration: 0.38, revealDelay: 0.16,
            hudMorph: 0.45, hudRevealDuration: 0.3, hudRevealDelay: 0.1),
        Case(
            curve: .smooth, speed: 1, morph: 0.50, revealDuration: 0.38, revealDelay: 0.16,
            hudMorph: 0.45, hudRevealDuration: 0.3, hudRevealDelay: 0.1),
        // Speed 2 (the maximum): everything takes half as long.
        Case(
            curve: .bouncy, speed: 2, morph: 0.31, revealDuration: 0.19, revealDelay: 0.08,
            hudMorph: 0.225, hudRevealDuration: 0.15, hudRevealDelay: 0.05),
        Case(
            curve: .snappy, speed: 2, morph: 0.19, revealDuration: 0.19, revealDelay: 0.08,
            hudMorph: 0.225, hudRevealDuration: 0.15, hudRevealDelay: 0.05),
        Case(
            curve: .smooth, speed: 2, morph: 0.25, revealDuration: 0.19, revealDelay: 0.08,
            hudMorph: 0.225, hudRevealDuration: 0.15, hudRevealDelay: 0.05),
        // Speed 0.5 (the minimum): everything takes twice as long.
        Case(
            curve: .bouncy, speed: 0.5, morph: 1.24, revealDuration: 0.76, revealDelay: 0.32,
            hudMorph: 0.9, hudRevealDuration: 0.6, hudRevealDelay: 0.2),
        Case(
            curve: .snappy, speed: 0.5, morph: 0.76, revealDuration: 0.76, revealDelay: 0.32,
            hudMorph: 0.9, hudRevealDuration: 0.6, hudRevealDelay: 0.2),
        Case(
            curve: .smooth, speed: 0.5, morph: 1.0, revealDuration: 0.76, revealDelay: 0.32,
            hudMorph: 0.9, hudRevealDuration: 0.6, hudRevealDelay: 0.2),
        // An in-between speed.
        Case(
            curve: .bouncy, speed: 1.25, morph: 0.496, revealDuration: 0.304,
            revealDelay: 0.128, hudMorph: 0.36, hudRevealDuration: 0.24, hudRevealDelay: 0.08),
        Case(
            curve: .snappy, speed: 1.25, morph: 0.304, revealDuration: 0.304,
            revealDelay: 0.128, hudMorph: 0.36, hudRevealDuration: 0.24, hudRevealDelay: 0.08),
        Case(
            curve: .smooth, speed: 1.25, morph: 0.4, revealDuration: 0.304,
            revealDelay: 0.128, hudMorph: 0.36, hudRevealDuration: 0.24, hudRevealDelay: 0.08),
    ]

    @Test(arguments: cases)
    func motionScalesWithSpeed(_ c: Case) {
        let settings = IslandSettings(motionCurve: c.curve, speed: c.speed)
        let spec = MotionSpec(settings: settings, systemReduceMotion: false)

        #expect(spec.reducesMotion == false)
        #expect(spec.animatesEqualizer)
        #expect(spec.animatesPulse)

        #expect(isClose(spec.islandMorph.duration, c.morph))
        #expect(spec.islandMorph.curve == c.curve.timingCurve)

        #expect(isClose(spec.contentReveal.duration, c.revealDuration))
        #expect(isClose(spec.contentReveal.delay, c.revealDelay))
        #expect(spec.contentReveal.curve == TimingCurve(0.2, 0.8, 0.2, 1))
        #expect(spec.contentReveal.initialBlurRadius == 6)
        #expect(spec.contentReveal.initialScale == 0.96)

        #expect(isClose(spec.hudMorph.duration, c.hudMorph))
        #expect(spec.hudMorph.curve == TimingCurve(0.34, 1.4, 0.64, 1))

        #expect(isClose(spec.hudReveal.duration, c.hudRevealDuration))
        #expect(isClose(spec.hudReveal.delay, c.hudRevealDelay))
        #expect(spec.hudReveal.curve == TimingCurve(0.2, 0.8, 0.2, 1))
        #expect(spec.hudReveal.initialBlurRadius == 5)
        #expect(spec.hudReveal.initialScale == 0.96)
    }

    @Test func defaultsGiveTheBouncyCanvasTiming() {
        let spec = MotionSpec(settings: .defaults, systemReduceMotion: false)
        #expect(spec.islandMorph == MotionSpec.Transition(duration: 0.62, curve: .bouncy))
        #expect(spec.contentReveal == MotionSpec.baseContentReveal)
        #expect(spec.hudMorph == MotionSpec.baseHUDMorph)
        #expect(spec.hudReveal == MotionSpec.baseHUDReveal)
    }

    @Test func outOfRangeSpeedIsClampedBeforeScaling() {
        // `IslandSettings` clamps 10 to 2 and 0 to 0.5, so durations stay finite.
        let fast = MotionSpec(settings: IslandSettings(speed: 10), systemReduceMotion: false)
        #expect(isClose(fast.islandMorph.duration, 0.31))
        let slow = MotionSpec(settings: IslandSettings(speed: 0), systemReduceMotion: false)
        #expect(isClose(slow.islandMorph.duration, 1.24))
    }

    // MARK: Reduce motion

    @Test(arguments: [
        (false, false, false),
        (true, false, true),
        (false, true, true),
        (true, true, true),
    ])
    @MainActor
    func reduceMotionIsOnWhenEitherSourceIs(inApp: Bool, system: Bool, expected: Bool) {
        let settings = IslandSettings(reduceMotion: inApp)
        #expect(
            MotionSpec.reducesMotion(settings: settings, systemReduceMotion: system) == expected)

        let spec = MotionSpec(settings: settings, systemReduceMotion: system)
        #expect(spec.reducesMotion == expected)
        #expect(spec.animatesEqualizer == !expected)
        #expect(spec.animatesPulse == !expected)

        let provider = FixedReduceMotionProvider(isReduceMotionEnabled: system)
        #expect(provider.motionSpec(for: settings) == spec)
    }

    @Test(arguments: IslandSettings.MotionCurve.allCases, [0.5, 1.0, 2.0])
    func reduceMotionIsAShortFadeForEveryCurveAndSpeed(
        curve: IslandSettings.MotionCurve, speed: Double
    ) {
        let settings = IslandSettings(motionCurve: curve, speed: speed, reduceMotion: true)
        let spec = MotionSpec(settings: settings, systemReduceMotion: false)

        let fade = MotionSpec.Transition(duration: 0.2, curve: TimingCurve(0, 0, 0.58, 1))
        #expect(spec.islandMorph == fade)
        #expect(spec.hudMorph == fade)

        for reveal in [spec.contentReveal, spec.hudReveal] {
            #expect(reveal.duration == 0.2)
            #expect(reveal.delay == 0)
            #expect(reveal.curve == TimingCurve(0, 0, 0.58, 1))
            #expect(reveal.initialBlurRadius == 0)
            #expect(reveal.initialScale == 1)
        }
        #expect(spec.animatesEqualizer == false)
        #expect(spec.animatesPulse == false)
        #expect(spec.islandSpring == nil)
    }

    // MARK: Spring

    @Test(arguments: [
        (IslandSettings.MotionCurve.bouncy, 0.5, 0.3),
        (.snappy, 0.34, 0.15),
        (.smooth, 0.42, 0),
    ])
    func eachCurveHasASpring(curve: IslandSettings.MotionCurve, duration: Double, bounce: Double) {
        #expect(curve.baseSpring == MotionSpec.Spring(duration: duration, bounce: bounce))
        let spec = MotionSpec(
            settings: IslandSettings(motionCurve: curve), systemReduceMotion: false)
        #expect(spec.islandSpring == curve.baseSpring)
    }

    @Test(arguments: IslandSettings.MotionCurve.allCases, [0.5, 1.0, 2.0])
    func springDurationScalesWithSpeedButBounceDoesNot(
        curve: IslandSettings.MotionCurve, speed: Double
    ) {
        let settings = IslandSettings(motionCurve: curve, speed: speed)
        let spring = MotionSpec(settings: settings, systemReduceMotion: false).islandSpring
        #expect(isClose(spring?.duration ?? -1, curve.baseSpring.duration / speed))
        #expect(spring?.bounce == curve.baseSpring.bounce)
    }

    @Test func springsBounceLessThanTheCanvasCurvesOvershoot() {
        // Only the curves that overshoot get a bounce, and none is close to undamped.
        for curve in IslandSettings.MotionCurve.allCases {
            let overshoots = curve.timingCurve.y1 > 1 || curve.timingCurve.y2 > 1
            #expect((curve.baseSpring.bounce > 0) == overshoots)
            #expect(curve.baseSpring.bounce < 0.5)
        }
    }

    @Test func systemReduceMotionAloneGivesTheSameFade() {
        let fromSystem = MotionSpec(
            settings: IslandSettings(motionCurve: .snappy, speed: 1.5), systemReduceMotion: true)
        let fromToggle = MotionSpec(
            settings: IslandSettings(reduceMotion: true), systemReduceMotion: false)
        #expect(fromSystem == fromToggle)
    }

    // MARK: Provider

    @Test @MainActor func providerStreamYieldsTheCurrentValue() async {
        let provider = FixedReduceMotionProvider(isReduceMotionEnabled: true)
        var values: [Bool] = []
        for await value in provider.reduceMotionUpdates() {
            values.append(value)
        }
        #expect(values == [true])
    }
}
