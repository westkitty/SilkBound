#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_godot="$tmpdir/fake-godot"
cat > "$fake_godot" <<'FAKE_GODOT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "4.7.2.stable.official"
  exit 0
fi

case "${FIXTURE_MODE:-expected}" in
  expected)
    if [[ " $* " == *" res://tests/run_all.gd "* ]]; then
      echo "ERROR: Parse JSON failed. Error at line 0: Expected key"
    fi
    ;;
  unrelated)
    if [[ " $* " == *" res://tests/run_all.gd "* ]]; then
      echo "ERROR: Parse JSON failed. Error at line 0: Expected key"
      echo "ERROR: Unexpected test runtime failure"
    fi
    ;;
  near-miss)
    if [[ " $* " == *" res://tests/run_all.gd "* ]]; then
      echo "ERROR: Parse JSON failed. Error at line 0: Expected key (unexpected suffix)"
    fi
    ;;
  expected-on-import)
    if [[ " $* " == *" --editor "* ]]; then
      echo "ERROR: Parse JSON failed. Error at line 0: Expected key"
    fi
    ;;
  *)
    echo "Unknown FIXTURE_MODE: ${FIXTURE_MODE}" >&2
    exit 64
    ;;
esac
FAKE_GODOT
chmod +x "$fake_godot"

if ! FIXTURE_MODE=expected GODOT_BIN="$fake_godot" "$ROOT/tools/validate_project.sh" >"$tmpdir/expected.log" 2>&1; then
  cat "$tmpdir/expected.log" >&2
  echo "Validator rejected the exact expected malformed-save diagnostic." >&2
  exit 1
fi
grep -Fq 'ERROR: Parse JSON failed. Error at line 0: Expected key' "$tmpdir/expected.log"

for mode in unrelated near-miss expected-on-import; do
  if FIXTURE_MODE="$mode" GODOT_BIN="$fake_godot" "$ROOT/tools/validate_project.sh" >"$tmpdir/$mode.log" 2>&1; then
    cat "$tmpdir/$mode.log" >&2
    echo "Validator incorrectly accepted fixture mode: $mode" >&2
    exit 1
  fi
  grep -Fq 'Critical Godot diagnostic found during' "$tmpdir/$mode.log"
done

echo "Validator diagnostic-filter regression tests passed."
