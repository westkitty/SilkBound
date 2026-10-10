#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
"$ROOT/tools/validate_project.sh"
mkdir -p "$ROOT/build"
(cd "$ROOT" && "$GODOT_BIN" --headless --path . --export-debug "Android" build/SilkBound-debug.apk)
test -s "$ROOT/build/SilkBound-debug.apk"
unzip -tq "$ROOT/build/SilkBound-debug.apk"
sha256sum "$ROOT/build/SilkBound-debug.apk" | tee "$ROOT/build/SilkBound-debug.apk.sha256"
echo "APK created: $ROOT/build/SilkBound-debug.apk"
