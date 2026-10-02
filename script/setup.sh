#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v swift >/dev/null || { echo "Install a Swift toolchain before setup." >&2; exit 1; }
swift --version
swift package resolve
if [[ "$(uname -s)" == Darwin ]]; then
  xcodebuild -version
  command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
  xcodegen generate
fi
if ! command -v rg >/dev/null; then
  echo "Optional: install ripgrep; configure Todo Tree's executable path in user settings."
fi
