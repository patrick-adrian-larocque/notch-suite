import Foundation

/// Why a line of `mediaremote-adapter stream` output was rejected.
public enum NowPlayingStreamError: Error, Equatable {
    /// The line is not valid JSON.
    case malformedJSON
    /// The line is JSON but not a `{"type", "diff", "payload"}` envelope.
    case invalidEnvelope(String)
}

/// Turns mediaremote-adapter `stream` output into a current `NowPlaying`.
///
/// Feed it one line at a time. A `diff: false` payload replaces the state. A
/// `diff: true` payload is merged into the last state, and a key set to `null`
/// removes that value. A rejected line throws and leaves the state untouched.
public struct NowPlayingStreamParser: Sendable {
    /// The merged raw key/value state, after every line ingested so far.
    public private(set) var state: [String: JSONValue] = [:]

    public init() {}

    /// The current now-playing info, or `nil` when nothing valid is playing.
    public var nowPlaying: NowPlaying? {
        NowPlaying(state: state)
    }

    /// Applies one line of stream output and returns the resulting `nowPlaying`.
    ///
    /// Blank lines are ignored, so a trailing newline or CRLF line ending is safe.
    @discardableResult
    public mutating func ingest(line: String) throws -> NowPlaying? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nowPlaying }

        let (isDiff, payload) = try Self.decodeEnvelope(trimmed)
        if isDiff {
            for (key, value) in payload {
                state[key] = value == .null ? nil : value
            }
        } else {
            state = payload.filter { $0.value != .null }
        }
        return nowPlaying
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
        try validateMandatoryKeys(in: payload)
        return (isDiff, payload)
    }

    /// Rejects a payload that gives a mandatory key the wrong type.
    ///
    /// Without this, a diff such as `{"title": 5}` would overwrite the good title and
    /// quietly turn `nowPlaying` into `nil`. A `null` is still allowed: in a diff it removes
    /// the key. Optional keys stay lenient; a wrongly typed one just reads as absent.
    private static func validateMandatoryKeys(in payload: [String: JSONValue]) throws {
        for key in ["bundleIdentifier", "title"] {
            if let value = payload[key], value != .null, value.stringValue == nil {
                throw NowPlayingStreamError.invalidEnvelope("\"\(key)\" must be a string")
            }
        }
        if let value = payload["playing"], value != .null, value.boolValue == nil {
            throw NowPlayingStreamError.invalidEnvelope("\"playing\" must be a boolean")
        }
    }
}
