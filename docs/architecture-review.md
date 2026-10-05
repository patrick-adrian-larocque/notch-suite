# Architecture review

Snapshot of `main` at `8ee5162` (2026-10-03). Based on the code as it is, not on plans.
Update or replace this file when the architecture changes.

## Summary

The project is small (about 4,400 lines over two targets; the largest file is 381 lines)
and the split between the portable `NotchCore` package and the macOS `App` target is
clean. The island's layout, timing and drawing are well built and tested. The data side
is not: there is no media engine yet, most core models are not connected to the app,
and nothing collects or ranks activities.

The media path does not run yet. Its parsing and state pieces exist and are tested in
`NotchCore`, but `App/Media/*` contains only TODO comments and there is no Now Playing
view.

## 1. What exists today

| Area | Where | What it actually is |
| --- | --- | --- |
| Entry point | `App/NotchSuiteApp.swift` | `NotchSuiteApp` shows a menu bar item with only Quit. `AppDelegate.applicationDidFinishLaunching` creates `NotchPanelController` and, in Debug builds, starts the HUD spike. |
| Island UI | `App/` | `NotchPanel` is the borderless window. `NotchPanelController` positions it, tracks the mouse, and builds the objects below it. `IslandHostingView` limits clicks to the island. `IslandView` draws the island by switching on mode and level; only open idle has content (`IdleOpenView`). `NotchShape`, `IslandTokens`, `IslandMotion` and `IslandControls` are styling and small controls. |
| UI state | `App/IslandModel.swift`, `Sources/NotchCore/IslandStateMachine.swift` | `IslandStateMachine` owns which mode is showing, how expanded it is, any alert, the volume/brightness takeover (HUD), and hover. It is the only live state. `IslandModel` combines it with the notch measurements and the Reduce Motion setting. |
| Media | `NotchCore`: `NowPlaying`, `NowPlayingStreamParser`, `JSONValue`, `PlaybackState`, `PlaybackProgress`, `ArtworkTracker`, `NowPlayingSource`, `MediaCommand`. `App/Media/*`: TODO comments only. | The core pieces are tested but nothing uses them. |
| App / bundle ID handling | `NowPlaying.bundleIdentifier`, a required `String` | That one field is the whole story. There is no app identity type, no app name or icon lookup, and the process ID the adapter sends is ignored. |
| Other models, unused by the app | `TimerState`, `BatteryState`, `ShelfStore`, `ShelfItem`, `DisplayPlacement`, `IslandStyle` | All tested, none connected. |
| Service protocols | `NowPlayingSource`, `PowerSource`, `ShelfStorage`, `SettingsStore`, `ReduceMotionProvider` (all in `NotchCore`) | Only `ReduceMotionProvider` has a real implementation (`WorkspaceReduceMotionProvider`). `SettingsStore` has only the in-memory test version. |
| Helpers | `DelayScheduler`, `TaskDelayScheduler`, `RGBColor`, `JSONValue`, `MotionSpec`, `NotchGeometry`, `ScreenNotchGeometryProvider` | Good shape. |
| Saved settings | None | `IslandSettings` has defaults and allowed ranges, but nothing saves or loads it. The app always runs with `.defaults`. The only `UserDefaults` read is the HUD spike's on/off switch. |
| XPC, extensions, background or privileged parts | None today | The planned media engine is a long-running `/usr/bin/perl` child process. The Debug-only HUD spike uses keyboard event taps (Accessibility and Input Monitoring) and private frameworks (DisplayServices, CoreBrightness). |
| Dependencies | No Swift packages | Apple frameworks only: AppKit, SwiftUI, Observation, CoreGraphics, and in the spike CoreAudio and AudioToolbox. mediaremote-adapter is planned, not yet bundled. |

## 2. How the parts relate

**Ownership**

- `AppDelegate` owns `NotchPanelController`.
- `NotchPanelController.init` creates everything else: `ScreenNotchGeometryProvider`,
  `WorkspaceReduceMotionProvider`, `NotchPanel`,
  `IslandStateMachine(scheduler: TaskDelayScheduler())`, `IslandModel`, and
  `IslandHostingView(IslandView)`. The window controller is also the place where the
  app's objects get created.
- The Debug HUD spike (`HUDSpikeController`) separately owns a second `NotchPanel`, a
  second `IslandStateMachine`, and its own scheduler.

**Dependencies:** `App` depends on `NotchCore`. `NotchCore` imports only Foundation and
Observation, so the compiler enforces the split.

**Where data comes in**

- Screen geometry from `NSScreen`.
- Display changes from `didChangeScreenParametersNotification`.
- The pointer from `NSEvent` global and local mouse monitors plus the tracking area.
- Reduce Motion from `NSWorkspace`.
- Clicks from SwiftUI buttons.
- Debug only: media keys, CoreAudio, and display and keyboard brightness.

**How it reaches the island:** events call `IslandStateMachine` methods such as
`pointerEntered()` and `click()`. The machine is `@Observable`, so `IslandView`
re-renders. `NotchPanelController.followIsland()` watches `islandSize` to update where
clicks are accepted.

## 3. The media path, step by step

```text
player plays something
  -> [MISSING] engine: perl + MediaRemoteAdapter.framework   (MediaRemoteEngine.swift is TODOs)
  -> raw line: {"type":"data","diff":bool,"payload":{...}}
  -> NowPlayingStreamParser.ingest(line:)        parse and check the envelope
       validateMandatoryKeys rejects a WRONG TYPE for bundleIdentifier/title/playing,
       but not a MISSING key
  -> parser.state: [String: JSONValue]            diff merge; null removes a key
  -> parser.nowPlaying -> NowPlaying.init?(state:)    <- app-ID gate
  -> [MISSING] MediaRemoteNowPlayingSource yields NowPlaying? on an AsyncStream
  -> PlaybackState.updated(with:)                 nil -> .stopped(lastPlayed:)
  -> PlaybackProgress / ArtworkTracker            elapsed time and artwork rules
  -> [MISSING] NowPlayingPresentation -> IslandStateMachine.selectMode(.nowPlaying)
  -> IslandView.levelContent: (.nowPlaying, _) -> Color.clear   (no view yet)
```

### Where a missing app ID becomes "nothing playing"

1. `Sources/NotchCore/NowPlaying.swift`, `init?(state:)`: the `guard` requires
   `bundleIdentifier` to be a string and returns `nil` otherwise. Its doc comment says
   this is "how 'nothing is playing' looks".
2. `NowPlayingStreamParser.nowPlaying` returns that `nil`. The parser accepts a line
   with no `bundleIdentifier` key, so the line is valid and the result is quietly `nil`.
3. `PlaybackState.updated(with: nil)` turns a playing track into
   `.stopped(lastPlayed:)`, which would show as "last played" instead of what is
   actually playing.
4. `Tests/NotchCoreTests/NowPlayingTests.swift`, `isNilWhenAMandatoryKeyIsMissing`,
   asserts that a missing `bundleIdentifier` gives `nil`.

On macOS 27.2 the adapter sent `title`, `playing` and `processIdentifier` without a
`bundleIdentifier` (see `docs/requirements/now-playing.md` on the #24 branch). The
adapter's README says the key is always present, but in practice it isn't. The
`processIdentifier` that could identify the app is currently discarded.

### Other places the data is changed or filtered

- `PlaybackProgress.init`: a non-finite `duration` becomes unknown.
- `ArtworkTracker.update`: empty artwork counts as none; old artwork is kept during
  brief dropouts on the same track.
- `NowPlaying.isSameTrack`: compares app ID, title, artist and album.
- `NowPlayingStreamParser.artworkData`: decodes base64 artwork, but is defined in
  `ArtworkState.swift`.

## 4. Problems and risks

| Risk | Where | Severity |
| --- | --- | --- |
| A missing app ID is treated as nothing playing. App identity is a field defined by the adapter's JSON, not a concept of its own. | `NowPlaying`, `PlaybackState.isSameTrack` | High, and #24 is about to depend on it |
| The window controller also creates the app's objects and would naturally end up owning the media source. | `NotchPanelController.init` | Medium |
| The island can show only one thing: one `mode`, alerts as a fixed two-case enum (`IslandAlert`), nothing that ranks or tracks several activities. | `IslandStateMachine`, `IslandAlert` | High for the Dynamic Island goal |
| The list of activities is a closed enum used everywhere. Adding one means editing the enum, both size tables, `IslandLayout.designOpenSize`, `IslandView.levelContent` and `spokenName`. | `IslandLayout.swift`, `IslandView.swift` | Medium |
| The HUD spike runs a second panel and state machine; `HUDSpikeDelayScheduler` duplicates `TaskDelayScheduler`. The main machine already has `hudKeyPressed(_:)`. | `HUDSpikeController.swift` | Medium (Debug only) |
| Settings can't be changed: nothing persists `IslandSettings` and the app never loads it. | `SettingsStore`, `NotchPanelController` | Medium |
| Two ways to pick the screen: `ScreenNotchGeometryProvider.screen` hard-codes "built-in, else main", while the tested `DisplayPlacement` (which respects `showOn` and multiple displays) is unused. | `ScreenNotchGeometryProvider` | Low to medium |
| The core media model is shaped like the adapter: `NowPlaying` is documented "as reported by mediaremote-adapter", and the artwork decoding sits in the artwork file. | `NowPlaying.swift`, `ArtworkState.swift` | Low |
| `.message` exists in `IslandMode` with no model, issue or provider. | `IslandLayout.swift` | Low |

**Not problems today:** no hard-coded Music or Spotify assumptions in code (only in
tests), no oversized files, no parsing or service work in UI code, no fragile
notification chains beyond the one screen-change observer, and no unnecessary
dependencies.

## 5. Keep, rename, move, split, merge, replace, remove, introduce

- **Keep:**
  - The `NotchCore`/`App` split.
  - `IslandStateMachine` with its injected scheduler.
  - `IslandLayout` as pure size math.
  - `NowPlayingStreamParser`, `PlaybackProgress`, `ArtworkTracker`, `MotionSpec`, `NotchGeometry`.
  - The `NotchPanel` and `IslandHostingView` click handling.
  - The service protocols.
- **Rename:**
  - `IslandMode` to `ActivityKind`, once activities exist. It names what is showing, not a mode.
  - The `NowPlaying` doc comment, so it no longer says "as reported by mediaremote-adapter".
- **Move:**
  - `NowPlayingStreamParser.artworkData` into `NowPlayingStreamParser.swift`.
  - Object creation out of `NotchPanelController.init` into an `AppEnvironment` owned by `AppDelegate`.
- **Split:** `NotchPanelController` into the panel and pointer controller (keep) and app
  setup (moves to `AppEnvironment`).
- **Merge:** the HUD spike into the main island. Send its key events to
  `hudKeyPressed(_:)` instead of a second panel, and delete `HUDSpikeDelayScheduler` in
  favor of `TaskDelayScheduler`.
- **Replace:**
  - The required `bundleIdentifier: String` with an optional `AppIdentity` (bundle ID and process ID).
  - `ScreenNotchGeometryProvider.screen`'s own screen choice with `DisplayPlacement.placements`.
- **Remove:** `IslandMode.message` until there is a messages issue.
- **Introduce:**
  - `AppIdentity` (core) with an `AppIdentityResolver` (app side, using `NSRunningApplication` for name and icon).
  - `ActivityCenter` (core) to hold and rank activities.
  - A `UserDefaultsSettingsStore`.
  - A scripted test provider that plays back fake activities, for previews and tests.

## 6. Comparison with a layer-based layout

A possible long-term layout sorts code by layer:

```text
NotchSuite
|-- Presentation / Notch UI
|-- Activity model + state
|-- Activity providers (Media, Power, Timers, Transfers, future)
|-- App identity / metadata
|-- System integrations
|-- Persistence / settings
`-- Shared utilities
```

The current project sorts code by platform instead: `NotchCore` is portable and tested
on Linux, `App` is macOS-specific. Keep that. The compiler stops `NotchCore` from
importing AppKit, which keeps the logic testable in CI; folders alone can't do that.

The layer layout's ideas fit inside the current split:

- Activity model, ranking and app identity go in `NotchCore`.
- Each provider is a core protocol with an implementation in `App`, the way
  `NowPlayingSource`, `PowerSource` and `ShelfStorage` already work.
- Presentation and system integrations stay in `App`.

What's missing is a concept (activities), not a reorganization.

## 7. Can it grow into a multi-activity Dynamic Island?

| Need | Today | Gap |
| --- | --- | --- |
| Several activities at once | One `mode` | An `ActivityCenter` that holds a list and picks primary and secondary |
| Compact / peek / open | Strong: `IslandLevel` plus state-machine rules and tests | None |
| Priority | Only "an alert replaces the mode" | A priority value on activities and a choosing rule |
| Transitions and dismissal | Strong for hover, click, collapse, alert and HUD timing; `MotionSpec` handles animation | Nothing ends an activity yet (track stops, battery full) |
| Source app identity and icons | Missing | `AppIdentity` plus a resolver |
| Per-provider permissions | Not modeled; the spike checks its own | A provider availability state: available, needs permission, unavailable |
| Test and fake providers | Good base: core protocols, `ManualScheduler`, `InMemorySettingsStore` | A scripted activity provider |
| Future system integrations | The protocol-in-core, implementation-in-app pattern scales | None |

The layout, timing and drawing side is well prepared. The data side is not: nothing
produces activities, ranks them, or identifies their source app.

## 8. Recommendations

### Immediate (before #24's code)

1. **App identity.** In `NowPlaying.swift`, make `bundleIdentifier` optional, read
   `processIdentifier`, and require only `title` and `playing` in `init?(state:)`.
   Update `NowPlayingStreamParser.validateMandatoryKeys`, make
   `PlaybackState.isSameTrack` work with an optional ID, and change
   `isNilWhenAMandatoryKeyIsMissing`. *Why:* otherwise players that don't report an app
   ID show as "nothing playing".
2. **Move app setup out of the window controller.** Move the object creation in
   `NotchPanelController.init` into an `AppEnvironment` built in
   `AppDelegate.applicationDidFinishLaunching`, and pass the model in. *Why:* #24's
   media source gets a proper owner and a clean start and stop.
3. **Move `artworkData`** from `ArtworkState.swift` to `NowPlayingStreamParser.swift`.
   *Why:* the adapter's format stays in the parser.

### Medium-term

1. **`AppIdentity` and `AppIdentityResolver`.** Look up the app from the process ID with
   `NSRunningApplication` (bundle ID, name, icon). *Why:* icons and names for every
   activity, not only media.
2. **Merge the HUD spike** into the main island: route `HUDSpikeController`'s key events
   to `hudKeyPressed`, delete the second panel and scheduler. *Why:* one island, one
   source of truth.
3. **Save settings.** Add a `UserDefaultsSettingsStore`, load it at launch, assign it to
   `IslandStateMachine.settings`. *Why:* the settings window (#28) needs storage.
4. **Use the display rules.** Have `NotchPanelController` use
   `DisplayPlacement.placements`. *Why:* the `showOn` setting and multiple displays
   already have tested logic.
5. **Per-kind views.** Move `IslandView.levelContent`'s switch into per-kind view
   builders. *Why:* adding an activity becomes adding one file.

### Long-term

1. **`ActivityCenter` in `NotchCore`.** Holds activities (kind, priority, app identity,
   payload) from providers and picks primary and secondary. It drives
   `IslandStateMachine.selectMode` and `alertArrived` rather than replacing them.
2. **Rename `IslandMode` to `ActivityKind`**, and drop `.message` until it has an issue.
3. **Provider availability state**, so the UI can show "needs permission" instead of
   quietly showing nothing.
4. **Scripted test provider**, for previews and end-to-end tests of priority and
   dismissal.

## Current architecture

```text
NotchSuiteApp + AppDelegate
 |-- NotchPanelController  (also creates the app's objects)
 |    |-- NotchPanel + IslandHostingView --> IslandView (switch on mode and level)
 |    |-- ScreenNotchGeometryProvider       (own screen choice)
 |    |-- WorkspaceReduceMotionProvider
 |    `-- IslandModel --> IslandStateMachine (one mode, level, alert, HUD)
 `-- [Debug] HUDSpikeController  (own panel + own state machine + own scheduler)

NotchCore (tested, mostly not connected)
  NowPlayingStreamParser --> NowPlaying (bundleIdentifier required)
                               |--> PlaybackState
                               |--> PlaybackProgress
                               `--> ArtworkTracker
  TimerState, BatteryState, ShelfStore, DisplayPlacement, SettingsStore: unused

App/Media: TODO comments only (no engine, no source, no view)
```

## Proposed architecture

```text
AppDelegate
 `-- AppEnvironment  (creates and owns objects)
      |-- Providers (App, each implementing a NotchCore protocol)
      |    MediaRemote NowPlayingSource | PowerSource | System HUD keys
      |    Timer | Scripted test provider
      |         |
      |         v
      |-- ActivityCenter (core): ranks activities, picks primary and secondary
      |         ^                         |
      |    AppIdentityResolver (App)      v
      |-- IslandStateMachine (unchanged: level, hover, timing)
      |         ^
      |    UserDefaultsSettingsStore
      `-- NotchPanelController, one per display via DisplayPlacement
               `-- IslandView + per-kind views
                   (reads IslandStateMachine and ActivityCenter)
```

## The five highest-value changes

1. Make app identity optional (`NowPlaying`, parser, `PlaybackState`) before writing
   the #24 code.
2. Move object creation into `AppEnvironment`, so the media source has an owner.
3. Merge the HUD spike into the main state machine through `hudKeyPressed(_:)`,
   removing the second panel and the duplicate scheduler.
4. Save settings and use `DisplayPlacement`, connecting tested models that already exist.
5. Add `ActivityCenter` with priorities in front of the state machine, when the second
   activity (#27 Charging) arrives, not before.

## Leave as-is for now

- **The `NotchCore`/`App` split.** Better than sorting by layer because the compiler
  enforces it.
- **`IslandStateMachine`.** Its hover, click, alert and HUD rules and its scheduler are
  well tested. An activity center should drive it, not replace it.
- **`IslandLayout` and `MotionSpec`.** Pure functions of mode and level that match the
  design canvas.
- **`NowPlayingStreamParser`'s update and bad-line handling, `PlaybackProgress`, and
  `ArtworkTracker`.**
- **The window's click handling** (`NotchPanel`, `IslandHostingView`, `islandHitRect`).
  It's subtle and correct.
- **`ActivityCenter` itself**, until a second real activity exists. Building it for one
  activity would be guessing.
