import Foundation
import Testing

@testable import NotchCore

@Suite struct IslandAppearanceTests {
    // MARK: Style

    @Test(arguments: IslandStyle.allCases)
    func notchedScreensAreAlwaysAttached(option: IslandStyle) {
        #expect(IslandStyle.resolved(hasNotch: true, styleWithoutNotch: option) == .attached)
    }

    @Test(arguments: IslandStyle.allCases)
    func screensWithoutANotchUseTheOption(option: IslandStyle) {
        #expect(IslandStyle.resolved(hasNotch: false, styleWithoutNotch: option) == option)
    }

    @Test func attachedIsFlushWithTheTopEdge() {
        #expect(IslandStyle.attached.topOffset(menuBarHeight: 24) == 0)
        #expect(!IslandStyle.attached.isFullyRounded)
        #expect(!IslandStyle.attached.canShowCenterText)
    }

    @Test func floatingIsARoundedPillBelowTheMenuBar() {
        #expect(IslandStyle.floating.topOffset(menuBarHeight: 24) == 32)
        #expect(IslandStyle.floating.topOffset(menuBarHeight: -5) == 8)
        #expect(IslandStyle.floating.isFullyRounded)
        #expect(IslandStyle.floating.canShowCenterText)
    }

    // MARK: Appearance

    @Test(arguments: SystemAppearance.allCases, IslandSettings.Accent.allCases)
    func notchedScreenIsAlwaysBlack(system: SystemAppearance, accent: IslandSettings.Accent) {
        let appearance = IslandAppearance(hasNotch: true, system: system, accent: accent)
        #expect(
            appearance
                == IslandAppearance(
                    surfaceHex: "#000000", borderHex: nil, accentHex: accent.hex,
                    contentAppearance: .dark))
    }

    @Test(arguments: IslandSettings.Accent.allCases)
    func noNotchInDarkModeIsBlack(accent: IslandSettings.Accent) {
        let appearance = IslandAppearance(hasNotch: false, system: .dark, accent: accent)
        #expect(
            appearance
                == IslandAppearance(
                    surfaceHex: "#000000", borderHex: nil, accentHex: accent.hex,
                    contentAppearance: .dark))
    }

    @Test(arguments: IslandSettings.Accent.allCases)
    func noNotchInLightModeIsLightWithADarkerAccent(accent: IslandSettings.Accent) {
        let appearance = IslandAppearance(hasNotch: false, system: .light, accent: accent)
        #expect(
            appearance
                == IslandAppearance(
                    surfaceHex: "#fafafa", borderHex: "#d4d4d8", accentHex: accent.darkerHex,
                    contentAppearance: .light))
    }

    // MARK: Accent contrast

    @Test func darkerAccentValues() {
        #expect(IslandSettings.Accent.amber.darkerHex == "#b45309")
        #expect(IslandSettings.Accent.blue.darkerHex == "#1d4ed8")
        #expect(IslandSettings.Accent.green.darkerHex == "#15803d")
        #expect(IslandSettings.Accent.pink.darkerHex == "#be185d")
    }

    @Test(arguments: IslandSettings.Accent.allCases)
    func darkerAccentIsDarkerAndReadableOnTheLightSurface(accent: IslandSettings.Accent) throws {
        let darker = try #require(Self.luminance(accent.darkerHex))
        let original = try #require(Self.luminance(accent.hex))
        let surface = try #require(Self.luminance(IslandAppearance.lightSurfaceHex))
        #expect(darker < original)
        // WCAG AA for normal text.
        #expect(Self.contrast(darker, surface) >= 4.5)
    }

    // MARK: Helpers

    /// WCAG relative luminance of a `#rrggbb` color, or `nil` if it doesn't parse.
    private static func luminance(_ hex: String) -> Double? {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16)
        else { return nil }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xff) / 255
            return c <= 0.039_28 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    private static func contrast(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
