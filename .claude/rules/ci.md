---
paths:
  - ".github/workflows/**"
---

# Workflow rules

- Every job sets `timeout-minutes`.
- Set `permissions:` explicitly and as narrowly as the job allows.
- Workflows triggered by pushes or comments use a `concurrency` group. CI cancels in-progress runs on the same ref; the Claude workflows queue instead, so a reply is not cut off.
- Pin actions to a major version tag such as `actions/checkout@v6`. Never `@main` or `@latest`.
- macOS jobs cost 10x on GitHub-hosted runners. Keep them behind the Linux job (`needs:`), skip draft PRs when hosted, and add one only when a change needs macOS.
- Runner choice goes through the `CI_RUNNER` repository variable. Fork PRs must always stay on GitHub-hosted runners. Keep the existing `runs-on` expression's shape when adding a job.
- Swift on macOS runs as `xcrun swift`, so a swiftly toolchain can't replace Xcode's compiler. Swift on Linux runs through `scripts/ci-swift.sh`.
