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
- To run the Linux side of CI from a Mac, use `SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh test` for the build and tests, and `SWIFT_IMAGE=swift:6.4-noble scripts/ci-swift.sh format lint --strict --recursive Sources Tests` for the lint. It needs Docker running (OrbStack on the owner's Mac) and shares `.build` with the macOS build, which works.
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

- One issue, one branch, one PR. The branch is `claude/issue-<N>-<slug>` (a cloud session may assign its own branch name instead). The PR follows `.github/pull_request_template.md` and says `Closes #N`.
- Before starting an issue, look for an open PR that closes it (`Closes #N`) or an unmerged `claude/issue-<N>-*` branch. If one exists, continue on it; never open a second PR for the same issue. `/work-issue` covers fork PRs and multiple matches.
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
