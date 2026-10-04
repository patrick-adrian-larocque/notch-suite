import Foundation
import NotchCore
import Testing

@testable import NotchSuite

/// `suspend()`/`resume()` over the real `MediaRemoteEngine`, pointed at a stub script
/// instead of mediaremote-adapter. The stub is launched the same way (`perl <script>
/// <framework> stream ...`) and just sleeps, so these tests cover the process lifecycle
/// and observer streams only.
///
/// Not covered: a later media update reaching the same observer after `resume()`. Under
/// this test host the engine delivered no stdout lines even for a trivial script (cause
/// not found), so that path is only checked by hand; see `App/Media/README.md`.
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

    private func makeRig() throws -> Rig {
        let script = FileManager.default.temporaryDirectory
            .appending(path: "stub-adapter-\(UUID().uuidString).pl")
        try "sleep 60;\n".write(to: script, atomically: true, encoding: .utf8)
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
