#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
swift build --build-tests
swift test --skip-build
swift format lint --strict --recursive Sources Tests App
