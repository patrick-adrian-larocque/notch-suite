# Repository workflow for Codex

- For requested changes to this repository, finish by committing and pushing the verified changes to `origin` without asking for a separate commit or push instruction.
- For issue work, use a `claude/issue-<N>-<slug>` branch. This takes precedence over the general branch rule below.
- For other work starting on `main`, create a descriptive `codex/<task>` branch before committing. If already on a branch for the current task, keep using it. Do not push changes directly to `main`.
- For every pull request, request Codex review with `@codex review`, then follow the draft, CI, current-head review, and merge gates in [docs/review-workflow.md](docs/review-workflow.md).
- Stage and commit only files that belong to the current task. Leave unrelated changes untouched. Use a short, descriptive commit message, and never force-push.
- Do not commit or push for read-only requests, or when the user asks to keep changes local. If authentication, permissions, or branch rules prevent a push, report the blocker and the local commit state.

## Feature implementation sources

- Before planning media controls, hover/click expansion, or file drops, read the implementation sources and integration plan in [README.md](README.md).
- The owner's forks of mediaremote-adapter, boring.notch, and notchdrop are available to integrate and adapt. Inspect the relevant implementation before proposing a replacement; preserve the project's core/app boundary and required attribution.
- Report the distinction between available implementation sources and features already connected in the app. An unwired placeholder does not imply that the underlying implementation is unavailable.

## Engineering rules

- Before any non-trivial investigation, proposal, or implementation, read [docs/engineering-rules.md](docs/engineering-rules.md) and apply the relevant sections. It sets the reuse order, exact-version research, environment checks, lifecycle claims, and evidence labels (OBSERVED LOCAL FACT, UPSTREAM FACT, INFERENCE, UNVERIFIED).

## Instruction ownership

- `AGENTS.md` and, when present, `.agents/` are the Codex instruction entry points. `CLAUDE.md` and `.claude/` belong to Claude and are not Codex instruction sources; inspect them only when the task itself concerns Claude configuration.
- Shared repository context lives in provider-neutral files such as `README.md` and `docs/`, linked directly from each provider's own entry point. Concrete reviewer triggers stay in those entry points; shared policy must not copy provider, account, agent, thread, or authentication identifiers.

## Workspace commands

- Read `docs/workspace.md` for editor, Codex, and worktree setup.
- Run `./script/setup.sh` to resolve the core package and generate the macOS project.
- Run `./script/verify.sh` before pushing; app changes also require `./script/build_and_run.sh --build-only`.
- Use `./script/build_and_run.sh --verify` to build, launch, and check the app process.
- `project.yml` owns Xcode project structure; the `.xcodeproj` is generated. Use the Xcode MCP server to inspect, build, test and diagnose; use its runtime and debug tools (run, stop, code snippets, debugger, device interaction) only when the task needs them and with approval; never use its structural tools. Codex is not repository-enforced: `disabled_tools` in your local Codex config is an untested suggestion (see `docs/xcode-mcp.md`).

## Codex Cloud (Linux)

- Read `docs/cloud.md` when preparing or working in a Cloud environment. Use `./script/setup-cloud.sh` for the environment's install script; ordinary setup remains `./script/setup.sh` once Swift is installed.
- Run `./script/verify.sh` before pushing from Cloud. It builds and tests `NotchCore` and lints `Sources`, `Tests`, and `App`; it does not compile the macOS app.
- Keep portable logic in `NotchCore` and macOS services behind its protocols. Use core tests and fixtures to debug state, parsers, geometry, and shelf behavior on Linux.
- App changes still require `./script/build_and_run.sh --build-only` on a Mac or the macOS CI job before they are considered verified. When working in Cloud, report that check as pending rather than trying to run Xcode on Linux or claiming source lint verifies the app.
