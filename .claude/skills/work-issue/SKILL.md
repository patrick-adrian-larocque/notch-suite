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
2. **Branch** off an up-to-date `main` as `claude/issue-$issue-<short-slug>`, unless the session requires a specific branch.
3. **Plan briefly:** which files change, and which test proves each acceptance criterion.
4. **Implement with tests.**
   - Follow `CLAUDE.md`.
   - Keep `NotchCore` free of AppKit, SwiftUI, and Combine.
   - If you adapt code from boring.notch, NotchDrop, or mediaremote-adapter, follow /port-from-reference.
5. **Verify** with /swift-check and fix every failure before continuing.
6. **Commit and push.** Keep commits focused, with messages that explain why.
7. **Open a draft PR** that follows `.github/pull_request_template.md`:
   - `Closes #$issue`
   - A test plan listing only what you actually ran
   - Anything that still needs verification on a real Mac
8. **Report** the PR link, plus any acceptance criterion you could not verify.
