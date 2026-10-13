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


## 2026-10-12 — OMNI local stability and performance pass (NOT PUSHED)

- **Baseline:** draft PR #2 branch at d4028018cc9197b222daeb6242d7463f289df5c5, main at a8c896cc6e9181b84f63fee939eed26c8687eb65. Existing GitHub Android CI was green.
- **Scope:** keep original non-canon Starsilk premise, original assets, planet seeds, item economy, rescue narrative, live touch pointers, full physics collisions and save schema intact. No external dependencies or content reboots.
- **Terrain:** distinguish visual-only tile changes from true solidity transitions. Same-solidity edits update terrain and redraw visuals while preserving the existing collision body; solid/air transitions still rebuild physics synchronously. Batched terraforming dirties collision only when required. Extra deterministic tests prove both paths.
- **Save integrity:** a valid staged `.json.tmp` can restore progress only if both primary and backup are unreadable, preserving primary > backup > staged recovery precedence. No save format changes. Test simulates interruption after complete temporary write before atomic rename, then proves normal commits resume.
- **Validation:** pinned Godot 4.7.2 installed in Big Mac temporary cache for local verification; full `tools/validate_project.sh` import, 204 assertions / 0 failures, startup smoke, and `tests/test_validate_project.sh` passed. Test runner now drains twelve deferred teardown frames before quit; removes previously observed local ObjectDB/resources-at-exit diagnostics without hiding fatal errors.
- **Boundaries:** no Android device, emulator, APK export or new CI run for the local changes; no FPS uplift claim, no source commit/push, no PR merge. Physical field test checklist remains mandatory before calling the app release-ready.
- **Working directory:** `/Users/bigmac/SilkBound-OMNI` on user-owned Big Mac. Review only attributable files before any later Git delivery; Godot generated .uid/.import sidecars remain untracked and are not part of the intended patch.

## 2026-10-12 — OMNI / VISUAL staged-delivery candidate

- **Purpose:** preserve the existing Starsilk non-canon playable sandbox; repair visual asset identity and integration rather than replacing the game or its character designs.
- **Runtime discovery:** the three already-authored atmosphere PNGs displayed as undersized floating patches due to `CanvasLayer.follow_viewport_scale=0.14`. Corrected to full screen in the existing renderer; verified by 1280x720 Godot GUI captures.
- **Terrain art:** 4 deterministic, per-ID 16px variations with stronger geological shapes and contrasting copper, glass and silicate. Atlas first-group ID offsets and saved terrain schema are retained. World drawing picks reproducible variation; physics changes from earlier OMNI work remain respected.
- **Icons:** 27 semantically distinct 16px pictograms, 3 unique formerly reused upgrade indices, connected to real item pickup, inventory, crafting and touch hotbar render paths. Godot screenshot of inventory and HUD confirms scaled icon readability.
- **Preserved:** procedural seed state, resource economy, ship repair/travel, original player/NPC/enemy animation sheets, source assets, audio, touch-pointer ownership, save schema and collision fidelity. No new external asset or library; standard-library generator remains reproducible.
- **Validation:** Godot 4.7.2 macOS import, `tools/validate_project.sh` PASS with 204 assertions / 0 failures and startup smoke; native GUI captured inventory plus all three planets at 1280x720. `git diff --check` passed. No physical Android evidence, measured FPS uplift, new APK/export CI proof or PR merge is claimed by this source record.
- **Git scope:** update only 15 attributable source/data/documentation files; Godot-generated `.import` and `.uid` sidecars are intentionally left untracked. Commit/push evidence belongs to Git history/Actions and must be checked separately.

## 2026-10-12 — First approved Game OMNI implementation batch (P001, P002, P003)

### Repository and authority
- Project: `westkitty/SilkBound`; existing local checkout: `/Users/bigmac/SilkBound-OMNI`.
- Branch/starting HEAD: `uplift/glassfall-evidence-20261011`, `c8c798571d1dba12b50459be778ac5b967947b05`.
- The user requested implementation after receiving Game OMNI Evaluation. Implementation scope was bounded to three evidenced first-priority groups. This does **not** confer commit, push, merge, dependency-update or Android publishing authority; no such action was performed for this batch.
- Pre-existing untracked `.import` and `.uid` generated sidecars were preserved unmodified and remain untracked. No pre-existing tracked changes were found.

### Verified defects, changes, and preservation
- **D001 / P001 — terminal death softlock (P1):** Running the previous project, Death -> Close hid the only restart option, while the ended session stayed frozen. The terminal dialogue now suppresses Close/X/Back rather than hiding the restart route; a new captain is an explicit distinct life, not a canon resurrection. Godot regression probes cover death, Close, gameplay input rejection and actual new-expedition transition.
- **D002 / P002 — Back navigation (P2):** Pause -> Settings -> Close previously unpaused. Modal-kind history now returns to Pause and handles ship/navigation, ship/storage, and title/settings routes. Escape/back respects this chain and does not unlock terminal states. No replacement menu framework or dependency was introduced.
- **P003 — title / Continue:** Existing procedural world, ship art and panel language now compose a title with first-run Begin, valid-save Continue, saved-game replacement confirmation, and a memorial entry for an ended expedition. Selection never overwrites before confirmation. An Android pause/close at title skips game save. Pause can save and return to title without losing world modifications.
- **Protected:** offline single-player, save JSON schema, death finality, no player Starsilk handling, world seeds, mining, construction, ship progression, scanner, original authored assets, accessibility settings, old test-mode launch contract, and PR #2 draft boundary.

### Validation evidence
- Baseline: Godot 4.7.2 `tools/validate_project.sh` passed 204 assertions / 0 failures.
- New candidate: Godot 4.7.2 `tools/validate_project.sh` passed 234 assertions / 0 failures, full resource import and bounded startup smoke.
- Native isolated tests cover title begin/continue, non-destructive confirmation cancel, confirmed new life, menu Back stack, dead-run memorial and restart, and tested unchanged gameplay contracts.
- Godot GUI screenshot evidence: `/Users/bigmac/.cache/silkbound-omni/omni-title.png` and `omni-title-settings.png` (1280x720), held only in temporary local working cache, not submitted as production APK screenshots.
- Validation limits: no new GitHub CI run, APK export, Android ADB/mobile test, controller feel measurement, thermal or battery measurement. Existing CI success at `c8c7985` does not transfer automatically to these edits.

### Remaining work
1. Physical Android title, touch and Back-route QA; detect viewport clipping and system gesture collisions.
2. P004 first-run onboarding, P006 touch/layout refinements, P017 measured Android frame pacing.
3. P018 isolate Godot's known two resource references at test exit.
4. Continue other Game OMNI proposals in bounded, separately validated work batches.
5. Stage/commit/push only on a future explicit Git-delivery instruction.

### Git delivery
- New implementation commit: **not authorized / not created**.
- Push/merge: **not authorized / not performed**.

## 2026-10-12 — Game OMNI second bounded batch: P004, P006, P018

### Starting point and authority
- Preserved prior local uncommitted P001/P002/P003 work on `uplift/glassfall-evidence-20261011`; source base commit `c8c798571d1dba12b50459be778ac5b967947b05`.
- Implementation permission via user continuation "go on"; no authority inferred for commit, push, merge, dependency installation or production APK publication.
- Existing Godot-generated untracked .uid/.import sidecars left in place and excluded from all delivery claims.

### P004 — first expedition guidance
- Five real milestones: movement, terrain destruction, scan, craft Shelter walls ×2, physical ship console. Actual game events, not clicking "Next", advance the HUD. Guide can be viewed from title/Pause, resumed, or skipped.
- New optional `onboarding_step` save field defaults to complete for old saves. A new captain restarts guidance. No quest/canon, economy, or save-version migration. Deferred event checkpoints preserve newly spawned mined resources.
- Native tests probe all triggers, ingredient subtraction, ship proximity, state persistence, legacy behavior, skip and return routing.

### P006 — compact Android control usability
- Actual window width compensates logical hitbox size when the engine downscales a 1280 reference canvas onto narrow landscape output; caps size and preserves per-finger ownership.
- All ten controls spaced to avoid collisions, with improved caption size, left-handed parity and a less-clipped guided objective.
- The existing eight-slot hotbar is now a horizontally swipeable ScrollContainer, with large physical touch targets, selected-slot automatic reveal, and no quarter-second snap-back while manually scrolling.
- Three planet GUI renders at 720 × 405 reviewed. Native regression checks verify physical touch sizes, disjoint zones, hotbar/stick separation, scrolling and both handed layouts. **No physical Android testing or FPS measurement.**

### P018 — forensic differential and next probe
- Confirmed baseline Ubuntu CI run `38304192370` leak diagnostics: 7 ObjectDB instances, 2 resources retained at test exit, despite 204 passing assertions.
- Three macOS Godot 4.7.2 verbose runs of the new 264-assertion suite: 0 test failures, 0 corresponding lifetime warnings.
- Root cause remains unknown and unverified on Linux. Android CI test invocation now records verbose detail and a distinct non-suppressing warning annotation for future source revisions. Details in `docs/QQQ_RESOURCE_LIFETIME.md`.

### Validation and boundaries
- Final macOS Godot 4.7.2 `tools/validate_project.sh`: import, **267 assertions/zero failures**, startup smoke PASS. Test-validator self-check and whitespace checks run separately.
- Preserved original ship and player art, Starsilk canon limits, procedural seeds, saved terrain/quests, offline operation and P001/P002/P003 menu protections.
- No local Android SDK export, new GitHub CI, hardware performance trace, resource-leak repair claim, commit/push/merge/release for this batch.
- Final three additional native checks verify title guide / Back safety and backward compatibility with legacy saves missing the optional guide key: **267 assertions, zero failures**. Prior three macOS verbose lifetime runs were at 264 and remain distinct historical evidence.


## 2026-10-13 — Game OMNI implementation commit and Git delivery checkpoint

- Implementation commit: `eb571db95fae0dd75001e0b708a1f89e14312396` (parent `c8c798571d1dba12b50459be778ac5b967947b05`), on the existing `uplift/glassfall-evidence-20261011` feature branch. Exactly 12 attributable code, test, workflow, and documentation files were committed.
- Validated before the implementation commit: macOS Godot 4.7.2 import, 267 regression assertions / zero failures, startup smoke; workflow YAML parse and validator self-test. Title and three planets have native macOS graphical captures. Physical Android playability is not verified.
- This separate documentation follow-up records the implementation SHA without requiring this documentation commit to contain its own hash. Older entries describing earlier uncommitted work remain historically accurate at the time of authorship.
- Push to the existing draft PR #2 branch and fresh Android CI were authorized by the user's continuation, but delivery is not a verified fact until the remote SHA and matching CI are checked. Do not merge main, force-push, deploy or release.
- Hardware field testing, real-device frame pacing and Linux Godot ObjectDB/resource-at-exit diagnosis remain open.
