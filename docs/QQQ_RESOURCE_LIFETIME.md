# P018 — Godot test teardown resource evidence

## Source identity
- Repository: westkitty/SilkBound
- Previous pushed branch commit: `c8c798571d1dba12b50459be778ac5b967947b05`
- GitHub Actions run: https://github.com/westkitty/SilkBound/actions/runs/38304192370
- Job ID: 114994124976
- Runner: Ubuntu 24.04 / Godot 4.7.2, headless deterministic game tests

## Confirmed baseline warning
The Linux job completed **204 assertions, zero failures** and then reported:
- `WARNING: 7 ObjectDB instances were leaked at exit`
- `ERROR: 2 resources still in use at exit`

This happened after the test script printed its successful summary. The export process still produced a validated ARM64 debug APK. A successful package does not establish clean in-game resource ownership.

## Local differential check
Three macOS Godot 4.7.2 runs of the expanded **264-assertion** suite in `--headless --verbose` mode passed with no ObjectDB, Resource, or RID-at-exit leak diagnostics. Working-copy logs: `/Users/bigmac/.cache/silkbound-omni/p018-repeat-1.log` through `-3.log`; these are local cache evidence, not downloadable APK artifacts.

This **does not prove** the Linux warning has disappeared. Different runtime, renderer and source revision. The Linux-specific retained types remain unknown.

## Diagnostic change
The pending Android CI workflow invokes its gameplay tests with `--verbose` and emits a GitHub warning annotation if ObjectDB, Resource, or RID exit-lifetime diagnostics appear. The existing test exit-status and parser-error gates remain active. The warning is not hidden or reclassified as a passing cleanup test.

## Next decisive test
1. Obtain an authorized new commit on PR #2, then run its exact Linux Actions workflow.
2. Examine the verbose log around retained objects/resources. Record concrete object classes/paths and whether they are bound to the test harness or the running game.
3. Only after Linux reproduction, make a bounded lifetime fix with a regression check. Avoid global suppression, fake pass messages, or destructive cleanup of shared Resources.
4. Re-run Godot import, all regression tests and Android export; compare object counts before/after.
