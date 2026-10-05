# Media integration (#24)

Requirements, sources and open questions: `docs/requirements/now-playing.md` on the #24
branch. Architecture background: `docs/architecture-review.md`.

## What exists

| Piece | Where | Status |
| --- | --- | --- |
| `AppIdentity` | `Sources/NotchCore/AppIdentity.swift` | Done. Optional bundle and process identifiers; `isSameApplication(as:)` never treats two unknowns as a match. |
| `NowPlaying` | `Sources/NotchCore/NowPlaying.swift` | Done. A session needs `playing` and `title`; `app` is optional identity. |
| `NowPlayingStreamParser`, `NowPlayingReport` | `Sources/NotchCore/NowPlayingStreamParser.swift` | Done. Reports `noSession`, `session`, or `incomplete`; malformed lines throw and keep the last state. |
| `PlaybackState`, `PlaybackProgress`, `ArtworkTracker` | `Sources/NotchCore/` | Done. |
| `AppIdentityResolver` | `App/Media/AppIdentityResolver.swift` | Done. PID or bundle ID to bundle ID, name and icon, with a PID-reuse check. |
| `AppEnvironment` | `App/AppEnvironment.swift` | Done. Owns app-level objects; the media source goes here. |
| mediaremote-adapter | `Vendor/mediaremote-adapter/` | Bundled, unmodified, pinned to `73f14ab`. |
| `MediaRemoteEngine` | `MediaRemoteEngine.swift` | Done. Adapted from boring.notch: runs `stream`, splits lines, restarts with backoff, runs `send`. |
| `MediaRemoteNowPlayingSource` | `MediaRemoteNowPlayingSource.swift` | Done. Applies the contract below; started and stopped by `AppEnvironment`. Implements `NowPlayingSource`'s `artworkUpdates()` and `healthUpdates()` streams as well as `nowPlayingUpdates()`. |
| `NowPlayingPresentation` | `NowPlayingPresentation.swift` | Done. Depends on `any NowPlayingSource`, not the concrete type, so tests can drive it with a fake. |
| Compact, peek and open views | `NowPlayingIslandView.swift` | Done: artwork, eq bars, title, progress, transport controls, an engine-down subtitle. `#Preview`s with sample data cover all three levels. |

The source runs from launch and the island now shows it: a session moves the island
into `.nowPlaying` and back to idle when it ends. Sleep/wake is handled in
`AppEnvironment` (stop on `willSleep`, restart on `didWake`). Both have been checked live
(see "Live checks and what's left").

## Testing

- **Previews**: `NowPlayingIslandView.swift` has `#Preview`s for compact, peek, open,
  open while paused with artwork loading, and open with the engine down. They use
  `NowPlayingPresentation.preview(...)`, a `DEBUG`-only factory in
  `NowPlayingPresentation.swift` that sets sample state directly and never touches the
  real adapter process. Open the file in Xcode and use the canvas (⌥⌘↩).
- **Unit tests**: the `NotchSuiteTests` target (`AppTests/`, macOS-only, not part of the
  `swift test` package) exercises `NowPlayingPresentation` over `FakeNowPlayingSource`
  (`AppTests/Media/FakeNowPlayingSource.swift`), a lock-backed fake conforming to
  `NowPlayingSource`. Covers a session starting and ending, artwork arriving after the
  track, engine health flipping `isEngineDown`, and a failed command setting
  `lastCommandError`. Run it from the `NotchSuiteTests` scheme in Xcode. The tests are
  hosted by the app, so `AppDelegate` skips building `AppEnvironment` when
  `XCTestConfigurationFilePath` is set; otherwise each run left an orphaned adapter behind
  (the runner ends the host without `applicationWillTerminate`).

## The media contract

| Adapter output | `NowPlayingReport` | Source yields | `PlaybackState` |
| --- | --- | --- | --- |
| `"payload": {}` | `.noSession` | `nil` (the first line of each stream waits 0.5 s, since every stream starts with one) | `.stopped(lastPlayed:)` |
| `playing` and `title`, any identity | `.session(NowPlaying)` | the `NowPlaying` | `.playing` or `.paused` |
| state with keys but missing `playing` or `title` | `.incomplete(missingKeys:)` | nothing (keep last) | unchanged |
| bad JSON, bad envelope, wrongly typed known key | `ingest` throws | nothing (keep last), log it | unchanged |

Identity is never required. The adapter always sends `processIdentifier` and adds
`bundleIdentifier` only when it can look the process up, so a report without a bundle
identifier is normal (seen on macOS 27.2). A report with no identity at all is still a
session with `AppIdentity.unknown`: the track is shown and controlled the same way,
because commands always go to the system's current player.

## Data flow and ownership

```text
mediaremote-adapter (perl child)       MediaRemoteEngine            [App]
  -> stdout lines                      line buffer                  [App]
  -> NowPlayingStreamParser.ingest     -> NowPlayingReport          [NotchCore]
  -> MediaRemoteNowPlayingSource       .session -> NowPlaying       [App]
                                       .noSession -> nil
                                       .incomplete / throws -> keep last, log
  -> NowPlayingPresentation            PlaybackState.updated(with:) [NotchCore]
                                       PlaybackProgress, ArtworkTracker
                                       AppIdentityResolver.resolve(app) when app changes
  -> IslandStateMachine.selectMode(.nowPlaying)                     [NotchCore]
  -> IslandView, NowPlayingIslandView                                [App]
```

`NowPlayingPresentation` depends on `any NowPlayingSource` (the `NotchCore` protocol),
not the concrete `MediaRemoteNowPlayingSource`, and reaches artwork and engine health
through that protocol's `artworkUpdates()` and `healthUpdates()` streams rather than
closures on the concrete type. That's what lets `NotchSuiteTests` drive it with a fake.

`AppEnvironment` creates and starts the source and the presentation model, gives the
presentation model the `stateMachine` and `appIdentityResolver`, and stops the engine
on termination. Nothing else creates media objects.

## Live checks and what's left

Checked live on macOS 27.2 (2026-10-04): Music and Spotify updates, transport controls,
long-title truncation, and two real sleep/wake cycles (one adapter before, none during
`willSleep`, a new single adapter after wake, same app process, updates resumed).

Not yet checked live: eq bars when paused or with reduce motion, long titles at the compact
level, and a force-quit or crash of the app, which orphans the adapter (only a normal quit
stops it).

Design choice, not a requirement: `suspend()` goes through `MediaRemoteEngine.stop()`, which
resets the retry backoff, so a wake starts a new operating period at the initial 1 s delay.

## Checking it live

Debug builds log each update, resolve its app, and send `pause` once when launched with:

```sh
open -n build/DerivedData/Build/Products/Debug/NotchSuite.app --args -NowPlayingProbe YES
log stream --level info --predicate 'subsystem == "com.patricklarocque.NotchSuite" AND category == "MediaRemote"'
```

Play something, and expect `probe: update playing=true app=<name> icon=true`, then
`probe: pause sent` and a paused update. Quitting the app must leave no `perl` process
(`pgrep -fl mediaremote-adapter`). Note: `send` exits 0 even when no player received
the command, so a successful `send` only means the adapter ran.
