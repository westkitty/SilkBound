extends SceneTree

const Generator = preload("res://scripts/world/planet_generator.gd")
const Tiles = preload("res://scripts/world/tile_catalog.gd")
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
	game.call("_scan")
	var scanned_sites: Array = game.get("discoveries")
	_check(scanned_sites.has("ashlands"), "first scan stores the Ashlands field record")
	_check(
		hud.message_label.text.contains("FIELD RECORD STORED"),
		"first scan confirms that a new record was indexed"
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
	game.queue_free()
	await process_frame
