# Notch Suite

A macOS notch utility built from scratch: Now Playing media control, a file drop shelf, and system HUD replacements. GPLv3. `NotchCore` and a first app shell exist; `NotchUI` is planned.

## Architecture

Three layers, each depending only on the one before it:

1. `NotchCore` (`Sources/NotchCore`): pure Swift with no AppKit, SwiftUI, or Combine. It builds and tests on Linux. Use `Observation` and async sequences for reactive state.
2. `NotchUI` (planned): SwiftUI views. macOS only. Until it exists, the few views live in the app target, because a SwiftUI target in `Package.swift` would break `swift build` on Linux.
3. App target `NotchSuite` (`App/`, generated from `project.yml` by XcodeGen): the macOS app and its system integration. `AppTests/` holds its logic tests, built as the `NotchSuiteTests` Xcode target; it isn't part of the SwiftPM package, so it only runs through Xcode, not `swift test`.

Mac-only services (MediaRemote, screen and notch geometry, the file system, AirDrop) sit behind protocols defined in `NotchCore` and are implemented in the app target. That keeps the logic testable on Linux.

## Commands

Run from the repository root.

```sh
swift build --build-tests
swift test --skip-build
swift format lint --strict --recursive Sources Tests App AppTests
```

- `/swift-check` runs all three in order and reports one line per step. Run it before every push.
- `swift test --skip-build` only runs what `swift build --build-tests` already built, so run them in that order. On its own it reports failures. It doesn't cover `AppTests/`; run the `NotchSuiteTests` scheme in Xcode for that.
- To fix formatting: `swift format format --in-place --recursive Sources Tests App AppTests`.
- On a Mac these run natively. In Claude Code cloud sessions `swift` is a wrapper that runs Linux Swift in Docker (`.claude/hooks/session-start.sh`).
- To run the Linux side of CI from a Mac, use `/linux-check`, or run `scripts/ci-swift.sh test` for the build and tests and `scripts/ci-swift.sh format lint --strict --recursive Sources Tests App AppTests` for the lint. `SWIFT_IMAGE` defaults to the image `ci.yml` pins, so no environment prefix is needed. It needs Docker (OrbStack on the owner's Mac); the script starts OrbStack if it isn't running. It shares `.build` with the macOS build, which works. Set `SWIFT_PLATFORM=linux/amd64` to match GitHub's x86_64 runners (slower).
- The macOS app needs a Mac with Xcode and XcodeGen (`brew install xcodegen`). Generate the Xcode project first; it is gitignored, so regenerate it after pulling a change to `project.yml` or adding or removing a file in `App/` or `AppTests/`:

  ```sh
  xcodegen generate
  xcodebuild build -project NotchSuite.xcodeproj -scheme NotchSuite -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData
  ```

  Then open `NotchSuite.xcodeproj` and run the `NotchSuite` scheme, or open `build/DerivedData/Build/Products/Debug/NotchSuite.app`. It has no Dock icon; quit it from its status item. The project signs ad hoc ("Sign to Run Locally"); CI adds `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` to build without signing.
- `project.yml` owns the Xcode project's structure; `NotchSuite.xcodeproj` is generated output. The Xcode MCP server (`xcode-tools`) is for inspecting, building, testing and diagnosing it; its runtime and debug tools ask first. Its currently audited structural tools (new targets, build settings, entitlements, Info.plist keys, file moves) are denied for Claude, and the list must be re-audited after Xcode upgrades, because regenerating discards what they do. Edit `project.yml` instead. See `docs/xcode-mcp.md`.
- `.swift-version` pins swiftly's toolchain for this folder and is gitignored. CI uses Xcode's Swift on macOS and the `swift:6.4-noble` image on Linux.

## Existing implementation sources

Read README.md's "Credits / Inspiration and implementation sources" section
before planning media, island interaction, or file-shelf work. The owner's forks
are available sources to integrate and adapt, not merely inspiration. Do not
characterize an unwired feature as lacking an available implementation.

- `patrick-adrian-larocque/mediaremote-adapter`: intended media engine for the
  macOS `NowPlayingSource`; use the existing parser, playback models, and commands
  in `NotchCore` when connecting updates, artwork, and transport controls.
- `patrick-adrian-larocque/boring.notch`: implementation patterns for notch panels,
  hover/click expansion, and media UI integration.
- `patrick-adrian-larocque/notchdrop`: implementation source for file drops, the
  shelf, and dragging files out, adapted to `ShelfStore`/`ShelfStorage`.

Inspect the relevant fork before designing replacements. Verify compatibility
and packaging, adapt suitable code to this project's architecture, and follow
`/port-from-reference` for attribution. Distinguish available source, code already
in `NotchCore`, and services/UI actually connected in `App/` when reporting status.

## License rules

The project is GPLv3. Code adapted from these projects keeps its original copyright notice and gets an entry in `THIRD_PARTY_LICENSES`:

- boring.notch (GPLv3)
- NotchDrop (MIT)
- mediaremote-adapter (BSD-3-Clause)

Follow `/port-from-reference` whenever code from them is copied or closely followed. The forks `patrick-adrian-larocque/boring.notch`, `patrick-adrian-larocque/notchdrop` and `patrick-adrian-larocque/mediaremote-adapter` are for reading, never for pushing to. Run the `license-auditor` agent before merging a PR that ports code.

## Workflow

- One issue, one branch, one PR. The branch is `claude/issue-<N>-<slug>` (a cloud session may assign its own branch name instead). The PR follows `.github/pull_request_template.md` and says `Closes #N`.
- Before starting an issue, look for an open PR that closes it (`Closes #N`) or an unfinished `claude/issue-<N>-*` branch. A branch is finished only when it has no open PR and at least one merged or closed PR; an open PR always wins. Check with `gh pr list --head "<name>" --state all --json state,number`, using the bare branch name without `origin/` (with the prefix it returns `[]`). Git ancestry misses squash merges. If one exists, continue on it; never open a second PR for the same issue. `/work-issue` covers fork PRs and multiple matches.
- Never merge another open PR's branch into yours. If your work needs it, say so in your PR and wait for that PR to merge first.
- A draft PR is still in progress. Mark it ready for review once the criteria you can check on a draft are verified and the Linux job, if CI runs, is green. Then request a Copilot review. On GitHub's runners, marking it ready is what starts the macOS job. Copilot doesn't review drafts unless the repository turns that on.
- Fix Copilot's findings on the same PR. Push the fix, reply on each thread with the commit, then re-request a Copilot review. Copilot marks a finding resolved only when it re-reviews a commit that fixes it, so a thread resolved by hand still shows as open in its overview.
- Merge only once every CI job that ran is green and Copilot's latest overview lists no open findings. `ci.yml` runs only for changes to the Swift package, `.swift-format`, `ci.yml` or `scripts/ci-swift.sh`, so a PR that touches none of them has no CI to wait for. A finding that arrives after a merge goes in one follow-up PR that links the merged one.
- Run `/swift-check` before pushing. `/work-issue <N>` does the whole loop for one issue; the `feature-worker` agent runs it in its own worktree so issues can proceed in parallel.
- Linux first, macOS only when needed. macOS minutes on GitHub-hosted runners count 10x, so that job waits for the Linux job and skips draft PRs. The repository variable `CI_RUNNER=self-hosted` moves both jobs to the owner's Mac (`docs/self-hosted-runner.md`); fork PRs always stay on hosted runners.
- Check CI with `/ci-status`. Use the `macos-ci-investigator` agent for a failing macOS job.
- Ask the `reference-scout` agent how the reference projects solve something, instead of cloning them into this repo.

## Worktrees

`claude --worktree <name>` creates `.claude/worktrees/<name>/` on branch `worktree-<name>`. `swift build` and `swift test` work inside it. `${CLAUDE_PROJECT_DIR}` in hooks deliberately stays at the main checkout.

`worktree.baseRef` is `"head"` in `.claude/settings.json`, so worktrees branch from local HEAD and carry unpushed commits. That includes the commits of whatever feature branch HEAD is on, so switch to the branch you want first. Change it to `"fresh"` to branch from `origin/main` instead. There is no `.worktreeinclude`: no gitignored file is needed inside worktrees yet. Add one if that changes.

## Permissions

`.claude/settings.json` allows only the `swift build`, `swift test` and `swift format` commands. Read-only `git` commands such as `git status`, `git diff` and `git log` need no rule: Claude Code runs them without asking, and still asks for write-capable forms like `git diff --output=<file>`. Don't add `Bash(git <cmd> *)` allow rules, because they would approve those write-capable forms too.

## Secrets

`.claude/settings.json` denies the Read and Grep tools access to `.env` files and signing material (`*.p12`, `*.mobileprovision`, `*.cer`). It does not stop shell commands such as `cat`, so keep real secrets out of the repository.

## Where the details live

- `.claude/rules/swift-core.md`: rules for `Sources/NotchCore` and its tests (loads only when those files are touched).
- `.claude/rules/ci.md`: rules for `.github/workflows` (loads only when those files are touched).
- `.claude/rules/code-search.md`, `.claude/rules/reading-files.md`: how to search and read files.
