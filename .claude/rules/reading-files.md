# Reading files, and what to do when a read fails

Read files with the Read tool. Use Grep first when you don't yet know which file or section you need.

## Default method: locate, read, follow

1. **Locate.** Find the area by symbol, file name, error text or exact phrase: Grep or `rg -n`, `ast-grep`, Glob or `fd`. No semantic-search tool is configured here, so use the closest exact-match one. Don't read the whole file yet.
2. **Read** the section around the match with `offset`/`limit` (or `sed -n 'A,Bp'`), enough to understand it.
3. **Follow** evidence, not guesses: callers, imports, references, config, tests, linked sections.
4. **Decide.** Enough evidence: stop. Not enough: expand.
5. **Expand** slightly, changing one search dimension at a time: a nearby range, a related symbol, or another relevant file. Then read, follow and decide again, only as many times as needed.
6. **Last resort:** read the whole file only when understanding genuinely needs global context, such as a short config or code whose parts depend on each other.

## When a read fails

If a read fails or comes back partial, pick the fallback that matches the cause:

| What went wrong | Fallback |
|---|---|
| File too large for one read | Read it in chunks with `offset`/`limit`, or Grep for the section first and read just that range |
| Very long single lines (minified code, one-line JSON) | Slice by character: `python3 -c 'print(open("F").read()[A:B])'`. For JSON, extract only the needed fields with `jq` |
| A tool result was too large and saved to a file | Apply the same fallbacks to that saved file |
| File is on another branch | `git show <branch>:<path>`, without switching branches |
| File isn't in the working copy (for example a reference repo) | The GitHub file-contents tool, or a shallow clone into a temporary directory outside this repo |
| An older version | `git show <commit>:<path>`, or `git log -p -- <path>` for its history |
| Binary or unknown encoding | `file` to identify it, then `strings` or `od -A x -t x1z \| head` to peek (`xxd` isn't installed in cloud sessions), or `iconv` to convert text |
| JSON | `jq` |
| YAML | `yq`, but check `yq --version` first. Cloud sessions have the jq-style Python `yq` and Macs usually have mikefarah's, and the syntax differs. Otherwise use `python3` with `yaml.safe_load` |
| Apple `.plist` | `python3` with `plistlib`, which works everywhere (`plutil` exists only on macOS) |
| Compressed | `unzip -p`, `tar -xOf`, or `zcat` to read one file without extracting everything |

## Rules
- Never guess at content you didn't read. If a read was partial, say which part you didn't read.
- Try one fallback. If it fails too, report what's blocking instead of chaining workarounds.
- When you use a fallback, say so in one line so the user knows the normal read didn't work.
