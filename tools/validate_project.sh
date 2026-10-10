#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot executable not found: $GODOT_BIN" >&2
  exit 127
fi

version="$($GODOT_BIN --version)"
if [[ "$version" != 4.7.2.stable* ]]; then
  echo "Expected Godot 4.7.2 stable; got: $version" >&2
  exit 2
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_checked() {
  local label="$1"
  shift
  local log="$tmpdir/${label}.log"
  echo "== $label =="
  (cd "$ROOT" && "$GODOT_BIN" "$@") 2>&1 | tee "$log"
  if grep -Eiq 'SCRIPT ERROR|Parse Error|Failed loading resource|Invalid scene|ERROR:' "$log"; then
    echo "Critical Godot diagnostic found during $label." >&2
    exit 1
  fi
}

run_checked import --headless --editor --path . --import --quit
run_checked tests --headless --path . --script res://tests/run_all.gd
run_checked startup-smoke --headless --path . --quit-after 120

echo "Godot $version import, regression tests and startup smoke test passed."
