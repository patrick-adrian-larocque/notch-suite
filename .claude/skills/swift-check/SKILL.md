---
name: swift-check
description: Build, test, and strictly lint the Swift package (swift build, swift test, swift format lint --strict). Run it before every push, and whenever asked whether the code still builds or the tests pass.
allowed-tools:
  - Bash(swift build *)
  - Bash(swift test *)
  - Bash(swift format lint *)
---

Run this project's required pre-push checks from the repository root and report the result.

1. If there is no `Package.swift`, say there is nothing to check yet and stop.
2. If `swift` isn't on `PATH`, say the toolchain is missing and stop. In Claude Code cloud sessions it comes from `.claude/hooks/session-start.sh`.
3. Run these in order, stopping at the first failure:
   1. `swift build --build-tests`
   2. `swift test --skip-build`
   3. `swift format lint --strict --recursive Sources Tests App`
4. Report one line per step: passed or failed. For a failure, show the first real error with `file:line` and the smallest useful excerpt of output, then propose a fix. Don't change any files unless asked.

In cloud sessions `swift` runs Linux Swift inside Docker, so this covers the platform-independent code. SwiftUI and AppKit code is checked by the macOS job in `.github/workflows/ci.yml`.
