---
name: work-issue
description: Implement a GitHub issue end to end. Reads the issue, branches, implements with tests, runs /swift-check, and opens a draft PR that closes the issue.
disable-model-invocation: true
argument-hint: "[issue-number]"
arguments: [issue]
---

Implement GitHub issue #$issue in this repository.

1. **Read the issue and its comments.**
   - If a "Depends on" issue is still open, stop and report that instead of working around it.
   - If the acceptance criteria are missing or ambiguous, ask instead of guessing.
2. **Look for existing work first.** Search open PRs whose description closes #$issue (`Closes`, `Fixes` or `Resolves #$issue`), and remote branches named `claude/issue-$issue-*`. A PR that only mentions the issue, for example as a dependency or a follow-up, isn't this issue's PR. Ignore branches already merged into `main` (`git branch -r --merged origin/main` lists them).
   - One open PR from a branch in this repository: check out that branch and continue there. Never open a second PR for the same issue.
   - An open PR from a fork: you can't push to it, so stop and report that PR.
   - A matching branch with no open PR, left by an interrupted run: check it out and continue there. Step 8 opens its PR.
   - More than one open PR or unmerged branch: stop and list them. The owner decides which one continues.
   - If the work needs another open PR's changes, stop and report which PR has to merge first. Never merge another PR's branch into yours.
3. **Branch** only when step 2 found no PR or branch to continue: off an up-to-date `main`, as `claude/issue-$issue-<short-slug>`, unless the session requires a specific branch.
4. **Plan briefly:** which files change, and which test proves each acceptance criterion.
5. **Implement with tests.**
   - Follow `CLAUDE.md`.
   - Keep `NotchCore` free of AppKit, SwiftUI, and Combine.
   - If you adapt code from boring.notch, NotchDrop, or mediaremote-adapter, follow /port-from-reference.
6. **Verify** with /swift-check and fix every failure before continuing.
7. **Commit and push.** Keep commits focused, with messages that explain why.
8. **Open or update the PR.**
   - With no PR yet, open a draft that follows `.github/pull_request_template.md`. It says `Closes #$issue` and has a test plan listing only what you actually ran, plus anything that still needs a real Mac.
   - With an existing PR, update its description instead.
   - Mark the PR ready for review once every acceptance criterion you can check on a draft is verified and the Linux job is green. If the PR changes nothing `ci.yml` watches (`Package.swift`, `Package.resolved`, `Sources/`, `Tests/`, `.swift-format`, `ci.yml`, `scripts/ci-swift.sh`), no CI runs and there is nothing to wait for.
   - Then request a Copilot review. On GitHub's runners, marking the PR ready is what starts the macOS job, so wait for it before counting a macOS criterion as verified.
9. **Work Copilot's findings on this PR.**
   - For each finding, push a fix and reply on its thread with the commit.
   - Then re-request a Copilot review. It marks a finding resolved only when it re-reviews a commit that fixes it; resolving a thread by hand doesn't update its overview.
   - Repeat until the latest overview lists no open findings. Don't merge: the owner merges.
10. **Report** the PR link, whether it's still a draft, the state of each CI job, any open Copilot findings, and any acceptance criterion you could not verify.
