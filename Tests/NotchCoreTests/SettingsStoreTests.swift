import Testing

@testable import NotchCore

@Suite struct SettingsStoreTests {
    @Test func emptyStoreLoadsDefaults() async throws {
        let store: any SettingsStore = InMemorySettingsStore()
        #expect(try await store.load() == .defaults)
    }

    @Test func savedSettingsLoadBack() async throws {
        let store: any SettingsStore = InMemorySettingsStore()
        let settings = IslandSettings(hoverAction: .off, accent: .green)
        try await store.save(settings)
        #expect(try await store.load() == settings)
    }

    @Test func saveReplacesEarlierSettings() async throws {
        let store: any SettingsStore = InMemorySettingsStore(IslandSettings(accent: .blue))
        try await store.save(IslandSettings(accent: .pink))
        #expect(try await store.load().accent == .pink)
    }
}
