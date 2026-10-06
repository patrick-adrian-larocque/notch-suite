# How agent instruction files interact

Which coding agents read which instruction files, whether they interfere, and what is verified. Labels follow [engineering-rules.md](engineering-rules.md) section 9. Checked 2026-10-06.

## Versions and sources checked

| Subject | Version or revision | Date shown by the source |
| --- | --- | --- |
| Claude Code | 2.1.291 installed; [memory docs](https://code.claude.com/docs/en/memory) | none |
| Codex | [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [skills](https://learn.chatgpt.com/docs/build-skills) | none |
| VS Code Copilot | 1.140.0, commit `07f806f999227108933c2e30515b26eecc1fda74`, read from `microsoft/vscode` source at that commit | commit-pinned; docs footer 9/30/2026 |
| GitHub Copilot docs | `github/docs` file `content/copilot/reference/custom-instructions-support.md`, last commit `3cb6f44605` | 2026-10-02 |
| Copilot CLI | [add custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions) | none |

Most documentation pages show no date or version. Where a claim could change, it is pinned to a source revision or marked as unpinned.

## Who reads what

| Tool | Reads | Does not read |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` (and `.claude/CLAUDE.md`, `CLAUDE.local.md`), `.claude/rules`, `.claude/skills` | `.agents/`, `AGENTS.local.md`, `AGENTS.override.md`. Reads `AGENTS.md` only when no `CLAUDE.md` exists |
| Codex | `AGENTS.override.md` or `AGENTS.md` from the repository root down to the working directory, `.agents/skills` | `CLAUDE.md` unless added to `project_doc_fallback_filenames`; `.claude/` is not mentioned |
| VS Code Copilot | `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.claude/rules`, skills in `.agents/skills`, `.github/skills`, `.claude/skills` | |
| Copilot on GitHub.com | Cloud agent: repository, path-specific, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`. Code review: the same plus `REVIEW.md`. Chat: repository-wide and personal only | |
| Copilot CLI | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, combined | |

## Verified facts

1. **UPSTREAM FACT** (Claude memory docs, requires Claude Code v2.1.277 or later): with both `AGENTS.md` and `CLAUDE.md` in or above the working directory, Claude reads `CLAUDE.md` only. The project setting `claude-md-and-agents-md` loads both. `.claude/rules` files load alongside either. Anything under `.agents/` is not read.
2. **UPSTREAM FACT** (Codex guide): instruction files are concatenated from the root down, nearer ones last; the default size cap is 32 KiB; extra file names, such as `CLAUDE.md`, only count when listed in `project_doc_fallback_filenames`. Skills are scanned in `.agents/skills` from the working directory up to the repository root; two skills with the same name are not merged.
3. **OBSERVED LOCAL FACT** (VS Code 1.140.0 source, `chat.shared.contribution.ts`): `chat.useAgentsMdFile` defaults to `true`, `chat.useClaudeMdFile` defaults to `true`, and `chat.useNestedAgentsMdFiles` defaults to `false`. Both root files are therefore attached to chat requests unless the user turns one off. This repository's `.vscode/settings.json` sets `chat.useNestedAgentsMdFiles` to `true`.
4. **OBSERVED LOCAL FACT** (same source, `promptsServiceImpl.ts`, `promptFileLocations.ts`): skills are discovered in `.agents/skills`, `.github/skills`, `.claude/skills` and the user-level equivalents. Skills with the same folder name are deduplicated, the first one wins, and workspace skills outrank personal ones. All workspace locations share one priority, so the winner follows list order, which puts `.agents/skills` first. That tie order is an **INFERENCE** from the list order.
5. **OBSERVED LOCAL FACT** (same source, `computeAutomaticInstructions.test.ts`): plain `.md` files under `.claude/rules`, with or without `paths:` frontmatter, are loaded as instructions. This repository's `.claude/rules/*.md` are visible to VS Code Copilot.
6. **UPSTREAM FACT** (GitHub support matrix): the table in the source rows above. For VS Code chat it lists `AGENTS.md` only, but fact 3 shows `CLAUDE.md` is also on by default in 1.140.0. The installed source is trusted over the table.
7. **UPSTREAM FACT** (VS Code docs): "Applicable instruction sources are additive. Do not depend on a file order or precedence rule to resolve conflicts."
8. **UPSTREAM FACT** (Copilot CLI docs): instructions from multiple files are combined, with identical copies removed.

## What this means here

- **No interference for Claude or Codex.** Claude ignores `AGENTS.md` and `.agents/` while `CLAUDE.md` exists. Codex ignores `CLAUDE.md` and `.claude/`. This repository has no fallback setting that changes that.
- **Copilot sees both root files**, so any rule that differs by tool would conflict there. Each root file opens with a scope note saying which tool it is for, and tool-specific rules live only in that tool's file.
- **Skills with the same names in `.claude/skills` and `.agents/skills` are intentional.** VS Code lists one of each pair, so keep the two copies equivalent in what they do. Do not rely on which copy wins.
- **`.claude/rules` can reach Copilot.** Those files mention Claude Code tools, such as the Grep tool. They are accurate for Claude and only mildly misleading elsewhere.

Rules that keep it this way:

1. Tool-specific rules go in that tool's own file, and the file says so in its scope note. Shared policy goes in `docs/`.
2. Do not set Claude's project instructions to `claude-md-and-agents-md`.
3. Do not add `CLAUDE.md` to Codex's `project_doc_fallback_filenames`.
4. Do not add a `.github/copilot-instructions.md` that restates policy; point it at `docs/` if one is ever needed.

## Not verified

- How the Copilot cloud agent and code review combine `CLAUDE.md` and `AGENTS.md` when both exist. Their code is not public, and the docs list both as supported without saying how they merge.
- Whether Copilot code review truncates long instruction files. No limit was found in the GitHub docs source, so none is assumed. Note that `AGENTS.md` is about 4.6 KB and `CLAUDE.md` about 10.7 KB, with the review rules at character 912 and 6840.
- Behavior in VS Code versions other than 1.140.0, or in Insiders.
- Cursor, Gemini CLI, Windsurf, Zed and other tools were not researched.

## How to re-check

```sh
APP="/Applications/Visual Studio Code.app"
SHA=$(jq -r .commit "$APP/Contents/Resources/app/product.json")
gh api -H 'Accept: application/vnd.github.raw' \
  "repos/microsoft/vscode/contents/src/vs/workbench/contrib/chat/browser/chat.shared.contribution.ts?ref=$SHA" \
  | grep -n -A8 'USE_CLAUDE_MD\]'
gh api -H 'Accept: application/vnd.github.raw' \
  repos/github/docs/contents/content/copilot/reference/custom-instructions-support.md
claude --version
```
