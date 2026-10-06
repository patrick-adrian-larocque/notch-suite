---
name: linux-check
description: "Run CI's Linux job locally on a Mac through OrbStack (scripts/ci-swift.sh): build, test, and strict lint in the swift:6.4-noble image. Use to check Linux parity before pushing, or when CI's Linux job fails but /swift-check passes."
allowed-tools:
  - Bash(scripts/ci-swift.sh *)
  - Bash(orbctl status)
---

Run the Linux side of CI from the repository root and report the result. `/swift-check` runs the same steps with the Mac's own toolchain; this runs them in the Linux image CI uses, so it catches code that only builds on macOS (AppKit, Combine, or Foundation differences) in `NotchCore`.

1. If there is no `Package.swift`, say there is nothing to check and stop.
2. If `docker` isn't on `PATH`, say OrbStack isn't installed (`brew install --cask orbstack`) and stop. If `orbctl status` doesn't print `Running`, the script starts OrbStack itself; wait for it.
3. Run these in order, stopping at the first failure. Pass no environment variables: the script defaults to the image `ci.yml` pins.
   1. `scripts/ci-swift.sh build --build-tests`
   2. `scripts/ci-swift.sh test --skip-build`
   3. `scripts/ci-swift.sh format lint --strict --recursive Sources Tests App AppTests`
4. Report one line per step: passed or failed. For a failure, show the first real error with `file:line` and the smallest useful excerpt, then propose a fix. Don't change any files unless asked.

Notes:
- The first run after OrbStack starts can be slow while the image and the `notch-suite-swiftpm` cache volume warm up.
- The container shares `.build` with the macOS build; this works because the triples differ.
- On Apple silicon the image runs as linux/arm64. To match GitHub's x86_64 runners, set `SWIFT_PLATFORM=linux/amd64` (slower, uses Rosetta). Only do this when asked.
- SwiftUI and AppKit code in `App/` can't build on Linux; the macOS job and `/macos-build` cover it.
