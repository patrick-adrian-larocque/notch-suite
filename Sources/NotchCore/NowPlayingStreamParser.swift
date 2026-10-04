import Foundation

/// Why a line of `mediaremote-adapter stream` output was rejected.
public enum NowPlayingStreamError: Error, Equatable {
    /// The line is not valid JSON.
    case malformedJSON
    /// The line is JSON but not a `{"type", "diff", "payload"}` envelope, or it gives a
    /// known key the wrong type.
    case invalidEnvelope(String)
}

/// What the stream says about media, after the last accepted line.
public enum NowPlayingReport: Sendable, Equatable {
    /// No player reports a session. The adapter sends an empty payload for this.
    case noSession
    /// A player reports a session. Its `AppIdentity` may be partial or unknown.
    case session(NowPlaying)
    /// The merged state has keys but lacks `missingKeys`, which a session needs. This
    /// is not "nothing playing": a diff can leave the state like this for a moment, and
    /// callers should keep showing the last session rather than stop.
    case incomplete(missingKeys: [String])

    /// The session's `NowPlaying`, or `nil` for the other cases.
    public var nowPlaying: NowPlaying? {
        if case .session(let nowPlaying) = self { return nowPlaying }
        return nil
    }
}

/// Turns mediaremote-adapter `stream` output into a `NowPlayingReport`.
///
/// Feed it one line at a time. A `diff: false` payload replaces the state. A
/// `diff: true` payload is merged into the last state, and a key set to `null`
/// removes that value. A rejected line throws and leaves the state untouched, so a
/// malformed line never reads as "nothing playing".
public struct NowPlayingStreamParser: Sendable {
    /// The merged raw key/value state, after every line ingested so far.
    public private(set) var state: [String: JSONValue] = [:]

    public init() {}

    /// What the current state says: no session, a session, or an incomplete state.
    public var report: NowPlayingReport {
        if state.isEmpty { return .noSession }
        if let nowPlaying = NowPlaying(state: state) { return .session(nowPlaying) }
        return .incomplete(missingKeys: NowPlaying.requiredKeys.filter { state[$0] == nil })
    }

    /// The current session, or `nil` when there is none or the state is incomplete.
    /// Use `report` to tell those two apart.
    public var nowPlaying: NowPlaying? {
        report.nowPlaying
    }

    /// Applies one line of stream output and returns the resulting `report`.
    ///
    /// Blank lines are ignored, so a trailing newline or CRLF line ending is safe.
    @discardableResult
    public mutating func ingest(line: String) throws -> NowPlayingReport {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return report }

        let (isDiff, payload) = try Self.decodeEnvelope(trimmed)
        if isDiff {
            for (key, value) in payload {
                state[key] = value == .null ? nil : value
            }
        } else {
            state = payload.filter { $0.value != .null }
        }
        return report
    }

    private static func decodeEnvelope(_ text: String) throws -> (Bool, [String: JSONValue]) {
        let value: JSONValue
        do {
            value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        } catch {
            throw NowPlayingStreamError.malformedJSON
        }
        guard let envelope = value.objectValue else {
            throw NowPlayingStreamError.invalidEnvelope("expected a JSON object")
        }
        guard envelope["type"]?.stringValue == "data" else {
            throw NowPlayingStreamError.invalidEnvelope("\"type\" must be \"data\"")
        }
        guard let isDiff = envelope["diff"]?.boolValue else {
            throw NowPlayingStreamError.invalidEnvelope("\"diff\" must be a boolean")
        }
        guard let payload = envelope["payload"]?.objectValue else {
            throw NowPlayingStreamError.invalidEnvelope("\"payload\" must be an object")
        }
        try validateKnownKeys(in: payload)
        return (isDiff, payload)
    }

    /// Rejects a payload that gives a session or identity key the wrong type.
    ///
    /// Without this, a diff such as `{"title": 5}` would overwrite the good title and
    /// quietly end the session. A `null` is still allowed: in a diff it removes the key.
    /// Other optional keys stay lenient; a wrongly typed one just reads as absent.
    private static func validateKnownKeys(in payload: [String: JSONValue]) throws {
        func check(_ key: String, _ isValid: (JSONValue) -> Bool, _ expected: String) throws {
            if let value = payload[key], value != .null, !isValid(value) {
                throw NowPlayingStreamError.invalidEnvelope("\"\(key)\" must be \(expected)")
            }
        }
        try check("title", { $0.stringValue != nil }, "a string")
        try check("bundleIdentifier", { $0.stringValue != nil }, "a string")
        try check("playing", { $0.boolValue != nil }, "a boolean")
        try check(
            "processIdentifier", { NowPlaying.processIdentifier($0) != nil },
            "a positive 32-bit integer")
    }
}
