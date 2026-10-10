# SILKBOUND — The Outer Reaches

**A Starsilk Blood Eclipse War sandbox** · Godot 4.7.2 stable · Android ARM64 / landscape

SILKBOUND is an offline, single-player salvage-survival game set in an explicitly **non-canon** peripheral system during Years 7–120 of the Blood Eclipse War. You captain a damaged civilian vessel, survey three seeded planets, mine ordinary geological materials, build shelters, fabricate field equipment, help stranded civilians, and decide how much salvage to spend keeping the ship mobile.

This is original Starsilk fiction and game code, not a Starbound reskin. Starsilk is never a mineable resource or a player power. The generated worlds, vessel, people, operations and outcomes are simulation inventions.

## Play the loop

1. Start beside the damaged vessel on the Ashlands landing shelf.
2. Cut the guaranteed salvage outcrop east of the ship; pickup drops physically land in the world.
3. Carry **6 scrap + 4 ferrite** to the ship console and patch its drive. This unlocks the real Glassfall route.
4. Survey Glassfall. Geological pressure warns, escalates, and changes a bounded section of terrain; its shallow shear remains after saving or leaving.
5. Fabricate a conventional coolant loop from recovered ferrite, glass and crystal to reach the Drowned Remnant.
6. Build shelter, use consumables, scan technical evidence, meet Iri and Vale, and return to earlier planets with their edits intact.

Recipes, resource spending, terrain placement, health/oxygen/heat exposure, enemy attacks, ship upgrades, planet gates, rescues and persistent saves are connected gameplay systems rather than menu-only labels.

## Controls

### Touch (landscape)

- Left virtual stick: move; hold farther out to steer more strongly.
- Right buttons: jump, mine/place, attack and interact.
- Upper-right: scan, build mode, inventory, fabrication, ship service and pause. The pause menu opens the field log, compendium and settings.
- Eight-item build hotbar is centered along the lower edge. Use the settings panel for larger touch targets and left-handed layout.
- Controls track separate touch-pointer identities, so lifting an action finger does not cancel the movement stick.

### Keyboard and mouse

- **A / D** or **← / →** move; **Space / W / ↑** jump; **Shift** sprint.
- **Left mouse** mines or places while build mode is active; **right mouse** attacks.
- **E** interact; **Q** scan; **B** build; **I** inventory; **C** fabricate; **H** ship console; **J** field log; **M** compendium; **Esc** pause.

## Run in Godot

1. Install **Godot 4.7.2 stable** with the Compatibility renderer.
2. Open this directory in the editor and run `scenes/main.tscn` (also configured as the project main scene).
3. Or run the project from a terminal:

```sh
godot --path .
```

The first launch creates a random world seed and a local save under `user://saves/`. The seed, terrain edits, dropped items, ship, inventory, settings, quests and localized terraforming state are saved locally. No account or network connection is used.

## Validate and export Android

- `docs/BUILD.md` documents the pinned editor, Java 17 and Android SDK setup.
- `tools/validate_project.sh` imports the project, runs the GDScript regression tests and performs a bounded startup smoke test.
- `export_presets.cfg` contains the **Android** debug preset (`com.westkitty.silkbound`, landscape project setting, ARM64 only, original launcher icon).
- `.github/workflows/android.yml` runs on pushes, pull requests and manual dispatch. It pins Godot/editor templates to **4.7.2**, configures Java 17 and Android API 36, imports, tests, smoke-runs, exports, inspects and checksums a debug APK, then uploads that APK as a GitHub Actions artifact.

The generated APK is intentionally not committed. Check the repository's **Actions → Android debug APK → Artifacts** for the verified build from a successful run.

## Project boundaries

See:

- [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) — implemented systems and known scope limits.
- [`docs/CANON_BOUNDARIES.md`](docs/CANON_BOUNDARIES.md) — canon facts versus simulation invention.
- [`docs/ASSET_PROVENANCE.md`](docs/ASSET_PROVENANCE.md) — original generated art/audio and regeneration command.
