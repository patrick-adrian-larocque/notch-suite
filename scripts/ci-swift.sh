#!/bin/bash
# Runs `swift <args>` for CI's Linux job inside the official Linux image
# ($SWIFT_IMAGE). The same command works on GitHub's Ubuntu runners and on the
# self-hosted Mac, where OrbStack provides Docker (docs/self-hosted-runner.md).
#
# Optional environment:
#   SWIFT_IMAGE     image to run; defaults to the one ci.yml pins
#   SWIFT_PLATFORM  e.g. linux/amd64, to match GitHub's x86_64 runners; OrbStack
#                   on Apple silicon runs linux/arm64 natively by default
set -euo pipefail

# Keep in sync with SWIFT_IMAGE in .github/workflows/ci.yml.
image="${SWIFT_IMAGE:-swift:6.4-noble}"

if ! command -v docker >/dev/null 2>&1; then
  echo "::error::docker not found. On the self-hosted Mac, make sure OrbStack is running and docker is on the runner's PATH (docs/self-hosted-runner.md)."
  exit 1
fi

# The docker CLI can be on PATH while its daemon is down. On a Mac that means
# OrbStack isn't running, so start it instead of failing on an opaque socket error.
if ! docker info >/dev/null 2>&1; then
  if command -v orbctl >/dev/null 2>&1; then
    echo "OrbStack isn't running; starting it..." >&2
    orbctl start >&2 || true
    for _ in $(seq 1 60); do
      docker info >/dev/null 2>&1 && break
      sleep 1
    done
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "::error::The Docker daemon isn't reachable. On the self-hosted Mac, start OrbStack (docs/self-hosted-runner.md)."
    exit 1
  fi
fi

platform=()
if [ -n "${SWIFT_PLATFORM:-}" ]; then
  platform=(--platform "$SWIFT_PLATFORM")
fi

# Mount the workspace at the same path so .build stays valid between steps, and
# keep SwiftPM's download cache in a named volume that outlives the container.
exec docker run --rm ${platform[@]+"${platform[@]}"} \
  -v "$PWD:$PWD" -w "$PWD" \
  -v notch-suite-swiftpm:/root/.cache \
  "$image" swift "$@"
