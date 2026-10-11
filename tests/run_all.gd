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
	await _test_safe_reentry_placement()
	await _test_scanner_resource_coverage()
	await _test_world_changes_and_terraforming()
	_test_versioned_save_round_trip()
	await _test_main_scene_startup_and_touch_signals()
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
	Save.delete_slot("test_contract")
	_check(
		not bool(Save.load_slot("../escape")["ok"]),
		"invalid slot names are rejected before filesystem access"
	)


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
			hud.message_label.text.contains("GLASS 1 CELLS")
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
