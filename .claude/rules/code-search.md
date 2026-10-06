# Finding and reading code

## Defaults
These are always available:
- **Find files by name or path pattern:** the Glob tool. Some Claude Code builds don't offer it; there, `find` in Bash is the replacement (the shell snapshot maps it to the embedded `bfs`). Check `ToolSearch` before assuming it's missing.
- **Search text or regex:** the Grep tool (it is ripgrep), or `rg`/`grep` in Bash when the tool isn't offered (`grep` maps to the embedded `ugrep`, which has no lookahead).
- **Read a file:** the Read tool, with `offset`/`limit` for large files.
- In zsh, an unmatched glob like `*/*.jsonl` aborts the command; use `find` instead.

## Extra tools, for jobs the defaults can't do
In cloud sessions the SessionStart hook installs these. Its startup line says which ones are available.

| Need | Use | If it's missing or fails |
|---|---|---|
| Find code by structure: "every SwiftUI view", "calls to `foo(...)`", "types conforming to `P`" | `ast-grep run --lang swift -p '<pattern>'` | Grep with a regex, then Read to confirm |
| Find a file when you don't know its exact name | `fd -e swift \| fzf --filter '<fuzzy query>'` | Glob with wildcards, like `**/*Notch*View*.swift` |
| List files for a shell pipeline (type filters, `-x` to run a command on each) | `fd` | `git ls-files`, then `find` |
| Search text inside a shell pipeline | `rg` | `grep -rn` |

## Rules
- Call ast-grep by its full name, `ast-grep`. Never use `sg`, which is a different system command.
- ast-grep patterns must match the code's exact syntax shape. `@Published var $P = $V` misses `@Published var p: T = v`. An empty result doesn't prove there are no matches, so confirm with Grep.
- `fzf` is interactive by default. Only run it as `fzf --filter '<query>'`.
- If a tool is missing or errors, use the fallback from the table and mention it in one line. Don't install tools mid-task unless asked.
- To search the reference repos (boring.notch, NotchDrop, mediaremote-adapter), shallow-clone them into a temporary directory outside this repo, then use the same tools.
- On a Mac, the extra tools come from `brew install fd fzf ast-grep`.

## Shell pitfalls
- zsh aborts the whole command when an unquoted glob matches nothing: `(eval):1: no matches found: --include=*.swift`. grep never runs. Quote globs and patterns: `--include='*.swift'`. The SessionStart hook turns this off on fresh sessions, but a resumed session doesn't source it.
- In Bash, `grep` is a function that runs the embedded ugrep in basic-regex mode (`-G`). `a|b` matches nothing without `-E`, with no error. Use `-E`, or `-P` for lookahead.
- The function isn't visible to `xargs`, `bash -c`, scripts or `env -i`. They get BSD grep, which has no `-P`: `grep: invalid option -- P`. Use `rg` there.
- `rg` skips gitignored paths. Add `--no-ignore` to search `build/` or `.build/`.
