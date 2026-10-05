# Architecture phase 1: media identity and ownership

Follows the architecture review in PR #49 (snapshot of `8ee5162`). This note records what
phase 1 changed and the plans it deliberately left for later. The review's other
findings still hold.

## What changed

| Change | Files |
| --- | --- |
| `AppIdentity`: optional bundle and process identifiers, compared without treating two unknowns as a match | `Sources/NotchCore/AppIdentity.swift` |
| `NowPlaying.app` replaces the required `bundleIdentifier`; a session needs only `playing` and `title` | `Sources/NotchCore/NowPlaying.swift` |
| `NowPlayingReport` (`noSession`, `session`, `incomplete`) from the parser; `processIdentifier` validated | `Sources/NotchCore/NowPlayingStreamParser.swift` |
| `isSameTrack` uses identity only where it can decide | `Sources/NotchCore/PlaybackState.swift` |
| `artworkData` moved next to the parser | `Sources/NotchCore/ArtworkState.swift`, `NowPlayingStreamParser.swift` |
| `AppIdentityResolver`: PID or bundle ID to name and icon, with a PID-reuse check | `App/Media/AppIdentityResolver.swift` |
| `AppEnvironment` composition root owned by `AppDelegate`; `NotchPanelController` receives its model and providers | `App/AppEnvironment.swift`, `App/NotchPanelController.swift`, `App/NotchSuiteApp.swift` |

## Why the identity contract changed

The review assumed `bundleIdentifier` was the adapter's mandatory key, as its README
says. The adapter's source (`src/adapter/keys.m`, `mandatoryPayloadKeys`) requires
`processIdentifier`, `playing` and `title`, and adds `bundleIdentifier` only when
`NSRunningApplication` can resolve the process. A report without it is normal.

This project requires only `playing` and `title`. A report with no identity at all
is a session with unknown identity, not a malformed one: showing and controlling the
track doesn't depend on identity, since commands always go to the system's current
player (adapter issue #41). The full contract table is in `App/Media/README.md`.

## Ownership after phase 1

```text
AppDelegate
 `-- AppEnvironment
      |-- IslandStateMachine (TaskDelayScheduler)
      |-- IslandModel (stateMachine, geometry)
      |-- AppIdentityResolver
      `-- NotchPanelController (model, ScreenNotchGeometryProvider, WorkspaceReduceMotionProvider)
           |-- NotchPanel
           `-- IslandHostingView -> IslandView
[Debug] HUDSpikeController (still separate; see below)
```

## Deferred, with the plan for each

**HUD spike consolidation (separate small change).** `HUDSpikeController` creates its
own `NotchPanel`, `IslandStateMachine` and `HUDSpikeDelayScheduler` (a copy of
`TaskDelayScheduler`). It calls `machine.hudKeyPressed(kind)` and reads `machine.hud`,
both of which the main state machine already has. Steps:

1. `startIfEnabled` takes `AppEnvironment.stateMachine` instead of creating a machine.
2. Delete `HUDSpikeDelayScheduler` and `HUDSpikeDelay`.
3. Draw the HUD inside `IslandView` when `stateMachine.hud != nil`, using
   `HUDSpikeView`'s level view, and delete the spike's `NotchPanel` and positioning.
4. Keep the key tap, audio and brightness observers and the status menu as they are.

Step 3 adds HUD content to `IslandView`, which changes visible behavior, so it belongs
in the #26 work rather than in this refactor.

**Settings persistence.** Add `UserDefaultsSettingsStore: SettingsStore` in `App`. In
`AppEnvironment.init`, load it and assign `stateMachine.settings` before `start()`, and
save on change from the settings window (#28).

**Display placement.** Replace `ScreenNotchGeometryProvider.screen`'s fixed "built-in,
else main" choice with `DisplayPlacement.placements(for:showOn:)`, and have
`AppEnvironment` create one `NotchPanelController` per placement, rebuilt on screen
changes.

**ActivityCenter.** Not built. It belongs in `NotchCore` between providers and
`IslandStateMachine` once a second real activity (charging, #27) defines priority and
lifetime rules.

**IslandMode rename.** Not done. `IslandMode` may stay as "what the island is showing"
alongside a future `ActivityKind` ("what exists"); decide when `ActivityCenter` lands.
