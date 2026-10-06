---
name: work-issue
description: Implement a GitHub issue end to end. Reads the issue, continues any existing PR or branch for it (or branches), implements with tests, runs /swift-check, opens or updates the PR that closes the issue, marks it ready, and addresses Codex review findings.
---

Implement GitHub issue #<N> in this repository, where <N> is the number the user gave.

1. **Read the issue and its comments.**
   - If a "Depends on" issue is still open, stop and report that instead of working around it.
   - If the acceptance criteria are missing or ambiguous, ask instead of guessing.
2. **Look for existing work first.** Search open PRs whose description closes #<N> (`Closes`, `Fixes` or `Resolves #<N>`), and remote branches named `claude/issue-<N>-*`. A PR that only mentions the issue, for example as a dependency or a follow-up, isn't this issue's PR. `git branch -r` only shows refs already fetched, so first run `git fetch origin --prune` to refresh them. To list the branches, run `git branch -r --list 'origin/claude/issue-<N>-*'`, with the issue number substituted before you run it: for issue 7, that is `git branch -r --list 'origin/claude/issue-7-*'`. Always substitute the real issue number into the command; never run it with a placeholder. For each one, strip the `origin/` prefix and run `gh pr list --head "<bare-name>" --state all --json state,number`. Never pass the `origin/` prefix: `gh pr list --head origin/<name>` returns `[]`. Read the result like this, and an open PR always wins:
   - Any `OPEN` PR: the branch is in progress. Continue it, even if it also has a merged PR from earlier work.
   - Only `MERGED` or `CLOSED` PRs: the branch is finished. Ignore it.
   - No PR at all: an interrupted run (see below).

   Don't use git ancestry to decide this: squash and rebase merges leave the branch's commits out of `main`'s history, and this repo doesn't delete merged branches.
   - One open PR from a branch in this repository: check out that branch and continue there. Never open a second PR for the same issue.
   - If the branch to continue is already checked out in another worktree (`git worktree list` shows it), git won't check it out a second time. If you are `feature-worker` (your own isolated worktree), stop and report which worktree holds it. Otherwise work in that worktree only if it is the current session's own; if it isn't, stop and report it. Don't use `--force`.
   - An open PR from a fork: you can't push to it, so stop and report that PR.
   - A matching branch with no open PR, left by an interrupted run: check it out and continue there. Step 8 opens its PR.
   - More than one candidate (any open PR, or a branch with no PR at all): stop and list them. The owner decides which one continues.
   - If the work needs another open PR's changes, stop and report which PR has to merge first. Never merge another PR's branch into yours.
3. **Branch** only when step 2 found no PR or branch to continue: off an up-to-date `main`, as `claude/issue-<N>-<short-slug>`, unless the session requires a specific branch.
4. **Plan briefly:** which files change, and which test proves each acceptance criterion.
5. **Implement with tests.**
   - Follow `AGENTS.md`.
   - Keep `NotchCore` free of AppKit, SwiftUI, and Combine.
   - If you adapt code from boring.notch, NotchDrop, or mediaremote-adapter, follow /port-from-reference.
6. **Verify** with /swift-check and fix every failure before continuing. If the change touches `App/` or `project.yml` and you are on a Mac, also run /macos-build.
7. **Commit and push.** Keep commits focused, with messages that explain why.
8. **Open or update the PR.**
   - With no PR yet, open a draft that follows `.github/pull_request_template.md`. It says `Closes #<N>` and has a test plan listing only what you actually ran, plus anything that still needs a real Mac.
   - With an existing PR, update its description instead.
   - Mark the PR ready for review once every acceptance criterion you can check on a draft is verified and the Linux job, if CI runs, is green. Consult `.github/workflows/ci.yml` for watched paths; outside those filters no CI runs and there is nothing to wait for.
   - Then request Codex review with a PR comment: `@codex review`. On GitHub's runners, marking the PR ready is what starts the macOS job, so wait for it before counting a macOS criterion as verified.
9. **Address Codex findings on this PR.**
   - Check both inline review threads and PR conversation comments for actionable findings. Push fixes and reply with the commit and disposition of each finding.
   - After every change to the PR head, re-request Codex review. Verify review completion against the current head; an earlier review, request, reaction, or pending review does not satisfy the gate.
   - Follow `docs/review-workflow.md` until Codex review of the current head has completed, all actionable findings are addressed, and applicable CI passes. A completed bot review or completion/no-findings comment tied to that head suffices without a formal GitHub `APPROVED` review; separate branch protections and required approvals still apply. Report conflicts, never relax protections. Don't merge: the owner merges.
10. **Report** the PR link, whether it's still a draft, the state of each CI job, the current head and completed Codex review evidence, any unresolved actionable findings or protection conflicts, and any acceptance criterion you could not verify.
