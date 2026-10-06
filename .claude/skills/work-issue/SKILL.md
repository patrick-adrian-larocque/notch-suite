---
name: work-issue
description: Implement a GitHub issue end to end. Reads the issue, continues any existing PR or branch for it (or branches), implements with tests, runs /swift-check, opens or updates the PR that closes the issue, marks it ready, and addresses review findings the owner raises.
disable-model-invocation: true
argument-hint: "[issue-number]"
arguments: [issue]
---

Implement GitHub issue #$issue in this repository.

1. **Read the issue and its comments.**
   - If a "Depends on" issue is still open, stop and report that instead of working around it.
   - If the acceptance criteria are missing or ambiguous, ask instead of guessing.
2. **Look for existing work first.** Search open PRs whose description closes #$issue (`Closes`, `Fixes` or `Resolves #$issue`), and remote branches named `claude/issue-$issue-*`. A PR that only mentions the issue, for example as a dependency or a follow-up, isn't this issue's PR. `git branch -r` only shows refs already fetched, so first run `git fetch origin --prune` to refresh them. To list the branches, run `git branch -r --list 'origin/claude/issue-$issue-*'`, with the issue number substituted before you run it: for issue 7, that is `git branch -r --list 'origin/claude/issue-7-*'`. Always substitute the real issue number into the command; never run it with a placeholder. For each one, strip the `origin/` prefix and run `gh pr list --head "<bare-name>" --state all --json state,number`. Never pass the `origin/` prefix: `gh pr list --head origin/<name>` returns `[]`. Read the result like this, and an open PR always wins:
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
3. **Branch** only when step 2 found no PR or branch to continue: off an up-to-date `main`, as `claude/issue-$issue-<short-slug>`, unless the session requires a specific branch.
4. **Plan briefly:** which files change, and which test proves each acceptance criterion.
5. **Implement with tests.**
   - Follow `CLAUDE.md`.
   - Keep `NotchCore` free of AppKit, SwiftUI, and Combine.
   - If you adapt code from boring.notch, NotchDrop, or mediaremote-adapter, follow /port-from-reference.
6. **Verify** with /swift-check and fix every failure before continuing. If the change touches `App/` or `project.yml` and you are on a Mac, also run /macos-build.
7. **Commit and push.** Keep commits focused, with messages that explain why.
8. **Open or update the PR.**
   - With no PR yet, open a draft that follows `.github/pull_request_template.md`. It says `Closes #$issue` and has a test plan listing only what you actually ran, plus anything that still needs a real Mac.
   - With an existing PR, update its description instead.
   - Mark the PR ready for review once every acceptance criterion you can check on a draft is verified and the Linux job, if CI runs, is green. Consult `.github/workflows/ci.yml` for watched paths; outside those filters no CI runs and there is nothing to wait for.
   - On GitHub's runners, marking the PR ready is what starts the macOS job, so wait for it before counting a macOS criterion as verified. Then ask the owner to comment `@claude review` on the PR (see `CLAUDE.md`). Don't request Codex, Copilot or any other automated review.
9. **Address review findings on this PR.**
   - Check both inline review threads and PR conversation comments for actionable findings. Push fixes and reply with the commit and disposition of each finding.
   - After every change to the PR head, confirm that findings raised against an earlier commit still have a disposition on the current head.
   - Follow `docs/review-workflow.md` for the draft, CI and finding-disposition gates until all actionable findings are addressed and applicable CI passes. Separate branch protections and required approvals still apply. Report conflicts, never relax protections. Don't merge: the owner merges.
10. **Report** the PR link, whether it's still a draft, the state of each CI job, the current head, any unresolved actionable findings or protection conflicts, and any acceptance criterion you could not verify.
