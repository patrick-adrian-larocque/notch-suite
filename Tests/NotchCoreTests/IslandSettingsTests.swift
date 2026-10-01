import Foundation
import Testing

@testable import NotchCore

@Suite struct IslandSettingsTests {
    // MARK: Defaults

    @Test func defaultsMatchTheDesignCanvas() {
        let settings = IslandSettings()
        #expect(settings.hoverAction == .peek)
        #expect(settings.hoverDelayMilliseconds == 120)
        #expect(settings.leaveDelayMilliseconds == 350)
        #expect(settings.collapseOnLeave == true)
        #expect(settings.collapseDelayMilliseconds == 1200)
        #expect(settings.alertExpand == true)
        #expect(settings.alertCollapseSeconds == 4)
        #expect(settings.motionCurve == .bouncy)
        #expect(settings.speed == 1.0)
        #expect(settings.reduceMotion == false)
        #expect(settings.accent == .amber)
        #expect(settings.showNotchOutline == false)
        #expect(settings.notchWidthPreview == 196)
        #expect(settings.showOn == .builtIn)
        #expect(settings.replaceSystemHUDs == true)
        #expect(settings == IslandSettings.defaults)
    }

    @Test func rangesMatchTheDesignCanvas() {
        #expect(IslandSettings.hoverDelayRange == 0...600)
        #expect(IslandSettings.leaveDelayRange == 0...1500)
        #expect(IslandSettings.collapseDelayRange == 0...3000)
        #expect(IslandSettings.alertCollapseRange == 1...10)
        #expect(IslandSettings.speedRange == 0.5...2.0)
        #expect(IslandSettings.notchWidthPreviewRange == 160...240)
        #expect(IslandSettings.notchWidthPreviewStep == 2)
    }

    @Test func enumCasesMatchTheDesignCanvas() {
        #expect(IslandSettings.HoverAction.allCases == [.off, .peek, .open])
        #expect(IslandSettings.MotionCurve.allCases == [.bouncy, .snappy, .smooth])
        #expect(IslandSettings.Accent.allCases == [.amber, .blue, .green, .pink])
        #expect(IslandSettings.ShowOn.allCases == [.builtIn, .mainDisplay, .all])
    }

    @Test(arguments: [
        (IslandSettings.Accent.amber, "#f59e0b"),
        (.blue, "#60a5fa"),
        (.green, "#4ade80"),
        (.pink, "#f472b6"),
    ])
    func accentHex(accent: IslandSettings.Accent, hex: String) {
        #expect(accent.hex == hex)
    }

    // MARK: Clamping

    /// A writable numeric setting with its range, so each one can be clamped
    /// through both the initializer and a property assignment.
    struct IntSetting: Sendable, CustomTestStringConvertible {
        let name: String
        let range: ClosedRange<Int>
        let keyPath: WritableKeyPath<IslandSettings, Int> & Sendable
        let make: @Sendable (Int) -> IslandSettings

        var testDescription: String { name }
    }

    static let intSettings: [IntSetting] = [
        IntSetting(
            name: "hoverDelayMilliseconds", range: IslandSettings.hoverDelayRange,
            keyPath: \.hoverDelayMilliseconds,
            make: { IslandSettings(hoverDelayMilliseconds: $0) }),
        IntSetting(
            name: "leaveDelayMilliseconds", range: IslandSettings.leaveDelayRange,
            keyPath: \.leaveDelayMilliseconds,
            make: { IslandSettings(leaveDelayMilliseconds: $0) }),
        IntSetting(
            name: "collapseDelayMilliseconds", range: IslandSettings.collapseDelayRange,
            keyPath: \.collapseDelayMilliseconds,
            make: { IslandSettings(collapseDelayMilliseconds: $0) }),
        IntSetting(
            name: "alertCollapseSeconds", range: IslandSettings.alertCollapseRange,
            keyPath: \.alertCollapseSeconds,
            make: { IslandSettings(alertCollapseSeconds: $0) }),
    ]

    @Test(arguments: intSettings)
    func initializerClampsBothEnds(setting: IntSetting) {
        let low = setting.range.lowerBound
        let high = setting.range.upperBound
        #expect(setting.make(low - 1)[keyPath: setting.keyPath] == low)
        #expect(setting.make(.min)[keyPath: setting.keyPath] == low)
        #expect(setting.make(low)[keyPath: setting.keyPath] == low)
        #expect(setting.make(high)[keyPath: setting.keyPath] == high)
        #expect(setting.make(high + 1)[keyPath: setting.keyPath] == high)
        #expect(setting.make(.max)[keyPath: setting.keyPath] == high)
    }

    @Test(arguments: intSettings)
    func assignmentClampsBothEnds(setting: IntSetting) {
        var settings = IslandSettings()
        settings[keyPath: setting.keyPath] = setting.range.lowerBound - 1
        #expect(settings[keyPath: setting.keyPath] == setting.range.lowerBound)
        settings[keyPath: setting.keyPath] = setting.range.upperBound + 1
        #expect(settings[keyPath: setting.keyPath] == setting.range.upperBound)
        settings[keyPath: setting.keyPath] = setting.range.lowerBound
        #expect(settings[keyPath: setting.keyPath] == setting.range.lowerBound)
        settings[keyPath: setting.keyPath] = setting.range.upperBound
        #expect(settings[keyPath: setting.keyPath] == setting.range.upperBound)
    }

    @Test func speedClampsBothEnds() {
        #expect(IslandSettings(speed: 0.49).speed == 0.5)
        #expect(IslandSettings(speed: -.infinity).speed == 0.5)
        #expect(IslandSettings(speed: 0.5).speed == 0.5)
        #expect(IslandSettings(speed: 2.0).speed == 2.0)
        #expect(IslandSettings(speed: 2.01).speed == 2.0)
        #expect(IslandSettings(speed: .infinity).speed == 2.0)

        var settings = IslandSettings()
        settings.speed = 0.1
        #expect(settings.speed == 0.5)
        settings.speed = 5
        #expect(settings.speed == 2.0)
    }

    @Test func speedNaNFallsBackToDefault() {
        #expect(IslandSettings(speed: .nan).speed == 1.0)
        var settings = IslandSettings(speed: 1.5)
        settings.speed = .nan
        #expect(settings.speed == 1.0)
    }

    @Test func notchWidthPreviewClampsBothEnds() {
        #expect(IslandSettings(notchWidthPreview: 159.9).notchWidthPreview == 160)
        #expect(IslandSettings(notchWidthPreview: -.infinity).notchWidthPreview == 160)
        #expect(IslandSettings(notchWidthPreview: 160).notchWidthPreview == 160)
        #expect(IslandSettings(notchWidthPreview: 240).notchWidthPreview == 240)
        #expect(IslandSettings(notchWidthPreview: 240.1).notchWidthPreview == 240)
        #expect(IslandSettings(notchWidthPreview: .infinity).notchWidthPreview == 240)

        var settings = IslandSettings()
        settings.notchWidthPreview = 100
        #expect(settings.notchWidthPreview == 160)
        settings.notchWidthPreview = 500
        #expect(settings.notchWidthPreview == 240)
    }

    @Test func notchWidthPreviewNaNFallsBackToDefault() {
        #expect(IslandSettings(notchWidthPreview: .nan).notchWidthPreview == 196)
        var settings = IslandSettings(notchWidthPreview: 220)
        settings.notchWidthPreview = .nan
        #expect(settings.notchWidthPreview == 196)
    }

    @Test func inRangeValuesAreKept() {
        let settings = IslandSettings(
            hoverDelayMilliseconds: 300, leaveDelayMilliseconds: 700,
            collapseDelayMilliseconds: 2000, alertCollapseSeconds: 7, speed: 1.25,
            notchWidthPreview: 210)
        #expect(settings.hoverDelayMilliseconds == 300)
        #expect(settings.leaveDelayMilliseconds == 700)
        #expect(settings.collapseDelayMilliseconds == 2000)
        #expect(settings.notchWidthPreview == 210)
        #expect(settings.alertCollapseSeconds == 7)
        #expect(settings.speed == 1.25)
    }

    // MARK: Reset

    @Test func resetRestoresDefaults() {
        var settings = Self.everythingChanged
        #expect(settings != .defaults)
        settings.reset()
        #expect(settings == .defaults)
    }

    // MARK: Codable

    /// Every setting differs from its default.
    static let everythingChanged = IslandSettings(
        hoverAction: .open,
        hoverDelayMilliseconds: 40,
        leaveDelayMilliseconds: 900,
        collapseOnLeave: false,
        collapseDelayMilliseconds: 2500,
        alertExpand: false,
        alertCollapseSeconds: 9,
        motionCurve: .smooth,
        speed: 1.75,
        reduceMotion: true,
        accent: .pink,
        showNotchOutline: true,
        notchWidthPreview: 224,
        showOn: .all,
        replaceSystemHUDs: false
    )

    @Test(arguments: [IslandSettings.defaults, everythingChanged])
    func codableRoundTrip(settings: IslandSettings) throws {
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(IslandSettings.self, from: data) == settings)
    }

    @Test func emptyObjectDecodesToDefaults() throws {
        let decoded = try decode("{}")
        #expect(decoded == .defaults)
    }

    @Test func eachMissingKeyDecodesToItsDefault() throws {
        let full =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(Self.everythingChanged)) as? [String: Any]
        let keys = try #require(full).keys
        #expect(keys.count == IslandSettings.CodingKeys.allCases.count)

        for key in keys {
            var partial = try #require(full)
            partial.removeValue(forKey: key)
            let data = try JSONSerialization.data(withJSONObject: partial)
            let decoded = try JSONDecoder().decode(IslandSettings.self, from: data)

            var expected = Self.everythingChanged
            let defaults = IslandSettings.defaults
            switch IslandSettings.CodingKeys(rawValue: key) {
            case .hoverAction: expected.hoverAction = defaults.hoverAction
            case .hoverDelayMilliseconds:
                expected.hoverDelayMilliseconds = defaults.hoverDelayMilliseconds
            case .leaveDelayMilliseconds:
                expected.leaveDelayMilliseconds = defaults.leaveDelayMilliseconds
            case .collapseOnLeave: expected.collapseOnLeave = defaults.collapseOnLeave
            case .collapseDelayMilliseconds:
                expected.collapseDelayMilliseconds = defaults.collapseDelayMilliseconds
            case .alertExpand: expected.alertExpand = defaults.alertExpand
            case .alertCollapseSeconds:
                expected.alertCollapseSeconds = defaults.alertCollapseSeconds
            case .motionCurve: expected.motionCurve = defaults.motionCurve
            case .speed: expected.speed = defaults.speed
            case .reduceMotion: expected.reduceMotion = defaults.reduceMotion
            case .accent: expected.accent = defaults.accent
            case .showNotchOutline: expected.showNotchOutline = defaults.showNotchOutline
            case .notchWidthPreview: expected.notchWidthPreview = defaults.notchWidthPreview
            case .showOn: expected.showOn = defaults.showOn
            case .replaceSystemHUDs: expected.replaceSystemHUDs = defaults.replaceSystemHUDs
            case nil: Issue.record("Unexpected encoded key \(key)")
            }
            #expect(decoded == expected, "missing \(key)")
        }
    }

    @Test func outOfRangeValuesAreClampedOnDecode() throws {
        let decoded = try decode(
            """
            {"hoverDelayMilliseconds": -5, "leaveDelayMilliseconds": 99999,
             "collapseDelayMilliseconds": 3001, "alertCollapseSeconds": 0, "speed": 3,
             "notchWidthPreview": 120}
            """)
        #expect(decoded.hoverDelayMilliseconds == 0)
        #expect(decoded.leaveDelayMilliseconds == 1500)
        #expect(decoded.collapseDelayMilliseconds == 3000)
        #expect(decoded.alertCollapseSeconds == 1)
        #expect(decoded.speed == 2.0)
        #expect(decoded.notchWidthPreview == 160)
    }

    @Test func unknownOrMistypedValuesFallBackToDefaults() throws {
        let decoded = try decode(
            """
            {"accent": "purple", "motionCurve": 3, "hoverDelayMilliseconds": "fast",
             "showOn": "projector", "replaceSystemHUDs": "yes", "reduceMotion": true}
            """)
        #expect(decoded.accent == .amber)
        #expect(decoded.motionCurve == .bouncy)
        #expect(decoded.hoverDelayMilliseconds == 120)
        #expect(decoded.showOn == .builtIn)
        #expect(decoded.replaceSystemHUDs == true)
        #expect(decoded.reduceMotion == true)
    }

    @Test func nonObjectInputFailsToDecode() {
        #expect(throws: DecodingError.self) { try decode("[]") }
    }

    private func decode(_ json: String) throws -> IslandSettings {
        try JSONDecoder().decode(IslandSettings.self, from: Data(json.utf8))
    }
}
