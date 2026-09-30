# Repository workflow for Codex

- For requested changes to this repository, finish by committing and pushing the verified changes to `origin` without asking for a separate commit or push instruction.
- If working on `main`, create a descriptive `codex/<task>` branch before committing. If already on a task branch, keep using it. Do not push changes directly to `main`.
- Stage and commit only files that belong to the current task. Leave unrelated changes untouched. Use a short, descriptive commit message, and never force-push.
- For issue work, follow the branch and draft pull request workflow in `CLAUDE.md`.
- Do not commit or push for read-only requests, or when the user asks to keep changes local. If authentication, permissions, or branch rules prevent a push, report the blocker and the local commit state.
