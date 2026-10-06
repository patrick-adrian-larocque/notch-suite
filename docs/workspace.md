# Workspace scaffolding

## Configuration map

| File | Purpose |
| --- | --- |
| `.vscode/settings.json` | Swift formatting on save, indentation, SwiftPM integration, generated-file search/watcher exclusions. |
| `.vscode/tasks.json` | Setup, core build/test/verify/lint/format, Debug/Release app builds, launch and log streams. |
| `.vscode/launch.json` | Attach debugger to a running app, optionally building and launching first. |
| `.vscode/extensions.json` | Recommended Swift, Todo Tree, Codex, and Markdown extensions. |
| `.codex/config.toml` | Project root discovery without machine-specific model or permission overrides. |
| `.codex/environments/environment.toml` | Worktree setup and Run/Verify/Build/Lint actions. |
| `AGENTS.md` / `.agents/` | Codex instructions and, when present, local Codex skills/agents. |
| `CLAUDE.md` / `.claude/` | Claude instructions, skills, agents, rules, and hooks. |
| `README.md` / `docs/` | Provider-neutral project facts and shared repository policy linked from each provider's own entry point. |
| `script/setup.sh` | Resolve the package; on macOS check Xcode/XcodeGen and generate the app project. |
| `script/setup-cloud.sh` | Install native Swift 6.4 and LLDB on Ubuntu 24.04 for Codex Cloud, then resolve the package. |
| `script/verify.sh` | Required core build, tests and strict format lint, stopping on failure. |
| `script/build_and_run.sh` | Build and launch the app, Release build, debugger and log modes. |
| `.github/workflows/` | Existing CI and GitHub automation. |

## First use

Open the repository root in VS Code, install the recommended extensions, and run
**Tasks: Run Task → Workspace: Setup**. Setup checks installed prerequisites and
does not install software. macOS app work requires Xcode and XcodeGen; Linux can
use the core package. Use Swiftly for the local `.swift-version` if installed;
select the matching toolchain with **Swift: Select Toolchain**. Shell tasks use
`swift` on PATH, so check `swift --version` if editor and terminal disagree.

**Swift: Verify** builds tests before running them, then lints. **Swift: Lint**
populates Problems; save formats the current file but does not run the full lint.
**Swift: Format all** rewrites Sources, Tests, and App intentionally.

## Debugging and app integration

Use **App: Build, run, and attach** in Run and Debug, then select the NotchSuite
process from this checkout. The app is launched as a bundle before attachment;
there is no separate CodeLLDB requirement. macOS may ask for debugger permissions.
The process picker is intentional when other worktrees also run NotchSuite.
Core test debugging is provided by the Swift extension's Test Explorer.

`Package.swift` describes NotchCore and its tests, not App. Build tasks validate
App with Xcode; configuring a debugger does not supply Xcode-aware completion.
A future Xcode build-server integration must be evaluated separately, with its
required executable and generated configuration verified before being enabled.
Use Xcode for app indexing and debugging when needed in the meantime.

Log/telemetry tasks keep running: stop their task terminals when finished.
Release build compiles the app without relaunching it. Run only one build/run
operation per checkout at a time.

## Codex and worktrees

The environment setup prepares fresh worktrees from their own root. Run and build
actions require macOS. Shared project config is loaded only for trusted projects;
trust, credentials, models, installed plugins/MCP servers, and permissions belong
to the user's settings. No empty hooks, fake connectors, or account defaults are
required to make this repository scaffold functional.

Git manages worktrees; inspect them with `git worktree list`. Existing Claude
checkouts live in `.claude/worktrees/`; Codex chooses its own worktree locations.
Do not commit checkout contents. Keep machine-specific tool paths in VS Code user
settings (for example `todo-tree.ripgrep.ripgrep`).

## Validation limits

For Codex Cloud environment setup and Linux debugging, see [the Cloud guide](cloud.md).
The local `.codex/environments/environment.toml` configures desktop worktrees
and actions; Cloud installation is configured in the Cloud environment itself.

JSON/TOML and scripts can be checked from the shell. VS Code task rendering,
format-on-save, debugger attachment, and Codex action/worktree UI behavior need
an editor session to verify. A successful shell build alone does not prove those
UI integrations.

References: [VS Code debugging](https://code.visualstudio.com/docs/debugtest/debugging),
[Codex local environments](https://learn.chatgpt.com/docs/environments/local-environment),
and [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference).
