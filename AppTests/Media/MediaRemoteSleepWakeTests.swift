import Foundation
import NotchCore
import Testing

@testable import NotchSuite

/// `suspend()`/`resume()` over the real `MediaRemoteEngine`, pointed at a stub script
/// instead of mediaremote-adapter. The stub is launched the same way (`perl <script>
/// <framework> stream ...`). Most tests use a stub that just sleeps, covering the process
/// lifecycle and observer streams; one uses a stub that reports a session on each launch.
///
/// Fixed sleeps rather than polling: running `pgrep` synchronously in a polling loop on
/// the main actor kept the observer's stream from finishing.
@MainActor
@Suite struct MediaRemoteSleepWakeTests {
    private struct Rig {
        let source: MediaRemoteNowPlayingSource
        let engine: MediaRemoteEngine
        let script: URL
    }

    private func makeRig(script body: String = "sleep 60;\n") throws -> Rig {
        let script = FileManager.default.temporaryDirectory
            .appending(path: "stub-adapter-\(UUID().uuidString).pl")
        try body.write(to: script, atomically: true, encoding: .utf8)
        let engine = MediaRemoteEngine(resources: .init(scriptURL: script, frameworkURL: script))
        return Rig(
            source: MediaRemoteNowPlayingSource(engine: engine), engine: engine, script: script)
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(400))
    }

    /// How many processes started from `script` are alive.
    private func processCount(_ script: URL) -> Int {
        let pgrep = Process()
        let output = Pipe()
        pgrep.executableURL = URL(filePath: "/usr/bin/pgrep")
        pgrep.arguments = ["-f", script.path]
        pgrep.standardOutput = output
        try? pgrep.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        pgrep.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").count
    }

    /// Records whether an observer stream has finished.
    private final class Observer {
        var finished = false
    }

    private func observe(_ source: MediaRemoteNowPlayingSource) -> Observer {
        let observer = Observer()
        let updates = source.nowPlayingUpdates()
        Task { @MainActor in
            for await _ in updates {}
            observer.finished = true
        }
        return observer
    }

    @Test func suspendEndsTheProcessKeepsObserversAndResumeRestartsIt() async throws {
        let rig = try makeRig()
        defer { try? FileManager.default.removeItem(at: rig.script) }
        let observer = observe(rig.source)
        rig.source.start()
        await settle()
        #expect(processCount(rig.script) == 1)

        rig.source.suspend()
        await settle()
        #expect(processCount(rig.script) == 0)
        #expect(rig.engine.status == .stopped)
        #expect(!observer.finished)

        rig.source.resume()
        await settle()
        #expect(processCount(rig.script) == 1)
        #expect(rig.engine.status == .running)
        #expect(!observer.finished)

        rig.source.stop()
        await settle()
        #expect(observer.finished)
        #expect(processCount(rig.script) == 0)
    }

    @Test func anUpdateAfterResumeReachesTheSameObserver() async throws {
        // Each launch reports a session titled with its own pid, so a restart is visible.
        let rig = try makeRig(
            script: #"""
                $| = 1;
                print qq~{"type":"data","diff":false,"payload":{"playing":true,"title":"T$$","processIdentifier":1}}\n~;
                sleep 60;
                """#)
        defer { try? FileManager.default.removeItem(at: rig.script) }
        let titles = TitleLog()
        let updates = rig.source.nowPlayingUpdates()
        Task { @MainActor in
            for await update in updates { if let update { titles.values.append(update.title) } }
            titles.finished = true
        }
        rig.source.start()
        await waitForTitles(titles, count: 1)

        rig.source.suspend()
        await settle()
        rig.source.resume()
        await waitForTitles(titles, count: 2)

        #expect(titles.values.count == 2)
        #expect(titles.values.first != titles.values.last)  // a new launch has a new pid
        #expect(!titles.finished)
        rig.source.stop()
    }

    private final class TitleLog {
        var values: [String] = []
        var finished = false
    }

    /// Waits up to five seconds for `count` titles, polling with sleeps only.
    private func waitForTitles(_ titles: TitleLog, count: Int) async {
        let deadline = ContinuousClock.now + .seconds(5)
        while titles.values.count < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func repeatedSuspendAndResumeAreSafe() async throws {
        let rig = try makeRig()
        defer { try? FileManager.default.removeItem(at: rig.script) }
        rig.source.start()
        await settle()

        rig.source.suspend()
        rig.source.suspend()
        await settle()
        #expect(processCount(rig.script) == 0)

        rig.source.resume()
        rig.source.resume()
        await settle()
        // A second resume must not start a second process.
        #expect(processCount(rig.script) == 1)
        #expect(rig.engine.status == .running)

        rig.source.stop()
        await settle()
        #expect(processCount(rig.script) == 0)
    }
}
