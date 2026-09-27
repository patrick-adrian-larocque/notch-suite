#!/bin/bash
# Makes `swift` and `lldb` usable in Claude Code web sessions, where download.swift.org
# is blocked but Docker is available.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

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
