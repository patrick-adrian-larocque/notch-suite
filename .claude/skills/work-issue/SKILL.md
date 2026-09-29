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
2. **Look for existing work first.** Search open PRs for one that mentions #$issue, and remote branches for `claude/issue-$issue-*`.
   - If an open PR exists, check out its branch and continue there. Never open a second PR for the same issue.
   - If the work needs another open PR's changes, stop and report which PR has to merge first. Never merge another PR's branch into yours.
3. **Branch** only when step 2 found nothing: off an up-to-date `main`, as `claude/issue-$issue-<short-slug>`, unless the session requires a specific branch.
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
   - Once every acceptance criterion is verified and CI is green, mark the PR ready for review. Don't merge it: the owner merges.
9. **Report** the PR link, whether it's still a draft, and any acceptance criterion you could not verify.
