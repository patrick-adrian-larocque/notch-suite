import Testing

@testable import NotchCore

@Suite struct DisplayPlacementTests {
    // Illustrative numbers for a notched laptop screen, not taken from a specific model.
    private static let notchedMetrics = ScreenMetrics(
        screenWidth: 1512,
        topInset: 38,
        auxiliaryTopLeftWidth: 657,
        auxiliaryTopRightWidth: 657)
    private static let externalMetrics = ScreenMetrics(screenWidth: 2560, topInset: 0)

    private static func builtIn(
        hasMenuBar: Bool = true, isAvailable: Bool = true
    ) -> DisplayInfo {
        DisplayInfo(
            id: 1, isBuiltIn: true, hasMenuBar: hasMenuBar, metrics: notchedMetrics,
            isAvailable: isAvailable)
    }

    private static func external(id: DisplayInfo.ID = 2, hasMenuBar: Bool = false) -> DisplayInfo {
        DisplayInfo(id: id, isBuiltIn: false, hasMenuBar: hasMenuBar, metrics: externalMetrics)
    }

    private static func ids(
        _ displays: [DisplayInfo], _ showOn: IslandSettings.ShowOn
    ) -> [DisplayInfo.ID] {
        DisplayPlacement.displays(for: displays, showOn: showOn).map(\.id)
    }

    // MARK: Inputs

    @Test func hasNotchComesFromMetrics() {
        #expect(Self.builtIn().hasNotch)
        #expect(!Self.external().hasNotch)
    }

    @Test func displaysAreAvailableByDefault() {
        #expect(Self.external().isAvailable)
    }

    // MARK: One built-in screen

    @Test(arguments: IslandSettings.ShowOn.allCases)
    func oneBuiltInScreenAlwaysGetsTheIsland(showOn: IslandSettings.ShowOn) {
        #expect(Self.ids([Self.builtIn()], showOn) == [1])
    }

    // MARK: Built-in plus external

    @Test func builtInIsTheDefaultEvenWhenTheMenuBarIsElsewhere() {
        let displays = [Self.builtIn(hasMenuBar: false), Self.external(hasMenuBar: true)]
        #expect(IslandSettings.defaults.showOn == .builtIn)
        #expect(Self.ids(displays, .builtIn) == [1])
    }

    @Test func mainDisplayFollowsTheMenuBar() {
        #expect(
            Self.ids(
                [Self.builtIn(hasMenuBar: false), Self.external(hasMenuBar: true)], .mainDisplay)
                == [2])
        #expect(
            Self.ids(
                [Self.builtIn(hasMenuBar: true), Self.external(hasMenuBar: false)], .mainDisplay)
                == [1])
    }

    @Test func allMirrorsOnEveryScreenInOrder() {
        let displays = [Self.external(id: 3), Self.builtIn(), Self.external(id: 2)]
        #expect(Self.ids(displays, .all) == [3, 1, 2])
    }

    @Test func allSizesEachIslandToItsOwnNotch() {
        let placements = DisplayPlacement.placements(
            for: [Self.builtIn(), Self.external()], showOn: .all)
        #expect(placements.count == 2)
        #expect(placements[0].geometry == NotchGeometry(metrics: Self.notchedMetrics))
        #expect(placements[0].geometry.notchWidth == 198)
        #expect(placements[0].geometry.isPhysical)
        #expect(placements[1].geometry == NotchGeometry(metrics: Self.externalMetrics))
        #expect(placements[1].geometry.notchWidth == 196)
        #expect(!placements[1].geometry.isPhysical)
    }

    @Test func placementsUseTheGivenVirtualNotch() {
        let virtual = VirtualNotch(width: 220, height: 30)
        let placements = DisplayPlacement.placements(
            for: [Self.builtIn(), Self.external()], showOn: .all, virtualNotch: virtual)
        #expect(placements[0].geometry.notchWidth == 198)
        #expect(placements[1].geometry.notchWidth == 220)
        #expect(placements[1].geometry.notchHeight == 30)
    }

    // MARK: Lid closed

    @Test(arguments: IslandSettings.ShowOn.allCases)
    func closedLidMovesTheIslandToTheExternalDisplay(showOn: IslandSettings.ShowOn) {
        let displays = [
            Self.builtIn(hasMenuBar: false, isAvailable: false), Self.external(hasMenuBar: true),
        ]
        #expect(Self.ids(displays, showOn) == [2])
    }

    @Test func closedLidPrefersTheDisplayWithTheMenuBar() {
        let displays = [
            Self.builtIn(hasMenuBar: false, isAvailable: false),
            Self.external(id: 2),
            Self.external(id: 3, hasMenuBar: true),
        ]
        #expect(Self.ids(displays, .builtIn) == [3])
        #expect(Self.ids(displays, .mainDisplay) == [3])
        #expect(Self.ids(displays, .all) == [2, 3])
    }

    @Test func closedLidFallsBackToTheFirstAvailableDisplay() {
        // The menu bar flag can still sit on the closed built-in display while macOS moves it.
        let displays = [
            Self.builtIn(hasMenuBar: true, isAvailable: false),
            Self.external(id: 2),
            Self.external(id: 3),
        ]
        #expect(Self.ids(displays, .builtIn) == [2])
        #expect(Self.ids(displays, .mainDisplay) == [2])
    }

    @Test func noBuiltInDisplayUsesTheMainDisplay() {
        let displays = [Self.external(id: 2), Self.external(id: 3, hasMenuBar: true)]
        #expect(Self.ids(displays, .builtIn) == [3])
    }

    @Test(arguments: IslandSettings.ShowOn.allCases)
    func noAvailableDisplayGetsNoIsland(showOn: IslandSettings.ShowOn) {
        #expect(Self.ids([], showOn).isEmpty)
        #expect(Self.ids([Self.builtIn(isAvailable: false)], showOn).isEmpty)
    }

    // MARK: Style

    @Test func styleIsAttachedByDefault() {
        let placements = DisplayPlacement.placements(
            for: [Self.builtIn(), Self.external()], showOn: .all)
        #expect(placements.map(\.style) == [.attached, .attached])
    }

    @Test func floatingAppliesOnlyToScreensWithoutANotch() {
        let placements = DisplayPlacement.placements(
            for: [Self.builtIn(), Self.external()], showOn: .all, styleWithoutNotch: .floating)
        #expect(placements.map(\.style) == [.attached, .floating])
    }

    @Test func placementAppearanceUsesItsOwnScreen() {
        let placements = DisplayPlacement.placements(
            for: [Self.builtIn(), Self.external()], showOn: .all)
        let notched = placements[0].appearance(system: .light, accent: .amber)
        let plain = placements[1].appearance(system: .light, accent: .amber)
        #expect(notched == IslandAppearance(hasNotch: true, system: .light, accent: .amber))
        #expect(plain == IslandAppearance(hasNotch: false, system: .light, accent: .amber))
        #expect(notched.surfaceHex == "#000000")
        #expect(plain.surfaceHex == "#fafafa")
    }
}
