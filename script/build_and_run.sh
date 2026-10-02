#!/usr/bin/env bash
set -euo pipefail

mode="${1:-run}"
case "$mode" in
  run|--build-only|--verify|--debug|--logs|--telemetry) ;;
  *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
command -v xcodegen >/dev/null || { echo "Install XcodeGen with: brew install xcodegen" >&2; exit 1; }
xcodegen generate
xcodebuild build -project NotchSuite.xcodeproj -scheme NotchSuite \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData
app_bundle="$root_dir/build/DerivedData/Build/Products/Debug/NotchSuite.app"
app_binary="$app_bundle/Contents/MacOS/NotchSuite"
[[ "$mode" == --build-only ]] && exit 0
# Stop only this checkout's app, leaving instances from other worktrees alone.
while read -r process_id executable; do
  if [[ "$executable" == "$app_binary" ]]; then
    kill "$process_id"
    for _ in {1..50}; do
      kill -0 "$process_id" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$process_id" 2>/dev/null; then
      echo "Previous app instance did not stop; quit it and retry." >&2
      exit 1
    fi
  fi
done < <(ps -axo pid=,comm=)
if [[ "$mode" == --debug ]]; then
  exec xcrun lldb -- "$app_binary"
fi
/usr/bin/open -n "$app_bundle"
case "$mode" in
  --verify)
    sleep 2
    ps -axo comm= | grep -Fx "$app_binary" >/dev/null
    echo "Notch Suite is running."
    ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "NotchSuite"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.patricklarocque.NotchSuite"' ;;
esac
