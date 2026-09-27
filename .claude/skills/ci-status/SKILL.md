---
name: ci-status
description: Summarize GitHub Actions results for the current branch or a PR. Lists which jobs passed or failed, finds the first real error in failing logs, and reviews artifacts such as snapshot images. Use when asked whether CI passed, why CI is red, or right after pushing.
argument-hint: "[pr-number]"
---

Report the CI state for PR $ARGUMENTS, or for the current branch if no PR number is given.

Use whichever GitHub tools the session has: GitHub MCP tools in cloud sessions, or `gh run list` / `gh run view --log-failed` locally.

1. List the latest workflow run for each workflow on the branch's head commit, with each job's status and duration.
2. Treat a skipped macOS job on a draft PR as expected (it's skipped to save minutes), not as a failure.
3. For each failed job:
   - Fetch its logs and find the first real error, not the cascade after it.
   - Quote `file:line` and the smallest useful excerpt.
4. If the run uploaded artifacts such as snapshot images, download them, look at the images, and describe any visual problems.
5. Classify each failure as one of:
   - caused by this branch's changes
   - also failing on `main`
   - infrastructure, only with evidence, such as the same commit passing earlier
6. Propose a fix. Don't push anything unless asked.

For a long or unclear failure, delegate to the `macos-ci-investigator` agent.
