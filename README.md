# Notch Suite

A macOS notch utility built from scratch — Now Playing media control, a file
drop shelf, and system HUD replacements — informed by the architecture of a
few excellent open-source projects, with existing implementations available
in the owner's forks to integrate and adapt.

## Status

Early scaffold. `NotchCore` (pure Swift, tested on Linux and macOS) has a parser
for mediaremote-adapter's `stream` output and the island's layout and notch
geometry. The app is a shell: a black placeholder island over the notch and a
status item with Quit. The core already includes playback models and commands,
an island interaction state machine, and shelf logic. The remaining work is to
connect these to the macOS services and UI using the forked implementations below.
The placeholder UI does not mean the media engine or reference implementations
are unavailable.

## License

GPLv3 (see [LICENSE](./LICENSE)). This project is licensed GPLv3 because it
may incorporate or closely adapt source code from
[boring.notch](https://github.com/TheBoredTeam/boring.notch), which is
itself GPLv3-licensed and requires that of any derivative work.

## Credits / Inspiration and implementation sources

- **[boring.notch](https://github.com/TheBoredTeam/boring.notch)** (GPLv3) —
  architecture reference for notch window management, gestures, HUD
  replacement, and the manager/observer pattern.
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** (MIT) —
  reference/source for the file-shelf / AirDrop drop-zone feature.
- **[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)**
  (BSD-3-Clause) — Now Playing media detection engine.

### Owner's forks and integration plan

These forks are available implementation sources for this project, not just
visual inspiration:

| Fork | Intended integration |
| --- | --- |
| [mediaremote-adapter](https://github.com/patrick-adrian-larocque/mediaremote-adapter) | Add the adapter to the macOS app and implement `NowPlayingSource`: feed its output through `NowPlayingStreamParser`, publish playback/artwork updates, and forward media commands. |
| [boring.notch](https://github.com/patrick-adrian-larocque/boring.notch) | Adapt relevant notch panel, hover/click, expansion, and media UI integration patterns to this project's state machine and layout. |
| [notchdrop](https://github.com/patrick-adrian-larocque/notchdrop) | Adapt file drop, shelf, and drag-out behavior to `ShelfStore` and the macOS `ShelfStorage` implementation. |

Start feature work by inspecting the relevant fork and its upstream documentation.
Reuse or adapt suitable implementations while preserving the `NotchCore`/macOS
app boundary. Verify current APIs, packaging, and macOS requirements before
integration; availability of source does not mean it is already bundled or wired
into this app. Preserve original notices and record reused code in
`THIRD_PARTY_LICENSES` through `/port-from-reference`.

The forks are read-only sources for this workflow: adapt code into `notch-suite`
and push changes here, rather than modifying the reference forks.

See [THIRD_PARTY_LICENSES](./THIRD_PARTY_LICENSES) for the full license texts
of reused components.

## Building

macOS 14+, Xcode. The core builds with SwiftPM:

    swift build --build-tests
    swift test --skip-build
    swift format lint --strict --recursive Sources Tests App AppTests

The app's Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

    xcodegen generate
    open NotchSuite.xcodeproj

## VS Code and Codex workspace

Open this repository root in VS Code. `.vscode/settings.json` enables Swift
formatting on save using the Swift extension and the root `.swift-format`.
Swiftly selects the local `.swift-version` when present. Install recommended
extensions from the Extensions panel; machine-specific executable paths belong
in user settings, including Todo Tree's ripgrep path.

Use **Tasks: Run Task** for `Swift: Verify` (build, tests, strict lint), individual
core checks, `Swift: Format all` (rewrites files), or `App: Build and run`.
Lint findings appear in Problems when the lint task runs; linting is not automatic
on save. `App/` is an Xcode target, so the core SwiftPM integration alone does not
provide its Xcode build settings or Xcode-aware completion. Use the shared attach configuration for app debugging.

`./script/build_and_run.sh` generates the Xcode project, builds, and relaunches
this checkout's app. It requires macOS, Xcode, and XcodeGen. Options include
`--build-only`, `--verify`, `--debug`, `--logs`, and `--telemetry`.
`.codex/environments/environment.toml` provides Run and Verify actions for the
Codex app. Existing GitHub workflows remain in `.github/workflows/`; worktrees
are separate checkouts managed by Git, not editor configuration files.

See [the complete workspace guide](docs/workspace.md) for setup, debugging,
Release builds, log tasks, Codex worktrees, and configuration boundaries.

## Codex Cloud

Cloud can build and test `NotchCore`, debug portable logic with LLDB, and lint
all Swift sources. The app's UI and macOS integrations require a Mac for builds
and runtime checks.

For a new Ubuntu 24.04 environment, use `./script/setup-cloud.sh` as its install
script and `./script/verify.sh` to validate the setup. Swift 6.4 and LLDB run
natively, so Docker is not required. See [the Cloud guide](docs/cloud.md) for
environment creation, network access, focused tests, debugging, and macOS handoff.
