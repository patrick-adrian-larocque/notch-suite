import Foundation
import Testing

@testable import NotchCore

// Minimal fakes, as the app target's implementations would conform. They show the
// protocols can be implemented and consumed from Swift 6 concurrency without AppKit.

private struct FakePowerSource: PowerSource {
    var states: [BatteryState]

    func batteryStates() -> AsyncStream<BatteryState> {
        AsyncStream { continuation in
            for state in states { continuation.yield(state) }
            continuation.finish()
        }
    }
}

private actor FakeNowPlayingSource: NowPlayingSource {
    nonisolated let updates: [NowPlaying?]
    private(set) var sent: [MediaCommand] = []

    init(updates: [NowPlaying?]) {
        self.updates = updates
    }

    nonisolated func nowPlayingUpdates() -> AsyncStream<NowPlaying?> {
        AsyncStream { continuation in
            for update in updates { continuation.yield(update) }
            continuation.finish()
        }
    }

    nonisolated func artworkUpdates() -> AsyncStream<Data?> {
        AsyncStream { $0.finish() }
    }

    nonisolated func healthUpdates() -> AsyncStream<NowPlayingSourceHealth> {
        AsyncStream { $0.finish() }
    }

    func send(_ command: MediaCommand) {
        sent.append(command)
    }
}

private actor FakeShelfStorage: ShelfStorage {
    struct Missing: Error {}

    private var saved: [ShelfItem]?

    func item(for url: URL) throws -> ShelfItem {
        guard url.lastPathComponent != "missing" else { throw Missing() }
        return ShelfItem(url: url, kind: url.pathExtension == "pdf" ? .pdf(pageCount: 1) : .file)
    }

    func load() -> [ShelfItem] {
        saved ?? []
    }

    func save(_ items: [ShelfItem]) {
        saved = items
    }
}

@Suite struct ServiceProtocolTests {
    @Test func powerSourceStreamsStates() async {
        let expected = [
            BatteryState(percent: 40, isCharging: false),
            BatteryState(percent: 41, isCharging: true, minutesToFull: 90),
        ]
        let source: any PowerSource = FakePowerSource(states: expected)
        var received: [BatteryState] = []
        for await state in source.batteryStates() { received.append(state) }
        #expect(received == expected)
    }

    @Test func powerSourceWithoutBatteryFinishesEmpty() async {
        let source: any PowerSource = FakePowerSource(states: [])
        var count = 0
        for await _ in source.batteryStates() { count += 1 }
        #expect(count == 0)
    }

    @Test func nowPlayingSourceStreamsUpdatesAndTakesCommands() async throws {
        let song = NowPlaying(
            app: AppIdentity(bundleIdentifier: "com.apple.Music"), playing: true, title: "Song")
        let fake = FakeNowPlayingSource(updates: [song, nil])
        let source: any NowPlayingSource = fake
        var received: [NowPlaying?] = []
        for await update in source.nowPlayingUpdates() { received.append(update) }
        #expect(received == [song, nil])

        try await source.send(.togglePlayPause)
        try await source.send(.nextTrack)
        #expect(await fake.sent == [.togglePlayPause, .nextTrack])
    }

    @Test func shelfStorageFeedsTheStore() async throws {
        let storage: any ShelfStorage = FakeShelfStorage()
        #expect(try await storage.load().isEmpty)

        var store = ShelfStore()
        store.add(try await storage.item(for: URL(fileURLWithPath: "/tmp/a.txt")))
        store.add(try await storage.item(for: URL(fileURLWithPath: "/tmp/b.pdf")))
        try await storage.save(store.items)

        let reloaded = ShelfStore(items: try await storage.load())
        #expect(reloaded == store)
        #expect(reloaded.items.map(\.name) == ["b.pdf", "a.txt"])
        #expect(reloaded.items.first?.kind == .pdf(pageCount: 1))

        await #expect(throws: FakeShelfStorage.Missing.self) {
            try await storage.item(for: URL(fileURLWithPath: "/tmp/missing"))
        }
    }
}
