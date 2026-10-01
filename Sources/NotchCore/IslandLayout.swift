/// What the island is showing.
public enum IslandMode: String, Sendable, Hashable, CaseIterable {
    case idle
    case nowPlaying
    case timer
    case message
    case charging
    case shelf
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
}

/// Maps a mode and level to the island's size.
///
/// Peek and open sizes are fixed. Compact sizes hug the notch, so their width is the
/// notch width plus a per-mode extra. With the design's 196 pt notch this reproduces
/// the canvas sizes exactly; on a Mac with a different notch, pass its width.
public struct IslandLayout: Sendable, Hashable {
    /// The notch width the design canvas was drawn against, in points.
    public static let designNotchWidth: Double = 196

    /// The layout at the design's notch width.
    public static let design = IslandLayout()

    /// The width of the physical notch, in points.
    public var notchWidth: Double

    public init(notchWidth: Double = IslandLayout.designNotchWidth) {
        self.notchWidth = notchWidth
    }

    public func size(for mode: IslandMode, at level: IslandLevel) -> IslandSize {
        switch level {
        case .compact:
            let height: Double = mode == .idle ? 32 : 36
            let cornerRadius: Double = mode == .idle ? 10 : 12
            return IslandSize(
                width: notchWidth + Self.compactExtraWidth(for: mode),
                height: height,
                cornerRadius: cornerRadius)
        case .peek:
            return Self.peekSize(for: mode)
        case .open:
            return Self.openSize(for: mode)
        }
    }

    /// How much wider than the notch the compact island is, in points.
    static func compactExtraWidth(for mode: IslandMode) -> Double {
        switch mode {
        case .idle: 0
        case .nowPlaying: 152
        case .timer: 124
        case .message: 104
        case .charging: 144
        case .shelf: 104
        }
    }

    private static func peekSize(for mode: IslandMode) -> IslandSize {
        switch mode {
        case .idle: IslandSize(width: 232, height: 36, cornerRadius: 12)
        case .nowPlaying: IslandSize(width: 440, height: 40, cornerRadius: 14)
        case .timer: IslandSize(width: 400, height: 40, cornerRadius: 14)
        case .message: IslandSize(width: 440, height: 40, cornerRadius: 14)
        case .charging: IslandSize(width: 400, height: 40, cornerRadius: 14)
        case .shelf: IslandSize(width: 380, height: 40, cornerRadius: 14)
        }
    }

    private static func openSize(for mode: IslandMode) -> IslandSize {
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
