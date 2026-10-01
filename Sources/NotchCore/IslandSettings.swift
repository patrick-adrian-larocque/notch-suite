/// The island's user settings: hover and collapse timing, motion, and appearance.
///
/// Every numeric setting has a range, published as a static constant so the
/// settings panel can bound its sliders with the same values. A value outside
/// its range is clamped, whether it comes from the initializer, a property
/// assignment, or decoding.
public struct IslandSettings: Sendable, Equatable {
    /// What hovering over the compact island does.
    public enum HoverAction: String, Sendable, Hashable, CaseIterable, Codable {
        /// Hovering does nothing; only a click opens the island.
        case off
        /// Hovering grows the island to its peek level.
        case peek
        /// Hovering opens the island fully.
        case open
    }

    /// The animation curve used when the island changes size.
    public enum MotionCurve: String, Sendable, Hashable, CaseIterable, Codable {
        case bouncy
        case snappy
        case smooth
    }

    /// The accent color, as a named choice rather than a platform color.
    ///
    /// The UI layer turns `hex` into a color.
    public enum Accent: String, Sendable, Hashable, CaseIterable, Codable {
        case amber
        case blue
        case green
        case pink

        /// The color as `#rrggbb`, matching the design canvas.
        public var hex: String {
            switch self {
            case .amber: "#f59e0b"
            case .blue: "#60a5fa"
            case .green: "#4ade80"
            case .pink: "#f472b6"
            }
        }
    }

    // MARK: Ranges

    /// Allowed hover delay, in milliseconds.
    public static let hoverDelayRange: ClosedRange<Int> = 0...600
    /// Allowed leave delay, in milliseconds.
    public static let leaveDelayRange: ClosedRange<Int> = 0...1500
    /// Allowed collapse delay, in milliseconds.
    public static let collapseDelayRange: ClosedRange<Int> = 0...3000
    /// Allowed alert collapse delay, in seconds.
    public static let alertCollapseRange: ClosedRange<Int> = 1...10
    /// Allowed animation speed multiplier.
    public static let speedRange: ClosedRange<Double> = 0.5...2.0

    /// The settings a fresh install starts with.
    public static let defaults = IslandSettings()

    // MARK: Hover

    /// What hovering over the compact island does. Default `.peek`.
    public var hoverAction: HoverAction
    /// How long the pointer must rest on the island before hover takes effect,
    /// in milliseconds. Default 120, range `hoverDelayRange`.
    public var hoverDelayMilliseconds: Int {
        didSet {
            hoverDelayMilliseconds = Self.clamp(hoverDelayMilliseconds, to: Self.hoverDelayRange)
        }
    }
    /// How long after the pointer leaves before a peek returns to compact, in
    /// milliseconds. Default 350, range `leaveDelayRange`.
    public var leaveDelayMilliseconds: Int {
        didSet {
            leaveDelayMilliseconds = Self.clamp(leaveDelayMilliseconds, to: Self.leaveDelayRange)
        }
    }

    // MARK: Collapse

    /// Whether an open island collapses when the pointer leaves it. Default `true`.
    public var collapseOnLeave: Bool
    /// How long after the pointer leaves an open island before it collapses,
    /// in milliseconds. Default 1200, range `collapseDelayRange`.
    public var collapseDelayMilliseconds: Int {
        didSet {
            collapseDelayMilliseconds = Self.clamp(
                collapseDelayMilliseconds, to: Self.collapseDelayRange)
        }
    }
    /// Whether alerts (notifications, power connected) arrive open. Default `true`.
    public var alertExpand: Bool
    /// How long an alert stays open before it collapses, in seconds.
    /// Default 4, range `alertCollapseRange`.
    public var alertCollapseSeconds: Int {
        didSet {
            alertCollapseSeconds = Self.clamp(alertCollapseSeconds, to: Self.alertCollapseRange)
        }
    }

    // MARK: Motion

    /// The animation curve. Default `.bouncy`.
    public var motionCurve: MotionCurve
    /// Animation speed multiplier, where 2 is twice as fast. Default 1.0, range
    /// `speedRange`. A NaN resets it to the default.
    public var speed: Double {
        didSet { speed = Self.clampSpeed(speed) }
    }
    /// Whether to replace size animations with a short fade. Default `false`.
    public var reduceMotion: Bool

    // MARK: Appearance

    /// The accent color. Default `.amber`.
    public var accent: Accent
    /// Whether to draw the outline of the physical notch. Default `false`.
    public var showNotchOutline: Bool

    /// Creates settings, clamping every numeric value into its range.
    ///
    /// Each parameter defaults to the design canvas's value, so `IslandSettings()`
    /// equals `IslandSettings.defaults`.
    public init(
        hoverAction: HoverAction = .peek,
        hoverDelayMilliseconds: Int = 120,
        leaveDelayMilliseconds: Int = 350,
        collapseOnLeave: Bool = true,
        collapseDelayMilliseconds: Int = 1200,
        alertExpand: Bool = true,
        alertCollapseSeconds: Int = 4,
        motionCurve: MotionCurve = .bouncy,
        speed: Double = 1.0,
        reduceMotion: Bool = false,
        accent: Accent = .amber,
        showNotchOutline: Bool = false
    ) {
        // Observers don't run during init, so clamp here explicitly.
        self.hoverAction = hoverAction
        self.hoverDelayMilliseconds = Self.clamp(hoverDelayMilliseconds, to: Self.hoverDelayRange)
        self.leaveDelayMilliseconds = Self.clamp(leaveDelayMilliseconds, to: Self.leaveDelayRange)
        self.collapseOnLeave = collapseOnLeave
        self.collapseDelayMilliseconds = Self.clamp(
            collapseDelayMilliseconds, to: Self.collapseDelayRange)
        self.alertExpand = alertExpand
        self.alertCollapseSeconds = Self.clamp(alertCollapseSeconds, to: Self.alertCollapseRange)
        self.motionCurve = motionCurve
        self.speed = Self.clampSpeed(speed)
        self.reduceMotion = reduceMotion
        self.accent = accent
        self.showNotchOutline = showNotchOutline
    }

    /// Restores every setting to its default.
    public mutating func reset() {
        self = Self.defaults
    }

    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clampSpeed(_ value: Double) -> Double {
        value.isNaN ? 1.0 : clamp(value, to: speedRange)
    }
}

extension IslandSettings: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case hoverAction
        case hoverDelayMilliseconds
        case leaveDelayMilliseconds
        case collapseOnLeave
        case collapseDelayMilliseconds
        case alertExpand
        case alertCollapseSeconds
        case motionCurve
        case speed
        case reduceMotion
        case accent
        case showNotchOutline
    }

    /// Decodes settings leniently, so stored settings survive app updates.
    ///
    /// A missing key, or a value of the wrong type such as an accent this
    /// version doesn't know, falls back to that setting's default instead of
    /// failing the whole decode. Out-of-range numbers are clamped. Decoding
    /// fails only when the input isn't a keyed container at all.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.defaults

        func value<T: Decodable>(_ key: CodingKeys, _ defaultValue: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? defaultValue
        }

        self.init(
            hoverAction: value(.hoverAction, fallback.hoverAction),
            hoverDelayMilliseconds: value(.hoverDelayMilliseconds, fallback.hoverDelayMilliseconds),
            leaveDelayMilliseconds: value(.leaveDelayMilliseconds, fallback.leaveDelayMilliseconds),
            collapseOnLeave: value(.collapseOnLeave, fallback.collapseOnLeave),
            collapseDelayMilliseconds: value(
                .collapseDelayMilliseconds, fallback.collapseDelayMilliseconds),
            alertExpand: value(.alertExpand, fallback.alertExpand),
            alertCollapseSeconds: value(.alertCollapseSeconds, fallback.alertCollapseSeconds),
            motionCurve: value(.motionCurve, fallback.motionCurve),
            speed: value(.speed, fallback.speed),
            reduceMotion: value(.reduceMotion, fallback.reduceMotion),
            accent: value(.accent, fallback.accent),
            showNotchOutline: value(.showNotchOutline, fallback.showNotchOutline)
        )
    }
}
