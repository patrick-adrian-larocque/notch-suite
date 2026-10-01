/// The battery's charge, as the charging island shows it.
///
/// Values are normalized wherever they come from, the initializer or a property
/// assignment: `percent` is clamped into `percentRange`, and `minutesToFull` is
/// `nil` unless the battery is charging and the estimate is non-negative.
public struct BatteryState: Sendable, Hashable {
    /// Allowed charge, in percent.
    public static let percentRange: ClosedRange<Int> = 0...100

    /// The charge, in percent, within `percentRange`.
    public var percent: Int {
        didSet { percent = Self.clamp(percent) }
    }

    /// Whether the battery is charging. Setting it to `false` clears `minutesToFull`.
    public var isCharging: Bool {
        didSet {
            if !isCharging { minutesToFull = nil }
        }
    }

    /// Minutes until the battery is full, or `nil` when it isn't charging or
    /// macOS is still estimating.
    public var minutesToFull: Int? {
        didSet { minutesToFull = Self.normalize(minutesToFull, isCharging: isCharging) }
    }

    /// Creates a battery state, normalizing `percent` and `minutesToFull`.
    public init(percent: Int, isCharging: Bool, minutesToFull: Int? = nil) {
        // Observers don't run during init, so normalize here explicitly.
        self.percent = Self.clamp(percent)
        self.isCharging = isCharging
        self.minutesToFull = Self.normalize(minutesToFull, isCharging: isCharging)
    }

    /// Whether the battery is at 100 percent.
    public var isFull: Bool {
        percent == Self.percentRange.upperBound
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, percentRange.lowerBound), percentRange.upperBound)
    }

    private static func normalize(_ minutes: Int?, isCharging: Bool) -> Int? {
        guard isCharging, let minutes, minutes >= 0 else { return nil }
        return minutes
    }
}
