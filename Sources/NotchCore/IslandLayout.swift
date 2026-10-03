/// What the island is showing.
public enum IslandMode: String, Sendable, Hashable, CaseIterable {
    case idle
    case nowPlaying
    case timer
    case message
    case charging
    case shelf

    /// How far the compact island extends past each side of the notch, in points.
    public var compactWing: Double {
        switch self {
        case .idle: 0
        case .nowPlaying: 76
        case .timer: 62
        case .message: 52
        case .charging: 72
        case .shelf: 52
        }
    }

    /// How far the peek island extends past each side of the notch, in points.
    public var peekWing: Double {
        switch self {
        case .idle: 18
        case .nowPlaying: 122
        case .timer: 102
        case .message: 122
        case .charging: 102
        case .shelf: 92
        }
    }
}

/// How far the island is expanded, from smallest to largest.
public enum IslandLevel: String, Sendable, Hashable, CaseIterable, Comparable {
    /// Hugs the notch.
    case compact
    /// Slightly larger, for a glance (hover or a fresh event).
    case peek
    /// Fully expanded.
    case open

    public static func < (lhs: IslandLevel, rhs: IslandLevel) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .compact: 0
        case .peek: 1
        case .open: 2
        }
    }
}

/// The island's outer size and corner radius, in points.
public struct IslandSize: Sendable, Hashable {
    public var width: Double
    public var height: Double
    public var cornerRadius: Double

    public init(width: Double, height: Double, cornerRadius: Double) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    /// The smallest width and height the pointer can hit, in points, from Apple's
    /// Human Interface Guidelines.
    public static let minimumHitTarget: Double = 44

    /// The width of the area that responds to the pointer: ``width``, but at least
    /// ``minimumHitTarget``.
    public var hitTargetWidth: Double { max(width, Self.minimumHitTarget) }

    /// The height of the area that responds to the pointer: ``height``, but at least
    /// ``minimumHitTarget``.
    ///
    /// The compact island is shorter than this, so its hit area reaches a little below
    /// the island. That keeps the target at the minimum without drawing the island any
    /// taller than the notch.
    public var hitTargetHeight: Double { max(height, Self.minimumHitTarget) }
}

/// Maps a mode and level to the island's size.
///
/// Compact and peek sizes wrap the notch: their width is `N + 2W`, where `N` is the
/// notch width and `W` is the mode's ``IslandMode/compactWing`` or
/// ``IslandMode/peekWing``. Open sizes are fixed, except that open is never narrower
/// than peek: on a notch wide enough to push peek past the design's open width, open
/// takes the peek width. No size is shorter than the notch, so the island covers the
/// camera housing without a gap below it. With the design's 196 × 32 pt notch this
/// reproduces the canvas sizes exactly; on a Mac with a different notch, pass its size.
public struct IslandLayout: Sendable, Hashable {
    /// The notch width the design canvas was drawn against, in points.
    public static let designNotchWidth: Double = 196

    /// The notch height the design canvas was drawn against, in points.
    public static let designNotchHeight: Double = 32

    /// The layout at the design's notch size.
    public static let design = IslandLayout()

    /// The width of the physical notch, in points.
    public var notchWidth: Double

    /// The height of the physical notch, in points. Every island is at least this tall.
    public var notchHeight: Double

    public init(
        notchWidth: Double = IslandLayout.designNotchWidth,
        notchHeight: Double = IslandLayout.designNotchHeight
    ) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
    }

    /// The layout around the notch `geometry` describes, real or virtual.
    public init(geometry: NotchGeometry) {
        self.init(notchWidth: geometry.notchWidth, notchHeight: geometry.notchHeight)
    }

    /// The island's size for `mode` at `level`.
    public func size(for mode: IslandMode, at level: IslandLevel) -> IslandSize {
        var size = designSize(for: mode, at: level)
        size.height = max(size.height, notchHeight)
        return size
    }

    /// The width of the widest island over every mode and level.
    ///
    /// The window that holds the island needs at least this much room.
    public var maximumWidth: Double {
        allSizes.map(\.width).max() ?? 0
    }

    /// The height of the tallest island over every mode and level.
    public var maximumHeight: Double {
        allSizes.map(\.height).max() ?? 0
    }

    private var allSizes: [IslandSize] {
        IslandMode.allCases.flatMap { mode in
            IslandLevel.allCases.map { size(for: mode, at: $0) }
        }
    }

    /// The canvas size, before the notch height is applied.
    private func designSize(for mode: IslandMode, at level: IslandLevel) -> IslandSize {
        switch level {
        case .compact:
            IslandSize(
                width: notchWidth + 2 * mode.compactWing,
                height: mode == .idle ? 32 : 36,
                cornerRadius: mode == .idle ? 10 : 12)
        case .peek:
            IslandSize(
                width: notchWidth + 2 * mode.peekWing,
                height: mode == .idle ? 36 : 40,
                cornerRadius: mode == .idle ? 12 : 14)
        case .open:
            openSize(for: mode)
        }
    }

    /// The design's open size, widened to the peek width when a wide notch makes peek
    /// wider, so opening never narrows the island.
    private func openSize(for mode: IslandMode) -> IslandSize {
        var size = Self.designOpenSize(for: mode)
        size.width = max(size.width, notchWidth + 2 * mode.peekWing)
        return size
    }

    private static func designOpenSize(for mode: IslandMode) -> IslandSize {
        switch mode {
        case .idle: IslandSize(width: 440, height: 156, cornerRadius: 30)
        case .nowPlaying: IslandSize(width: 460, height: 206, cornerRadius: 32)
        case .timer: IslandSize(width: 420, height: 168, cornerRadius: 30)
        case .message: IslandSize(width: 440, height: 104, cornerRadius: 28)
        case .charging: IslandSize(width: 400, height: 120, cornerRadius: 28)
        case .shelf: IslandSize(width: 460, height: 200, cornerRadius: 30)
        }
    }
}
