#!/bin/bash
# Runs a Swift toolchain command (swift, lldb, ...) inside the official Linux image.
# Symlink it as the tool name (e.g. /usr/local/bin/swift), or call it as
# `swift-in-docker.sh <tool> [args...]`.
set -euo pipefail

image="${NOTCH_SWIFT_IMAGE:-swift:6.4-noble}"

tool="$(basename "$0")"
if [ "$tool" = "swift-in-docker.sh" ]; then
  tool="${1:?usage: swift-in-docker.sh <tool> [args...]}"
  shift
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

args=(
  --rm -i
  --network host
  # lldb needs ptrace inside the container.
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined
  -v "$root:$root" -w "$PWD"
  -v swiftpm-cache:/root/.cache
  -e HTTPS_PROXY -e https_proxy -e NO_PROXY -e no_proxy
)

ca=/root/.ccr/ca-bundle.crt
if [ -f "$ca" ]; then
  args+=(-v "$ca:/etc/ccr-ca.crt:ro" -e GIT_SSL_CAINFO=/etc/ccr-ca.crt -e SSL_CERT_FILE=/etc/ccr-ca.crt)
fi

if [ -t 0 ] && [ -t 1 ]; then
  args+=(-t)
fi

exec docker run "${args[@]}" "$image" "$tool" "$@"
