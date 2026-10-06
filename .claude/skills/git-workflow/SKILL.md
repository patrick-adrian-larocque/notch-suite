---
name: git-workflow
description: This project's git conventions for branching, committing, pushing, and opening PRs (branch names, what to stage, commit attribution, pre-push checks, which remotes never to push to). Use before creating a branch, committing, pushing, or opening a PR here.
argument-hint: "[branch|commit|push|pr]"
---

Follow these rules for the git step in `$ARGUMENTS`, or for whichever steps you are about to do. For a whole issue, use /work-issue, which includes them.

Read-only git (`status`, `diff`, `log`, `branch`) needs no approval. Anything that writes goes through the normal permission prompt; don't add `Bash(git ... *)` allow rules (`CLAUDE.md` explains why).

## Branch
- One issue, one branch, one PR. Name it `claude/issue-<N>-<short-slug>`, unless the session assigns its own name.
- Before creating one, check for existing work: `gh pr list --head "<bare-name>" --state all --json state,number`. Use the bare name, never `origin/<name>`, which returns `[]`. An open PR always wins; continue it instead of opening a second.
- Don't judge "already merged" by git ancestry. Squash merges leave no trace in `main`'s history.
- Never merge another open PR's branch into yours. If you need it, say so in the PR and wait for it to merge.
- Branch off an up-to-date `main`. A worktree (`.claude/worktrees/`) branches from local HEAD, so switch to the branch you want first.

## Commit
1. `git status` and `git diff` first. Read what you are about to commit.
2. Stage files by name. Never `git add -A` or `git add .`.
3. Never stage: `.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/*.local.md`, `build/`, `.build/`, `NotchSuite.xcodeproj/`, `.swift-version`, or anything that looks like a secret (`.env*`, `*.p12`, `*.mobileprovision`, `*.cer`). They are gitignored; if one shows up, stop and find out why.
4. Keep commits focused. The message says why, not just what.
5. End the message with the attribution trailer the session gives you. Add none if the session gives none.
6. Don't use `--no-verify`, `--amend`, or `reset --hard` unless asked. A failed hook means fix the cause and make a new commit.

## Push
1. Run /swift-check first. On a Mac, if the change touches `App/` or `project.yml`, also run /macos-build.
2. `git remote -v` must show only this repo's `origin`. Never push to `patrick-adrian-larocque/boring.notch`, `notchdrop`, or `mediaremote-adapter`; they are read-only references.
3. Never force-push, and never push to `main` directly.
4. If the PR ports code from a reference repo, run the `license-auditor` agent before it merges (see /port-from-reference).

## Pull request
- Open it as a draft, following `.github/pull_request_template.md`, with `Closes #<N>`.
- The test plan lists only what you actually ran.
- End the description with the PR attribution line the session gives you, if any.
- Mark it ready once the checkable criteria are verified and the Linux job, if CI runs, is green. Ask the owner to comment `@claude review` (see `CLAUDE.md`); don't request Codex, Copilot or any other automated review. Follow `docs/review-workflow.md`: all actionable inline and conversation findings addressed, applicable CI passing, and separate branch protections satisfied. The owner merges.

Report what you did, and what you stopped on, in a few lines.
