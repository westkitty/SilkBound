# SilkBound Operational State

<!-- operational-state:metadata
{
  "schema_version": 1,
  "project_id": "silkbound-android",
  "project_name": "SilkBound — The Outer Reaches",
  "project_root": "github://westkitty/SilkBound",
  "artifact_path": "scenes/main.tscn",
  "state_revision": 6,
  "last_updated": "2026-10-13T09:02:51Z",
  "current_baseline": {
    "identity": "Local feature branch implementation commit eb571db95fae0dd75001e0b708a1f89e14312396 (267 local Godot assertions passed); remote delivery and Android CI pending",
    "state": "current-baseline",
    "last_verified": "2026-10-13T09:02:51Z"
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

GitHub Actions 38304192370 verified commit c8c798571d1dba12b50459be778ac5b967947b05: 204 assertions / zero failures, Godot import/startup, Android ARM64 APK export and artifact 11771254350. The TWO new uncommitted Game OMNI batches together pass macOS Godot 4.7.2 import, 267 assertions / zero failures and startup. Title/Settings rendered at 1280x720; all three planets rendered at 720x405. Exact new Android CI and physical device proof are pending. Source implementation is committed locally as eb571db95fae0dd75001e0b708a1f89e14312396; push and documentation follow-up remain pending as of this record.

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

<!-- operational-state:entry
{
  "id": "VER-003",
  "title": "OMNI local engine and validator regression",
  "state": "verified",
  "evidence": "Local Godot 4.7.2 macOS: tools/validate_project.sh PASS, tests/test_validate_project.sh PASS; 204 assertions, zero failures; source working tree only",
  "artifact_revision": "uncommitted working tree based on d4028018cc9197b222daeb6242d7463f289df5c5",
  "recheck_trigger": "Source/test change or GitHub CI export"
}
-->
### VER-003 — OMNI local engine and validator regression

- State: **verified locally**, not Android hardware
- Evidence: macOS Godot 4.7.2 import, 204 assertions, startup smoke, validator self-test
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "VER-004",
  "title": "Godot visual assets and player-facing integration",
  "state": "verified",
  "evidence": "Big Mac Godot 4.7.2 GUI: 1280x720 captures of Ashlands/Glassfall/Drowned and inventory panel; Godot import/tests 204/0 and startup smoke PASS",
  "artifact_revision": "OMNI + visual candidate based on d4028018cc9197b222daeb6242d7463f289df5c5",
  "recheck_trigger": "Parallax, atlas, HUD or asset-generation changes"
}
-->
### VER-004 — Godot visual assets and player-facing integration

- State: **verified on macOS runtime**, not physical Android
- Evidence: three planetary screens and 27-icon inventory/HUD screenshot; local Godot 4.7.2 suite 204/0
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "VER-005",
  "title": "Game OMNI shell death, navigation and title flows",
  "state": "verified",
  "evidence": "Big Mac Godot 4.7.2 local candidate: 234 regression assertions, zero failures, import and startup smoke; isolated death/Back/title/confirm tests and 1280x720 title GUI captures",
  "artifact_revision": "Uncommitted local working tree based on c8c798571d1dba12b50459be778ac5b967947b05",
  "recheck_trigger": "Title, menu, save, death, input or HUD source changes"
}
-->
### VER-005 — Game OMNI shell death, navigation and title flows

- State: **verified in local Godot runtime**, not on Android device
- Evidence: death-screen softlock fixed, submenu Back paths validated, title and confirmation verified with 234 assertions / zero failures, import and startup smoke; screenshot evidence preserved in local cache
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "VER-006",
  "title": "Five-step field guide and compact landscape touch controls",
  "state": "verified",
  "evidence": "macOS Godot 4.7.2 local validator: 267 assertions/zero failures, three 720x405 gameplay captures; native tests cover real mining, scanning, crafting, ship, saved guide progress, separated hit targets and touch rail scrolling",
  "artifact_revision": "Uncommitted worktree based on c8c798571d1dba12b50459be778ac5b967947b05",
  "recheck_trigger": "Onboarding, HUD, saves, touch event paths, mobile viewport behavior"
}
-->
### VER-006 — Five-step field guide and compact landscape touch controls

- State: verified locally in Godot, not on physical Android.
- Evidence: 267 assertions / zero failures; three 720x405 captures and tested compact touch layout.
<!-- /operational-state:entry -->

## 6. Known Not Working

The pushed c8c7985 baseline had a reproduced death-dialog Close trap and Settings-from-Pause Back inconsistency; both were repaired and locally verified in source implementation commit eb571db. Remote and Android verification must still be checked. The baseline Ubuntu CI also reported seven ObjectDB instances and two resources retained at test exit, but three macOS verbose runs on the current candidate showed no such warnings. Linux root cause is unknown, not a confirmed gameplay resource leak. Native Android QA remains pending.

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

<!-- operational-state:entry
{
  "id": "UNV-002",
  "title": "Android export of both new local Game OMNI implementation batches",
  "state": "implemented-unverified",
  "evidence": "Baseline c8c7985 Android CI run 38304192370/artifact 11771254350 succeeded; new local source commit eb571db covering title/death/menu/guide/touch/diagnostic improvements has no verified Android build yet",
  "validation_method": "After separately authorized Git delivery, verify GitHub Actions APK for that exact new commit and test physical Android title/back/death paths"
}
-->
### UNV-002 — Android export of both new local Game OMNI implementation batches

- State: **implemented-unverified**
- Evidence: baseline c8c7985 CI passed; local P001-P004/P006 commit lacks a fresh Android CI APK and physical-device proof
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

<!-- operational-state:entry
{
  "id": "PND-002",
  "title": "Fresh Android CI and hardware evidence for new Game OMNI shell candidate",
  "state": "pending",
  "evidence": "GitHub c8c7985 APK verified; new local title/death/navigation and guide/touch changes were committed as eb571db; remote push and Android build unverified",
  "blocks_completion": true
}
-->
### PND-002 — Fresh Android CI and hardware evidence for new Game OMNI shell candidate

- State: **pending**
- Evidence: locally committed shell candidate requires verified normal push, new CI APK, and physical-device field-test evidence
<!-- /operational-state:entry -->

<!-- operational-state:entry
{
  "id": "PND-003",
  "title": "Linux Godot ObjectDB and resource retention at test exit",
  "state": "pending",
  "evidence": "Ubuntu CI run 38304192370 job 114994124976: 7 ObjectDB instances and 2 Resources at test exit; 3 new macOS verbose trials show no warnings",
  "blocks_completion": false,
  "validation_needed": "Fresh Linux CI with verbose trace, identify retained object types, isolate ownership, repair only when reproduced"
}
-->
### PND-003 — Linux Godot ObjectDB and resource retention at test exit

- State: pending, platform-specific.
- Evidence: Ubuntu warnings confirmed, no macOS reproduction; new CI verbosity unverified until authorized push.
<!-- /operational-state:entry -->

## 10. Active Decisions, Defaults, and Prohibitions

Maintain draft PR #2 on `uplift/glassfall-evidence-20261011`, not `main`. The most recent user-authorized continuation includes stage, commit and normal push to the existing PR #2 feature branch, with CI verification. It does not permit merge, force-push, release or deployment. No force-push, dependencies, destructive history changes, canon additions or premature production-release claims. Existing GitHub repository is already initialized; do not run `git init` again.

## 11. Validation and Evidence Matrix

| ID | Evidence state | Proof location | Recheck trigger |
|---|---|---|---|
| INV-001 | requested | docs/CANON_BOUNDARIES.md | Canon/lore/content change |
| INV-002 | requested | tests/run_all.gd | Save, world, economy, input changes |
| VER-001 | verified | Actions 38118392548, 38118394708 | Script/scene/build changes |
| VER-002 | verified | docs/PERFORMANCE.md and 178 test assertions | Renderer/scanner modifications |
| UNV-001 | implemented-unverified | docs/ANDROID_FIELD_TEST.md | Physical device capture |
| PND-001 | pending | docs/ANDROID_FIELD_TEST.md | Before merging PR #2 |
| VER-003 | verified locally | Big Mac Godot 4.7.2, 204 tests | Source/test changes |
| VER-004 | verified on macOS | Three planetary captures, inventory screenshot | Visual source changes |
| VER-005 | verified on macOS | Prior 234-check title/death tests, covered by current suite | Menu/save/death source changes |
| VER-006 | verified locally | 267 native assertions and three 720x405 captures | Onboarding/touch/save source changes |
| UNV-002 | implemented-unverified | Baseline c8c7985 CI success; new OMNI code unbuilt | Fresh CI + physical Android |
| PND-002 | pending | OMNI implementation committed locally as eb571db | Push verification, fresh CI + physical Android |
| PND-003 | pending | Linux CI resource lifetime warnings | Verbose Linux CI forensic review |

## 12. Current Change Scope and Impact Radius

Current local Game OMNI work P001-P004/P006 and P018 instrumentation: title/death/menu repair, optional real-action field guide, compact touch hitboxes and a swipeable large-slot hotbar, expanded native tests and verbose CI lifetime reporting. Changed source includes core game, GameHUD, touch action drawing, regression tests and Android workflow. Preserve offline save/load, older save compatibility, original assets, Starsilk canon limits, world geometry/collision, ship economy, and independent touch-pointer ownership. Do not equate macOS validation with Android hardware acceptance.

## 13. Compact Revision Log

- Revision 1, 2026-10-11: bootstrapped current working control plane from verified GitHub source and CI. Hardware limitations and pending device QA remain explicit.

- Revision 2, 2026-10-12: OMNI local working tree validated; solidity-preserving terrain changes now skip physics rebuilds, valid staged saves recover only after primary/backup fail, test runner teardown is clean. No remote CI, APK, device proof or Git publication for these edits.

- Revision 3, 2026-10-12: authored asset uplift proof (full-screen biome backdrop, four deterministic terrain variants, 27 semantic item icons, UI integration). Local Godot import, 204 assertions / 0 failures, startup and fresh inventory capture passed. New Android CI / hardware evidence still pending.

- Revision 4, 2026-10-12: implemented P001 terminal death non-dismissable route, P002 context-aware Back and P003 title/Continue/confirm/save-suspension guards. Local Godot 4.7.2 234 assertions/0 failures, GUI captures, import and startup PASS. Baseline c8c7985 CI successful, but new local changes have no commit/push/APK/hardware qualification yet.

- Revision 5, 2026-10-12: P004 real-action guide, P006 compact hitboxes/scrollable hotbar, P018 CI lifetime diagnostic expansion. Godot macOS 4.7.2 267 assertions/0 failures, startup/import, three 720x405 planet screenshots; three verbose local runs free of lifecycle warnings. No new Git commit, push, Linux CI artifact or native Android proof.

- Revision 6, 2026-10-13: implementation commit eb571db95fae0dd75001e0b708a1f89e14312396 created on PR #2 feature branch, with 267/267 local Godot assertions, project import/startup and YAML gate passed. Normal push and exact-head CI verification pending. No main merge, release, or physical Android sign-off claimed.
