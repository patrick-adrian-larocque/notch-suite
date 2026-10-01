/// Loads and saves `IslandSettings`.
///
/// The app target implements this on top of macOS storage. `InMemorySettingsStore`
/// is a storage-free implementation for tests and previews.
public protocol SettingsStore: Sendable {
    /// Returns the stored settings, or `IslandSettings.defaults` when nothing
    /// has been saved yet.
    ///
    /// Throws only when stored settings exist but can't be read.
    func load() async throws -> IslandSettings

    /// Stores `settings`, replacing whatever was saved before.
    func save(_ settings: IslandSettings) async throws
}

/// A `SettingsStore` that keeps settings in memory and never throws.
public actor InMemorySettingsStore: SettingsStore {
    private var stored: IslandSettings?

    /// Creates a store holding `settings`, or an empty store when `nil`.
    public init(_ settings: IslandSettings? = nil) {
        stored = settings
    }

    public func load() -> IslandSettings {
        stored ?? .defaults
    }

    public func save(_ settings: IslandSettings) {
        stored = settings
    }
}
