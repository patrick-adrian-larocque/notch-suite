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
| `MediaRemoteNowPlayingSource` | `MediaRemoteNowPlayingSource.swift` | Done. Applies the contract below; started and stopped by `AppEnvironment`. |
| `NowPlayingPresentation` and views | `NowPlayingPresentation.swift` | TODO comments only. |

The source runs from launch, but nothing draws it yet: the island still shows idle.

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
  -> IslandView, Now Playing views                                  [TODO, App]
```

`AppEnvironment` creates and starts the source and the presentation model, gives the
presentation model the `stateMachine` and `appIdentityResolver`, and stops the engine
on termination. Nothing else creates media objects.

## Next steps, in order

1. `NowPlayingPresentation` and compact, peek and open views.
2. Show `MediaRemoteEngine.Status.failed` and `.unavailable` instead of an idle island.
3. Stop the adapter on sleep and start it on wake.
4. Hands-on check with Music and Spotify.

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
