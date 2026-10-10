# Project state (implementation snapshot)

## Implemented in source

- Godot 4.7.2 project with the main scene and Compatibility renderer configured for landscape play.
- Seeded Ashlands, Glassfall and Drowned Remnant maps (288 × 88 cells each), with biome-specific strata, caves, veins, landing shelf and generated salvage shelters. Base geometry is deterministic; terrain edits are saved separately. Rendering and merged horizontal collision runs are split into 32-cell chunks.
- `CharacterBody2D` rover controller with keyboard and virtual-stick movement, sprint, jump cutting, air movement, swimming modifier, fall damage and the original multi-state pixel animation sheet.
- Material hardness, crack progress, mining drops, area pickups, finite slot inventory, atomic recipes, hotbar build selection, supported terrain placement, storage transfer, shelters, lamps and workbench interaction.
- Functional ship service console, repair costs, locked-but-real destination routes, return travel, conventional cutter/cargo/scanner/thermal upgrades and persistent per-world state.
- Health, energy, oxygen and heat exposure; food and medfoam; two survivor NPCs; ship-repair, ration-funded rescue, transformed-fault survey and archive-delivery quest state.
- A four-state Glassfall pressure sequence culminating in a bounded, persistent terrain/fault mutation; scanner returns for geology, salvage, water, archive hardware and fault cells.
- Wildlife/security threats with telegraphed attacks, melee damage/knockback and salvage. Localized terrain and exposure hazards are kept separate from invented enemy superpowers.
- Versioned local JSON save with backup recovery, world edits, loose pickups, ship, inventory, settings, discovered notes and quest/terraforming state. A fresh expedition is available only after the captain's death has ended the previous run.
- Original source-generated pixel art, launcher icon and synthesized audio; touch-size, handedness, volume, shake and flash settings.
- Deterministic test runner, Android debug export preset, validation/build helpers and an Android Actions workflow.

## Scope and evidence limits

This is a focused single-player vertical slice, not a complete implementation of every requested expansion. Worlds are bounded maps generated on arrival, not an unbounded streaming universe; each destination has one fixed saved world state. The mobile UI is implemented but has not been confirmed on physical phones/tablets. The controller has no dedicated gamepad mapping, slopes, or drag-and-drop inventory. Threat behavior uses a small number of reusable archetypes rather than a large faction simulation. There is one primary local save slot (plus settings and backup), not a multi-slot save selector. The world map is modest and no FPS claim is made.

The current development container has no installed Godot executable, Java runtime or Android SDK. A local Godot 4.7.2 source build was attempted in a temporary cache but stopped before producing an executable; no Godot-native import, test execution, smoke launch or APK export has **passed** locally. The official editor/template release assets redirect to a host blocked by this sandbox's outbound network policy. `gdtoolkit` was used only as a GDScript syntax/style parser; that is not a substitute for Godot. The checked-in GitHub Actions workflow is intended to provide the pinned engine, run the actual tests and export the APK after source is pushed; its run and artifact must be inspected before claiming Android build success. Physical-device testing remains separate and unverified.
