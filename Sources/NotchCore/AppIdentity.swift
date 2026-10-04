/// Which application a report came from, as far as the report says.
///
/// Either part can be missing. mediaremote-adapter always sends the process identifier
/// but adds the bundle identifier only when it can look the process up, so a report
/// with a process identifier and no bundle identifier is normal. Unknown identity never
/// means "nothing is playing".
///
/// This is only what the report carries. The app target turns it into a name and an
/// icon; `NotchCore` stays free of macOS types.
public struct AppIdentity: Sendable, Hashable {
    /// The application's bundle identifier, such as `com.apple.Music`.
    public var bundleIdentifier: String?
    /// The application's process identifier. Only meaningful while that process runs:
    /// the system reuses process identifiers after a process exits.
    public var processIdentifier: Int32?

    public init(bundleIdentifier: String? = nil, processIdentifier: Int32? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }

    /// An identity with neither part.
    public static let unknown = AppIdentity()

    /// `true` when neither part is known.
    public var isUnknown: Bool {
        bundleIdentifier == nil && processIdentifier == nil
    }

    /// Whether `self` and `other` name the same application, or `nil` when the two don't
    /// share a part that could decide it.
    ///
    /// Any part both know and disagree on means different applications. A bundle
    /// identifier that differs under an equal process identifier is a reused process
    /// identifier, and a process identifier that differs under an equal bundle identifier
    /// is the same application relaunched, which starts a new session. Otherwise, any part
    /// both know and agree on means the same application. Two missing parts prove nothing,
    /// so they give `nil` rather than `true`.
    public func isSameApplication(as other: AppIdentity) -> Bool? {
        let bundles = Self.compare(bundleIdentifier, other.bundleIdentifier)
        let processes = Self.compare(processIdentifier, other.processIdentifier)
        if bundles == false || processes == false { return false }
        if bundles == true || processes == true { return true }
        return nil
    }

    /// `nil` when either side is missing, otherwise whether they are equal.
    private static func compare<Value: Equatable>(_ lhs: Value?, _ rhs: Value?) -> Bool? {
        guard let lhs, let rhs else { return nil }
        return lhs == rhs
    }
}
