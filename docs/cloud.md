# Notch Suite in Codex Cloud

Use Cloud for implementation, source review, and debugging of the portable Swift
package. The macOS app still needs a Mac for compilation and runtime validation.

| Work | Linux / Cloud | Mac |
| --- | --- | --- |
| Build and test `NotchCore` | Yes | Yes |
| Parser fixtures, state machines, layout, geometry, settings, and shelf logic | Yes | Yes |
| Strict Swift formatting across `Sources`, `Tests`, and `App` | Yes | Yes |
| LLDB debugging of core tests | Yes, when the environment permits tracing processes | Yes |
| Compile `App/` with SwiftUI, AppKit, and macOS services | No | Xcode required |
| Launch the notch UI, media services, file drops, and system integration | No | Runtime checks required |

## Create the environment

1. In Codex, choose **Work in → Cloud → Select environment → Create environment**,
   or open **Settings → Codex Cloud → Environments → Create environment**.
2. Select `patrick-adrian-larocque/notch-suite`, connecting GitHub if prompted.
   The checkout used during setup must contain `script/setup-cloud.sh`. When
   testing this change before it is merged, use the `codex/cloud-setup` branch.
3. Ask the setup conversation to prepare Ubuntu 24.04 with native Swift 6.4.0,
   Swift Format, LLDB, and the troubleshooting tools below using this install
   command from the repo root:

   ```sh
   ./script/setup-cloud.sh
   ```

4. Allow access to `download.swift.org`, `www.swift.org` (release signing keys),
   and Ubuntu's package repositories (`archive.ubuntu.com`, `security.ubuntu.com`,
   or `ports.ubuntu.com` on ARM64). If the environment uses an apt mirror, allow
   that mirror too. GitHub access is useful for inspecting the documented
   implementation forks. There are currently no external SwiftPM dependencies
   or application secrets required for the core tests.
5. Have setup run `./script/verify.sh` and review its build, test, and lint results.
   No app server or start service is needed. Save and **Publish** the prepared
   environment, then start a new task using it.

The installer supports Ubuntu 24.04 on x86_64 and ARM64 with root or passwordless
sudo. It downloads the pinned official Swift release and verifies its PGP
signature before extraction. Tools live in `/opt/notch-suite/swift-6.4.0` with
links in `/usr/local/bin`, so later task shells can invoke `swift` and `lldb`
without sourcing a setup shell. A matching preinstalled toolchain is reused.
Docker is unnecessary inside Cloud; the existing Docker scripts remain available
for Claude sessions, CI, and reproducing Linux checks from a Mac.

If Cloud supplies another distribution, ask setup to install the matching native
Swift 6.4.0 toolchain, LLDB, and the tools below first. The script reuses a working
matching toolchain but deliberately stops rather than installing Ubuntu binaries on an
unsupported distribution.

The installer also ensures these tools are available when Swift is already
installed. Ubuntu's `fdfind` and `batcat` executables get `fd` and `bat` links
in `/usr/local/bin`, which work in later shells without personal aliases.

| Tool | Use |
| --- | --- |
| `rg` | Search source code and logs. |
| `fd` | Find files by name, extension, or path. |
| `bat` | Read source with syntax highlighting and line numbers. |
| `fzf` | Filter file lists and other output. |
| `eza` | Inspect directory listings and trees. |
| `jq` | Inspect JSON configuration, fixtures, and command output. |
| `shellcheck` | Diagnose shell-script errors. |

Use noninteractive forms in agent tasks, for example:

```sh
fd -e swift | fzf --filter 'StateMachine'
bat --paging=never Sources/NotchCore/MotionSpec.swift
eza --tree --level=2 Sources Tests
swift package dump-package | jq '.targets[].name'
shellcheck script/setup-cloud.sh
```

These Ubuntu packages require the `universe` repository, enabled in the standard
Ubuntu 24.04 image. No extra download hosts are needed beyond the Ubuntu package
repositories already allowed during setup. After adding these tools to an
existing Cloud environment, rerun setup and republish so new tasks inherit them.

The desktop `.codex/environments/environment.toml` is a local worktree/action
configuration. Committing it does not create or publish a Cloud environment.
Install/start configuration belongs to the Cloud environment. After changing
that setup, republish and test a new task; existing tasks retain their own state.
See the [official Cloud environment guide](https://learn.chatgpt.com/docs/environments/cloud-environments)
and [Swift's Linux installation instructions](https://www.swift.org/install/linux/tarball/).

## Daily checks and debugging

Run the same entry points as local development:

```sh
./script/setup.sh
./script/verify.sh
```

For a focused test, rebuild tests before using `--skip-build`:

```sh
swift build --build-tests
swift test --skip-build --filter IslandStateMachineTests
```

For LLDB, build the debug tests and load Swift 6.4's Linux test runner with
the Swift Testing entry point (this repository uses Swift Testing):

```sh
swift build --build-tests
lldb .build/debug/NotchCoreTests-test-runner -- --testing-library swift-testing
```

Set breakpoints in `Sources/NotchCore` or `Tests/NotchCoreTests`, then use `run`,
`bt`, and `frame variable` to inspect failures. If the environment denies process
tracing, use focused tests, assertions, and diagnostic output; installing LLDB
does not grant ptrace permission. Filesystem persistence and published tool caches
avoid repeated downloads; a fresh task should still rebuild tests for its source
revision before `--skip-build`.

## macOS validation and handoff

Keep system integrations in `App/` behind `NotchCore` protocols. Cloud may edit
those sources and lint them, but passing Linux checks does not prove the app
compiles or works. Report app compilation/runtime checks as pending until they
run on macOS.

On a Mac, pull the task branch, then run:

```sh
./script/setup.sh
./script/verify.sh
./script/build_and_run.sh --build-only
# For changes needing runtime validation:
./script/build_and_run.sh --verify
```

Existing CI runs Linux checks first and builds the app in its macOS job. Hosted
macOS skips draft PRs; mark a PR ready to get that build. The self-hosted runner
also builds drafts; see [the runner guide](self-hosted-runner.md). Cloud should
report the actual macOS job result when using it as build evidence. Visual
behavior and macOS service interactions still require a Mac runtime check.
