# SilkBound Operational State

<!-- operational-state:metadata
{
  "schema_version": 1,
  "project_id": "silkbound-android",
  "project_name": "SilkBound — The Outer Reaches",
  "project_root": "github://westkitty/SilkBound",
  "artifact_path": "scenes/main.tscn",
  "state_revision": 1,
  "last_updated": "2026-10-11T06:33:30Z",
  "current_baseline": {
    "identity": "PR #2 implementation 4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab",
    "state": "current-baseline",
    "last_verified": "2026-10-11T06:33:28Z"
  },
  "scope_boundaries": [
    "Godot 4.7.2 offline Android ARM64 survival game",
    "non-canon Starsilk operational sandbox",
    "draft PR #2; no main merge"
  ]
}
-->

## 1. Project Identity and Scope

GitHub: `westkitty/SilkBound`. Offline original Godot 4.7.2 landscape Android ARM64 survival sandbox, explicitly non-canon within Starsilk's Blood Eclipse War era. See `docs/CANON_BOUNDARIES.md` for controlling fictional boundaries.

## 2. Current Baseline

`main`: `a8c896cc6e9181b84f63fee939eed26c8687eb65` (prior verified merge). Draft PR #2 feature implementation: `4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab` (Godot/Android CI verified). Later documentation revision may differ without changing executable code.

## 3. Artifact Contract

Three seeded planets; salvaging, crafting, sheltering, surviving, surveying Glassfall before/after shear, ship repair/coolant, quests and local save/restore. Mobile-first touch controls and original assets retained; build a debug Android APK with signed package and checksum.

## 4. Active Invariants

<!-- operational-state:entry
{
  "id": "INV-001",
  "title": "Canon and game purpose",
  "state": "requested",
  "rule": "No new named canon incidents, Starsilk mining or Kail cameo; player is fictional captain; death is final.",
  "evidence": "docs/CANON_BOUNDARIES.md"
}
-->
### INV-001 — Canon and game purpose

- State: **requested**
- Evidence: docs/CANON_BOUNDARIES.md
<!-- /operational-state:entry -->
<!-- operational-state:entry
{
  "id": "INV-002",
  "title": "Gameplay/persistence contract",
  "state": "requested",
  "rule": "Preserve offline mode, procedural seeds, materials, cost gates, save schema, world edits, and real collisions even for hidden visuals.",
  "evidence": "README.md and tests/run_all.gd"
}
-->
### INV-002 — Gameplay/persistence contract

- State: **requested**
- Evidence: README.md and tests/run_all.gd
<!-- /operational-state:entry -->

## 5. Verified Working Behavior

<!-- operational-state:entry
{
  "id": "VER-001",
  "title": "Godot import, test, startup and Android ARM64 build",
  "state": "verified",
  "evidence": "GitHub Actions 38118392548 and 38118394708: success; 178 test assertions, zero failures; debug artifact 11694422822",
  "artifact_revision": "4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab",
  "recheck_trigger": "Script/scene/asset/export change"
}
-->
### VER-001 — Godot import, test, startup and Android ARM64 build

- State: **verified**
- Evidence: GitHub Actions 38118392548 and 38118394708: success; 178 test assertions, zero failures; debug artifact 11694422822
<!-- /operational-state:entry -->
<!-- operational-state:entry
{
  "id": "VER-002",
  "title": "Source-level scanner redraw and chunk visibility logic",
  "state": "verified",
  "evidence": "Godot CI 38118392548: 9 to 1 scanner redraw requests; 9 to 2 visible art chunks near ship; 9 collision chunks intact",
  "artifact_revision": "4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab",
  "recheck_trigger": "Scanner/terrain/camera change"
}
-->
### VER-002 — Source-level scanner redraw and chunk visibility logic

- State: **verified**
- Evidence: Godot CI 38118392548: 9 to 1 scanner redraw requests; 9 to 2 visible art chunks near ship; 9 collision chunks intact
<!-- /operational-state:entry -->

## 6. Known Not Working

No currently verified production regression on final implementation HEAD. An older one-shot tile timing comparison was unsound and superseded, not a confirmed code failure.

## 7. Implemented but Unverified

<!-- operational-state:entry
{
  "id": "UNV-001",
  "title": "Physical Android visual and performance behavior",
  "state": "implemented-unverified",
  "evidence": "CI builds and headless tests only; no native touchscreen screen capture, frame-time or thermal metrics yet",
  "validation_method": "docs/ANDROID_FIELD_TEST.md"
}
-->
### UNV-001 — Physical Android visual and performance behavior

- State: **implemented-unverified**
- Evidence: CI builds and headless tests only; no native touchscreen screen capture, frame-time or thermal metrics yet
<!-- /operational-state:entry -->

## 8. Unknown or Evidence-Stale State

Actual on-device FPS/p95, GPU draw commands, low-memory behavior, long-session stability, offscreen chunk reveal, and performance on real phones or tablets are unknown.

## 9. Pending Work

<!-- operational-state:entry
{
  "id": "PND-001",
  "title": "Physical device QA before release merge",
  "state": "pending",
  "evidence": "docs/ANDROID_FIELD_TEST.md lists repeatable touch, world-travel, scanner, camera and persistence checks",
  "blocks_completion": true
}
-->
### PND-001 — Physical device QA before release merge

- State: **pending**
- Evidence: docs/ANDROID_FIELD_TEST.md lists repeatable touch, world-travel, scanner, camera and persistence checks
<!-- /operational-state:entry -->

## 10. Active Decisions, Defaults, and Prohibitions

Maintain draft PR #2 on `uplift/glassfall-evidence-20261011`, not `main`. No force-push, dependencies, destructive history changes, canon additions or premature production-release claims. Existing GitHub repository is already initialized; do not run `git init` again.

## 11. Validation and Evidence Matrix

| ID | Evidence state | Proof location | Recheck trigger |
|---|---|---|---|
| INV-001 | requested | docs/CANON_BOUNDARIES.md | Canon/lore/content change |
| INV-002 | requested | tests/run_all.gd | Save, world, economy, input changes |
| VER-001 | verified | Actions 38118392548, 38118394708 | Script/scene/build changes |
| VER-002 | verified | docs/PERFORMANCE.md and 178 test assertions | Renderer/scanner modifications |
| UNV-001 | implemented-unverified | docs/ANDROID_FIELD_TEST.md | Physical device capture |
| PND-001 | pending | docs/ANDROID_FIELD_TEST.md | Before merging PR #2 |

## 12. Current Change Scope and Impact Radius

Bounded performance changes: resolved tile cache, focused scanner overlay redrawing, priority material bearing, viewport-only art chunk culling, and transient-state repair. Changed source/test paths: `scripts/world/world_grid.gd`, `scripts/core/game.gd`, `tests/run_all.gd`. Full collision and saved modifications remain authoritative.

## 13. Compact Revision Log

- Revision 1, 2026-10-11: bootstrapped current working control plane from verified GitHub source and CI. Hardware limitations and pending device QA remain explicit.
