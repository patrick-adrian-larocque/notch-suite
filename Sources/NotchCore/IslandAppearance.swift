/// How the island attaches to its screen.
///
/// Notched screens always use ``attached``. Screens without a notch default to
/// ``attached`` too, with ``floating`` as an option. The option isn't an
/// ``IslandSettings`` value yet, so callers pass it in.
public enum IslandStyle: String, Sendable, Hashable, CaseIterable, Codable {
    /// Flush with the top edge, around the real notch or a virtual one.
    case attached
    /// A pill below the menu bar, so it never covers menu items.
    case floating

    /// The gap between the bottom of the menu bar and a floating pill, in points, matching
    /// the design canvas.
    public static let floatingMenuBarGap: Double = 8

    /// The style a screen uses: ``attached`` on a notched screen, otherwise
    /// `styleWithoutNotch`.
    public static func resolved(hasNotch: Bool, styleWithoutNotch: IslandStyle) -> IslandStyle {
        hasNotch ? .attached : styleWithoutNotch
    }

    /// `true` when all four corners are fully rounded, making a pill. An attached island
    /// rounds only its bottom corners.
    public var isFullyRounded: Bool {
        self == .floating
    }

    /// `true` when the island's centre can hold text. An attached island keeps its centre
    /// clear, because on a notched screen that is where the camera cutout sits.
    public var canShowCenterText: Bool {
        self == .floating
    }

    /// The distance from the screen's top edge to the island's top edge, in points.
    public func topOffset(menuBarHeight: Double) -> Double {
        switch self {
        case .attached: 0
        case .floating: max(0, menuBarHeight) + Self.floatingMenuBarGap
        }
    }
}

/// The system's light or dark appearance.
public enum SystemAppearance: String, Sendable, Hashable, CaseIterable, Codable {
    case light
    case dark
}

extension IslandSettings.Accent {
    /// A darker shade of the accent, as `#rrggbb`, for contrast on a light island.
    ///
    /// Each is the Tailwind 700 shade of the accent's hue: amber 700, blue 700, green 700
    /// and pink 700.
    public var darkerHex: String {
        switch self {
        case .amber: "#b45309"
        case .blue: "#1d4ed8"
        case .green: "#15803d"
        case .pink: "#be185d"
        }
    }
}

/// The colors an island is drawn with, as `#rrggbb` strings.
///
/// The UI layer turns these into platform colors.
public struct IslandAppearance: Sendable, Hashable {
    /// The black surface used on notched screens and in dark mode.
    public static let darkSurfaceHex = "#000000"
    /// The surface used on screens without a notch in light mode.
    public static let lightSurfaceHex = "#fafafa"
    /// The border used on screens without a notch in light mode.
    public static let lightBorderHex = "#d4d4d8"

    /// The island's fill.
    public var surfaceHex: String
    /// The island's outline, or `nil` for none.
    public var borderHex: String?
    /// The accent color to draw on this surface.
    public var accentHex: String
    /// Whether content on the island is drawn for a dark or a light surface.
    public var contentAppearance: SystemAppearance

    public init(
        surfaceHex: String,
        borderHex: String?,
        accentHex: String,
        contentAppearance: SystemAppearance
    ) {
        self.surfaceHex = surfaceHex
        self.borderHex = borderHex
        self.accentHex = accentHex
        self.contentAppearance = contentAppearance
    }

    /// The appearance of an island.
    ///
    /// On a notched screen the island is always black, in light and dark mode alike,
    /// because it has to match the camera cutout. On a screen without a notch it follows
    /// the system appearance: black in dark mode, and in light mode a light surface with a
    /// border and ``IslandSettings/Accent/darkerHex`` for contrast.
    public init(hasNotch: Bool, system: SystemAppearance, accent: IslandSettings.Accent) {
        if hasNotch || system == .dark {
            self.init(
                surfaceHex: Self.darkSurfaceHex,
                borderHex: nil,
                accentHex: accent.hex,
                contentAppearance: .dark)
        } else {
            self.init(
                surfaceHex: Self.lightSurfaceHex,
                borderHex: Self.lightBorderHex,
                accentHex: accent.darkerHex,
                contentAppearance: .light)
        }
    }
}
