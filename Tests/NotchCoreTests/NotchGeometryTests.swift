import Testing

@testable import NotchCore

@Suite struct NotchGeometryTests {
    // Illustrative numbers for a notched laptop screen, not taken from a specific model.
    private let notched = ScreenMetrics(
        screenWidth: 1512,
        topInset: 38,
        auxiliaryTopLeftWidth: 657,
        auxiliaryTopRightWidth: 657)

    @Test func measuresNotchedScreen() {
        let geometry = NotchGeometry(metrics: notched)
        #expect(
            geometry
                == NotchGeometry(
                    notchWidth: 198,
                    notchHeight: 38,
                    leftAreaWidth: 657,
                    rightAreaWidth: 657,
                    isPhysical: true))
    }

    @Test func notchedScreenIgnoresVirtualNotch() {
        let geometry = NotchGeometry(
            metrics: notched, virtualNotch: VirtualNotch(width: 300, height: 50))
        #expect(geometry.notchWidth == 198)
        #expect(geometry.notchHeight == 38)
        #expect(geometry.isPhysical)
    }

    @Test func measuresFractionalAndAsymmetricAuxAreas() {
        let geometry = NotchGeometry(
            metrics: ScreenMetrics(
                screenWidth: 1728,
                topInset: 32.5,
                auxiliaryTopLeftWidth: 764.25,
                auxiliaryTopRightWidth: 763.75))
        #expect(geometry.notchWidth == 200)
        #expect(geometry.notchHeight == 32.5)
        #expect(geometry.leftAreaWidth == 764.25)
        #expect(geometry.rightAreaWidth == 763.75)
        #expect(geometry.maximumWingWidth == 763.75)
        #expect(geometry.isPhysical)
    }

    @Test func nonNotchScreenUsesDefaultVirtualNotch() {
        let geometry = NotchGeometry(metrics: ScreenMetrics(screenWidth: 1920, topInset: 0))
        #expect(
            geometry
                == NotchGeometry(
                    notchWidth: 196,
                    notchHeight: 32,
                    leftAreaWidth: 862,
                    rightAreaWidth: 862,
                    isPhysical: false))
    }

    @Test func nonNotchScreenUsesConfiguredVirtualNotch() {
        let geometry = NotchGeometry(
            metrics: ScreenMetrics(screenWidth: 1920, topInset: 0),
            virtualNotch: VirtualNotch(width: 220, height: 30))
        #expect(geometry.notchWidth == 220)
        #expect(geometry.notchHeight == 30)
        #expect(geometry.leftAreaWidth == 850)
        #expect(geometry.rightAreaWidth == 850)
        #expect(!geometry.isPhysical)
    }

    @Test(
        "Unusable aux areas fall back to the virtual notch",
        arguments: [
            (nil, nil),
            (nil, 657.0),
            (657.0, nil),
            (0.0, 657.0),
            (657.0, 0.0),
            (0.0, 0.0),
            (-1.0, 657.0),
            (Double.nan, 657.0),
            (Double.infinity, 657.0),
        ] as [(Double?, Double?)])
    func unusableAuxAreasFallBack(left: Double?, right: Double?) {
        let geometry = NotchGeometry(
            metrics: ScreenMetrics(
                screenWidth: 1512,
                topInset: 38,
                auxiliaryTopLeftWidth: left,
                auxiliaryTopRightWidth: right))
        // The top inset is still the real menu bar height, so it is kept.
        #expect(
            geometry
                == NotchGeometry(
                    notchWidth: 196,
                    notchHeight: 38,
                    leftAreaWidth: 658,
                    rightAreaWidth: 658,
                    isPhysical: false))
    }

    @Test(
        "Aux areas that leave no gap fall back to the virtual notch",
        arguments: [(756.0, 756.0), (800.0, 800.0)])
    func auxAreasWithoutGapFallBack(left: Double, right: Double) {
        let geometry = NotchGeometry(
            metrics: ScreenMetrics(
                screenWidth: 1512,
                topInset: 38,
                auxiliaryTopLeftWidth: left,
                auxiliaryTopRightWidth: right))
        #expect(geometry.notchWidth == 196)
        #expect(!geometry.isPhysical)
    }

    @Test func auxAreasWithoutTopInsetFallBack() {
        let geometry = NotchGeometry(
            metrics: ScreenMetrics(
                screenWidth: 1512,
                topInset: 0,
                auxiliaryTopLeftWidth: 657,
                auxiliaryTopRightWidth: 657))
        #expect(geometry.notchWidth == 196)
        #expect(geometry.notchHeight == 32)
        #expect(!geometry.isPhysical)
    }

    @Test func virtualNotchIsClampedToScreenWidth() {
        let geometry = NotchGeometry(
            metrics: ScreenMetrics(screenWidth: 150, topInset: 0))
        #expect(geometry.notchWidth == 150)
        #expect(geometry.leftAreaWidth == 0)
        #expect(geometry.rightAreaWidth == 0)
    }

    @Test func wingWidthsFollowTheNotch() {
        let virtual = NotchGeometry(metrics: ScreenMetrics(screenWidth: 1920, topInset: 0))
        // On the canvas notch, idle compact (196) has no wings and Now Playing (348) has 76.
        #expect(virtual.wingWidth(forIslandWidth: 196) == 0)
        #expect(virtual.wingWidth(forIslandWidth: 348) == 76)
        #expect(virtual.wingWidth(forIslandWidth: 100) == 0)

        let physical = NotchGeometry(metrics: notched)
        #expect(physical.wingWidth(forIslandWidth: 348) == 75)
        #expect(physical.islandWidth(wingWidth: 76) == 350)
        #expect(physical.islandWidth(wingWidth: -5) == 198)
        #expect(physical.maximumWingWidth == 657)
    }

    @Test func islandIsCentredOnTheNotch() {
        let physical = NotchGeometry(metrics: notched)
        #expect(physical.notchMidX == 756)
        #expect(physical.islandMinX(forIslandWidth: 198) == 657)
        #expect(physical.islandMinX(forIslandWidth: 350) == 581)

        let asymmetric = NotchGeometry(
            metrics: ScreenMetrics(
                screenWidth: 1728,
                topInset: 32.5,
                auxiliaryTopLeftWidth: 764.25,
                auxiliaryTopRightWidth: 763.75))
        #expect(asymmetric.notchMidX == 864.25)

        let virtual = NotchGeometry(metrics: ScreenMetrics(screenWidth: 1440, topInset: 24))
        #expect(virtual.notchMidX == 720)
        #expect(virtual.islandMinX(forIslandWidth: 196) == 622)
    }

    @MainActor
    @Test func providerProducesGeometry() {
        struct FixedProvider: NotchGeometryProvider {
            var metrics: ScreenMetrics?
            func screenMetrics() -> ScreenMetrics? { metrics }
        }
        #expect(FixedProvider(metrics: nil).geometry() == nil)
        #expect(FixedProvider(metrics: notched).geometry()?.notchWidth == 198)
        #expect(
            FixedProvider(metrics: ScreenMetrics(screenWidth: 1920, topInset: 0))
                .geometry(virtualNotch: VirtualNotch(width: 210, height: 34))?.notchWidth == 210)
    }
}
