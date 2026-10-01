# Notch Suite

A macOS notch utility built from scratch — Now Playing media control, a file
drop shelf, and system HUD replacements — informed by the architecture of a
few excellent open-source projects.

## Status

Early scaffold. `NotchCore` (pure Swift, tested on Linux and macOS) has a parser
for mediaremote-adapter's `stream` output and the island's layout and notch
geometry. The app is a shell: a black placeholder island over the notch and a
status item with Quit.

## License

GPLv3 (see [LICENSE](./LICENSE)). This project is licensed GPLv3 because it
may incorporate or closely adapt source code from
[boring.notch](https://github.com/TheBoredTeam/boring.notch), which is
itself GPLv3-licensed and requires that of any derivative work.

## Credits / Inspiration

- **[boring.notch](https://github.com/TheBoredTeam/boring.notch)** (GPLv3) —
  architecture reference for notch window management, gestures, HUD
  replacement, and the manager/observer pattern.
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** (MIT) —
  reference/source for the file-shelf / AirDrop drop-zone feature.
- **[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)**
  (BSD-3-Clause) — Now Playing media detection engine.

See [THIRD_PARTY_LICENSES](./THIRD_PARTY_LICENSES) for the full license texts
of reused components.

## Building

macOS 14+, Xcode. The core builds with SwiftPM:

    swift build --build-tests
    swift test --skip-build
    swift format lint --strict --recursive Sources Tests App

The app's Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

    xcodegen generate
    open NotchSuite.xcodeproj
