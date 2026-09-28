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
- `swift test --skip-build` only runs what `swift build --build-tests` already built, so run them in that order. On its own it reports failures.
- To fix formatting: `swift format format --in-place --recursive Sources Tests`.
- On a Mac these run natively. In Claude Code cloud sessions `swift` is a wrapper that runs Linux Swift in Docker (`.claude/hooks/session-start.sh`).
- To run what CI's Linux job runs, from a Mac: `SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh test`. It needs Docker running (OrbStack on the owner's Mac).
- The macOS app build command will be added here once the app target exists.
- `.swift-version` pins swiftly's toolchain for this folder and is gitignored. CI uses Xcode's Swift on macOS and the `swift:6.4-noble` image on Linux.

## Key files

- `Package.swift`: targets `NotchCore` and `NotchCoreTests` (macOS 14+, Swift tools 6.0).
- `.swift-format`: the formatter config that `swift format lint --strict` enforces.
- `.github/workflows/ci.yml`: the Linux and macOS jobs. `docs/self-hosted-runner.md` covers the Mac runner.
- `THIRD_PARTY_LICENSES`: license texts for anything adapted from the reference projects.

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
