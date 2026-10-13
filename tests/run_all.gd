extends SceneTree

const Generator = preload("res://scripts/world/planet_generator.gd")
const Tiles = preload("res://scripts/world/tile_catalog.gd")
const Items = preload("res://scripts/inventory/item_catalog.gd")
const Survival = preload("res://scripts/survival/survival_system.gd")
const TerrainChunk = preload("res://scripts/world/terrain_chunk.gd")
const TestInventory = preload("res://scripts/inventory/inventory.gd")
const Crafting = preload("res://scripts/inventory/crafting.gd")
const Travel = preload("res://scripts/travel/travel_system.gd")
const Save = preload("res://scripts/persistence/save_system.gd")
const Quests = preload("res://scripts/quests/quest_system.gd")
const Combat = preload("res://scripts/combat/combat_system.gd")
const Router = preload("res://scripts/ui/touch_action_router.gd")

class LegacyTileView:
	extends RefCounted

	var world_width := 0
	var world_height := 0
	var base_cells := PackedInt32Array()
	var modifications: Dictionary = {}

	func setup(world: WorldGrid) -> void:
		world_width = world.world_width
		world_height = world.world_height
		base_cells = world.base_cells
		modifications = world.modifications

	func get_tile(x: int, y: int) -> int:
		if x < 0 or x >= world_width or y < 0 or y >= world_height:
			return Tiles.Tile.BASALT
		var index := y * world_width + x
		var key := str(index)
		if modifications.has(key):
			return int(modifications[key])
		return int(base_cells[index])


var failures := 0
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_deterministic_generation()
	_test_inventory_and_crafting()
	_test_travel_gates_and_identity()
	_test_combat_rules()
	_test_quest_state()
	_test_touch_pointer_isolation()
	await _test_released_touch_outside_controls()
	_test_survival_damage_timing()
	await _test_environment_cache_invalidation()
	await _test_tile_lookup_equivalence_and_benchmark()
	await _test_visual_chunk_culling()
	await _test_safe_reentry_placement()
	await _test_collision_refresh_scope()
	await _test_scanner_resource_coverage()
	await _test_world_changes_and_terraforming()
	_test_versioned_save_round_trip()
	await _test_main_scene_startup_and_touch_signals()
	await _test_game_shell_navigation()
	await _test_first_expedition_guidance()
	await _test_responsive_touch_controls()
	# Godot may queue nested collision/scene frees for later frames. Do not
	# quit the test tree while those resources are still pending.
	for _frame in range(12):
		await process_frame
	print("SilkBound tests: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS  %s" % label)
	else:
		failures += 1
		push_error("FAIL  %s" % label)


func _test_deterministic_generation() -> void:
	var first := Generator.generate(773421, Generator.Biome.ASHLANDS, 72, 58)
	var second := Generator.generate(773421, Generator.Biome.ASHLANDS, 72, 58)
	_check(
		first["cells"] == second["cells"], "same seed yields byte-for-byte identical base terrain"
	)
	_check(first["surface"] == second["surface"], "same seed yields identical surface profile")
	var other := Generator.generate(773422, Generator.Biome.ASHLANDS, 72, 58)
	_check(first["cells"] != other["cells"], "a different seed changes the generated terrain")
	var glass := Generator.generate(773421, Generator.Biome.GLASSFALL, 72, 58)
	_check(first["cells"] != glass["cells"], "biome selection changes the generated geology")


func _test_inventory_and_crafting() -> void:
	var inventory := TestInventory.new()
	inventory.setup({"scrap": 5, "fiber": 1, "ferrite": 2})
	_check(
		inventory.spend({"scrap": 2, "ferrite": 1}),
		"multi-item spend succeeds when all ingredients exist"
	)
	_check(
		inventory.count("scrap") == 3 and inventory.count("ferrite") == 1,
		"successful spend removes exact quantities"
	)
	var before_scrap := inventory.count("scrap")
	_check(not inventory.spend({"scrap": 99, "fiber": 2}), "insufficient spend is rejected")
	_check(
		inventory.count("scrap") == before_scrap and inventory.count("fiber") == 1,
		"failed spend has no partial side effects"
	)
	var fabricator := TestInventory.new()
	fabricator.setup({"scrap": 2, "fiber": 1})
	var crafted := Crafting.craft("shelter_wall", fabricator)
	_check(bool(crafted["ok"]), "valid shelter recipe crafts")
	_check(
		(
			fabricator.count("scrap") == 0
			and fabricator.count("fiber") == 0
			and fabricator.count("wall") == 2
		),
		"crafting consumes ingredients and creates actual building items"
	)
	var blocked := TestInventory.new()
	blocked.setup({"fiber": 2})
	var failed := Crafting.craft("field_ration", blocked)
	_check(not bool(failed["ok"]), "recipe without required gel fails")
	_check(
		blocked.count("fiber") == 2 and blocked.count("rations") == 0,
		"failed craft does not partially consume resources"
	)
	var full := TestInventory.new()
	full.setup({"scrap": 10}, 1)
	_check(not full.can_add("copper", 1), "inventory slot limit is enforced")
	var stack_limited := TestInventory.new()
	stack_limited.setup({}, 1)
	_check(
		stack_limited.add_item("scrap", 100) == 1 and stack_limited.count("scrap") == 99,
		"stack limit and partial pickup remainder are accounted for"
	)


func _test_travel_gates_and_identity() -> void:
	var state := {"current_planet": "ashlands", "visited_planets": ["ashlands"]}
	var broken_ship := {"engine_repaired": false, "coolant_installed": false}
	var denied := Travel.travel(state, "glassfall", broken_ship)
	_check(not bool(denied["ok"]), "unrepaired ship cannot travel to Glassfall")
	_check(
		state["current_planet"] == "ashlands", "failed travel leaves the current planet unchanged"
	)
	var repaired_ship := {"engine_repaired": true, "coolant_installed": false}
	_check(
		bool(Travel.travel(state, "glassfall", repaired_ship)["ok"]),
		"engine repair opens an existing Glassfall route"
	)
	_check(
		state["visited_planets"].has("glassfall"), "planet identity is recorded on first arrival"
	)
	_check(
		bool(Travel.travel(state, "ashlands", repaired_ship)["ok"]),
		"return route to a previous world remains reachable"
	)
	_check(
		(
			Travel.planet_seed(120000, "glassfall") == 120307
			and Travel.planet_seed(120000, "glassfall") != Travel.planet_seed(120000, "ashlands")
		),
		"planet seed identity is stable and distinct across routes"
	)
	var incomplete_coolant_ship := {"engine_repaired": false, "coolant_installed": true}
	_check(
		not Travel.is_unlocked("drowned", incomplete_coolant_ship),
		"coolant alone cannot bypass a damaged drive"
	)
	var coolant_ship := {"engine_repaired": true, "coolant_installed": true}
	_check(
		Travel.is_unlocked("drowned", coolant_ship),
		"engine and coolant installation open the Drowned Remnant route"
	)


func _test_combat_rules() -> void:
	_check(
		Combat.can_hit_melee(Vector2.ZERO, Vector2(50, 0), 1, 78.0),
		"melee accepts a target inside the facing hitbox"
	)
	_check(
		not Combat.can_hit_melee(Vector2.ZERO, Vector2(-50, 0), 1, 78.0),
		"melee does not hit behind the player"
	)
	_check(
		not Combat.can_hit_melee(Vector2.ZERO, Vector2(90, 0), 1, 78.0),
		"melee rejects a target outside reach"
	)
	var hit := Combat.apply_damage(34.0, 22.0)
	_check(
		float(hit["health"]) == 12.0 and not bool(hit["defeated"]),
		"damage reduces target health without premature defeat"
	)
	var defeat := Combat.apply_damage(float(hit["health"]), 50.0)
	_check(
		float(defeat["health"]) == 0.0 and bool(defeat["defeated"]),
		"lethal damage reaches a final defeated state"
	)


func _test_quest_state() -> void:
	var quests := Quests.new()
	quests.setup({"ship_patch": "corrupt", "iri_supplies": {"status": "unknown", "note": 7}})
	_check(
		quests.status("ship_patch") == "active",
		"invalid saved quest entries recover to a safe default"
	)
	_check(quests.status("iri_supplies") == "available", "unknown quest status is not trusted")
	quests.setup()
	_check(quests.status("ship_patch") == "active", "ship-repair quest is available from the start")
	_check(
		quests.activate("iri_supplies", "Two rations are needed."),
		"survivor quest accepts a practical supply objective"
	)
	_check(
		quests.complete("iri_supplies", "Supplies delivered."),
		"quest completion records its consequence note"
	)
	_check(quests.is_complete("iri_supplies"), "completed rescue remains complete")
	_check(not quests.complete("iri_supplies"), "completed quest cannot be awarded twice")


func _test_survival_damage_timing() -> void:
	var stalled := Survival.new()
	var stepped := Survival.new()
	stalled.setup({"health": 100.0, "oxygen": 0.0})
	stepped.setup({"health": 100.0, "oxygen": 0.0})
	stalled.tick(3.25, {"underwater": true})
	for iteration in range(13):
		stepped.tick(0.25, {"underwater": true})
	_check(
		is_equal_approx(stalled.health, stepped.health) and stalled.health == 85.0,
		"a long frame applies every survival damage interval"
	)
	stalled.tick(0.75, {"underwater": true})
	stepped.tick(0.75, {"underwater": true})
	_check(
		is_equal_approx(stalled.health, stepped.health) and stalled.health == 80.0,
		"damage interval remainder survives across frame boundaries"
	)


func _test_safe_reentry_placement() -> void:
	var rescue_world := WorldGrid.new()
	root.add_child(rescue_world)
	rescue_world.setup("reentry-contract", 91142, Generator.Biome.GLASSFALL)
	var buried_column := 70
	var buried := rescue_world.cell_to_world(
		Vector2i(buried_column, rescue_world.surface_at(buried_column) + 4)
	)
	var fallback := rescue_world.cell_to_world(rescue_world.spawn_cell)
	_check(not rescue_world.captain_space_clear(buried), "buried save location is unsafe")
	var landed := rescue_world.safe_reentry_position(buried, fallback)
	_check(rescue_world.captain_space_clear(landed), "reentry finds unobstructed space")
	_check(
		absi(rescue_world.world_to_cell(landed).x - buried_column) <= 15,
		"reentry prefers nearby existing surface instead of distant ship landing"
	)
	_check(
		rescue_world.safe_reentry_position(fallback, buried) == fallback,
		"valid stored landing coordinates are not moved"
	)
	var original_edits := rescue_world.modifications.duplicate(true)
	rescue_world.safe_reentry_position(buried, fallback)
	_check(
		rescue_world.modifications == original_edits,
		"landing recovery never constructs or erases terrain"
	)
	rescue_world.queue_free()
	await process_frame


func _test_collision_refresh_scope() -> void:
	var terrain := WorldGrid.new()
	root.add_child(terrain)
	terrain.setup("collision-scope", 714220, Generator.Biome.ASHLANDS)
	var x := 70
	var deep_y := terrain.world_height - 3
	var empty_y := terrain.surface_at(x) - 8
	var chunk_index := int(x / WorldGrid.CHUNK_WIDTH)
	var first_body: StaticBody2D = terrain.collision_chunks[chunk_index]
	var original_tile := terrain.get_tile(x, deep_y)
	_check(Tiles.is_solid(original_tile), "collision scope probe begins in solid bedrock")
	_check(terrain.set_tile(x, deep_y, Tiles.Tile.REINFORCED), "solid material may be resurfaced")
	_check(
		terrain.collision_chunks[chunk_index] == first_body,
		"solid-to-solid editing retains live physics shapes"
	)
	_check(
		terrain.get_tile(x, deep_y) == Tiles.Tile.REINFORCED,
		"visual-only tile edits still update resolved terrain"
	)
	_check(terrain.set_tile(x, deep_y, original_tile), "resurfaced tile can be restored")
	_check(
		terrain.collision_chunks[chunk_index] == first_body,
		"restoring solid material does not rebuild collision"
	)
	_check(not Tiles.is_solid(terrain.get_tile(x, empty_y)), "air probe begins unobstructed")
	_check(terrain.set_tile(x, empty_y, Tiles.Tile.WATER), "open air can become water")
	_check(
		terrain.collision_chunks[chunk_index] == first_body,
		"non-solid water edits do not rebuild physics shapes"
	)
	_check(terrain.set_tile(x, empty_y, Tiles.Tile.BRICK), "building adds a solid tile")
	var second_body: StaticBody2D = terrain.collision_chunks[chunk_index]
	_check(
		second_body != first_body and is_instance_valid(second_body),
		"non-solid-to-solid edits rebuild collision immediately"
	)
	_check(terrain.set_tile(x, empty_y, Tiles.Tile.AIR), "mining removes solid tiles")
	var third_body: StaticBody2D = terrain.collision_chunks[chunk_index]
	_check(
		third_body != second_body and is_instance_valid(third_body),
		"solid-to-air edits also rebuild collision immediately"
	)
	terrain._batching = true
	terrain._set_tile_batched(x, deep_y, Tiles.Tile.GLASS)
	terrain._set_tile_batched(x + 1, deep_y, Tiles.Tile.GLASS)
	terrain._batching = false
	terrain._refresh_dirty_chunks()
	_check(
		terrain.collision_chunks[chunk_index] == third_body,
		"batched solid-only transformations preserve collision"
	)
	terrain._batching = true
	terrain._set_tile_batched(x, empty_y, Tiles.Tile.BRICK)
	terrain._batching = false
	terrain._refresh_dirty_chunks()
	_check(
		terrain.collision_chunks[chunk_index] != third_body,
		"batched solidity changes still rebuild the affected collision chunk"
	)
	_check(
		terrain.collision_chunks.size() == terrain.chunk_views.size(),
		"terrain collision chunks remain intact after mixed edits"
	)
	terrain.queue_free()
	await process_frame


func _test_visual_chunk_culling() -> void:
	var cull_world := WorldGrid.new()
	root.add_child(cull_world)
	cull_world.setup("cull-test", 553812, Generator.Biome.ASHLANDS)
	var total := cull_world.chunk_views.size()
	var collisions := cull_world.collision_chunks.size()
	cull_world.update_visible_chunks(10.0 * 32.0, 1280.0)
	var nearby := 0
	for chunk in cull_world.chunk_views.values():
		if (chunk as CanvasItem).visible:
			nearby += 1
	_check(
		total == 9 and nearby > 0 and nearby <= 4,
		"1280px landscape view keeps a bounded set of terrain chunks visible"
	)
	print("SILKBOUND PERF chunk_visibility all=%d visible=%d" % [total, nearby])
	var first_chunk: CanvasItem = cull_world.chunk_views[0]
	var final_chunk: CanvasItem = cull_world.chunk_views[total - 1]
	_check(first_chunk.visible and not final_chunk.visible, "far chunks are hidden near ship")
	cull_world.update_visible_chunks(float(cull_world.world_width * WorldGrid.TILE_SIZE - 300), 1280.0)
	_check(
		not first_chunk.visible and final_chunk.visible,
		"camera travel reveals destination chunks and hides the departed edge"
	)
	_check(
		cull_world.collision_chunks.size() == collisions,
		"visual culling never disables world collision"
	)
	cull_world.queue_free()
	await process_frame


func _probe_legacy_tile_reads(view: LegacyTileView) -> Dictionary:
	var checksum := 0
	var started := Time.get_ticks_usec()
	for iteration in range(8):
		for y in range(8, 72):
			for x in range(12, 220):
				checksum += view.get_tile(x, y)
	return {"elapsed_usec": Time.get_ticks_usec() - started, "checksum": checksum}


func _probe_cached_tile_reads(view: WorldGrid) -> Dictionary:
	var checksum := 0
	var started := Time.get_ticks_usec()
	for iteration in range(8):
		for y in range(8, 72):
			for x in range(12, 220):
				checksum += view.get_tile(x, y)
	return {"elapsed_usec": Time.get_ticks_usec() - started, "checksum": checksum}


func _test_tile_lookup_equivalence_and_benchmark() -> void:
	var perf_world := WorldGrid.new()
	root.add_child(perf_world)
	perf_world.setup("tile-benchmark", 553812, Generator.Biome.GLASSFALL)
	var cell := Vector2i(32, perf_world.surface_at(32))
	var old_tile := perf_world.get_tile(cell.x, cell.y)
	perf_world.set_tile(cell.x, cell.y, Tiles.Tile.AIR)
	_check(
		perf_world.get_tile(cell.x, cell.y) == Tiles.Tile.AIR
		and perf_world.base_cells[perf_world.cell_index(cell.x, cell.y)] == old_tile,
		"resolved tile cache reflects edits without mutating seeded base geology"
	)
	var saved_edits := perf_world.modifications.duplicate(true)
	perf_world.cracks[perf_world.cell_index(cell.x, cell.y)] = 11.0
	perf_world.scan_highlights[str(perf_world.cell_index(cell.x, cell.y))] = "ferrite"
	perf_world.setup("tile-benchmark", 553812, Generator.Biome.GLASSFALL, saved_edits)
	_check(
		perf_world.get_tile(cell.x, cell.y) == Tiles.Tile.AIR
		and perf_world.modifications == saved_edits,
		"cached tile IDs reconstruct exactly from persistent edit indices"
	)
	_check(
		perf_world.cracks.is_empty() and perf_world.scan_highlights.is_empty(),
		"world setup clears transient crack and scanner state"
	)
	var legacy := LegacyTileView.new()
	legacy.setup(perf_world)
	var old_checksum := 0
	var new_checksum := 0
	var legacy_samples: Array[int] = []
	var cached_samples: Array[int] = []
	# Warm both paths and alternate order to avoid a one-sided cache/CPU advantage.
	_probe_legacy_tile_reads(legacy)
	_probe_cached_tile_reads(perf_world)
	for sample_index in range(6):
		var legacy_result: Dictionary
		var cached_result: Dictionary
		if sample_index % 2 == 0:
			legacy_result = _probe_legacy_tile_reads(legacy)
			cached_result = _probe_cached_tile_reads(perf_world)
		else:
			cached_result = _probe_cached_tile_reads(perf_world)
			legacy_result = _probe_legacy_tile_reads(legacy)
		legacy_samples.append(int(legacy_result["elapsed_usec"]))
		cached_samples.append(int(cached_result["elapsed_usec"]))
		old_checksum = int(legacy_result["checksum"])
		new_checksum = int(cached_result["checksum"])
	_check(
		new_checksum == old_checksum,
		"cached and prior tile-read methods agree over 106496 matched world queries"
	)
	legacy_samples.sort()
	cached_samples.sort()
	var legacy_median := float(legacy_samples[2] + legacy_samples[3]) * 0.5
	var cached_median := float(cached_samples[2] + cached_samples[3]) * 0.5
	print(
		"SILKBOUND PERF tile_reads=106496 trials=6 legacy_median_usec=%0.1f cached_median_usec=%0.1f"
		% [legacy_median, cached_median]
	)
	perf_world.queue_free()
	await process_frame


func _test_environment_cache_invalidation() -> void:
	var sample_world := WorldGrid.new()
	root.add_child(sample_world)
	sample_world.setup("environment-cache", 773421, Generator.Biome.GLASSFALL)
	var cell := Vector2i(9, sample_world.surface_at(9) - 3)
	var sample_position := sample_world.cell_to_world(cell)
	var before_shelter := sample_world.is_sheltered(sample_position)
	_check(not before_shelter, "landing shelf is not initially an artificial shelter")
	_check(not sample_world.is_thermal_zone(sample_position), "untouched shelf is thermally stable")
	var baseline_samples := sample_world.environment_sample_count
	for iteration in range(30):
		sample_world.is_sheltered(sample_position)
		sample_world.is_thermal_zone(sample_position)
	_check(
		sample_world.environment_sample_count == baseline_samples,
		"unchanged location reuses one bounded environment sample"
	)
	_check(sample_world.set_tile(cell.x + 1, cell.y, Tiles.Tile.LAMP), "test lamp is placed")
	_check(sample_world.is_sheltered(sample_position), "placement immediately updates shelter")
	_check(
		sample_world.environment_sample_count == baseline_samples + 1,
		"terrain edits invalidate the cached environment"
	)
	_check(sample_world.set_tile(cell.x + 1, cell.y, Tiles.Tile.AIR), "test lamp is removed")
	_check(
		not sample_world.is_sheltered(sample_position), "removed lamp cannot leave false shelter"
	)
	_check(sample_world.set_tile(cell.x - 1, cell.y, Tiles.Tile.FAULT), "test fault is exposed")
	_check(sample_world.is_thermal_zone(sample_position), "new fault triggers local heat warning")
	_check(sample_world.set_tile(cell.x - 1, cell.y, Tiles.Tile.AIR), "test fault is removed")
	_check(not sample_world.is_thermal_zone(sample_position), "removed fault clears heat warning")
	var surface_y := sample_world.surface_at(10)
	sample_world.mine_cell(10, surface_y, 1.0)
	_check(
		sample_world.cracks.has(sample_world.cell_index(10, surface_y)),
		"partial mining creates a tracked crack"
	)
	sample_world.set_tile(10, surface_y, Tiles.Tile.AIR)
	_check(
		not sample_world.cracks.has(sample_world.cell_index(10, surface_y)),
		"replaced terrain does not inherit obsolete mining damage"
	)
	sample_world.set_fault_warning_phase(2)
	_check(sample_world.fault_warning_phase == 2, "Glassfall pre-failure visual phase is tracked")
	sample_world.queue_free()
	await process_frame


func _test_released_touch_outside_controls() -> void:
	var touch_scene: PackedScene = load("res://scenes/main.tscn")
	var touch_game: Node = touch_scene.instantiate()
	touch_game.set("test_mode", true)
	root.add_child(touch_game)
	await process_frame
	await process_frame
	var touch_hud: GameHUD = touch_game.get("hud")
	var jump_button: TouchActionButton = touch_hud.action_buttons[0]
	var mine_button: TouchActionButton = touch_hud.action_buttons[1]
	jump_button.active_pointers[411] = true
	jump_button.action_pressed.emit("jump", 411)
	mine_button.active_pointers[412] = true
	mine_button.action_pressed.emit("mine", 412)
	touch_hud.stick._pointer_id = 413
	touch_hud.stick._axis = Vector2.RIGHT
	touch_hud.stick.axis_changed.emit(Vector2.RIGHT)
	var outside_release := InputEventScreenTouch.new()
	outside_release.pressed = false
	outside_release.position = Vector2(-1000.0, -1000.0)
	outside_release.index = 412
	touch_hud._input(outside_release)
	_check(
		not bool(touch_game.call("is_action_held", "mine"))
		and bool(touch_game.call("is_action_held", "jump")),
		"outside release ends only the matching held action"
	)
	_check(
		touch_hud.stick._pointer_id == 413
		and (touch_game.get("player") as SilkboundPlayer).touch_axis == Vector2.RIGHT,
		"outside action release preserves an independent movement pointer"
	)
	outside_release.index = 413
	touch_hud._input(outside_release)
	_check(
		touch_hud.stick._pointer_id == -999
		and (touch_game.get("player") as SilkboundPlayer).touch_axis == Vector2.ZERO,
		"outside stick release immediately neutralizes movement"
	)
	_check(bool(touch_game.call("is_action_held", "jump")), "stick release preserves jump")
	touch_hud.apply_control_settings()
	_check(
		not bool(touch_game.call("is_action_held", "jump")),
		"rebuilding controls releases stale action ownership"
	)
	_check(
		touch_hud.action_buttons.size() == 10,
		"control rebuild preserves the ten existing actions"
	)
	touch_game.queue_free()
	await process_frame


func _test_touch_pointer_isolation() -> void:
	var router := Router.new()
	_check(router.press("move_left", 11), "first movement pointer becomes active")
	_check(router.press("jump", 22), "independent jump pointer becomes active")
	_check(
		router.is_held("move_left") and router.is_held("jump"),
		"movement and jump can be held simultaneously"
	)
	_check(router.release("jump", 22), "releasing the jump pointer ends only jump")
	_check(
		router.is_held("move_left") and not router.is_held("jump"),
		"one finger release does not cancel the other action"
	)
	_check(router.release("move_left", 11), "movement ends when its own pointer releases")


func _test_scanner_resource_coverage() -> void:
	var scan_world := WorldGrid.new()
	root.add_child(scan_world)
	scan_world.setup("scan-coverage", 773421, Generator.Biome.ASHLANDS)
	var origin := Vector2i(80, 10)
	var sample_cells := {
		"ferrite": {"offset": Vector2i.ZERO, "tile": Tiles.Tile.FERRITE},
		"copper": {"offset": Vector2i(1, 0), "tile": Tiles.Tile.COPPER},
		"crystal": {"offset": Vector2i(0, 1), "tile": Tiles.Tile.CRYSTAL},
		"glass": {"offset": Vector2i(-1, 0), "tile": Tiles.Tile.GLASS},
		"wreckage": {"offset": Vector2i(0, -1), "tile": Tiles.Tile.SCRAP},
		"water": {"offset": Vector2i(2, 0), "tile": Tiles.Tile.WATER},
		"archive": {"offset": Vector2i(-2, 0), "tile": Tiles.Tile.ARCHIVE},
		"fiber": {"offset": Vector2i(0, 2), "tile": Tiles.Tile.FIBER},
		"fault": {"offset": Vector2i(0, -2), "tile": Tiles.Tile.FAULT}
	}
	for category in sample_cells:
		var sample: Dictionary = sample_cells[category]
		var offset: Vector2i = sample["offset"]
		scan_world.set_tile(origin.x + offset.x, origin.y + offset.y, int(sample["tile"]))
	var result := scan_world.scan_area(scan_world.cell_to_world(origin), 4)
	var scan_draws := scan_world.scan_redraw_request_count
	_check(scan_draws == 1, "nearby scan redraws one local chunk instead of all nine")
	print("SILKBOUND PERF scan_redraw_requests legacy=9 localized=%d" % scan_draws)
	var second_result := scan_world.scan_area(scan_world.cell_to_world(origin), 4)
	_check(
		scan_world.scan_redraw_request_count == scan_draws
		and int(second_result["ore"]) == int(result["ore"]),
		"unchanged repeated scan skips all terrain redraw requests"
	)
	var signals: Dictionary = result["nearest"]
	var ferrite_signal: Dictionary = signals["ferrite"]
	_check(
		int(ferrite_signal["x"]) == origin.x
		and int(ferrite_signal["y"]) == origin.y,
		"scanner nearest-return coordinates identify the true ore cell"
	)
	for category in sample_cells:
		_check(
			int(result[category]) == 1,
			"scanner reports a distinct %s cell count" % String(category)
		)
	_check(
		int(result["ore"]) == 3, "legacy ore total remains the sum of ferrite, copper and crystal"
	)
	for category in [
		"ferrite", "copper", "crystal", "glass", "wreckage", "archive", "fiber", "fault"
	]:
		var sample: Dictionary = sample_cells[category]
		var offset: Vector2i = sample["offset"]
		var cell_key := str(scan_world.cell_index(origin.x + offset.x, origin.y + offset.y))
		_check(
			String(scan_world.scan_highlights.get(cell_key, "")) == category,
			"scan marker preserves the %s material identity for its visual treatment" % category
		)
		_check(
			TerrainChunk.SCAN_COLORS.has(category),
			"%s has a dedicated on-world scan color" % category
		)
	var water_offset: Vector2i = sample_cells["water"]["offset"]
	var water_key := str(
		scan_world.cell_index(origin.x + water_offset.x, origin.y + water_offset.y)
	)
	_check(
		not scan_world.scan_highlights.has(water_key),
		"water remains visible without dense scan outlines"
	)
	scan_world.clear_scan_highlights()
	_check(
		scan_world.scan_highlights.is_empty()
		and scan_world.scan_redraw_request_count == scan_draws + 1,
		"scanner expiry clears only the previously highlighted chunk"
	)
	scan_world.clear_scan_highlights()
	_check(
		scan_world.scan_redraw_request_count == scan_draws + 1,
		"repeated expiry never schedules duplicate redraws"
	)
	# An edge scan spans two chunks; moving away must invalidate both,
	# while an unchanged repeat must not schedule a second redraw.
	_check(scan_world.set_tile(95, 10, Tiles.Tile.FERRITE), "edge ore exists in first chunk")
	_check(scan_world.set_tile(96, 10, Tiles.Tile.CRYSTAL), "edge ore exists in second chunk")
	var before_edge := scan_world.scan_redraw_request_count
	var edge_origin := scan_world.cell_to_world(Vector2i(95, 10))
	var edge_returns := scan_world.scan_area(edge_origin, 4)
	_check(
		int(edge_returns["ferrite"]) == 1 and int(edge_returns["crystal"]) == 1,
		"two-chunk scan preserves resource totals on both sides of chunk boundary"
	)
	_check(
		scan_world.scan_redraw_request_count - before_edge == 2,
		"edge scan redraws the two affected terrain chunks"
	)
	var after_edge := scan_world.scan_redraw_request_count
	scan_world.scan_area(edge_origin, 4)
	_check(
		scan_world.scan_redraw_request_count == after_edge,
		"identical edge scan retains markers without new render work"
	)
	scan_world.scan_area(scan_world.cell_to_world(Vector2i(160, 10)), 4)
	_check(
		scan_world.scan_redraw_request_count - after_edge == 2,
		"moving scan to empty terrain clears only the two previous chunks"
	)
	_check(
		scan_world.scan_highlights.is_empty(),
		"moving a scan to a quiet region leaves no ghost resource outlines"
	)
	scan_world.queue_free()
	await process_frame


func _test_world_changes_and_terraforming() -> void:
	var world := WorldGrid.new()
	root.add_child(world)
	world.setup("test-ash", 98241, Generator.Biome.ASHLANDS)
	var surface_y := world.surface_at(15)
	_check(
		world.get_tile(15, surface_y) == Tiles.Tile.SCRAP,
		"starter outcrop is guaranteed and reachable"
	)
	var mined := world.mine_cell(15, surface_y, 120.0)
	_check(
		bool(mined.get("broken", false)) and world.get_tile(15, surface_y) == Tiles.Tile.AIR,
		"mining removes a real terrain cell"
	)
	var mined_drop: Dictionary = mined.get("drop", {})
	_check(
		String(mined_drop.get("item", "")) == "scrap" and int(mined_drop.get("amount", 0)) == 2,
		"removed wreckage yields its correct pickup data"
	)
	var placement_x := -1
	for x in range(30, world.world_width - 4):
		if world.get_tile(x, world.surface_at(x) - 1) == Tiles.Tile.AIR:
			placement_x = x
			break
	var placement_y := world.surface_at(placement_x) - 1
	var placed := world.place_building(
		placement_x, placement_y, Tiles.Tile.WALL, Vector2(-10000, -10000)
	)
	_check(
		bool(placed["ok"]) and world.get_tile(placement_x, placement_y) == Tiles.Tile.WALL,
		"supported building changes the terrain state"
	)
	var rejected := world.place_building(
		placement_x, placement_y, Tiles.Tile.WALL, Vector2(-10000, -10000)
	)
	_check(
		not bool(rejected["ok"]) and world.get_tile(placement_x, placement_y) == Tiles.Tile.WALL,
		"occupied building placement is rejected without mutation"
	)
	var change := world.apply_terraform(62, 7)
	_check(int(change["changed"]) >= 20, "terraforming alters a bounded region of actual cells")
	var center: Vector2i = change["center"]
	_check(
		world.get_tile(center.x, center.y + 5) == Tiles.Tile.FAULT,
		"terraforming leaves a persistent shear-fault tile"
	)
	var persisted_edits := world.modifications.duplicate(true)
	var second_world := WorldGrid.new()
	root.add_child(second_world)
	second_world.setup("test-glassfall", 98241, Generator.Biome.ASHLANDS, persisted_edits)
	_check(
		second_world.get_tile(center.x, center.y + 5) == Tiles.Tile.FAULT,
		"world edits survive deterministic world reconstruction"
	)
	second_world.queue_free()
	world.queue_free()
	await process_frame


func _test_versioned_save_round_trip() -> void:
	var payload := {
		"inventory": {"scrap": 7, "rations": 2},
		"ship": {"engine_repaired": true, "integrity": 65},
		"quests": {"iri_supplies": {"status": "complete", "note": "supplies delivered"}},
		"world_states":
		{
			"glassfall":
			{"edits": {"123": Tiles.Tile.FAULT}, "terraform": {"phase": 3, "transformed": true}}
		}
	}
	_check(Save.save_slot(payload, "test_contract"), "versioned save writes to local user storage")
	var loaded := Save.load_slot("test_contract")
	_check(bool(loaded["ok"]), "valid save loads without recovery")
	_check(loaded["data"]["inventory"]["scrap"] == 7, "save preserves inventory quantities")
	_check(loaded["data"]["ship"]["engine_repaired"], "save preserves ship repair state")
	_check(
		loaded["data"]["quests"]["iri_supplies"]["status"] == "complete",
		"save preserves quest consequences"
	)
	_check(
		loaded["data"]["world_states"]["glassfall"]["terraform"]["transformed"],
		"save preserves terraforming state"
	)
	var newer_payload := payload.duplicate(true)
	newer_payload["inventory"]["scrap"] = 8
	_check(
		Save.save_slot(newer_payload, "test_contract"),
		"second save preserves the previous generation"
	)
	var damaged_file := FileAccess.open("user://saves/test_contract.json", FileAccess.WRITE)
	_check(damaged_file != null, "test can simulate a damaged local save")
	if damaged_file != null:
		damaged_file.store_string("{damaged")
		damaged_file.close()
	var recovered := Save.load_slot("test_contract")
	_check(
		(
			bool(recovered["ok"])
			and bool(recovered["recovered"])
			and int(recovered["data"]["inventory"]["scrap"]) == 7
		),
		"malformed primary save recovers the last valid backup"
	)
	_check(Save.save_slot(recovered["data"], "test_contract"), "recovered data saves again")
	var damaged_again := FileAccess.open("user://saves/test_contract.json", FileAccess.WRITE)
	_check(damaged_again != null, "test can simulate repeated primary damage")
	if damaged_again != null:
		damaged_again.store_string("{damaged-again")
		damaged_again.close()
	var recovered_again := Save.load_slot("test_contract")
	_check(
		(
			bool(recovered_again.get("ok", false))
			and bool(recovered_again.get("recovered", false))
			and int(recovered_again["data"]["inventory"]["scrap"]) == 7
		),
		"re-saving recovered data preserves a second chance to restore the last good generation"
	)
	var competing_staged := FileAccess.open(
		"user://saves/test_contract.json.tmp", FileAccess.WRITE
	)
	_check(competing_staged != null, "backup-priority fixture can stage newer uncommitted data")
	if competing_staged != null:
		competing_staged.store_string(
			JSON.stringify({"version": Save.SAVE_VERSION, "data": newer_payload})
		)
		competing_staged.close()
		var backup_priority := Save.load_slot("test_contract")
		_check(
			bool(backup_priority.get("ok", false))
			and String(backup_priority.get("recovery_source", "")) == "backup"
			and int(backup_priority["data"]["inventory"]["scrap"]) == 7,
			"valid backup wins over newer uncommitted staged data"
		)
	Save.delete_slot("test_contract")
	# Simulate a crash after writing the staged generation but before rename.
	# The backup is absent, so this is the only valid remaining save.
	Save.delete_slot("test_interrupted")
	_check(
		Save.save_slot(payload, "test_interrupted"),
		"interrupted-save fixture starts with a complete primary generation"
	)
	var interrupted_primary := "user://saves/test_interrupted.json"
	var staged_path := interrupted_primary + ".tmp"
	var original_data := FileAccess.get_file_as_string(interrupted_primary)
	var staged_file := FileAccess.open(staged_path, FileAccess.WRITE)
	_check(staged_file != null, "interrupted-save fixture can write the staged generation")
	if staged_file != null:
		staged_file.store_string(original_data)
		staged_file.flush()
		staged_file.close()
		var remove_result := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(interrupted_primary)
		)
		_check(remove_result == OK, "interrupted-save fixture can remove the uncommitted primary")
		var recovered_staged := Save.load_slot("test_interrupted")
		_check(
			bool(recovered_staged.get("ok", false))
			and bool(recovered_staged.get("recovered", false))
			and String(recovered_staged.get("recovery_source", "")) == "temporary"
			and int(recovered_staged["data"]["inventory"]["scrap"]) == 7,
			"valid staged generation recovers when primary and backup are absent"
		)
		_check(
			Save.save_slot(recovered_staged.get("data", {}), "test_interrupted"),
			"recovered staged generation can be committed as a normal primary"
		)
		var committed_result := Save.load_slot("test_interrupted")
		_check(
			bool(committed_result.get("ok", false))
			and not bool(committed_result.get("recovered", false)),
			"recovered staged save resumes normal primary loading"
		)
		var stale_stage := FileAccess.open(staged_path, FileAccess.WRITE)
		_check(stale_stage != null, "primary-priority fixture can create stale staged data")
		if stale_stage != null:
			stale_stage.store_string(
				JSON.stringify({"version": Save.SAVE_VERSION, "data": newer_payload})
			)
			stale_stage.close()
			var primary_priority := Save.load_slot("test_interrupted")
			_check(
				bool(primary_priority.get("ok", false))
				and not bool(primary_priority.get("recovered", false))
				and int(primary_priority["data"]["inventory"]["scrap"]) == 7,
				"valid primary wins over stale staged data"
			)
	Save.delete_slot("test_interrupted")
	_check(
		not bool(Save.load_slot("../escape")["ok"]),
		"invalid slot names are rejected before filesystem access"
	)


func _test_responsive_touch_controls() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as SilkboundGame
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var hud := game.hud
	hud._rebuild_touch_controls(Vector2i(1280, 720))
	await process_frame
	var base_diameter := hud.action_buttons[4].size.x
	# Rebuild at a narrower physical window without changing game-world
	# canvas coordinates. Hitboxes must grow instead of becoming tiny.
	hud._rebuild_touch_controls(Vector2i(720, 405))
	await process_frame
	_check(hud.action_buttons.size() == 10, "compact layout retains all original gameplay actions")
	_check(
		hud.action_buttons[4].size.x > base_diameter,
		"smaller landscape screens enlarge logical action hitboxes"
	)
	var all_onscreen := true
	var all_disjoint := true
	var readable := true
	for i in range(hud.action_buttons.size()):
		var action: TouchActionButton = hud.action_buttons[i]
		var bounds := action.get_global_rect()
		if bounds.position.x < 0 or bounds.position.y < 0 or bounds.end.x > hud.root.size.x or bounds.end.y > hud.root.size.y:
			all_onscreen = false
		if bounds.size.x * (720.0 / 1280.0) < 48.0:
			readable = false
		for j in range(i + 1, hud.action_buttons.size()):
			if bounds.intersects(hud.action_buttons[j].get_global_rect()):
				all_disjoint = false
	_check(all_onscreen, "all ten compact controls remain inside the reference viewport")
	_check(all_disjoint, "compact touch controls have separate collision-free hitboxes")
	_check(readable, "compact physical hitbox diameters stay at least 48 px")
	var status_panel := hud.root.get_node("StatusPanel") as Control
	_check(
		status_panel.get_global_rect().end.x < hud.action_buttons[9].get_global_rect().position.x,
		"utility controls stay clear of the left-side status panel"
	)
	var touch_bar := hud.root.get_node("TouchHotbar") as ScrollContainer
	_check(
		not hud.stick.get_global_rect().intersects(touch_bar.get_global_rect()),
		"movement stick remains clear of inventory hotbar"
	)
	_check(
		hud.hotbar_buttons.size() == 8
		and touch_bar.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"all eight saved construction slots survive in a swipeable rail"
	)
	var rail_button := hud.hotbar_buttons[0]
	_check(
		rail_button.size.x * (720.0 / 1280.0) >= 48.0
		and rail_button.size.y * (720.0 / 1280.0) >= 48.0,
		"narrow-window hotbar slots retain real minimum physical touch dimensions"
	)
	var rail_clear := true
	for action in hud.action_buttons:
		if touch_bar.get_global_rect().intersects(action.get_global_rect()):
			rail_clear = false
	_check(rail_clear, "larger hotbar stays clear of every action hitbox")
	game.selected_hotbar = 7
	hud.refresh()
	await process_frame
	await process_frame
	_check(
		touch_bar.scroll_horizontal > 0,
		"selecting the farthest hotbar item scrolls its slot into view"
	)
	game.selected_hotbar = 0
	hud.refresh()
	await process_frame
	await process_frame
	_check(touch_bar.scroll_horizontal == 0, "returning to first slot restores the left rail")
	touch_bar.scroll_horizontal = 100
	hud.refresh()
	await process_frame
	_check(
		touch_bar.scroll_horizontal == 100,
		"background refresh never overrides a player's manual hotbar swipe"
	)
	# Handedness must keep these guarantees after a live layout rebuild.
	game.settings["left_handed"] = true
	hud._rebuild_touch_controls(Vector2i(720, 405))
	await process_frame
	_check(
		hud.stick.get_global_rect().position.x > 960.0
		and hud.action_buttons[0].get_global_rect().position.x < 400.0,
		"left-handed arrangement swaps movement and action zones"
	)
	var left_disjoint := true
	for i in range(hud.action_buttons.size()):
		for j in range(i + 1, hud.action_buttons.size()):
			if hud.action_buttons[i].get_global_rect().intersects(hud.action_buttons[j].get_global_rect()):
				left_disjoint = false
	_check(left_disjoint, "left-handed compact controls remain separated")
	game.settings["left_handed"] = false
	hud._rebuild_touch_controls(Vector2i(1280, 720))
	await process_frame
	_check(
		absf(hud.action_buttons[4].size.x - base_diameter) < 0.1,
		"returning to reference landscape restores standard hitboxes"
	)
	game.queue_free()
	await process_frame


func _test_first_expedition_guidance() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as SilkboundGame
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var hud := game.hud
	_check(
		game.onboarding_step == 0 and game.field_guide_hint().contains("MOVE"),
		"fresh captain sees a real movement instruction"
	)
	_check(
		not game._advance_onboarding(3) and game.onboarding_step == 0,
		"unrelated input cannot claim a completed guided action"
	)
	game.player.global_position.x += 80.0
	game._process(0.016)
	_check(game.onboarding_step == 1, "crossing landing ground advances actual movement step")
	_check(hud.objective_label.text.contains("MINE"), "next guidance replaces only the context objective")
	var base := game.world.world_to_cell(game.player.global_position)
	var target := Vector2i(base.x + 1, base.y + 1)
	game.world.set_tile(target.x, target.y, Tiles.Tile.SCRAP)
	game._mouse_aim_active = true
	game._last_action_was_touch = false
	game._last_mouse_world = game.world.cell_to_world(target)
	for attempt in range(12):
		if game.onboarding_step != 1:
			break
		game._perform_mine()
	_check(game.onboarding_step == 2, "real tile destruction advances guided mining")
	game._scan()
	_check(game.onboarding_step == 3, "real local scanner sweep advances guided survey")
	var original_scrap := game.inventory.count("scrap")
	game._on_hud_action("craft:shelter_wall")
	_check(
		game.onboarding_step == 4 and game.inventory.count("scrap") == original_scrap - 2,
		"real successful crafting, with ingredient cost, advances fabrication"
	)
	game._on_hud_action("close")
	game.player.global_position = game.ship_sprite.global_position + Vector2(24, 0)
	game._dispatch_action("ship")
	_check(
		game.onboarding_step == 5 and game.is_paused and hud.current_panel_kind() == "ship",
		"arriving at the physical ship console finishes guided onboarding"
	)
	_check(game.field_guide_hint().is_empty(), "completed guide restores canonical objective")
	Save.delete_slot("test_field_guide")
	_check(game.save_game("test_field_guide"), "progressed guide can save to isolated test slot")
	var stored := Save.load_slot("test_field_guide")
	_check(
		bool(stored.get("ok", false)) and int(stored["data"].get("onboarding_step", -1)) == 5,
		"optional guide state persists without changing the save version"
	)
	Save.delete_slot("test_field_guide")
	var legacy_data: Dictionary = stored["data"].duplicate(true)
	legacy_data.erase("onboarding_step")
	game._restore_state(legacy_data)
	_check(
		game.onboarding_step == 5,
		"older saves lacking the optional guide field bypass retroactive onboarding"
	)
	game._begin_new_expedition()
	_check(game.onboarding_step == 0, "a genuinely new captain starts their own guide")
	game._show_pause_menu()
	game._on_hud_action("open_guide")
	_check(hud.current_panel_kind() == "guide", "guide is accessible through the pause menu")
	game._on_hud_action("guide_skip")
	_check(
		game.onboarding_step == 5 and hud.current_panel_kind() == "pause" and game.is_paused,
		"skipping guide removes hints and returns to originating pause menu"
	)
	game.queue_free()
	await process_frame


func _test_game_shell_navigation() -> void:
	# This test uses the game's isolated test mode: no live save slot is
	# read, replaced, saved or deleted by title/death flows.
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate() as SilkboundGame
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var hud := game.hud
	_check(not game.is_paused and not hud.modal.visible, "test-mode game boots without title overlay")

	# P002: an explicit parent context survives nested menu navigation.
	game._toggle_pause()
	_check(game.is_paused and hud.current_panel_kind() == "pause", "pause panel opens and freezes world")
	game._on_hud_action("open_settings")
	_check(game.is_paused and hud.current_panel_kind() == "settings", "settings opens from pause")
	hud._on_panel_action("close")
	_check(game.is_paused and hud.current_panel_kind() == "pause", "Back from settings returns to pause")
	game._toggle_pause()
	_check(not game.is_paused and not hud.modal.visible, "Back from pause resumes field operations")

	game.is_paused = true
	hud.show_ship()
	game._on_hud_action("open_travel")
	_check(game.is_paused and hud.current_panel_kind() == "travel", "ship navigation opens as a nested panel")
	hud._on_panel_action("close")
	_check(game.is_paused and hud.current_panel_kind() == "ship", "Back from travel restores ship console")
	game._on_hud_action("storage")
	_check(game.is_paused and hud.current_panel_kind() == "storage", "storage opens as a nested ship panel")
	hud._on_panel_action("close")
	_check(game.is_paused and hud.current_panel_kind() == "ship", "Back from storage restores ship console")
	hud._on_panel_action("close")
	_check(not game.is_paused and not hud.modal.visible, "closing base ship panel resumes operations")

	# P003: title has an explicit, nondestructive Continue/Begin boundary.
	var original_seed := game.base_seed
	game._had_valid_save = false
	game._show_title_menu()
	_check(game._title_open and game.is_paused and hud.current_panel_kind() == "title", "title screen suspends gameplay")
	_check(not hud._panel_close_button.visible and hud._title_curtain.visible, "title blocks implicit Close and shields gameplay")
	game._dispatch_action("mine")
	_check(game._title_open, "held gameplay actions cannot bypass the title screen")
	hud._on_panel_action("close")
	_check(hud.modal.visible and game._title_open, "back button cannot abandon first-run title")
	game._on_hud_action("title_settings")
	_check(hud.current_panel_kind() == "settings" and game._title_open, "settings available before first expedition")
	hud._on_panel_action("close")
	_check(hud.current_panel_kind() == "title" and game._title_open, "settings returns to title without starting")
	game._on_hud_action("title_guide")
	_check(
		game._title_open and hud.current_panel_kind() == "guide",
		"field guide is available before starting a new captain"
	)
	hud._on_panel_action("close")
	_check(
		game._title_open and hud.current_panel_kind() == "title",
		"Back from title field guide cannot secretly start gameplay"
	)
	game._on_hud_action("title_begin")
	_check(
		not game._title_open and not game.is_paused and game.base_seed == original_seed,
		"first expedition starts only after explicit Begin with original seed preserved"
	)

	game._had_valid_save = true
	game._show_title_menu()
	game._on_hud_action("title_new_confirm")
	_check(hud.current_panel_kind() == "title_confirm" and game._title_open, "existing save requires replace confirmation")
	hud._on_panel_action("close")
	_check(
		hud.current_panel_kind() == "title" and game.base_seed == original_seed,
		"cancel replacement preserves the original captain and seed"
	)
	game._on_hud_action("title_continue")
	_check(
		not game._title_open and not game.is_paused and game.base_seed == original_seed,
		"Continue resumes prior simulation without rerolling progress"
	)
	# Returning to title is non-destructive and retains a valid continuation.
	game._show_pause_menu()
	game._on_hud_action("return_title")
	_check(
		game._title_open and game.is_paused and hud.current_panel_kind() == "title",
		"pause-screen return brings the captain back to title without resetting progress"
	)
	game._on_hud_action("title_new_confirm")
	game._on_hud_action("title_new_confirmed")
	_check(
		not game._title_open and not game.run_ended and not game.is_paused
		and game.inventory.count("scrap") == 2,
		"explicit replacement confirmation begins a fresh expedition"
	)

	# P001: final death is final but never strands the player in a hidden menu.
	game._handle_final_death(true)
	_check(
		game.run_ended and hud.current_panel_kind() == "death" and hud.modal.visible,
		"final death exposes the one safe new-captain decision"
	)
	_check(not hud._panel_dismissible and not hud._panel_close_button.visible, "death dialogue cannot be dismissed")
	hud._on_panel_action("close")
	game._on_hud_action("close")
	game._dispatch_action("pause")
	_check(
		game.run_ended and hud.modal.visible and hud.current_panel_kind() == "death",
		"Close, Back and gameplay actions cannot strand a dead captain"
	)
	game._on_hud_action("new_expedition")
	_check(
		not game.run_ended and not game.is_paused and not hud.modal.visible,
		"explicit new expedition restores a playable world without resurrecting the captain"
	)
	# On a subsequent launch, the ended expedition is shown at the title.
	# Its Settings and Back actions must work without reviving the captain.
	game._handle_final_death(true)
	game._show_title_menu()
	_check(
		game.run_ended and game._title_open and hud.current_panel_kind() == "title",
		"an ended expedition opens a memorial title, not a playable Continue"
	)
	game._on_hud_action("title_new_confirm")
	hud._on_panel_action("close")
	_check(
		game.run_ended and game._title_open and hud.current_panel_kind() == "title",
		"Back from new-captain confirmation works after a death"
	)
	game._on_hud_action("title_settings")
	hud._on_panel_action("close")
	_check(
		game.run_ended and hud.current_panel_kind() == "title",
		"ended-run title settings return to the memorial without gameplay unlock"
	)
	game._on_hud_action("title_new_confirm")
	game._on_hud_action("title_new_confirmed")
	_check(
		not game.run_ended and not game._title_open and not game.is_paused,
		"a confirmed new captain from ended-run title can play"
	)
	game.queue_free()
	await process_frame


func _test_main_scene_startup_and_touch_signals() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "configured main scene resource loads")
	if packed == null:
		return
	var game: Node = packed.instantiate()
	game.set("test_mode", true)
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.get("world") is WorldGrid, "startup mounts a generated planet")
	_check(game.get("player") is CharacterBody2D, "startup creates a CharacterBody2D player")
	_check(
		String(game.get("player").name) == "FieldCaptain",
		"simulation player remains an original civilian captain"
	)
	_check(
		not FileAccess.get_file_as_string("res://scripts/core/game.gd").contains("KAIL")
		and not FileAccess.get_file_as_string("res://scripts/ui/game_hud.gd").contains("KAIL"),
		"non-canon player and survivor text must not represent the canonical character Kail"
	)
	_check(game.get("hud") != null, "startup creates the touch HUD")
	var hud: GameHUD = game.get("hud")
	hud.touch_action_pressed.emit("jump", 101)
	hud.touch_action_pressed.emit("mine", 202)
	_check(
		bool(game.call("is_action_held", "jump")) and bool(game.call("is_action_held", "mine")),
		"HUD actions reach the touch router independently"
	)
	hud.touch_action_released.emit("mine", 202)
	_check(
		bool(game.call("is_action_held", "jump")) and not bool(game.call("is_action_held", "mine")),
		"releasing one HUD action leaves concurrent input intact"
	)
	hud.touch_action_released.emit("jump", 101)
	_check(
		not bool(game.call("is_action_held", "jump")), "touch release clears its own held action"
	)
	var emulated_click := InputEventMouseButton.new()
	emulated_click.device = InputEvent.DEVICE_ID_EMULATION
	emulated_click.button_index = MOUSE_BUTTON_LEFT
	emulated_click.pressed = true
	game.call("_unhandled_input", emulated_click)
	_check(
		not bool(game.get("_mouse_mine_held")),
		"touch-emulated mouse clicks cannot activate held mining"
	)
	_check(
		not bool(game.get("_mouse_aim_active")),
		"touch-emulated mouse clicks cannot steal pointer aiming"
	)
	var physical_click := InputEventMouseButton.new()
	physical_click.device = InputEvent.DEVICE_ID_MOUSE
	physical_click.button_index = MOUSE_BUTTON_LEFT
	physical_click.pressed = true
	game.call("_unhandled_input", physical_click)
	_check(bool(game.get("_mouse_mine_held")), "physical mouse click can still initiate mining")
	physical_click.pressed = false
	game.call("_input", physical_click)
	_check(not bool(game.get("_mouse_mine_held")), "physical mouse release stops continuous mining")
	game.set("_mouse_aim_active", false)
	game.set("_last_action_was_touch", true)
	var scan_world: WorldGrid = game.get("world")
	var scan_player: CharacterBody2D = game.get("player")
	var scan_origin := scan_world.world_to_cell(scan_player.global_position)
	var scan_samples := [
		{"offset": Vector2i(2, -1), "tile": Tiles.Tile.GLASS},
		{"offset": Vector2i(3, -1), "tile": Tiles.Tile.FERRITE},
		{"offset": Vector2i(3, 0), "tile": Tiles.Tile.COPPER},
		{"offset": Vector2i(1, -2), "tile": Tiles.Tile.CRYSTAL},
		{"offset": Vector2i(-2, -1), "tile": Tiles.Tile.FIBER},
		{"offset": Vector2i(-1, 2), "tile": Tiles.Tile.ARCHIVE},
		{"offset": Vector2i(-2, 2), "tile": Tiles.Tile.FAULT},
		{"offset": Vector2i(4, 2), "tile": Tiles.Tile.WATER}
	]
	var glass_cell := Vector2i(-1, -1)
	for sample in scan_samples:
		var offset: Vector2i = sample["offset"]
		var cell := scan_origin + offset
		scan_world.set_tile(cell.x, cell.y, int(sample["tile"]))
		if int(sample["tile"]) == Tiles.Tile.GLASS:
			glass_cell = cell
	game.call("_scan")
	var scanned_sites: Array = game.get("discoveries")
	_check(scanned_sites.has("ashlands"), "first scan stores the Ashlands field record")
	_check(
		hud.message_label.text.contains("FIELD RECORD STORED"),
		"first scan confirms that a new record was indexed"
	)
	_check(
		(
			hud.message_label.text.contains("SIGNAL WRECKAGE")
			and hud.message_label.text.contains("GLASS 1 CELLS")
			and hud.message_label.text.contains("FERRITE ")
			and hud.message_label.text.contains("COPPER ")
			and hud.message_label.text.contains("CRYSTAL 1 CELLS")
		),
		"scanner readout identifies the exact material and nearby cell count"
	)
	_check(
		(
			scan_world.scan_highlights.has(str(scan_world.cell_index(glass_cell.x, glass_cell.y)))
			and scan_world.scan_highlights.has(
				str(scan_world.cell_index(scan_origin.x - 2, scan_origin.y - 1))
			)
		),
		"glass and fiber resource cells receive the visible scan pulse"
	)
	_check(
		hud.message_label.offset_top < -126.0,
		"dense multi-material scan results expand above the hotbar instead of clipping"
	)
	game.call("_scan")
	_check(
		not hud.message_label.text.contains("FIELD RECORD STORED"),
		"repeat scans do not claim a new discovery"
	)
	var touch_hotbar: Control = hud.root.get_node("TouchHotbar")
	_check(
		hud.message_label.offset_bottom <= touch_hotbar.offset_top,
		"field messages stay clear of the touch hotbar"
	)
	_check(
		hud.message_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"long scanner returns wrap instead of being clipped"
	)
	game.set("current_storage_kind", "planet")
	hud.show_storage({}, "PLANET CACHE")
	hud.refresh_current_panel()
	_check(hud._panel_kind == "storage", "storage refresh rebuilds the active local cache panel")
	hud.action_requested.emit("open_compendium")
	_check(
		hud._panel_kind == "compendium", "touch-accessible menu action opens the field compendium"
	)
	var ashlands_record_button: Button = null
	for row in hud.modal_rows.get_children():
		if row is Button and row.text.contains("SIMULATION RECORD — Ashlands"):
			ashlands_record_button = row as Button
	_check(
		ashlands_record_button != null, "the newly scanned world appears in the field compendium"
	)
	if ashlands_record_button != null:
		_check(
			ashlands_record_button.text.contains("gantry"),
			"the field record describes its world-specific environmental evidence"
		)
		_check(
			(
				ashlands_record_button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
				and ashlands_record_button.custom_minimum_size.y >= 80.0
			),
			"long field records wrap and reserve room for their evidence text"
		)
	hud.action_requested.emit("close")
	game.call("_on_hud_touch_pressed", "mine", 903)
	game.call("_on_hud_stick_changed", Vector2.RIGHT)
	var action_button: TouchActionButton = hud.action_buttons[0]
	action_button.active_pointers[73] = true
	hud.stick._pointer_id = 73
	hud.stick._axis = Vector2.RIGHT
	game.set("is_paused", true)
	game.call("_process", 0.016)
	_check(
		not bool(game.call("is_action_held", "mine")),
		"opening a paused interface clears held mining input"
	)
	_check(
		(game.get("player") as SilkboundPlayer).touch_axis == Vector2.ZERO,
		"pausing cannot leave virtual-stick movement latched"
	)
	_check(
		action_button.active_pointers.is_empty(),
		"paused input clears button-owned pointers as well as the action router"
	)
	_check(
		hud.stick._pointer_id == -999 and hud.stick._axis == Vector2.ZERO,
		"paused input also clears the actual virtual-stick ownership"
	)
	game.set("is_paused", false)
	var transitioning_captain: SilkboundPlayer = game.get("player")
	transitioning_captain.velocity = Vector2(165.0, 925.0)
	transitioning_captain._highest_fall_speed = 925.0
	transitioning_captain._jump_request = true
	transitioning_captain.set_touch_axis(Vector2.RIGHT)
	var repaired_ship: Dictionary = game.get("ship_state")
	repaired_ship["engine_repaired"] = true
	game.set("ship_state", repaired_ship)
	var glass_seed := Travel.planet_seed(int(game.get("base_seed")), "glassfall")
	var glass_geometry := Generator.generate(glass_seed, Generator.Biome.GLASSFALL)
	var blocked_column := WorldGrid.GLASSFALL_FAULT_X
	var blocked_y := int(glass_geometry["surface"][blocked_column]) + 4
	var blocked_position := Vector2(
		(float(blocked_column) + 0.5) * 32.0, (float(blocked_y) + 0.5) * 32.0
	)
	var saved_states: Dictionary = game.get("world_states")
	saved_states["glassfall"] = {
		"player_position": [blocked_position.x, blocked_position.y]
	}
	game.set("world_states", saved_states)
	game.call("_mount_planet", "glassfall")
	var field_world: WorldGrid = game.get("world")
	var field_player: SilkboundPlayer = game.get("player")
	_check(
		field_world.captain_space_clear(field_player.global_position)
		and field_player.global_position != blocked_position,
		"mounting saved terrain repairs a buried captain before physics resumes"
	)
	_check(
		bool(game.get("_spawn_adjusted")),
		"reentry recovery is surfaced as a visible navigation correction"
	)
	_check(
		field_player.velocity == Vector2.ZERO
		and field_player.touch_axis == Vector2.ZERO
		and is_zero_approx(field_player._highest_fall_speed)
		and not field_player._jump_request,
		"planet entry clears stale velocity, jump and movement from the previous world"
	)
	var survey_cell := Vector2i(
		WorldGrid.GLASSFALL_FAULT_X,
		field_world.surface_at(WorldGrid.GLASSFALL_FAULT_X) - 2
	)
	var left_of_ridge := Vector2i(
		WorldGrid.GLASSFALL_FAULT_X - 4, field_world.surface_at(WorldGrid.GLASSFALL_FAULT_X - 4) - 2
	)
	field_player.global_position = field_world.cell_to_world(left_of_ridge)
	_check(
		String(game.call("objective_text")).contains("4 E")
		and String(game.call("objective_text")).contains("SCAN BEFORE"),
		"the field objective shows direction, distance and time-sensitive pre-failure survey"
	)
	field_player.global_position = field_world.cell_to_world(survey_cell)
	game.call("_scan")
	_check(
		String(game.call("objective_text")).contains("PRE-FAILURE LOGGED"),
		"recording intact strata changes the live objective before the shear"
	)
	var field_records: Array = game.get("discoveries")
	_check(
		field_records.has("glassfall_before")
		and hud.message_label.text.contains("PRE-FAILURE STRATA RECORDED"),
		"scanning the intact ridge stores real pre-failure evidence"
	)
	var pressure: TerraformingSystem = game.get("terraformer")
	pressure.phase = 2
	game.call("terraform_notice", 2)
	_check(
		field_world.fault_warning_phase == 2,
		"the visible fault warning follows the actual geological phase"
	)
	var altered := field_world.apply_terraform(
		WorldGrid.GLASSFALL_FAULT_X, WorldGrid.GLASSFALL_FAULT_RADIUS
	)
	pressure.phase = 3
	pressure.transformed = true
	pressure.changed_cells = int(altered["changed"])
	field_world.set_fault_warning_phase(3)
	_check(
		String(game.call("objective_text")).contains("SCAN THE ALTERED FAULT"),
		"new terrain state requests a second independent field observation"
	)
	game.call("_scan")
	field_records = game.get("discoveries")
	_check(
		field_records.has("glassfall_after")
		and hud.message_label.text.contains("POST-FAILURE STRATA RECORDED"),
		"the same site scan now records the permanently altered ground"
	)
	_check(
		Items.DISCOVERIES.has("glassfall_before")
		and Items.DISCOVERIES.has("glassfall_after"),
		"both Glassfall states have separately readable compendium records"
	)
	_check(
		bool(game.call("save_game", "test_discovery_contract")),
		"changed geology and field evidence write to an isolated test slot"
	)
	var recorded_save := Save.load_slot("test_discovery_contract")
	_check(
		bool(recorded_save.get("ok", false))
		and recorded_save["data"]["discoveries"].has("glassfall_before")
		and recorded_save["data"]["discoveries"].has("glassfall_after")
		and not Dictionary(recorded_save["data"]["world_states"]["glassfall"]["edits"]).is_empty(),
		"survey records and persistent terrain edits survive a save round trip"
	)
	Save.delete_slot("test_discovery_contract")
	game.queue_free()
	await process_frame
