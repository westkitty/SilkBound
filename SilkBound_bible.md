# SilkBound Project Bible

Project: SILKBOUND — The Outer Reaches
Repository: https://github.com/westkitty/SilkBound
Scope: Godot 4.7.2 offline single-player Android ARM64 non-canon Starsilk salvage/survival sandbox
Policy: append new dated entries; do not erase history.

## 2026-10-11 — Bounded Glassfall, persistence and lifecycle uplift

### Verified baseline
- `main`: `a8c896cc6e9181b84f63fee939eed26c8687eb65`, merged PR #1. GitHub Actions baseline run `38111966437`: success.
- Main player flow: Ashlands guaranteed salvage, repair ship with 6 scrap + 4 ferrite, access Glassfall; bounded fault conversion; coolant unlocks Drowned Remnant; build, scan, quests, travel and local saves.
- Existing 288 × 88 seeded maps and generated assets remain authoritative; no native Godot installation in the execution container. Physical touch/gameplay unverified.
- Canon boundary: all generated people, worlds and outcomes are non-canon. Starsilk is neither mined nor wielded; the playable captain is NOT canonical Kail; the war's Siege Wall has not formed in this early era. Glassfall is a survey invention, not the named historical incident.

### Frozen improvement scope
1. Environmental cause/effect: survey Glassfall before and after a real permanent terrain shear; add static localized warning visuals and compendium evidence without new canon.
2. Gameplay reliability: preserve survival damage across long frames; reuse/revalidate bounded shelter and thermal probes; avoid stale crack overlays and unnecessary per-frame overlay redraw.
3. Mobile lifecycle/input: clear held input on pause/suspend, including touch control ownership; save newly earned records without waiting for a 40-second autosave.

### Implementation and tests
- Branch `uplift/glassfall-evidence-20261011` created from baseline; only attributable source, tests and documentation changed.
- Implementation commits: `ae7ab6ab9a66535b6de9f887972a7ca28f8bfc7d`, `9ccfad485aed3c22f819d0bf9602396e9b186cd2`, `d531bcb9bd77faec6f3c480a06c9e7a2b541900f`, `dfd5d67a4ef329bff3cc2e38e78f4a66632ae0b3`.
- GitHub Actions source/test success: `38113892002`, `38113954039`, `38114008218`, `38114013779`; latest artifact `11692612269` contains a debug APK and checksum.
- QA coverage: Godot deterministic assertions for elapsed hazard-damage intervals, cached environment probes and invalidation, static fault warning state, before/after records, saved terrain and record round trip, touch-button and stick reset on pause. Remote import, headless startup, APK export and package inspection passed.
- Locally: no Godot runtime; earlier scratch-source shell/static and asset-generation checks passed, but not a substitute for current-branch engine execution.
- No new dependencies; no deliberately removed game capabilities.

### Open proof obligations / deferred work
1. Install the current APK on an actual Android touchscreen device, verify simultaneous move + mine + jump, pause/resume, background/foreground and menu touch control recovery; record screenshots or video before UI sign-off.
2. Play Ashlands -> Glassfall fault event -> Drowned Remnant -> return and save/reload on device; inspect positioning, visual clarity and avoiding terrain entrapment during conversion.
3. Measure FPS/frame time, CPU/GPU use, thermal behavior and battery use in matched before/after runs. Do not claim a quantified performance uplift without those measurements.
4. Branch may be reviewed and merged separately after accepted verification. Current main stays at baseline unless a later merge is explicitly executed.

### Protected invariants
- No canon Kail cameo; no player Starsilk abilities; death is final.
- Generated original artwork and audio, seed reproducibility, original ship repair costs and resource gates, offline operation, local-save compatibility.
- No forced upgrades, force-push, branch replacement or deletion of prior history.

### Git delivery
- Implementation pushed to reviewed feature branch through GitHub connector; no force update.
- Documentation/Bible follow-up commit recorded separately by repository history.


## 2026-10-11 — Uplift Round 2: pointer release, saved-position safety and survey bearings

### Purpose / starting state
- Continued existing draft PR #2, target `westkitty/SilkBound`, same branch `uplift/glassfall-evidence-20261011`.
- Baseline feature HEAD: `3718fd122cb6f6edb6d6c037fb25f75303e7beb7`; `main` remained `a8c896cc6e9181b84f63fee939eed26c8687eb65`.
- Three frozen change groups; no new dependency or canon additions; original artwork, game economy, offline saving and planet sequence preserved.

### Changes and evidence
1. **Held input release outside controls:** `TouchActionButton.release_pointer()`, `VirtualStick.release_pointer()` and `GameHUD._input()` release exactly the lifted finger. A control-layout rebuild now unwinds held input. Test verifies concurrent mine/jump/stick independence and release outside the original control bounds.
2. **Persistent terrain reentry:** `WorldGrid.captain_space_clear()` and `safe_reentry_position()` detect solid intersections using the original 18x38 capsule footprint. Invalid saved coordinates relocate to nearby unblocked generated surface where possible, without terrain mutation. Mounting a different world uses `SilkboundPlayer.bind_world()` and clears old velocity, knockback/fall bookkeeping and touch/jump states.
3. **Readable Glassfall goal:** the status objective shows fault bearing in cells (east/west/here) and explicitly signals first/second scans. Tests exercise the legitimate drive-repaired prerequisite and the before/after change in guidance.

### Implementation history
- `3cafaa16a1b2c012bf77c0009e3a7a8ed9878b52`: pointer ownership changes and tests; initial CI failed because test-scene `var` type inference was invalid.
- `d9f1a9e0dce1b4e0d0d781abf362e44a88d56878`: explicit `PackedScene` and `Node` declarations; CI success.
- `bd8ae74debd4a878d09c82b5bad697fbbe04f7bc`: save reentry and integration tests; CI success.
- `eaec4d5209be4b2934281ba68b99eea539a694ec`: survey bearing and stage guidance; initial tests failed because the test bypassed the travel repair prerequisite.
- `e49b9a19896ae02c496ab3645e73ce0fada63229`: set repaired-drive precondition in tests; CI success.
- `4c6ad74a8373c226ec9a13b0dcf268417224660f`: clear player momentum and stale actions on world transition; push and PR CI success, **158 assertions / 0 failures**, Android ARM64 export and artifact upload.

### Protected state / unverified
- No player Starsilk control, canon Kail cameo, new Drakken mechanism or change to finality of death.
- Save compatibility and original authored media preserved. No force-push, branch deletion or merge.
- Native Godot CI verifies code/test and APK packaging; does not verify observed touch dispatch, UI layout, complete physical gameplay or FPS/thermal numbers.
- Follow `docs/ANDROID_FIELD_TEST.md` for real-device sign-off; draft PR #2 remains open.

### Git delivery
- GitHub connector pushed each scoped implementation commit to the existing draft PR branch.
- Documentation follow-up is additive; look at repository history for this documentation commit. No default-branch mutation was performed.


## 2026-10-11 — Source-level performance and QQQ closure audit

**Verified source baseline:** draft PR #2 HEAD `212120341e7c3c14d687b5acea1f63a181b97f58`. Existing main `a8c896cc6e9181b84f63fee939eed26c8687eb65` remained untouched. Baseline automated suite: 158 assertions, 0 failures; device FPS unknown.

**Bounded improvement scope:** (1) reduce redundant drawing of scanner overlays and distant terrain while preserving collision and world visibility on travel; (2) make high-frequency tile lookup efficient without changing edit serialization; (3) provide a physically grounded nearest-return bearing useful for salvage, plus new test and documentation proof.

**Implementation commits:** `2cf85397191e670159c6057f506d573ad4de85ab` (tile cache, redraw focus, bearing), `ec0512690c220f43f8374d8a66371ab19b8d8d93` (cross-chunk overlay regression), `ecf8825579c0ddeaa357f70e021d59a8dabef32e` (visual chunk culling), `4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab` (fair six-pair headless timing fixture).

**Validated:** push Actions `38118392548` and PR Actions `38118394708` SUCCESS for the same implementation HEAD: **178 assertions, 0 failures**, import, startup smoke, Android ARM64 APK export, package validation, checksum upload. Artifact `11694422822` (debug APK ZIP, not a release). No physical device run.

**Measured only in headless CI:** 106,496 tile accesses × six paired warm/alternated trials: legacy median 47,681.5 µs; cached median 23,629.0 µs (roughly 50% lower). Earlier one-pass measurement varied and was rejected as a speed claim. Scanner overlay redraw requests decrease 9 -> 1 for a one-chunk scan, repeated identical scans request 0. At a 1280px test viewport, 2 of 9 terrain-art chunks remain visible near the ship; all 9 physics chunks remain intact. These are not GPU draw-call counts or device FPS results. The extra resolved tile buffer adds roughly 99 KiB per active 288×88 planet.

**QQQ repair / regression:** `WorldGrid.setup` failed to clear previous mining-crack and scanner transient state on reuse; this was corrected and guarded. Scanner focus changes have cross-chunk move/expiry tests, exact resource count and bearing assertions, editor import, smoke and APK build. No dependency, config, save-schema or canonical Starsilk additions.

**Deferred:** physical-screen continuity after culling, Android low-end FPS/p95 frame times, memory, battery and thermal profiling, long-session resource lifecycle, bounded collision-chunk rebuild cost during repeated mining, save/load on-device, all procedures in `docs/ANDROID_FIELD_TEST.md`. Do not merge draft PR #2 until material hardware findings are accepted or repaired. Documentation closeout commit recorded separately by Git history.
