# NotchCore Scaffold and Claude Workflow Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the repo a real, Linux-testable `NotchCore` Swift package (issue #3), harden the Claude Code settings (issue #4), and write `CLAUDE.md` plus path-scoped rules (issue #5), so CI, the skills and the agents from the dev workflow template have something real to run against.

**Architecture:** One SwiftPM package with a pure-Swift `NotchCore` library and a Swift Testing test target. The first real logic is a parser for mediaremote-adapter's `stream` output: it keeps a raw `[String: JSONValue]` state, applies full payloads and `diff` merges to it (a `null` key removes a value), and projects that state into a typed `NowPlaying`. The Claude config work (settings, `CLAUDE.md`, rules) follows, documenting the commands that now exist. A review loop with the installed plugins and project agents closes it out.

**Tech Stack:** Swift 6.4 (Xcode 27.0 / swiftly 6.4.0 locally, `swift:6.4-noble` in Docker), swift-tools-version 6.0, Swift Testing, `swift format`, Claude Code 2.1.283, the `superpowers`, `pr-review-toolkit`, `code-simplifier`, `claude-md-management`, `plugin-dev` and `swift-lsp` plugins, GitHub CLI.

**Spec:** GitHub issues #3, #4 and #5 in `patrick-adrian-larocque/notch-suite` (read with `gh issue view <n>`), plus the `stream` command section of the mediaremote-adapter README (`gh api repos/ungive/mediaremote-adapter/readme`).

## Global Constraints

- `swift-tools-version` 6.0 or newer, `platforms: [.macOS(.v14)]` (issue #3).
- `NotchCore` imports no `AppKit`, `SwiftUI` or `Combine`; the Linux build enforces this (issue #3). Foundation is allowed.
- Tests use Swift Testing (`import Testing`), not XCTest (issue #3).
- `swift format lint --strict --recursive Sources Tests` must pass, with a checked-in `.swift-format` (issue #3).
- The parser is written fresh from the format documented in the README, not copied from mediaremote-adapter's source (issue #3). The PR description still credits the README as the format reference.
- `CLAUDE.md` stays under 200 lines and no rules file contradicts it or another (issue #5).
- `.claude/settings.json` keeps the existing SessionStart hook registration, adds the `$schema` line, and validates against it (issue #4).
- Work on one branch per issue, named `claude/issue-<N>-<slug>`. Nothing is pushed and no PR is opened until the user says so. Commits end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Reference forks (`patlar104/boring.notch`, `patlar104/notchdrop`, `patlar104/mediaremote-adapter`) are read-only.

## Review Focus

Inputs the spec doesn't spell out but a real `stream` will produce, most likely first. Each has a test in Task 3 unless noted.

- **One garbled line mid-stream** (the adapter or a wrapper printing plain text or a truncated line): the line is rejected and the state from before it survives. Tests: `recoversAfterABadLine`, `plainTextIsMalformedJSON`, `malformedJSONIsRejectedAndKeepsState`.
- **Artwork-sized lines** (about 1 MB of base64 `artworkData` in one line, then removed by a diff): parsed without trouble and cleanly removed. Test: `handlesAnArtworkSizedLineAndRemovesItAgain`.
- **`--micros` renamed keys** (`durationMicros` instead of `duration`): kept in the raw state, and `NowPlaying` still forms with `duration == nil` instead of failing. Test: `microsKeysAreKeptButDoNotBreakNowPlaying`.
- **Starting mid-stream** (a `diff: true` line arrives before any full payload): merged into an empty state, no crash. Test: `diffBeforeAnyFullStateMergesIntoEmptyState`.
- **Non-ASCII titles and CRLF line endings**: kept intact, no rejection. Tests: `keepsUnicodeAndEscapedTitles`, `toleratesTrailingNewlineAndCRLF`.

---

## Task 0: Preflight and branch

**Files:** none changed.

**Interfaces:**
- Consumes: the merged dev workflow template already on local `main` (agents, skills, CI, `scripts/ci-swift.sh`).
- Produces: a clean branch `claude/issue-3-notchcore` and a record of which tools, plugins and skills are present.

Verified on 2026-09-28: Swift 6.4 (swiftly, `.swift-version` 6.4.0), Xcode 27.0, `sourcekit-lsp`, `swift format`, Docker (OrbStack) with `swift:6.4-noble` pulled, `fd`, `fzf`, `rg`, `ast-grep`, `jq`, `yq`, `gh` (logged in as `patlar104`), Claude Code 2.1.283. Plugins installed: `superpowers`, `pr-review-toolkit`, `code-simplifier`, `claude-md-management`, `plugin-dev`, `feature-dev`, `swift-lsp`. Project skills `swift-check`, `port-from-reference`, `ci-status`, `triage-issue`, `work-issue` and project agents `core-verifier`, `feature-worker`, `license-auditor`, `macos-ci-investigator`, `reference-scout` came in with the template. Not available locally: node, npx, uv (Task 5 uses a Python venv instead).

- [ ] **Step 1: Re-check the toolchain and repo state**

Run:
```bash
cd /Users/patricklarocque/Developer/notch-suite
git status --short && git branch --show-current && git log --oneline -3
swift --version && xcrun swift --version && swift format --version
docker info --format '{{.ServerVersion}}' && docker image inspect swift:6.4-noble --format '{{.Id}}' | cut -c1-19
for t in fd fzf rg ast-grep jq yq gh; do command -v $t >/dev/null && echo "ok $t" || echo "MISSING $t"; done
```
Expected: branch `main` at `a0ba01c`, `git status` shows only `?? docs/superpowers/` (this plan), both Swift versions report 6.4, Docker answers, and no `MISSING` lines. If anything is missing, stop and fix it before continuing.

- [ ] **Step 2: Create the issue #3 branch**

Run:
```bash
git switch -c claude/issue-3-notchcore
```
Expected: `Switched to a new branch 'claude/issue-3-notchcore'`. The untracked plan file comes along and stays uncommitted until Task 7.

---

## Task 1: Package skeleton, format config, and `JSONValue` (issue #3)

**Files:**
- Create: `Package.swift`
- Create: `.swift-format`
- Create: `Tests/NotchCoreTests/JSONValueTests.swift`
- Create: `Sources/NotchCore/JSONValue.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public enum JSONValue: Sendable, Equatable, Decodable` with cases `.null`, `.bool(Bool)`, `.number(Double)`, `.string(String)`, `.array([JSONValue])`, `.object([String: JSONValue])`, and the accessors `stringValue: String?`, `boolValue: Bool?`, `numberValue: Double?`, `objectValue: [String: JSONValue]?`. Also the `NotchCore` library product and the `NotchCoreTests` test target.

- [ ] **Step 1: Write the package manifest and format config**

`Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchSuite",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotchCore", targets: ["NotchCore"])
    ],
    targets: [
        .target(name: "NotchCore"),
        .testTarget(name: "NotchCoreTests", dependencies: ["NotchCore"]),
    ]
)
```

`.swift-format`:
```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": { "spaces": 4 },
  "maximumBlankLines": 1,
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeEachArgument": false,
  "multiElementCollectionTrailingCommas": true
}
```

- [ ] **Step 2: Write the failing test**

`Tests/NotchCoreTests/JSONValueTests.swift`:
```swift
import Foundation
import Testing

@testable import NotchCore

@Suite struct JSONValueTests {
    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test func decodesEveryJSONKind() throws {
        let value = try decode(
            #"{"n":null,"b":true,"x":1.5,"s":"hi","a":[1,"two"],"o":{"k":false}}"#)
        #expect(
            value
                == .object([
                    "n": .null,
                    "b": .bool(true),
                    "x": .number(1.5),
                    "s": .string("hi"),
                    "a": .array([.number(1), .string("two")]),
                    "o": .object(["k": .bool(false)]),
                ]))
    }

    @Test func accessorsReturnNilForOtherKinds() throws {
        let value = try decode(#""text""#)
        #expect(value.stringValue == "text")
        #expect(value.boolValue == nil)
        #expect(value.numberValue == nil)
        #expect(value.objectValue == nil)
    }

    @Test func doesNotReadNumbersAsBooleans() throws {
        #expect(try decode("1").boolValue == nil)
        #expect(try decode("1") == .number(1))
    }

    @Test func rejectsTruncatedJSON() {
        #expect(throws: (any Error).self) { try decode(#"{"a":"#) }
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `swift build --build-tests 2>&1 | tail -5`
Expected: FAIL with a build error about the `NotchCore` target having no sources (or `cannot find 'JSONValue' in scope`).

- [ ] **Step 4: Write the implementation**

`Sources/NotchCore/JSONValue.swift`:
```swift
import Foundation

/// A decoded JSON value.
///
/// NotchCore keeps stream payloads in this form so diff merging can work on the
/// raw keys before anything is interpreted.
public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}

extension JSONValue: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}
```

- [ ] **Step 5: Run the tests and the lint**

Run:
```bash
swift build --build-tests 2>&1 | grep -Ei "warning|error|Build complete"
swift test --skip-build 2>&1 | tail -3
swift format lint --strict --recursive Sources Tests; echo "lint exit: $?"
```
Expected: `Build complete!` with no warnings, `Test run with 4 tests in 1 suite passed`, `lint exit: 0`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift .swift-format Sources Tests
git commit -m "Scaffold the NotchCore package with a JSON value type" -m "Refs #3. JSONValue holds raw stream payloads so diff merging can work on keys before anything is interpreted." -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: `NowPlaying` model (issue #3)

**Files:**
- Create: `Tests/NotchCoreTests/NowPlayingTests.swift`
- Create: `Sources/NotchCore/NowPlaying.swift`

**Interfaces:**
- Consumes: `JSONValue` and its `stringValue`, `boolValue`, `numberValue` accessors (Task 1).
- Produces: `public struct NowPlaying: Sendable, Equatable` with `bundleIdentifier: String`, `parentApplicationBundleIdentifier: String?`, `playing: Bool`, `title: String`, `artist: String?`, `album: String?`, `duration: Double?`, `elapsedTime: Double?`, `playbackRate: Double?`, a public memberwise `init` whose optional parameters default to `nil`, and an internal `init?(state: [String: JSONValue])` that returns `nil` when `bundleIdentifier`, `playing` or `title` is missing or mistyped.

- [ ] **Step 1: Write the failing test**

`Tests/NotchCoreTests/NowPlayingTests.swift`:
```swift
import Testing

@testable import NotchCore

@Suite struct NowPlayingTests {
    private let mandatory: [String: JSONValue] = [
        "bundleIdentifier": .string("com.apple.Music"),
        "playing": .bool(true),
        "title": .string("Song"),
    ]

    @Test func readsMandatoryKeysOnly() {
        let nowPlaying = NowPlaying(state: mandatory)
        #expect(
            nowPlaying
                == NowPlaying(bundleIdentifier: "com.apple.Music", playing: true, title: "Song"))
    }

    @Test func readsOptionalKeys() {
        var state = mandatory
        state["parentApplicationBundleIdentifier"] = .string("com.parent")
        state["artist"] = .string("Artist")
        state["album"] = .string("Album")
        state["duration"] = .number(215.5)
        state["elapsedTime"] = .number(12)
        state["playbackRate"] = .number(1)
        #expect(
            NowPlaying(state: state)
                == NowPlaying(
                    bundleIdentifier: "com.apple.Music",
                    parentApplicationBundleIdentifier: "com.parent",
                    playing: true,
                    title: "Song",
                    artist: "Artist",
                    album: "Album",
                    duration: 215.5,
                    elapsedTime: 12,
                    playbackRate: 1))
    }

    @Test(arguments: ["bundleIdentifier", "playing", "title"])
    func isNilWhenAMandatoryKeyIsMissing(missing: String) {
        var state = mandatory
        state[missing] = nil
        #expect(NowPlaying(state: state) == nil)
    }

    @Test func isNilWhenAMandatoryKeyHasTheWrongType() {
        var state = mandatory
        state["title"] = .number(7)
        #expect(NowPlaying(state: state) == nil)
    }

    @Test func ignoresAnOptionalKeyWithTheWrongType() {
        var state = mandatory
        state["artist"] = .number(5)
        #expect(NowPlaying(state: state)?.artist == nil)
        #expect(NowPlaying(state: state)?.title == "Song")
    }

    @Test func isNilForEmptyState() {
        #expect(NowPlaying(state: [:]) == nil)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error" | head -3`
Expected: FAIL with `cannot find 'NowPlaying' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NotchCore/NowPlaying.swift`:
```swift
/// What is playing right now, as reported by mediaremote-adapter.
///
/// `bundleIdentifier`, `playing` and `title` are the adapter's mandatory keys.
/// Everything else is optional because players report them unevenly.
public struct NowPlaying: Sendable, Equatable {
    public var bundleIdentifier: String
    public var parentApplicationBundleIdentifier: String?
    public var playing: Bool
    public var title: String
    public var artist: String?
    public var album: String?
    /// Track length in seconds.
    public var duration: Double?
    /// Elapsed time in seconds, as of the adapter's `timestamp`.
    public var elapsedTime: Double?
    public var playbackRate: Double?

    public init(
        bundleIdentifier: String,
        parentApplicationBundleIdentifier: String? = nil,
        playing: Bool,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: Double? = nil,
        elapsedTime: Double? = nil,
        playbackRate: Double? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.parentApplicationBundleIdentifier = parentApplicationBundleIdentifier
        self.playing = playing
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
    }
}

extension NowPlaying {
    /// Reads a `NowPlaying` out of the adapter's raw key/value state.
    ///
    /// Returns `nil` when a mandatory key is missing or has the wrong type, which
    /// is how "nothing is playing" looks. An optional key with the wrong type is
    /// treated as absent rather than failing the whole state.
    init?(state: [String: JSONValue]) {
        guard
            let bundleIdentifier = state["bundleIdentifier"]?.stringValue,
            let playing = state["playing"]?.boolValue,
            let title = state["title"]?.stringValue
        else {
            return nil
        }
        self.init(
            bundleIdentifier: bundleIdentifier,
            parentApplicationBundleIdentifier: state["parentApplicationBundleIdentifier"]?
                .stringValue,
            playing: playing,
            title: title,
            artist: state["artist"]?.stringValue,
            album: state["album"]?.stringValue,
            duration: state["duration"]?.numberValue,
            elapsedTime: state["elapsedTime"]?.numberValue,
            playbackRate: state["playbackRate"]?.numberValue
        )
    }
}
```

- [ ] **Step 4: Run the tests and the lint**

Run:
```bash
swift build --build-tests 2>&1 | grep -Ei "warning|error|Build complete"
swift test --skip-build 2>&1 | tail -2
swift format lint --strict --recursive Sources Tests; echo "lint exit: $?"
```
Expected: `Build complete!`, all tests pass (the `arguments:` test counts as 3 cases), `lint exit: 0`.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "Add the NowPlaying model" -m "Refs #3. Mandatory keys match mediaremote-adapter's (bundleIdentifier, playing, title); a wrongly typed optional key is treated as absent." -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: `NowPlayingStreamParser` (issue #3)

**Files:**
- Create: `Tests/NotchCoreTests/NowPlayingStreamParserTests.swift`
- Create: `Sources/NotchCore/NowPlayingStreamParser.swift`

**Interfaces:**
- Consumes: `JSONValue` (Task 1) and `NowPlaying.init?(state:)` (Task 2).
- Produces:
  - `public enum NowPlayingStreamError: Error, Equatable { case malformedJSON; case invalidEnvelope(String) }`
  - `public struct NowPlayingStreamParser: Sendable` with `init()`, `private(set) var state: [String: JSONValue]`, `var nowPlaying: NowPlaying?`, and `@discardableResult mutating func ingest(line: String) throws -> NowPlaying?`.
  - Behavior: blank lines are ignored; `diff: false` replaces the state and drops `null` values; `diff: true` merges and a `null` value removes its key; any thrown error leaves the state untouched.

- [ ] **Step 1: Write the failing test**

`Tests/NotchCoreTests/NowPlayingStreamParserTests.swift`:
```swift
import Testing

@testable import NotchCore

@Suite struct NowPlayingStreamParserTests {
    private func envelope(diff: Bool, _ payload: String) -> String {
        #"{"type":"data","diff":\#(diff),"payload":\#(payload)}"#
    }

    private let song =
        #"{"bundleIdentifier":"com.apple.Music","playing":true,"title":"Song","artist":"Artist"}"#

    // MARK: Full payloads

    @Test func fullPayloadProducesNowPlaying() throws {
        var parser = NowPlayingStreamParser()
        let result = try parser.ingest(line: envelope(diff: false, song))
        #expect(
            result
                == NowPlaying(
                    bundleIdentifier: "com.apple.Music", playing: true, title: "Song",
                    artist: "Artist"))
        #expect(parser.nowPlaying == result)
    }

    @Test func fullPayloadReplacesEarlierState() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let next = #"{"bundleIdentifier":"com.spotify.client","playing":false,"title":"Other"}"#
        let result = try parser.ingest(line: envelope(diff: false, next))
        #expect(
            result
                == NowPlaying(
                    bundleIdentifier: "com.spotify.client", playing: false, title: "Other")
        )
        #expect(parser.state["artist"] == nil)
    }

    @Test func fullPayloadDropsKeysThatAreNull() throws {
        var parser = NowPlayingStreamParser()
        let payload =
            #"{"bundleIdentifier":"com.apple.Music","playing":true,"title":"Song","album":null}"#
        try parser.ingest(line: envelope(diff: false, payload))
        #expect(parser.state["album"] == nil)
    }

    // MARK: Diffs

    @Test func diffMergesIntoTheLastFullState() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(
            line: envelope(diff: true, #"{"playing":false,"elapsedTime":42.5}"#))
        #expect(
            result
                == NowPlaying(
                    bundleIdentifier: "com.apple.Music", playing: false, title: "Song",
                    artist: "Artist", elapsedTime: 42.5))
    }

    @Test func diffCanStackOnEarlierDiffs() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        try parser.ingest(line: envelope(diff: true, #"{"album":"First"}"#))
        let result = try parser.ingest(line: envelope(diff: true, #"{"album":"Second"}"#))
        #expect(result?.album == "Second")
        #expect(result?.artist == "Artist")
    }

    @Test func nullKeyInADiffRemovesThatValue() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: true, #"{"artist":null}"#))
        #expect(result?.artist == nil)
        #expect(result?.title == "Song")
        #expect(parser.state["artist"] == nil)
    }

    @Test func nullingAMandatoryKeyClearsNowPlaying() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: true, #"{"title":null}"#))
        #expect(result == nil)
    }

    @Test func nullingAKeyThatWasNeverSetIsHarmless() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: true, #"{"genre":null}"#))
        #expect(result?.title == "Song")
    }

    @Test func diffBeforeAnyFullStateMergesIntoEmptyState() throws {
        var parser = NowPlayingStreamParser()
        let result = try parser.ingest(line: envelope(diff: true, #"{"title":"Song"}"#))
        #expect(result == nil)
        #expect(parser.state["title"] == .string("Song"))
    }

    // MARK: Empty and null payloads

    @Test func emptyFullPayloadMeansNothingIsPlaying() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        let result = try parser.ingest(line: envelope(diff: false, "{}"))
        #expect(result == nil)
        #expect(parser.state.isEmpty)
    }

    @Test func emptyDiffPayloadChangesNothing() throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        let after = try parser.ingest(line: envelope(diff: true, "{}"))
        #expect(after == before)
    }

    @Test func nullPayloadIsRejectedAndKeepsState() throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        #expect(throws: NowPlayingStreamError.self) {
            try parser.ingest(line: envelope(diff: false, "null"))
        }
        #expect(parser.nowPlaying == before)
    }

    @Test func missingPayloadIsRejected() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("\"payload\" must be an object")) {
            try parser.ingest(line: #"{"type":"data","diff":false}"#)
        }
    }

    // MARK: Malformed input

    @Test func malformedJSONIsRejectedAndKeepsState() throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        #expect(throws: NowPlayingStreamError.malformedJSON) {
            try parser.ingest(line: #"{"type":"data","diff":fal"#)
        }
        #expect(parser.nowPlaying == before)
    }

    @Test func plainTextIsMalformedJSON() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.malformedJSON) {
            try parser.ingest(line: "adapter started")
        }
    }

    @Test func nonObjectJSONIsAnInvalidEnvelope() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("expected a JSON object")) {
            try parser.ingest(line: "[1,2,3]")
        }
    }

    @Test func unexpectedTypeIsRejected() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("\"type\" must be \"data\"")) {
            try parser.ingest(line: #"{"type":"error","diff":false,"payload":{}}"#)
        }
    }

    @Test func missingDiffFlagIsRejected() {
        var parser = NowPlayingStreamParser()
        #expect(throws: NowPlayingStreamError.invalidEnvelope("\"diff\" must be a boolean")) {
            try parser.ingest(line: #"{"type":"data","payload":{}}"#)
        }
    }

    // MARK: Line handling

    @Test(arguments: ["", "   ", "\n", "\r\n"])
    func blankLinesAreIgnored(blank: String) throws {
        var parser = NowPlayingStreamParser()
        let before = try parser.ingest(line: envelope(diff: false, song))
        #expect(try parser.ingest(line: blank) == before)
    }

    @Test func toleratesTrailingNewlineAndCRLF() throws {
        var parser = NowPlayingStreamParser()
        let result = try parser.ingest(line: envelope(diff: false, song) + "\r\n")
        #expect(result?.title == "Song")
    }

    @Test func keepsUnicodeAndEscapedTitles() throws {
        var parser = NowPlayingStreamParser()
        let payload =
            #"{"bundleIdentifier":"b","playing":true,"title":"夜に駆ける \"Yoru\" é"}"#
        let result = try parser.ingest(line: envelope(diff: false, payload))
        #expect(result?.title == "夜に駆ける \"Yoru\" é")
    }

    // MARK: Realistic streams

    @Test func recoversAfterABadLine() throws {
        var parser = NowPlayingStreamParser()
        try parser.ingest(line: envelope(diff: false, song))
        #expect(throws: NowPlayingStreamError.malformedJSON) {
            try parser.ingest(line: "not json")
        }
        let result = try parser.ingest(line: envelope(diff: true, #"{"playing":false}"#))
        #expect(result?.playing == false)
        #expect(result?.title == "Song")
    }

    @Test func handlesAnArtworkSizedLineAndRemovesItAgain() throws {
        var parser = NowPlayingStreamParser()
        let artwork = String(repeating: "QUJD", count: 250_000)
        let payload = """
            {"bundleIdentifier":"b","playing":true,"title":"Song","artworkData":"\(artwork)"}
            """
        try parser.ingest(line: envelope(diff: false, payload))
        #expect(parser.state["artworkData"]?.stringValue?.count == 1_000_000)
        let result = try parser.ingest(line: envelope(diff: true, #"{"artworkData":null}"#))
        #expect(parser.state["artworkData"] == nil)
        #expect(result?.title == "Song")
    }

    @Test func microsKeysAreKeptButDoNotBreakNowPlaying() throws {
        var parser = NowPlayingStreamParser()
        let payload = """
            {"bundleIdentifier":"b","playing":true,"title":"Song",\
            "durationMicros":215000000,"elapsedTimeMicros":1000000}
            """
        let result = try parser.ingest(line: envelope(diff: false, payload))
        #expect(result?.title == "Song")
        #expect(result?.duration == nil)
        #expect(parser.state["durationMicros"] == .number(215_000_000))
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error" | head -3`
Expected: FAIL with `cannot find 'NowPlayingStreamParser' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NotchCore/NowPlayingStreamParser.swift`:
```swift
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
        return (isDiff, payload)
    }
}
```

- [ ] **Step 4: Run the tests and the lint**

Run:
```bash
swift build --build-tests 2>&1 | grep -Ei "warning|error|Build complete"
swift test --skip-build 2>&1 | grep -Ei "✘|failed|Test run with"
swift format lint --strict --recursive Sources Tests; echo "lint exit: $?"
```
Expected: `Build complete!` with no warnings, no `✘` lines, `Test run with 34 tests in 3 suites passed`, `lint exit: 0`.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "Parse mediaremote-adapter stream output into NowPlaying" -m "Refs #3. Full payloads replace the state, diffs merge into it, and a null key removes its value. A rejected line leaves the state untouched. Written fresh from the format in the mediaremote-adapter README." -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Verify issue #3 end to end and update the README

**Files:**
- Modify: `README.md` (the `## Status` and `## Building` sections)

**Interfaces:**
- Consumes: everything from Tasks 1 to 3.
- Produces: a branch that meets all four acceptance criteria of issue #3, verified on macOS and on Linux.

- [ ] **Step 1: Run the project's own verification skill**

Invoke `/swift-check` (Skill tool, `swift-check`).
Expected: three lines, all passed: `swift build --build-tests`, `swift test --skip-build`, `swift format lint --strict --recursive Sources Tests`.

- [ ] **Step 2: Prove the layering rule**

Run: `grep -rnE "import (AppKit|SwiftUI|Combine|Cocoa|UIKit)" Sources && echo VIOLATION || echo "clean"`
Expected: `clean`.

- [ ] **Step 3: Prove it builds and tests on Linux, the way CI does**

Run:
```bash
SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh build --build-tests --scratch-path .build-linux 2>&1 | tail -2
SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh test --skip-build --scratch-path .build-linux 2>&1 | tail -2
SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh format lint --strict --recursive Sources Tests; echo "lint exit: $?"
rm -rf .build-linux
```
Expected: `Build complete!`, `Test run with 34 tests in 3 suites passed`, `lint exit: 0`. (`.build-linux` keeps the Linux build separate from the macOS `.build`. It is deleted afterwards and is not ignored by git, so never commit it.)

- [ ] **Step 4: Update the README status and build sections**

In `README.md`, replace the `## Status` body with:
```markdown
Early scaffold. `NotchCore` (pure Swift, tested on Linux and macOS) has the first
piece of logic: a parser for mediaremote-adapter's `stream` output. The UI and
app targets are not started yet.
```
and the `## Building` body with:
```markdown
macOS 14+, Xcode. The core builds with SwiftPM:

    swift build --build-tests
    swift test --skip-build
    swift format lint --strict --recursive Sources Tests

The macOS app target will be added later.
```

- [ ] **Step 5: Commit and check nothing else is dirty**

```bash
git add README.md
git commit -m "Update the README for the NotchCore scaffold" -m "Closes #3 once merged." -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git status --short
```
Expected: `git status --short` shows only `?? docs/superpowers/`.

---

## Task 5: Harden Claude settings and set up worktrees (issue #4)

**Files:**
- Modify: `.gitignore`
- Modify: `.claude/settings.json` (comes from the cloud-config branch, merged in Step 2)

**Interfaces:**
- Consumes: the SessionStart hook registration and `.claude/rules/`, `.claude/hooks/`, `scripts/swift-in-docker.sh` from `origin/claude/custom-project-forked-template-tcln1h` (issue #1, cloud sessions only: the hook exits immediately unless `CLAUDE_CODE_REMOTE=true`).
- Produces: a schema-valid `.claude/settings.json` with an allowlist for routine commands, a denylist for secrets, and `worktree.baseRef: "head"`, plus the ignore rules that keep local Claude files out of `git status`.

Decision recorded here for `CLAUDE.md` in Task 6: `worktree.baseRef` is `"head"`, because work here is local and unpushed for long stretches, and `"fresh"` would branch subagent worktrees from `origin/main` and silently drop that work. No `.worktreeinclude` yet: no gitignored file is needed inside a worktree.

- [ ] **Step 1: Branch from the issue #3 branch**

The three branches are stacked (3, then 4, then 5) so the headless checks in Steps 6 and 7 have a real package to build. Each branch still carries only its own issue's changes.

Run: `git switch claude/issue-3-notchcore && git switch -c claude/issue-4-claude-settings`
Expected: `Switched to a new branch 'claude/issue-4-claude-settings'`.

- [ ] **Step 2: Merge the cloud-config branch (this is issue #1, the dependency)**

Run:
```bash
git merge --no-ff origin/claude/custom-project-forked-template-tcln1h -m "Merge the cloud session config (issue #1)" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git ls-files .claude scripts .github | head -30
```
Expected: a clean merge (already dry-run: no conflicts). The listing includes `.claude/settings.json`, `.claude/hooks/session-start.sh`, `.claude/rules/code-search.md`, `.claude/rules/reading-files.md`, `scripts/swift-in-docker.sh`, `.github/labels.yml`, `.github/workflows/labels.yml`.

- [ ] **Step 3: Write the settings**

Replace `.claude/settings.json` with:
```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(swift build)",
      "Bash(swift build *)",
      "Bash(swift test)",
      "Bash(swift test *)",
      "Bash(swift format)",
      "Bash(swift format *)",
      "Bash(git status)",
      "Bash(git status *)",
      "Bash(git diff)",
      "Bash(git diff *)",
      "Bash(git log)",
      "Bash(git log *)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./**/*.p12)",
      "Read(./**/*.mobileprovision)",
      "Read(./**/*.cer)"
    ]
  },
  "worktree": {
    "baseRef": "head"
  }
}
```

- [ ] **Step 4: Add the ignore rules**

Append to `.gitignore`, after the `# Editor` block:
```gitignore

# Claude Code: personal settings, personal instructions, and worktree checkouts
.claude/settings.local.json
CLAUDE.local.md
.claude/worktrees/
```

- [ ] **Step 5: Validate the settings against the published schema**

Run:
```bash
SP=/private/tmp/claude-501/-Users-patricklarocque-Developer-notch-suite/9150f06e-c963-46c7-b45e-4bd9d8b913cc/scratchpad
python3 -m venv $SP/venv && $SP/venv/bin/pip install -q jsonschema
$SP/venv/bin/python - <<'PY'
import json, jsonschema, os
sp = "/private/tmp/claude-501/-Users-patricklarocque-Developer-notch-suite/9150f06e-c963-46c7-b45e-4bd9d8b913cc/scratchpad"
schema = json.load(open(f"{sp}/claude-settings.schema.json"))
settings = json.load(open(".claude/settings.json"))
jsonschema.validate(settings, schema)
print("settings.json is valid against the schema")
PY
```
Expected: `settings.json is valid against the schema`. If the schema file is missing, re-download it: `curl -fsSL https://json.schemastore.org/claude-code-settings.json -o $SP/claude-settings.schema.json`. The venv lives in the scratchpad, so nothing is installed globally.

- [ ] **Step 6: Verify the deny rule and the allow rule with a real headless session**

Run:
```bash
printf 'FAKE_SECRET=do-not-print\n' > .env
claude -p "Use the Read tool on ./.env and print exactly what it returns." --max-turns 3 2>&1 | tail -5
echo "--- allow rule ---"
claude -p "Run: swift test --skip-build. Report only the last line of output." --max-turns 3 2>&1 | tail -3
rm -f .env
```
Expected: the first reply says the read was denied and does not contain `do-not-print`; the second prints the `Test run with 34 tests ... passed` line without asking for permission. Headless mode denies (rather than prompts for) anything not allowed, so a passing `swift test` shows the allow rule works. Confirm `.env` is gone: `ls .env` should fail.

- [ ] **Step 7: Verify a worktree builds, tests, and stays out of `git status`**

Run:
```bash
claude -w verify-worktree -p "Run: pwd; git branch --show-current; swift build --build-tests 2>&1 | tail -1" --max-turns 4 2>&1 | tail -6
ls .claude/worktrees/
git status --short
```
Expected: the reply shows a path under `.claude/worktrees/verify-worktree`, branch `worktree-verify-worktree`, and `Build complete!`. `git status --short` in the main checkout does not list `.claude/worktrees/`. Clean up with `git worktree remove .claude/worktrees/verify-worktree --force && git branch -D worktree-verify-worktree`. If `claude -w` in headless mode is not supported, do the same by hand: `git worktree add .claude/worktrees/verify-worktree -b worktree-verify-worktree`, run `swift build --build-tests && swift test --skip-build` inside, check `git status`, then remove it as above, and note in Task 7's report that the CLI flag itself was not exercised.

- [ ] **Step 8: Commit**

```bash
git add .gitignore .claude/settings.json
git commit -m "Harden Claude settings and ignore local Claude files" -m "Closes #4 once merged. Allows routine swift and read-only git commands, denies reading .env and signing material, validates against the published schema, and sets worktree.baseRef to head so unpushed work carries into subagent worktrees." -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git status --short
```
Expected: only `?? docs/superpowers/` remains.

---

## Task 6: Write `CLAUDE.md` and the path-scoped rules (issue #5)

**Files:**
- Create: `CLAUDE.md`
- Create: `.claude/rules/swift-core.md`
- Create: `.claude/rules/ci.md`

**Interfaces:**
- Consumes: the commands from Tasks 1 to 4, the worktree decision from Task 5, the existing `code-search.md` and `reading-files.md` rules, and the skills and agents from the template.
- Produces: a `CLAUDE.md` of at most 200 lines whose every command runs as written on this Mac, and two rules files that load only for their paths.

- [ ] **Step 1: Branch from the issue #4 branch**

Run:
```bash
git switch claude/issue-4-claude-settings && git switch -c claude/issue-5-claude-md
ls Package.swift .claude/settings.json
```
Expected: both files exist (this branch already contains issues #3 and #4).

- [ ] **Step 2: Write `CLAUDE.md`**

````markdown
# Notch Suite

A macOS notch utility built from scratch: Now Playing media control, a file drop shelf, and system HUD replacements. GPLv3. Only `NotchCore` exists so far; the UI and app targets are planned.

## Architecture

Three layers, each depending only on the one before it:

1. `NotchCore` (`Sources/NotchCore`): pure Swift with no AppKit, SwiftUI, or Combine. It builds and tests on Linux. Use `Observation` and async sequences for reactive state.
2. `NotchUI` (planned): SwiftUI views. macOS only.
3. App target (planned): the macOS app and its system integration.

Mac-only services (MediaRemote, screen and notch geometry, the file system, AirDrop) sit behind protocols defined in `NotchCore` and are implemented in the app target. That keeps the logic testable on Linux.

## Commands

Run from the repository root.

```sh
swift build --build-tests
swift test --skip-build
swift format lint --strict --recursive Sources Tests
```

- `/swift-check` runs all three in order and reports one line per step. Run it before every push.
- To fix formatting: `swift format format --in-place --recursive Sources Tests`.
- On a Mac these run natively. In Claude Code cloud sessions `swift` is a wrapper that runs Linux Swift in Docker (`.claude/hooks/session-start.sh`).
- To run what CI's Linux job runs, from a Mac: `SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh test`.
- The macOS app build command will be added here once the app target exists.
- `.swift-version` pins swiftly's toolchain for this folder and is gitignored. CI uses Xcode's Swift on macOS and the `swift:6.4-noble` image on Linux.

## License rules

The project is GPLv3. Code adapted from these projects keeps its original copyright notice and gets an entry in `THIRD_PARTY_LICENSES`:

- boring.notch (GPLv3)
- NotchDrop (MIT)
- mediaremote-adapter (BSD-3-Clause)

Follow `/port-from-reference` whenever code from them is copied or closely followed. The forks `patlar104/boring.notch`, `patlar104/notchdrop` and `patlar104/mediaremote-adapter` are for reading, never for pushing to. Run the `license-auditor` agent before merging a PR that ports code.

## Workflow

- One branch per issue, named `claude/issue-<N>-<slug>`. Open a draft PR that follows `.github/pull_request_template.md` and says `Closes #N`.
- Run `/swift-check` before pushing. `/work-issue <N>` does the whole loop for one issue; the `feature-worker` agent runs it in its own worktree so issues can proceed in parallel.
- Linux first, macOS only when needed. macOS minutes on GitHub-hosted runners count 10x, so that job waits for the Linux job and skips draft PRs. The repository variable `CI_RUNNER=self-hosted` moves both jobs to the owner's Mac (`docs/self-hosted-runner.md`); fork PRs always stay on hosted runners.
- Check CI with `/ci-status`. Use the `macos-ci-investigator` agent for a failing macOS job.
- Ask the `reference-scout` agent how the reference projects solve something, instead of cloning them into this repo.

## Worktrees

`claude --worktree <name>` creates `.claude/worktrees/<name>/` on branch `worktree-<name>`. `swift build` and `swift test` work inside it. `${CLAUDE_PROJECT_DIR}` in hooks deliberately stays at the main checkout.

`worktree.baseRef` is `"head"` in `.claude/settings.json`, so worktrees branch from local HEAD and carry unpushed commits. Change it to `"fresh"` to branch from `origin/main` instead. There is no `.worktreeinclude`: no gitignored file is needed inside worktrees yet. Add one if that changes.

## Where the details live

- `.claude/rules/swift-core.md`: rules for `Sources/NotchCore` and its tests (loads only when those files are touched).
- `.claude/rules/ci.md`: rules for `.github/workflows` (loads only when those files are touched).
- `.claude/rules/code-search.md`, `.claude/rules/reading-files.md`: how to search and read files.
````

- [ ] **Step 3: Write the two path-scoped rules**

`.claude/rules/swift-core.md`:
```markdown
---
paths:
  - "Sources/NotchCore/**"
  - "Tests/NotchCoreTests/**"
---

# NotchCore rules

- Never import `AppKit`, `SwiftUI`, `Combine`, `Cocoa`, or `UIKit`. The Linux build fails if you do. Foundation is fine.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Use `@testable import NotchCore` to reach internal API.
- The package builds in Swift 6 language mode. Make public types `Sendable` value types unless there is a reason not to. Don't use `@unchecked Sendable` without a comment saying why it is safe.
- Reactive state uses `Observation` or async sequences.
- A Mac-only service gets a protocol here and its implementation in the app target.
- Code adapted from the reference projects follows `/port-from-reference`.
- Run `/swift-check` before pushing.
```

`.claude/rules/ci.md`:
```markdown
---
paths:
  - ".github/workflows/**"
---

# Workflow rules

- Every job sets `timeout-minutes`.
- Set `permissions:` explicitly and as narrowly as the job allows.
- Workflows triggered by pushes or comments use a `concurrency` group. CI cancels in-progress runs on the same ref; the Claude workflows queue instead, so a reply is not cut off.
- Pin actions to a major version tag such as `actions/checkout@v6`. Never `@main` or `@latest`.
- macOS jobs cost 10x on GitHub-hosted runners. Keep them behind the Linux job (`needs:`), skip draft PRs when hosted, and add one only when a change needs macOS.
- Runner choice goes through the `CI_RUNNER` repository variable. Fork PRs must always stay on GitHub-hosted runners. Keep the existing `runs-on` expression's shape when adding a job.
- Swift on macOS runs as `xcrun swift`, so a swiftly toolchain can't replace Xcode's compiler. Swift on Linux runs through `scripts/ci-swift.sh`.
```

- [ ] **Step 4: Check the size and that every command in `CLAUDE.md` runs as written**

Run:
```bash
wc -l CLAUDE.md
swift build --build-tests 2>&1 | tail -1
swift test --skip-build 2>&1 | tail -1
swift format lint --strict --recursive Sources Tests; echo "lint exit: $?"
swift format format --in-place --recursive Sources Tests && git status --short
SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh test --scratch-path .build-linux 2>&1 | tail -1; rm -rf .build-linux
```
Expected: well under 200 lines, `Build complete!`, all tests pass, `lint exit: 0`, the in-place format changes no files (only `?? docs/superpowers/` in `git status`), and the Linux test run passes. Not verifiable here: the cloud-session wrapper (it needs a cloud session); say so in the Task 7 report.

- [ ] **Step 5: Improve `CLAUDE.md` with the claude-md-management plugin**

Invoke the `claude-md-management:claude-md-improver` skill on `CLAUDE.md` and read its quality report. Apply changes that fix a contradiction, a wrong command, or a missing fact. Reject changes that only add length. Re-run Step 4's `wc -l CLAUDE.md` afterwards.

- [ ] **Step 6: Confirm the frontmatter and that the rules load only for their paths**

Ask the `claude-code-guide` agent: "In Claude Code 2.1.283, what is the frontmatter syntax for a `.claude/rules/*.md` file that should load only for matching paths? Is `paths:` a YAML list of globs?" Compare its answer with the two rules files above and fix them if it differs. Then check by hand from this checkout:
```bash
claude -p "List every instruction file you have loaded right now (CLAUDE.md and .claude/rules/*). Do not read any files." --max-turns 2 2>&1 | tail -12
```
Expected: `CLAUDE.md`, `code-search.md` and `reading-files.md` are present, and `swift-core.md` and `ci.md` are not, since no matching file has been touched.

- [ ] **Step 7: Check the rules for contradictions**

Read `CLAUDE.md`, `swift-core.md`, `ci.md`, `code-search.md` and `reading-files.md` together once. Any two lines that give different instructions for the same situation get fixed now. Known pairs to check: the branch naming rule (CLAUDE.md) against the `feature-worker` and `work-issue` wording, and the CI concurrency line against `ci.yml` (cancel-in-progress) and `claude.yml` (queue).

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md .claude/rules
git commit -m "Write CLAUDE.md and path-scoped Claude rules" -m "Closes #5 once merged. Documents the layering rule, the commands that now exist, license rules, the workflow, and the worktree decision from #4." -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Review loop, then hand off

**Files:**
- Modify: whatever the review findings require.
- Create (commit): `docs/superpowers/plans/2026-09-28-notchcore-scaffold.md` (this plan).

**Interfaces:**
- Consumes: the three finished, stacked branches (`claude/issue-3-notchcore`, then `claude/issue-4-claude-settings` on top of it, then `claude/issue-5-claude-md` on top of that).
- Produces: branches with no open high-confidence findings, and a short report. Nothing is pushed.

The loop runs at most three rounds. A round is: review, triage the findings, fix what is real, re-verify. Stop early when a round produces no high-confidence finding.

- [ ] **Step 1: Round 1 reviews on the issue #3 branch (in parallel)**

`git switch claude/issue-3-notchcore`, then launch these together:
- `core-verifier` agent (the project's own): build, test and lint report with `file:line`.
- `license-auditor` agent (the project's own). Expected result: nothing ported. The parser was written from the README's format; if the auditor flags anything, that is real.
- `pr-review-toolkit:code-reviewer` on `git diff main...HEAD`.
- `pr-review-toolkit:silent-failure-hunter` on the parser's error handling (`try?` in `JSONValue.init(from:)`, the catch in `decodeEnvelope`).
- `pr-review-toolkit:pr-test-analyzer` on the three test files against issue #3's acceptance criteria.
- `pr-review-toolkit:type-design-analyzer` on `JSONValue`, `NowPlaying` and `NowPlayingStreamParser`.
- `code-simplifier:code-simplifier` on `Sources/NotchCore`.

- [ ] **Step 2: Triage and fix**

For each finding: reproduce it or read the code to confirm it; if it holds, write a failing test first when it is a behavior bug, fix it, and re-run `/swift-check`. Reject a finding that is a style preference the `.swift-format` config already settles, or that would add code no test or requirement needs (YAGNI), and say why in the report. Commit fixes on the branch they belong to as `Address review: <what>`.

- [ ] **Step 3: Round 1 reviews on the config branches**

- On `claude/issue-4-claude-settings`: `pr-review-toolkit:code-reviewer` on the settings diff. Question to answer: does anything in `permissions.allow` let a routine command do more than intended (`swift format *` includes `--in-place`, which is intended), and does `permissions.deny` miss a secret path.
- On `claude/issue-5-claude-md`: `claude-md-management:claude-md-improver` once more, and `plugin-dev:skill-reviewer` on `.claude/skills/*/SKILL.md`, since the skills came from a template and now have a real package to run against. If it finds a skill referencing something that does not exist (a file, a command, a `$ARGUMENTS` name), fix the skill in this branch.
- `plugin-dev:agent-development` guidance: check `.claude/agents/*.md` frontmatter (`tools`, `model`, `skills`, `isolation`) against what Claude Code accepts, and fix any field that is wrong.
- **Local fallbacks for the GitHub-MCP agents.** `macos-ci-investigator` lists only `mcp__github__*` tools for GitHub access and `reference-scout` says "read them with the GitHub tools". The GitHub MCP server is not connected in local sessions (it failed to connect at the start of this one), so neither agent tells a local session what to do. Add one line to each agent's body, on the `claude/issue-5-claude-md` branch:
  - `macos-ci-investigator`: "In local sessions, where the GitHub MCP tools are unavailable, use `gh run list`, `gh run view <id> --log-failed` and `gh run download <id>` through Bash."
  - `reference-scout`: "In local sessions, use `gh api repos/<owner>/<repo>/contents/<path>` and `gh search code --repo <owner>/<repo> <query>` through Bash, or clone shallowly into a temporary directory."
  Then confirm the frontmatter is unchanged and commit as `Give the GitHub agents a local gh fallback`.

- [ ] **Step 4: Rounds 2 and 3 as needed**

Re-run only the reviewers whose findings changed code, on the new diff. Fixes belong on the branch of the issue they concern. After a fix on `claude/issue-3-notchcore`, merge it forward: `git switch claude/issue-4-claude-settings && git merge claude/issue-3-notchcore`, then `git switch claude/issue-5-claude-md && git merge claude/issue-4-claude-settings`. Re-run `/swift-check` on the branch you land on.

- [ ] **Step 5: Final verification**

On `claude/issue-5-claude-md` run `/swift-check`, then:
```bash
git log --oneline main..HEAD
git status --short
git diff --stat main..HEAD | tail -3
```
Expected: `/swift-check` passes, and the commits read as focused units (one scaffold commit per Task 1 to 3, the README, the settings, `CLAUDE.md`, plus any `Address review:` fixes). `git status` shows only the plan file.

- [ ] **Step 6: Commit this plan and report**

```bash
git add docs/superpowers/plans/2026-09-28-notchcore-scaffold.md
git commit -m "Add the NotchCore scaffold implementation plan" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
Then report to the user, in this order: what passed and was verified (macOS, Linux, lint, layering, schema, the deny and allow rules, the worktree), what could not be verified locally (the cloud-session Docker wrapper, the Claude GitHub Action, the CI workflows on GitHub itself), review findings fixed and rejected with the reason, and the exact push and PR commands for the three branches, left for the user to run. Remind the user that the PR base needs the template commits (`a0ba01c` and its parent) merged first, and that the `CLAUDE_CODE_OAUTH_TOKEN` secret (issue #10) is still unset.
