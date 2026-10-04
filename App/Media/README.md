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
| `MediaRemoteEngine` | `MediaRemoteEngine.swift` | TODO comments only. |
| `MediaRemoteNowPlayingSource` | `MediaRemoteNowPlayingSource.swift` | TODO comments only. |
| `NowPlayingPresentation` and views | `NowPlayingPresentation.swift` | TODO comments only. |

No engine, fake player, or no-op `NowPlayingSource` is installed yet.

## The media contract

| Adapter output | `NowPlayingReport` | Source yields | `PlaybackState` |
| --- | --- | --- | --- |
| `"payload": {}` | `.noSession` | `nil` | `.stopped(lastPlayed:)` |
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
mediaremote-adapter (perl child)       MediaRemoteEngine            [TODO, App]
  -> stdout lines                      line buffer                  [TODO, App]
  -> NowPlayingStreamParser.ingest     -> NowPlayingReport          [NotchCore]
  -> MediaRemoteNowPlayingSource       .session -> NowPlaying       [TODO, App]
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

1. `MediaRemoteEngine`: bundle the pinned adapter, run `stream`, buffer lines, restart
   with backoff, stop on quit; report engine failure separately from `.noSession`.
2. `MediaRemoteNowPlayingSource`: apply the contract table above; map `MediaCommand`
   to `send` IDs.
3. `NowPlayingPresentation` and compact, peek and open views.
4. Hands-on check with Music and Spotify.
