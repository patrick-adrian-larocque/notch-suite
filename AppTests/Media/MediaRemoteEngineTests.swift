import Foundation
import Testing

@testable import NotchSuite

/// `MediaRemoteEngine`'s byte-to-line transport, over a stub script launched the way the
/// adapter is (`perl <script> <framework> stream ...`).
@MainActor
@Suite struct MediaRemoteEngineTests {
    @Test func deliversWholeLinesFromCRLFAndSplitChunks() async throws {
        let script = FileManager.default.temporaryDirectory
            .appending(path: "stub-engine-\(UUID().uuidString).pl")
        defer { try? FileManager.default.removeItem(at: script) }
        // "hello\n", then "a\r\n", then "b" and "c\n" in separate writes: one line, "bc".
        try #"""
        $| = 1;
        print "hello\n";
        print "a\r\n";
        print "b";
        select(undef, undef, undef, 0.3);
        print "c\n";
        sleep 30;
        """#.write(to: script, atomically: true, encoding: .utf8)
        let engine = MediaRemoteEngine(resources: .init(scriptURL: script, frameworkURL: script))
        var lines: [String] = []
        engine.onLine = { lines.append($0) }
        engine.start()
        defer { engine.stop() }

        let deadline = ContinuousClock.now + .seconds(5)
        while lines.count < 3, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(lines == ["hello", "a", "bc"])
    }
}
