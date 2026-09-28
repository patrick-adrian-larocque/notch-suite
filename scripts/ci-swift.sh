#!/bin/bash
# Runs `swift <args>` for CI's Linux job inside the official Linux image
# ($SWIFT_IMAGE). The same command works on GitHub's Ubuntu runners and on the
# self-hosted Mac, where OrbStack provides Docker (docs/self-hosted-runner.md).
set -euo pipefail

image="${SWIFT_IMAGE:?set SWIFT_IMAGE, e.g. swift:6.4-noble}"

if ! command -v docker >/dev/null 2>&1; then
  echo "::error::docker not found. On the self-hosted Mac, make sure OrbStack is running and docker is on the runner's PATH (docs/self-hosted-runner.md)."
  exit 1
fi

# Mount the workspace at the same path so .build stays valid between steps, and
# keep SwiftPM's download cache in a named volume that outlives the container.
exec docker run --rm \
  -v "$PWD:$PWD" -w "$PWD" \
  -v notch-suite-swiftpm:/root/.cache \
  "$image" swift "$@"
