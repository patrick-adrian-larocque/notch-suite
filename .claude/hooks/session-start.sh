#!/bin/bash
# Sets up Claude Code web sessions: code-search tools (fd, fzf, rg, ast-grep), then
# `swift` and `lldb` via Docker, since download.swift.org is blocked.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Best-effort: a failed install must never block the Swift setup below.
# .claude/rules/code-search.md describes the fallback for each missing tool.
install_search_tools() {
  local apt_packages=()
  command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1 || apt_packages+=(fd-find)
  command -v fzf >/dev/null 2>&1 || apt_packages+=(fzf)
  command -v rg >/dev/null 2>&1 || apt_packages+=(ripgrep)
  if [ ${#apt_packages[@]} -gt 0 ]; then
    timeout 120 apt-get update -qq >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive timeout 180 apt-get install -y -qq --no-install-recommends \
      "${apt_packages[@]}" >/dev/null 2>&1 || true
  fi
  # Debian/Ubuntu name the fd binary `fdfind`.
  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi

  if ! command -v ast-grep >/dev/null 2>&1; then
    PIP_ROOT_USER_ACTION=ignore timeout 180 pip install -q ast-grep-cli >/dev/null 2>&1 ||
      timeout 180 npm install -g --silent @ast-grep/cli >/dev/null 2>&1 ||
      true
  fi
  # Both packages also install an `sg` alias that shadows the system `sg` (switch group).
  if [ -e /usr/local/bin/sg ] && /usr/local/bin/sg --version 2>/dev/null | grep -q ast-grep; then
    rm -f /usr/local/bin/sg
  fi

  local available=() missing=() tool
  for tool in fd fzf rg ast-grep; do
    if command -v "$tool" >/dev/null 2>&1; then available+=("$tool"); else missing+=("$tool"); fi
  done
  echo "Code-search tools available: ${available[*]:-none}${missing:+; missing: ${missing[*]} (use the fallbacks in .claude/rules/code-search.md)}."
}
install_search_tools

image="swift:6.4-noble"
mirror="mirror.gcr.io/library/$image"

if ! docker info >/dev/null 2>&1; then
  nohup dockerd >/var/log/dockerd.log 2>&1 &
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  if ! docker info >/dev/null 2>&1; then
    echo "dockerd did not start; see /var/log/dockerd.log" >&2
    exit 1
  fi
fi

pull_image() {
  local attempt
  for attempt in 1 2 3; do
    # Docker Hub rate-limits anonymous pulls from shared egress IPs; Google's mirror
    # serves the identical image, so try it first.
    if docker pull -q "$mirror" >/dev/null 2>&1; then
      docker tag "$mirror" "$image"
      return 0
    fi
    if docker pull -q "$image" >/dev/null 2>&1; then
      return 0
    fi
    sleep $((attempt * 5))
  done
  return 1
}

if ! docker image inspect "$image" >/dev/null 2>&1; then
  if ! pull_image; then
    echo "Could not pull $image from $mirror or Docker Hub" >&2
    exit 1
  fi
fi

chmod +x "$CLAUDE_PROJECT_DIR/scripts/swift-in-docker.sh"
for tool in swift lldb; do
  ln -sf "$CLAUDE_PROJECT_DIR/scripts/swift-in-docker.sh" "/usr/local/bin/$tool"
done

echo "Swift toolchain ready: 'swift' and 'lldb' on PATH run inside Docker image $image (Linux, so no SwiftUI/AppKit; macOS builds run in CI)."
