/// The raw numbers the app reads off a screen, in points.
///
/// On macOS these come from `NSScreen`: `frame.width`, `safeAreaInsets.top`, and the
/// widths of `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`. The auxiliary areas are
/// the strips of menu bar beside the notch, and AppKit reports them as `nil` on a screen
/// without one, so their widths are optional here too.
public struct ScreenMetrics: Sendable, Equatable {
    public var screenWidth: Double
    public var topInset: Double
    public var auxiliaryTopLeftWidth: Double?
    public var auxiliaryTopRightWidth: Double?

    public init(
        screenWidth: Double,
        topInset: Double,
        auxiliaryTopLeftWidth: Double? = nil,
        auxiliaryTopRightWidth: Double? = nil
    ) {
        self.screenWidth = screenWidth
        self.topInset = topInset
        self.auxiliaryTopLeftWidth = auxiliaryTopLeftWidth
        self.auxiliaryTopRightWidth = auxiliaryTopRightWidth
    }
}

/// The notch the island draws around when a screen has no real one.
public struct VirtualNotch: Sendable, Equatable {
    /// The notch size the design canvas is drawn against.
    public static let `default` = VirtualNotch(width: 196, height: 32)

    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Where the notch is on a screen, and how much room there is beside it.
///
/// Built from plain numbers so it can be tested anywhere; the AppKit read lives
/// behind ``NotchGeometryProvider``.
public struct NotchGeometry: Sendable, Equatable {
    /// Width of the notch, real or virtual.
    public var notchWidth: Double
    /// Height of the notch, real or virtual.
    public var notchHeight: Double
    /// Room between the screen's left edge and the notch.
    public var leftAreaWidth: Double
    /// Room between the notch and the screen's right edge.
    public var rightAreaWidth: Double
    /// `true` when the notch was measured from the screen, `false` when it is virtual.
    public var isPhysical: Bool

    public init(
        notchWidth: Double,
        notchHeight: Double,
        leftAreaWidth: Double,
        rightAreaWidth: Double,
        isPhysical: Bool
    ) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.leftAreaWidth = leftAreaWidth
        self.rightAreaWidth = rightAreaWidth
        self.isPhysical = isPhysical
    }

    /// Derives the notch from a screen's metrics.
    ///
    /// The notch is measured as the gap between the two auxiliary areas, and its height
    /// is the top inset. That needs a positive top inset, two positive auxiliary widths,
    /// and a gap that is positive. If any of that is missing (a screen without a notch,
    /// or AppKit reporting only one side or a zero-width side), the geometry falls back
    /// to `virtualNotch`, centred on the screen. A fallback keeps a positive top inset as
    /// its height, because that is still the real menu bar height on that screen.
    ///
    /// Negative and non-finite inputs are treated as absent, and the virtual notch is
    /// clamped to the screen width.
    public init(metrics: ScreenMetrics, virtualNotch: VirtualNotch = .default) {
        let screenWidth = Self.usable(metrics.screenWidth) ?? 0
        let topInset = Self.usable(metrics.topInset) ?? 0

        if topInset > 0,
            let left = Self.usable(metrics.auxiliaryTopLeftWidth), left > 0,
            let right = Self.usable(metrics.auxiliaryTopRightWidth), right > 0
        {
            let gap = screenWidth - left - right
            if gap > 0 {
                self.init(
                    notchWidth: gap,
                    notchHeight: topInset,
                    leftAreaWidth: left,
                    rightAreaWidth: right,
                    isPhysical: true)
                return
            }
        }

        let width = min(Self.usable(virtualNotch.width) ?? 0, screenWidth)
        let height = topInset > 0 ? topInset : (Self.usable(virtualNotch.height) ?? 0)
        let side = (screenWidth - width) / 2
        self.init(
            notchWidth: width,
            notchHeight: height,
            leftAreaWidth: side,
            rightAreaWidth: side,
            isPhysical: false)
    }

    /// How far an island of `islandWidth` reaches past each side of the notch.
    ///
    /// Zero when the island is no wider than the notch.
    public func wingWidth(forIslandWidth islandWidth: Double) -> Double {
        max(0, (islandWidth - notchWidth) / 2)
    }

    /// The island width that gives wings of `wingWidth` on each side of the notch.
    public func islandWidth(wingWidth: Double) -> Double {
        notchWidth + 2 * max(0, wingWidth)
    }

    /// The widest wing that fits on both sides of the notch without leaving the screen.
    public var maximumWingWidth: Double {
        min(leftAreaWidth, rightAreaWidth)
    }

    /// The notch's centre line, measured from the screen's left edge.
    public var notchMidX: Double {
        leftAreaWidth + notchWidth / 2
    }

    /// The left edge of an island of `islandWidth` centred on the notch, measured from the
    /// screen's left edge. Negative when the island is wider than the room to the notch's left.
    public func islandMinX(forIslandWidth islandWidth: Double) -> Double {
        notchMidX - islandWidth / 2
    }

    private static func usable(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }
}

/// Reads the current screen's notch metrics.
///
/// Implemented in the app target on top of `NSScreen`, so that `NotchCore` stays free of
/// AppKit. It is main-actor isolated because `NSScreen` is read on the main thread.
@MainActor
public protocol NotchGeometryProvider {
    /// Metrics for the screen the island is shown on, or `nil` when there is no screen.
    func screenMetrics() -> ScreenMetrics?
}

extension NotchGeometryProvider {
    /// The geometry of the current screen, falling back to `virtualNotch` where needed.
    public func geometry(virtualNotch: VirtualNotch = .default) -> NotchGeometry? {
        screenMetrics().map { NotchGeometry(metrics: $0, virtualNotch: virtualNotch) }
    }
}
