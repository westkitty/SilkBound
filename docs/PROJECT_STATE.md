# Project state (implementation snapshot)

## Implemented in source

- Godot 4.7.2 project with the main scene and Compatibility renderer configured for landscape play.
- Seeded Ashlands, Glassfall and Drowned Remnant maps (288 × 88 cells each), with biome-specific strata, caves, veins, landing shelf and generated salvage shelters. Base geometry is deterministic; terrain edits are saved separately. Rendering and merged horizontal collision runs are split into 32-cell chunks.
- `CharacterBody2D` rover controller with keyboard and virtual-stick movement, sprint, jump cutting, air movement, swimming modifier, fall damage and the original multi-state pixel animation sheet.
- Material hardness, crack progress, mining drops, area pickups, finite slot inventory, atomic recipes, hotbar build selection, supported terrain placement, storage transfer, shelters, lamps and workbench interaction.
- Functional ship service console, repair costs, locked-but-real destination routes, return travel, conventional cutter/cargo/scanner/thermal upgrades and persistent per-world state.
- Health, energy, oxygen and heat exposure; food and medfoam; two survivor NPCs; ship-repair, ration-funded rescue, transformed-fault survey and archive-delivery quest state.
- A four-state Glassfall pressure sequence culminating in a bounded, persistent terrain/fault mutation; scanner returns for geology, salvage, water, archive hardware and fault cells. First scans now add a world-specific field record, explain the discovery in the HUD and unlock its compendium evidence.
- Wildlife/security threats with telegraphed attacks, melee damage/knockback and salvage. Localized terrain and exposure hazards are kept separate from invented enemy superpowers.
- Versioned local JSON save with backup recovery, world edits, loose pickups, ship, inventory, settings, discovered notes and quest/terraforming state. A fresh expedition is available only after the captain's death has ended the previous run.
- Original source-generated pixel art, launcher icon and synthesized audio; touch-size, handedness, volume, shake and flash settings. The three planetary parallax scenes share an eclipsed sky anchor but have distinct non-canon industrial, volcanic-glass and drowned-survey silhouettes.
- Deterministic test runner, Android debug export preset, validation/build helpers and an Android Actions workflow. A persistent fake-runner regression test proves the validator filters only the exact expected malformed-save diagnostic while unrelated critical errors still fail.

## Scope and evidence limits

This is a focused single-player vertical slice, not a complete implementation of every requested expansion. Worlds are bounded maps generated on arrival, not an unbounded streaming universe; each destination has one fixed saved world state. The mobile UI is implemented but has not been confirmed on physical phones/tablets. The controller has no dedicated gamepad mapping, slopes, or drag-and-drop inventory. Threat behavior uses a small number of reusable archetypes rather than a large faction simulation. There is one primary local save slot (plus settings and backup), not a multi-slot save selector. The world map is modest and no FPS claim is made.

The current development container has no installed Godot executable, Java runtime or Android SDK. A local Godot 4.7.2 source build was attempted in a temporary cache but stopped before producing an executable; the official prebuilt editor/template archives redirect to a host blocked by this sandbox's outbound network policy. Therefore no Godot-native import, gameplay test, smoke launch or APK export has been run locally. `gdtoolkit` was used for GDScript formatting and syntax/style checks, not as a substitute for Godot.

Historical October 10 CI verification succeeded in GitHub Actions for code commit `b6b8d6fc56205efd6927c5b66d826271b4bb93e3` (push run [38097079196](https://github.com/westkitty/SilkBound/actions/runs/38097079196); PR run [38097081193](https://github.com/westkitty/SilkBound/actions/runs/38097081193)). The workflow passed the validator diagnostic-filter regression, imported project resources, ran the deterministic gameplay tests, completed the bounded headless startup smoke test, exported an Android debug APK, verified the package and ARM64 native payload, and uploaded artifact `SilkBound-Android-debug-b6b8d6fc56205efd6927c5b66d826271b4bb93e3` (ID `11687105324`, 28,503,809 bytes). GitHub lists the artifact through 2026-11-10; it contains the APK and its SHA-256 file. Physical Android device testing remains unverified. The GDScript gameplay tests and Android export were executed remotely; this container still lacks Godot, Java and Android SDK, so those runtime checks have not been run locally.


## October 11, 2026 — bounded Glassfall / lifecycle uplift

Working branch: `uplift/glassfall-evidence-20261011`, based on merged main `a8c896cc6e9181b84f63fee939eed26c8687eb65`. The source/test implementation through `dfd5d67a4ef329bff3cc2e38e78f4a66632ae0b3` passed GitHub Actions [38114013779](https://github.com/westkitty/SilkBound/actions/runs/38114013779): Godot import, deterministic gameplay tests, startup smoke test, Android ARM64 debug export and package validation. APK artifact ID `11692612269` was uploaded. These results do **not** establish physical-device usability or a measured FPS gain.

Changes:
- Glassfall: physical warning lines trace the bounded fault surface at pressure phases 1 and 2. Scans near the intact and later converted shear produce independent `glassfall_before` and `glassfall_after` simulation records. The new records and real terrain edits survive a dedicated disk save/reload test; new discoveries are saved immediately in normal play.
- Survival: environmental damage now accounts for all elapsed whole-second intervals after long frames rather than losing hazard ticks.
- World sampling: shelter/thermal queries reuse one result per terrain-cell/revision, invalidating after placements and fault changes. Replaced tiles drop stale mining-crack state.
- Input/lifecycle: pausing and application suspension clear the game router, physical held mouse flags, touch buttons and virtual-stick ownership. Non-build gameplay no longer queues needless overlay redraws each frame.
- Regression coverage: explicitly exercises time-step equivalence, environment sample reuse/invalidation, survey records and mutation persistence, physical-world input cancellation.

Limitations: no target Android phone/tablet was driven through the full play loop; no real-frame timing, thermal, battery or long-session profiling was performed; chunk redraw costs remain dependent on actual hardware. Scope intentionally excludes new biomes, new Drakken powers, world-streaming architecture, new dependencies and changes to gameplay identity.


## October 11, 2026 — Round 2: Android input, reentry and readable survey objectives

Feature branch `uplift/glassfall-evidence-20261011`; reviewed implementation commit `4c6ad74a8373c226ec9a13b0dcf268417224660f` builds and passes Godot native checks on GitHub Actions: [push run 38115856673](https://github.com/westkitty/SilkBound/actions/runs/38115856673) and [PR run 38115860476](https://github.com/westkitty/SilkBound/actions/runs/38115860476). The deterministic test suite reports **158 assertions, 0 failures**, and the push run produced an approximately 28.8 MB Android ARM64 debug APK (artifact `11692704418`). Physical device verification is still outstanding.

Accepted cohesive change groups:
1. Touch input ownership: a global release event outside the original on-screen control releases only the corresponding finger, leaving separate movement/action pointers unaffected. Rebuilding a touch layout also emits releases rather than abandoning held input.
2. Saved-world safety: on mount, a stored position inside collidable terrain is redirected to a nearby unblocked surface point when available, without editing the world or rewriting progression. Existing player bodies now reset velocity, fall speed, jump requests and touch movement on interplanetary transitions.
3. Field guidance: the Glassfall HUD shows distance and east/west bearing to the fault, emphasizes scanning intact strata before pressure conversion, and then directs the player to scan the modified fault. The existing records, physical terrain conversion and rewards remain unchanged.

Observed intermediate validation failures were **test-code defects**, corrected before final validation: an untyped scene-instance declaration and a test that entered Glassfall without marking the drive repaired. Both fixes passed subsequent native tests. No new dependencies, shaders, maps, images, sound or canon events were added. No measured runtime performance increase is claimed.

Unverified: Android GUI event dispatch for off-control releases, simultaneous multitouch on real hardware, small-display layout and viewport clipping, long-session thermal behavior, full exploration progression and physically observed save/reload restoration. Follow `docs/ANDROID_FIELD_TEST.md`. This uplift remains in draft PR #2; `main` is not changed.


## October 11, 2026 — Performance / QQQ bounded repair pass

Working branch: `uplift/glassfall-evidence-20261011`; implementation head `4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab` passed both [push CI 38118392548](https://github.com/westkitty/SilkBound/actions/runs/38118392548) and [PR CI 38118394708](https://github.com/westkitty/SilkBound/actions/runs/38118394708). Godot import, tests (**178 assertions, 0 failures**), headless startup and Android ARM64 APK export passed. Built APK archive: artifact `11694422822`.

Changes: resolved packed-array tile reads synchronized with edit/reload paths; scanner overlay invalidates only changed chunks and skips unchanged repeats; old highlights clear on expiry; squared-distance scanning also returns real nearest material coordinates for a priority compass-style signal; camera-aware visual-only chunk culling keeps an offscreen safety margin and leaves collision active. `WorldGrid.setup()` now clears stale transient cracks and scan overlays on reuse.

Verified targeted measurements: matched six-trial Godot headless tile-read median **47,681.5 µs reference -> 23,629.0 µs cached** for 106,496 queries; scanner request count **9 -> 1** on the tested local scan, and near-ship visible terrain chunks **9 -> 2** at a 1280px test viewport. These are implementation-specific, runner-specific metrics, not measured Android frame rates. Earlier one-shot tile timing fluctuated and is superseded by the paired method-call benchmark. Source and method in `docs/PERFORMANCE.md`.

No new dependencies or visual assets; previously locked non-canon character/cosmology, progression gates, terrain save schema, and touch controls preserved in tested paths. Hardware visual/performance behavior remains unverified. PR #2 is intentionally still a draft; `main` unchanged.


## 2026-10-12 — Local OMNI verification (uncommitted)

The draft PR #2 source was cloned at d4028018 and inspected on Big Mac using a local Godot 4.7.2 editor. Two user-visible reliability improvements are implemented in the working copy: same-solidity mining/building/terraforming redraws no longer unnecessarily reconstruct physics chunks, and a complete staged save is recoverable when both the primary and backup are unreadable. The test runner now gives deferred Godot teardown twelve frames to finish, eliminating its observed local exit-resource diagnostics without relaxing the validator.

Local `tools/validate_project.sh` passed import, **204 assertions / 0 failures**, and startup smoke. `tests/test_validate_project.sh` also passed. This does **not** establish an Android binary for these edits, a measured device frame-rate improvement, device touch behavior or complete manual playthrough. The local modifications are not committed or pushed. Continue treating PR #2 as a draft until hardware proof is recorded.

## 2026-10-12 — OMNI visual asset candidate and delivery checks

Local Big Mac GUI inspection exposed a concrete backdrop scaling defect: the authored planet environment appeared as a small centered patch. Corrected full-viewport rendering in the existing CanvasLayer, confirmed with 1280x720 captures of all three planets. Regenerated exactly two tracked art files: terrain atlas (four deterministic 16px visual variants per tile ID, stronger material identity) and item atlas (27 distinctive equipment/material pictograms). Item catalog indices for three upgrades and live inventory, fabrication and hotbar UI were updated; all other generated artwork and audio remained unchanged.

Validation with Godot 4.7.2 on Big Mac: `tools/validate_project.sh` passed 204 assertions / 0 failures, import and startup smoke; graphical capture of the inventory panel confirmed expanded icons. CI-built Android APK for this source revision and physical touchscreen/thermal/performance QA must be verified separately. Work remains on draft PR #2's feature branch; no merge of main is authorized.
