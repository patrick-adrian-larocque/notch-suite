import Testing

@testable import NotchCore

@Suite struct RGBColorTests {
    @Test func parsesHexWithOrWithoutHash() {
        let amber = RGBColor(red: 245.0 / 255, green: 158.0 / 255, blue: 11.0 / 255)
        #expect(RGBColor(hex: "#f59e0b") == amber)
        #expect(RGBColor(hex: "f59e0b") == amber)
        #expect(RGBColor(hex: "#F59E0B") == amber)
    }

    @Test func parsesTheExtremes() {
        #expect(RGBColor(hex: "#000000") == RGBColor(red: 0, green: 0, blue: 0))
        #expect(RGBColor(hex: "#ffffff") == RGBColor(red: 1, green: 1, blue: 1))
        #expect(RGBColor(hex: "#ff0000") == RGBColor(red: 1, green: 0, blue: 0))
        #expect(RGBColor(hex: "#00ff00") == RGBColor(red: 0, green: 1, blue: 0))
        #expect(RGBColor(hex: "#0000ff") == RGBColor(red: 0, green: 0, blue: 1))
    }

    @Test(arguments: [
        "", "#", "#fff", "#ff00ff00", "#gggggg", "##ff0000", "+fffff", "-00001", " ffffff",
    ])
    func rejectsAnythingButSixHexDigits(hex: String) {
        #expect(RGBColor(hex: hex) == nil)
    }

    @Test func parsesEveryColorNotchCoreProduces() {
        var hexes = [
            IslandAppearance.darkSurfaceHex, IslandAppearance.lightSurfaceHex,
            IslandAppearance.lightBorderHex,
        ]
        for accent in IslandSettings.Accent.allCases {
            hexes += [accent.hex, accent.darkerHex]
        }
        for hex in hexes {
            #expect(RGBColor(hex: hex) != nil, "\(hex)")
        }
    }
}
