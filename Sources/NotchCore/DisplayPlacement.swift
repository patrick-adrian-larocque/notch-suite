/// One screen the island could appear on, as the app target reads it.
///
/// On macOS the app builds this from `NSScreen`: `id` is the `CGDirectDisplayID`,
/// `isBuiltIn` comes from `CGDisplayIsBuiltin`, and `hasMenuBar` marks the screen that
/// holds the menu bar (the first entry of `NSScreen.screens`).
public struct DisplayInfo: Sendable, Equatable, Identifiable {
    /// A display identifier. On macOS this is the `CGDirectDisplayID`.
    public typealias ID = UInt32

    public var id: ID
    /// `true` for the Mac's own display, `false` for an external one.
    public var isBuiltIn: Bool
    /// `true` for the screen that holds the menu bar.
    public var hasMenuBar: Bool
    /// The screen's metrics, which also say whether it has a notch.
    public var metrics: ScreenMetrics
    /// `false` when the screen can't show anything, for example a built-in display whose
    /// lid is closed while an external display is attached.
    public var isAvailable: Bool

    public init(
        id: ID,
        isBuiltIn: Bool,
        hasMenuBar: Bool,
        metrics: ScreenMetrics,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.isBuiltIn = isBuiltIn
        self.hasMenuBar = hasMenuBar
        self.metrics = metrics
        self.isAvailable = isAvailable
    }

    /// Whether the screen has a physical notch, as measured by ``NotchGeometry``.
    public var hasNotch: Bool {
        NotchGeometry(metrics: metrics).isPhysical
    }
}

/// Where one island goes and how it is drawn there.
public struct IslandPlacement: Sendable, Equatable {
    /// The screen that shows this island.
    public var display: DisplayInfo
    /// The notch on that screen, real or virtual. Each island is sized to its own screen.
    public var geometry: NotchGeometry
    /// The island's style on that screen.
    public var style: IslandStyle

    public init(display: DisplayInfo, geometry: NotchGeometry, style: IslandStyle) {
        self.display = display
        self.geometry = geometry
        self.style = style
    }

    /// The island's colors on this screen under the given system appearance and accent.
    public func appearance(
        system: SystemAppearance, accent: IslandSettings.Accent
    ) -> IslandAppearance {
        IslandAppearance(hasNotch: geometry.isPhysical, system: system, accent: accent)
    }
}

/// Decides which screens show the island.
public enum DisplayPlacement {
    /// The screens that get an island under `showOn`, in the order they were given.
    ///
    /// Unavailable screens never get one. Then:
    /// - `.builtIn` uses the built-in display. When it is missing or its lid is closed, the
    ///   island moves to the next display: the one with the menu bar, else the first
    ///   available one.
    /// - `.mainDisplay` uses the screen with the menu bar, else the first available one.
    /// - `.all` uses every available screen.
    ///
    /// Returns an empty array when no screen is available.
    public static func displays(
        for displays: [DisplayInfo], showOn: IslandSettings.ShowOn
    ) -> [DisplayInfo] {
        let available = displays.filter(\.isAvailable)
        switch showOn {
        case .builtIn:
            if let builtIn = available.first(where: \.isBuiltIn) {
                return [builtIn]
            }
            return mainDisplay(in: available).map { [$0] } ?? []
        case .mainDisplay:
            return mainDisplay(in: available).map { [$0] } ?? []
        case .all:
            return available
        }
    }

    /// The islands to show under `showOn`, each with its own geometry and style.
    ///
    /// - Parameters:
    ///   - displays: Every attached screen.
    ///   - showOn: The user's display setting.
    ///   - styleWithoutNotch: The style for screens without a notch. Notched screens are
    ///     always ``IslandStyle/attached``.
    ///   - virtualNotch: The notch drawn on screens without a real one.
    public static func placements(
        for displays: [DisplayInfo],
        showOn: IslandSettings.ShowOn,
        styleWithoutNotch: IslandStyle = .attached,
        virtualNotch: VirtualNotch = .default
    ) -> [IslandPlacement] {
        Self.displays(for: displays, showOn: showOn).map { display in
            let geometry = NotchGeometry(metrics: display.metrics, virtualNotch: virtualNotch)
            return IslandPlacement(
                display: display,
                geometry: geometry,
                style: IslandStyle.resolved(
                    hasNotch: geometry.isPhysical, styleWithoutNotch: styleWithoutNotch))
        }
    }

    private static func mainDisplay(in available: [DisplayInfo]) -> DisplayInfo? {
        available.first(where: \.hasMenuBar) ?? available.first
    }
}
