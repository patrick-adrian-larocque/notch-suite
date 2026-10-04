// Adapted from boring.notch (GPL-3.0-only),
// https://github.com/TheBoredTeam/boring.notch, revision 4ba4a92 (`dev`):
// `boringNotch/MediaControllers/NowPlayingStreamSupport.swift` (stream session and
// process stop) and `Shared/JSONLinesPipeHandler.swift` (line reading). Changes: lines
// are handed over as text for `NowPlayingStreamParser` instead of decoded here, the
// session restarts itself with a backoff, and commands run as short processes.

import Foundation
import os

/// Runs mediaremote-adapter and hands each line it prints to `onLine`.
///
/// The adapter only works inside `/usr/bin/perl`, which MediaRemote still serves on
/// macOS 15.4 and later. It reads the bundled script and framework; see
/// `Vendor/mediaremote-adapter/README.md`.
///
/// `start()` launches `stream` and keeps it running: when the process exits on its
/// own, the engine reports `.failed` and restarts it after a growing delay, up to
/// ``maximumRestartDelay``. `stop()` ends it for good. The engine never decides what a
/// line means; `MediaRemoteNowPlayingSource` does.
@MainActor
final class MediaRemoteEngine {
    /// Where the engine is.
    enum Status: Equatable, Sendable {
        /// Not started, or stopped by `stop()`.
        case stopped
        /// The adapter is running.
        case running
        /// The adapter exited or couldn't start; another attempt follows after the delay.
        /// This is not "nothing playing": the media state is unknown until it recovers.
        case failed(reason: String, retryingIn: Duration)
        /// The bundled script or framework is missing, so the engine can't run at all.
        case unavailable(reason: String)
    }

    /// The bundled adapter files.
    struct Resources: Sendable {
        let scriptURL: URL
        let frameworkURL: URL

        /// The files bundled in `bundle`, or `nil` when either is missing.
        static func bundled(in bundle: Bundle = .main) -> Resources? {
            guard
                let scriptURL = bundle.url(
                    forResource: "mediaremote-adapter", withExtension: "pl"),
                let frameworks = bundle.privateFrameworksURL
            else {
                return nil
            }
            let frameworkURL = frameworks.appending(path: "MediaRemoteAdapter.framework")
            let executable = frameworkURL.appending(path: "MediaRemoteAdapter").path
            guard FileManager.default.isReadableFile(atPath: scriptURL.path),
                FileManager.default.isExecutableFile(atPath: executable)
            else {
                return nil
            }
            return Resources(scriptURL: scriptURL, frameworkURL: frameworkURL)
        }
    }

    /// Why a command couldn't be delivered.
    enum CommandError: Error, Equatable {
        case unavailable
        case launchFailed(String)
        case exited(status: Int32)
        case timedOut
    }

    static let perlURL = URL(filePath: "/usr/bin/perl")
    /// The first restart waits this long; each failure in a row doubles it.
    static let initialRestartDelay: Duration = .seconds(1)
    static let maximumRestartDelay: Duration = .seconds(30)
    /// A run that lasts this long counts as healthy and resets the restart delay.
    static let healthyRunDuration: Duration = .seconds(10)
    /// Arguments after `stream`. Artwork is left out so updates stay small; the
    /// adapter's `--debounce` merges bursts of small changes.
    static let streamOptions = ["--no-artwork", "--debounce=100"]

    /// Called with each complete line of `stream` output, without its line ending.
    var onLine: (String) -> Void = { _ in }
    /// Called whenever ``status`` changes.
    var onStatusChange: (Status) -> Void = { _ in }

    private(set) var status: Status = .stopped {
        didSet { if status != oldValue { onStatusChange(status) } }
    }

    private let resources: Resources?
    private var session: StreamSession?
    private var restartTask: Task<Void, Never>?
    private var restartDelay = MediaRemoteEngine.initialRestartDelay
    private var startedAt: ContinuousClock.Instant?

    init(resources: Resources? = .bundled()) {
        self.resources = resources
    }

    /// Launches the adapter. Does nothing when it is already running.
    func start() {
        guard session == nil, restartTask == nil else { return }
        guard let resources else {
            status = .unavailable(reason: "mediaremote-adapter isn't bundled")
            return
        }
        let session = StreamSession(
            arguments: [resources.scriptURL.path, resources.frameworkURL.path, "stream"]
                + Self.streamOptions,
            onLine: { [weak self] line in self?.onLine(line) },
            onExit: { [weak self] reason in self?.sessionEnded(reason) })
        self.session = session
        startedAt = .now
        if let error = session.start() {
            sessionEnded("couldn't launch perl: \(error)")
        } else {
            status = .running
        }
    }

    /// Ends the adapter and any pending restart.
    func stop() {
        restartTask?.cancel()
        restartTask = nil
        session?.stop()
        session = nil
        restartDelay = Self.initialRestartDelay
        if case .unavailable = status { return }
        status = .stopped
    }

    /// Sends `send <id>` in a short-lived process and waits for it to exit.
    func send(commandID: Int) async throws(CommandError) {
        guard let resources else { throw .unavailable }
        try await Self.run(
            arguments: [
                resources.scriptURL.path, resources.frameworkURL.path, "send", String(commandID),
            ],
            timeout: .seconds(5))
    }

    private func sessionEnded(_ reason: String) {
        session?.stop()
        session = nil
        if let startedAt, ContinuousClock.now - startedAt >= Self.healthyRunDuration {
            restartDelay = Self.initialRestartDelay
        }
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, Self.maximumRestartDelay)
        status = .failed(reason: reason, retryingIn: delay)
        mediaRemoteLog.error(
            "adapter stopped: \(reason, privacy: .public); retrying in \(delay, privacy: .public)")
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.restartTask = nil
            self.start()
        }
    }

    /// Runs `/usr/bin/perl` with `arguments` and waits for a zero exit status.
    private static func run(arguments: [String], timeout: Duration) async throws(CommandError) {
        let process = Process()
        process.executableURL = perlURL
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let exits = AsyncStream<Int32> { continuation in
            process.terminationHandler = { process in
                continuation.yield(
                    process.terminationReason == .exit ? process.terminationStatus : -1)
                continuation.finish()
            }
        }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error.localizedDescription)
        }
        let status = await withTaskGroup(of: Int32?.self) { group in
            group.addTask {
                for await status in exits { return status }
                return -1
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let status else {
            StreamSession.kill(process)
            throw .timedOut
        }
        guard status == 0 else { throw .exited(status: status) }
    }
}

/// One run of `stream`: the process and the task reading its output.
@MainActor
private final class StreamSession {
    private let process = Process()
    private let pipe = Pipe()
    private let onLine: (String) -> Void
    private let onExit: (String) -> Void
    private var readTask: Task<Void, Never>?
    private var isStopped = false

    init(
        arguments: [String], onLine: @escaping (String) -> Void, onExit: @escaping (String) -> Void
    ) {
        process.executableURL = MediaRemoteEngine.perlURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        self.onLine = onLine
        self.onExit = onExit
    }

    /// Launches the process. Returns the launch error, or `nil` when it started.
    func start() -> (any Error)? {
        process.terminationHandler = { [weak self] process in
            let reason = "exited with status \(process.terminationStatus)"
            Task { @MainActor in self?.finish(reason) }
        }
        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            isStopped = true
            return error
        }
        let lines = Self.lines(from: pipe.fileHandleForReading)
        readTask = Task { [weak self] in
            for await line in lines {
                guard let self, !self.isStopped else { return }
                self.onLine(line)
            }
        }
        return nil
    }

    /// Ends the process without reporting it as a failure.
    func stop() {
        guard !isStopped else { return }
        isStopped = true
        process.terminationHandler = nil
        readTask?.cancel()
        Self.kill(process)
        try? pipe.fileHandleForReading.close()
    }

    private func finish(_ reason: String) {
        guard !isStopped else { return }
        stop()
        onExit(reason)
    }

    /// Splits the pipe's bytes into lines, dropping `\n` and a `\r` before it.
    ///
    /// Reads off the main actor; a line can be as large as a full artwork payload.
    private nonisolated static func lines(from handle: FileHandle) -> AsyncStream<String> {
        AsyncStream { continuation in
            let reader = Task.detached {
                var line = Data()
                do {
                    for try await byte in handle.bytes {
                        if Task.isCancelled { break }
                        guard byte == UInt8(ascii: "\n") else {
                            line.append(byte)
                            continue
                        }
                        if line.last == UInt8(ascii: "\r") { line.removeLast() }
                        if !line.isEmpty {
                            continuation.yield(String(decoding: line, as: UTF8.self))
                        }
                        line.removeAll(keepingCapacity: true)
                    }
                } catch {}
                continuation.finish()
            }
            continuation.onTermination = { _ in reader.cancel() }
        }
    }

    /// Ends `process`: SIGTERM, which the adapter handles, then SIGKILL if it lingers.
    nonisolated static func kill(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            if Darwin.kill(pid, 0) == 0, process.isRunning { Darwin.kill(pid, SIGKILL) }
        }
    }
}

let mediaRemoteLog = Logger(subsystem: "com.patricklarocque.NotchSuite", category: "MediaRemote")
