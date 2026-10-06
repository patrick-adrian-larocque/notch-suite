# Shared pull request review workflow

This file is provider-neutral repository policy. Codex reaches it through
`AGENTS.md`; Claude reaches it through `CLAUDE.md`. One provider must not use the
other's instruction file as its own instruction source. Keep provider, account,
agent, thread, and authentication identifiers out of this file.

- A draft pull request is still in progress. Mark it ready once the criteria
  checkable on a draft are verified and the Linux job, if CI runs, is green. On
  GitHub-hosted runners, marking it ready starts the macOS job.
- Request Codex review with a pull request comment: `@codex review`.
- Address actionable findings in both inline review threads and pull request
  conversation comments on the same pull request. Push fixes and reply with the
  commit and disposition of each finding.
- After every change to the pull request head, re-request Codex review. Verify
  that review completed against the current head; a request, reaction, pending
  review, or review of an earlier commit does not satisfy the gate.
- The owner merges only after applicable CI passes, current-head Codex review
  completes, and all actionable findings are addressed. A completed bot review
  or completion/no-findings comment tied to that head satisfies this policy
  without a formal GitHub `APPROVED` review.
- Separate branch protections and required approvals still apply. Report a
  conflict instead of relaxing them. Consult `.github/workflows/ci.yml` for
  watched paths; a pull request outside those filters has no CI to wait for.
- A finding that arrives after merge goes in one follow-up pull request that
  links the merged pull request.
