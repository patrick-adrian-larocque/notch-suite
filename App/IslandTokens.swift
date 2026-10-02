import NotchCore
import SwiftUI

extension Color {
    /// The color `hex` names, as `#rrggbb`.
    ///
    /// Only for hex strings written in this app or produced by NotchCore. A malformed
    /// one draws magenta so it stands out instead of passing for black.
    init(hex: String) {
        let rgb = RGBColor(hex: hex) ?? RGBColor(red: 1, green: 0, blue: 1)
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// The zinc greys the design canvas uses, from Tailwind's zinc scale.
enum Zinc {
    static let z100 = Color(hex: "#f4f4f5")
    static let z300 = Color(hex: "#d4d4d8")
    static let z400 = Color(hex: "#a1a1aa")
    static let z500 = Color(hex: "#71717a")
    static let z600 = Color(hex: "#52525b")
    static let z700 = Color(hex: "#3f3f46")
    static let z800 = Color(hex: "#27272a")
    static let z900 = Color(hex: "#18181b")
}

/// The colors one island is drawn with.
///
/// Built from `IslandAppearance`, which decides between the black island (every notched
/// screen, and dark mode elsewhere) and the light one (light mode without a notch).
struct IslandPalette {
    /// The island's fill.
    var surface: Color
    /// The island's outline, or `nil` for none.
    var border: Color?
    /// The accent from settings, shaded for this surface.
    var accent: Color
    /// Titles and the clock.
    var primary: Color
    /// Secondary text, such as the date.
    var secondary: Color
    /// Icon-only buttons, such as collapse.
    var icon: Color
    /// The fill behind a pill button.
    var controlFill: Color
    /// The fill behind a pill or icon button under the pointer or pressed.
    var controlFillActive: Color
    /// Whether the canvas's drop shadow under an open island shows on this surface.
    var castsShadow: Bool

    init(appearance: IslandAppearance) {
        surface = Color(hex: appearance.surfaceHex)
        border = appearance.borderHex.map(Color.init(hex:))
        accent = Color(hex: appearance.accentHex)
        switch appearance.contentAppearance {
        case .dark:
            primary = .white
            secondary = Zinc.z400
            icon = Zinc.z300
            controlFill = .white.opacity(0.1)
            controlFillActive = .white.opacity(0.2)
            castsShadow = true
        case .light:
            primary = Zinc.z900
            secondary = Zinc.z500
            icon = Zinc.z600
            controlFill = .black.opacity(0.06)
            controlFillActive = .black.opacity(0.12)
            castsShadow = false
        }
    }
}

/// The island's type styles.
///
/// The canvas is set in Geist and Geist Mono. The app uses the system's SF Pro and SF
/// Mono instead: they are already on every Mac, match the menu bar beside the island,
/// and need no bundled font files or licence entries.
enum IslandFont {
    /// Pill button labels: 13 pt medium.
    static let control = Font.system(size: 13, weight: .medium)
    /// Small secondary text, such as the date: 12 pt.
    static let caption = Font.system(size: 12)
    /// The clock on the open idle island: 24 pt medium SF Mono.
    static let clock = Font.system(size: 24, weight: .medium, design: .monospaced)
}
