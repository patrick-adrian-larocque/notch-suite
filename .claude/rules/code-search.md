# Finding and reading code

## Defaults
These are built in and always available:
- **Find files by name or path pattern:** the Glob tool.
- **Search text or regex:** the Grep tool (it is ripgrep).
- **Read a file:** the Read tool, with `offset`/`limit` for large files.

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
