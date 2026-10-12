# SilkBound performance evidence — 2026-10-11

This file records **source-level, headless Godot 4.7.2 CI evidence** for the draft SilkBound PR #2. It is not a claim about real-device FPS, GPU cost, thermal load or battery life.

## Exact environment and reproduction

- Repository: `westkitty/SilkBound`, branch `uplift/glassfall-evidence-20261011`
- Implementation revision: `4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab`
- Reference branch revision: `212120341e7c3c14d687b5acea1f63a181b97f58`
- CI evidence: [push run 38118392548](https://github.com/westkitty/SilkBound/actions/runs/38118392548) and [PR run 38118394708](https://github.com/westkitty/SilkBound/actions/runs/38118394708), both SUCCESS.
- Script under test: `tests/run_all.gd`, run by `.github/workflows/android.yml` via `"$GODOT_BIN" --headless --path . --script res://tests/run_all.gd`.
- Godot tests: **178 assertions, zero failures**, including terrain-cache save restoration, scan markers across a chunk boundary, duplicate scan/expiry no-ops, visual culling and preserved full collision.

## Matched microbenchmarks and count invariants

| Workload | Reference | Optimized | Evidence / meaning |
|---|---:|---:|---|
| Tile reads, 106,496 calls, six paired warmed/alternated trials | 47,681.5 µs median | 23,629.0 µs median | About 50.4% less benchmarked CPU time in one Actions runner, not a measured Android speedup |
| Scanner overlay redraw **requests**, local four-cell-radius scan in one chunk | 9 | 1 | Exactly 8 unnecessary queue requests avoided in this fixture |
| Identical repeated scanner highlight after scan | 9 in legacy path | 0 added | Unchanged world/scan geometry leaves overlay render state untouched |
| Terrain art chunks set visible near ship, 1280px-wide test view | 9 | 2 | Full landscape drawn conservatively with one extra chunk margin; physics chunks remain 9 |

The initial one-sample tile benchmark was inconclusive (different runner executions gave opposite rankings) because the comparison did not give both read paths equivalent method-call overhead and did not alternate trial order. The accepted benchmark uses a test-only `LegacyTileView` that reproduces the original lookup method, alternates six paired runs after warming both paths, and checks identical checksums for 106,496 accesses per trial. The reported medians describe **this runner only**.

The terrain cache is a second 288×88 `PackedInt32Array`, roughly 99 KiB per active world. It is rebuilt from seeded geology and saved edits; edits, mining, structures and terraforming update both the visible tile array and existing serialized modifications. Save format and world-generator seeds do not change.

## What has NOT been measured

- Actual Android FPS, p95/p99 frame times, 1% lows, GPU draw calls, input latency and shader/texture upload stalls
- Memory peaks and whether the 99 KiB world-cache tradeoff yields lower total CPU/GC work during long sessions
- Battery use, thermal throttling, orientation/window changes and mixed older/newer Android devices
- Comparison of repeated collision-chunk reconstruction under sustained mining and building

These remain `UNVERIFIED`, not failures.

## Performance frontier / next legitimate experiment

Use the **same Android device, seed, gameplay route and visual settings** on baseline vs uplift builds. Test cold start, 15-minute exploration, repeated scans, mining 50 contiguous tiles, Glassfall conversion and return travel. Capture p50/p95 frame time, FPS, memory and battery temperature where tools permit. Do not claim an improvement from a run unless comparable data exists for both revisions.

Next source-level hotspot to investigate if actual profiling corroborates it: `WorldGrid._refresh_chunk()` rebuilds an entire collision chunk after an individual solid-tile edit. Changing it requires a physics regression suite and must preserve immediate mining/build collisions.

Visual culling keeps the whole world's collision bodies intact and a one-chunk margin around the player's camera. This preserves distant solid terrain, but **requires physical visual proof** to rule out pop-in under camera smoothing or wide display conditions. See [Android field testing](ANDROID_FIELD_TEST.md).


## 2026-10-12 — Collision rebuild suppression (local, uncommitted)

Previously every `WorldGrid.set_tile()` change replaced its entire `StaticBody2D` collision chunk even when the edit preserved the tile's solid/non-solid state. The OMNI working copy now queues only visual redraws for those edits; a real solidity transition still performs immediate full-chunk collision reconstruction. Batched terraforming similarly tracks geometry dirtiness separately from visual dirtiness. Godot native tests assert the existing collision-body identity remains stable for solid-to-solid and air-to-water edits, while air-to-solid and solid-to-air edits replace it as required.

This is evidence of avoided unnecessary rebuild work and preserved immediate collision correctness, not measured FPS or a benchmarked speedup. Local Godot 4.7.2 validation passed 204 assertions / 0 failures. The changes have not been pushed to GitHub Actions or exercised on physical Android hardware.
