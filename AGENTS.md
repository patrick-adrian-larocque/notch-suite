# Repository workflow for Codex

- For requested changes to this repository, finish by committing and pushing the verified changes to `origin` without asking for a separate commit or push instruction.
- For issue work, use a `claude/issue-<N>-<slug>` branch and the draft pull request workflow in `CLAUDE.md`. This takes precedence over the general branch rule below.
- For other work starting on `main`, create a descriptive `codex/<task>` branch before committing. If already on a branch for the current task, keep using it. Do not push changes directly to `main`.
- Stage and commit only files that belong to the current task. Leave unrelated changes untouched. Use a short, descriptive commit message, and never force-push.
- Do not commit or push for read-only requests, or when the user asks to keep changes local. If authentication, permissions, or branch rules prevent a push, report the blocker and the local commit state.

## Feature implementation sources

- Before planning media controls, hover/click expansion, or file drops, read the implementation sources and integration plan in [README.md](README.md) and [CLAUDE.md](CLAUDE.md).
- The owner's forks of mediaremote-adapter, boring.notch, and notchdrop are available to integrate and adapt. Inspect the relevant implementation before proposing a replacement; preserve the project's core/app boundary and required attribution.
- Report the distinction between available implementation sources and features already connected in the app. An unwired placeholder does not imply that the underlying implementation is unavailable.

## Workspace commands

- Read `docs/workspace.md` for editor, Codex, and worktree setup.
- Run `./script/setup.sh` to resolve the core package and generate the macOS project.
- Run `./script/verify.sh` before pushing; app changes also require `./script/build_and_run.sh --build-only`.
- Use `./script/build_and_run.sh --verify` to build, launch, and check the app process.

## Codex Cloud (Linux)

- Read `docs/cloud.md` when preparing or working in a Cloud environment. Use `./script/setup-cloud.sh` for the environment's install script; ordinary setup remains `./script/setup.sh` once Swift is installed.
- Run `./script/verify.sh` before pushing from Cloud. It builds and tests `NotchCore` and lints `Sources`, `Tests`, and `App`; it does not compile the macOS app.
- Keep portable logic in `NotchCore` and macOS services behind its protocols. Use core tests and fixtures to debug state, parsers, geometry, and shelf behavior on Linux.
- App changes still require `./script/build_and_run.sh --build-only` on a Mac or the macOS CI job before they are considered verified. When working in Cloud, report that check as pending rather than trying to run Xcode on Linux or claiming source lint verifies the app.
