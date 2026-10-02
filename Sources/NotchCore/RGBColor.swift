/// An opaque sRGB color, with each channel from 0 to 1.
///
/// NotchCore describes colors as `#rrggbb` strings, such as ``IslandAppearance`` and
/// ``IslandSettings/Accent/hex``. This parses them, so the UI layer only has to hand
/// three numbers to its platform color type.
public struct RGBColor: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses `#rrggbb`, with or without the `#`, in either case.
    ///
    /// Returns `nil` for anything else, including the three-digit `#rgb` form, which
    /// NotchCore never produces.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        // `UInt32(_:radix:)` accepts a leading sign, so check the digits first.
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit),
            let value = UInt32(digits, radix: 16)
        else { return nil }
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255)
    }
}
