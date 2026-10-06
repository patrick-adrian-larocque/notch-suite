#!/bin/bash
# Sets up Claude Code web sessions: code-search tools (fd, fzf, rg, ast-grep), then
# `swift` and `lldb` via Docker, since download.swift.org is blocked.
set -euo pipefail

# zsh aborts a whole Bash command when an unquoted glob matches nothing ("no matches
# found: --include=*.swift"), so the grep or find in it never runs. Claude Code runs
# CLAUDE_ENV_FILE before each Bash command; keep zsh's nonomatch (pass the glob through,
# like bash) in effect. A resumed session doesn't source it, so code-search.md also
# says to quote globs.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'setopt nonomatch 2>/dev/null || true' >>"$CLAUDE_ENV_FILE"
fi

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  # On a Mac, tell the session whether OrbStack (the Linux CI side) is available.
  if [ "$(uname)" = "Darwin" ] && command -v orbctl >/dev/null 2>&1; then
    orb_status=$(orbctl status 2>/dev/null || true)
    if [ "$orb_status" = "Running" ]; then
      echo "OrbStack is running: /linux-check (scripts/ci-swift.sh) runs the Linux CI side."
    else
      echo "OrbStack is installed but not running: scripts/ci-swift.sh starts it on demand."
    fi
  fi
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

  # ast-grep isn't in Ubuntu's signed archive, so it comes from PyPI. This hook runs
  # as root, so pin one release and its published wheel hashes (x86_64 and arm64):
  # a new or tampered upload fails the install instead of running here. To update,
  # take the version and wheel sha256s from https://pypi.org/project/ast-grep-cli/.
  if ! command -v ast-grep >/dev/null 2>&1; then
    local version=0.45.3
    local sha256_x86_64=2d151b89c6d45c2640338fe5d24b2ee0810224902d603cb271803bf7418054ea
    local sha256_aarch64=ced023ae9fbc7c779570cd8bcc0fa7626d9561afd60369d3c335bfce2ca565b3
    local requirements
    requirements=
    if requirements=$(mktemp) &&
      printf 'ast-grep-cli==%s --hash=sha256:%s --hash=sha256:%s\n' \
        "$version" "$sha256_x86_64" "$sha256_aarch64" >"$requirements"; then
      PIP_ROOT_USER_ACTION=ignore timeout 180 pip install -q --no-deps --only-binary=:all: \
        --require-hashes -r "$requirements" >/dev/null 2>&1 || true
    fi
    [ -z "$requirements" ] || rm -f "$requirements"
  fi
  # The package also installs an `sg` alias that shadows the system `sg` (switch group).
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
