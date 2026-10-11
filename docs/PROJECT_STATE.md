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
