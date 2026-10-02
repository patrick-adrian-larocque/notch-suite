#!/bin/sh
# Prints the Authorization header for the GitHub MCP server as JSON.
# Claude Code runs this through "headersHelper" in .mcp.json each time it
# connects, so the token is never stored in a dotfile, in the repo, or in the
# environment of unrelated processes. It works from the terminal and from Xcode.
#
# Token order matches the claude() shell function in ~/.zshrc:
#   1. macOS Keychain item "claude-github-pat" (a fine-grained token is best)
#   2. the GitHub CLI's stored token (gh auth token)
# Prints nothing and exits 1 if neither is available.

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

token="$(security find-generic-password -a "${USER:-$(id -un)}" -s claude-github-pat -w 2>/dev/null)" \
  || token="$(gh auth token 2>/dev/null)"

[ -n "$token" ] || exit 1

# Tokens are plain ASCII with no quotes or backslashes, so direct printf is safe.
printf '{"Authorization":"Bearer %s"}\n' "$token"
