class_name SilkboundGame
extends Node2D

const PlayerScene = preload("res://scenes/player/player.tscn")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const PickupScene = preload("res://scenes/world/pickup.tscn")
const SurvivorScene = preload("res://scenes/npc/survivor.tscn")
const Tiles = preload("res://scripts/world/tile_catalog.gd")
const Items = preload("res://scripts/inventory/item_catalog.gd")
const Combat = preload("res://scripts/combat/combat_system.gd")
const TileAtlas = preload("res://assets/tiles/terrain_atlas.png")
const TILE_SIZE := 32
const ATTACK_RANGE := 78.0
const SAVE_SLOT := "slot_01"
const SOUND_PATHS := {
	"mine": "res://assets/audio/mine_impact.wav",
	"pickup": "res://assets/audio/pickup_chime.wav",
	"jump": "res://assets/audio/jump_thrust.wav",
	"craft": "res://assets/audio/craft_chime.wav",
	"warning": "res://assets/audio/warning_pulse.wav",
	"attack": "res://assets/audio/tool_swing.wav",
	"scan": "res://assets/audio/pickup_chime.wav",
	"ui": "res://assets/audio/craft_chime.wav"
}

var base_seed: int = 0
var current_planet_id := "ashlands"
var visited_planets: Array = ["ashlands"]
var world_states: Dictionary = {}
var inventory := Inventory.new()
var survival := SurvivalSystem.new()
var quest_system := QuestSystem.new()
var terraformer := TerraformingSystem.new()
var ship_state: Dictionary = {}
var settings: Dictionary = {}
var discoveries: Array = []
var hotbar_items: Array = [
	"wall", "floor", "door", "lamp", "crate", "workbench", "reinforced_panel", "salvaged_brick"
]
var selected_hotbar := 0
var is_paused := false
var run_ended := false
var build_mode := false
var current_storage_kind := "ship"
var test_mode := false

var world: WorldGrid
var player: SilkboundPlayer
var hud: GameHUD
var backdrop: ParallaxBackdrop
var ship_sprite: Sprite2D
var _ambience_player: AudioStreamPlayer
var _touch_router := TouchActionRouter.new()
var _rng := RandomNumberGenerator.new()
var _autosave_clock := 0.0
var _mine_repeat := 0.0
var _attack_repeat := 0.0
var _last_auto_save_millis := 0
var _last_mouse_world := Vector2.ZERO
var _mouse_aim_active := false
var _last_action_was_touch := false
var _scan_highlight_clock := 0.0
var _survivor_prompt_clock := 0.0
var _respawn_choice_open := false


func _ready() -> void:
	_rng.randomize()
	_ensure_input_map()
	_load_settings()
	if test_mode:
		_start_fresh_state()
	else:
		var saved := SaveSystem.load_slot(SAVE_SLOT)
		if bool(saved.get("ok", false)):
			_restore_state(saved["data"])
		else:
			_start_fresh_state()
	_mount_planet(current_planet_id)
	hud = GameHUD.new()
	hud.name = "TouchHUD"
	add_child(hud)
	hud.configure(self)
	hud.action_requested.connect(_on_hud_action)
	hud.touch_action_pressed.connect(_on_hud_touch_pressed)
	hud.touch_action_released.connect(_on_hud_touch_released)
	hud.touch_stick_changed.connect(_on_hud_stick_changed)
	_apply_audio_settings()
	if run_ended:
		_handle_final_death(true)
	else:
		(
			hud
			. show_message(
				"A damaged civilian vessel. No safe Starsilk handling. Keep the ship—and other people—alive.",
				7.0
			)
		)
	if not test_mode:
		save_game()


func _process(delta: float) -> void:
	if is_paused or run_ended or world == null or player == null:
		return
	_autosave_clock += delta
	if _autosave_clock >= 40.0:
		_autosave_clock = 0.0
		save_game()
	if _scan_highlight_clock > 0.0:
		_scan_highlight_clock -= delta
		if _scan_highlight_clock <= 0.0:
			world.scan_highlights.clear()
			for chunk in world.chunk_views.values():
				(chunk as CanvasItem).queue_redraw()
	if _survivor_prompt_clock > 0.0:
		_survivor_prompt_clock -= delta
		if _survivor_prompt_clock <= 0.0:
			hud.show_message("Nearby survivor: press USE or E to talk.", 2.5)
		_survivor_prompt_clock = 0.0 if _survivor_prompt_clock < 0.0 else _survivor_prompt_clock
	var sprinting := Input.is_action_pressed("sprint") or _touch_router.is_held("sprint")
	var underwater := world.is_underwater(player.global_position)
	var sheltered := world.is_sheltered(player.global_position)
	var thermal_stress := (
		world.is_thermal_zone(player.global_position)
		and not bool(ship_state.get("thermal_lining", false))
	)
	if survival.tick(
		delta,
		{
			"underwater": underwater,
			"sheltered": sheltered,
			"thermal_stress": thermal_stress,
			"sprinting": sprinting
		}
	):
		_handle_final_death(false)
		return
	terraformer.tick(delta, self)
	if _touch_router.is_held("mine") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mine_repeat -= delta
		if _mine_repeat <= 0.0:
			_mine_repeat = 0.19
			_perform_mine()
	else:
		_mine_repeat = 0.0
	if _touch_router.is_held("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_attack_repeat -= delta
		if _attack_repeat <= 0.0:
			_attack_repeat = 0.38
			_perform_attack()
	else:
		_attack_repeat = 0.0
	var nearest_survivor := _nearest_survivor(110.0)
	if nearest_survivor != null and _survivor_prompt_clock <= 0.0:
		_survivor_prompt_clock = 8.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_last_mouse_world = get_global_mouse_position()
		_mouse_aim_active = true
		_last_action_was_touch = false
	elif event is InputEventMouseButton and event.pressed:
		_last_mouse_world = get_global_mouse_position()
		_mouse_aim_active = true
		_last_action_was_touch = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			_perform_mine()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_perform_attack()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("interact"):
			_dispatch_action("interact")
		elif event.is_action_pressed("scan"):
			_dispatch_action("scan")
		elif event.is_action_pressed("build"):
			_dispatch_action("build")
		elif event.is_action_pressed("inventory"):
			_dispatch_action("inventory")
		elif event.is_action_pressed("craft"):
			_dispatch_action("craft")
		elif event.is_action_pressed("ship"):
			_dispatch_action("ship")
		elif event.is_action_pressed("quests"):
			_dispatch_action("quests")
		elif event.is_action_pressed("compendium"):
			_dispatch_action("compendium")
		elif event.is_action_pressed("pause"):
			_dispatch_action("pause")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if not run_ended and world != null:
			save_game()


func _draw() -> void:
	if not build_mode or world == null or player == null or run_ended:
		return
	var cell := _build_target_cell()
	if cell.x < 0:
		return
	var item_id := String(hotbar_items[selected_hotbar])
	var tile_id := int(Tiles.BUILD_ITEMS.get(item_id, Tiles.Tile.WALL))
	var valid := inventory.count(item_id) > 0 and world.get_tile(cell.x, cell.y) == Tiles.Tile.AIR
	var color := Color(0.28, 0.90, 0.82, 0.8) if valid else Color(0.95, 0.31, 0.38, 0.85)
	draw_rect(
		Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE),
		Color(color.r, color.g, color.b, 0.18),
		true
	)
	var atlas_region := Rect2((tile_id % 8) * 16, int(tile_id / 8) * 16, 16, 16)
	draw_texture_rect_region(
		TileAtlas,
		Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE),
		atlas_region,
		Color(color.r, color.g, color.b, 0.56)
	)
	draw_rect(
		Rect2(cell.x * TILE_SIZE + 1, cell.y * TILE_SIZE + 1, TILE_SIZE - 2, TILE_SIZE - 2),
		color,
		false,
		2.0
	)
	draw_line(
		Vector2(cell.x * TILE_SIZE + 5, cell.y * TILE_SIZE + TILE_SIZE - 5),
		Vector2(cell.x * TILE_SIZE + TILE_SIZE - 5, cell.y * TILE_SIZE + 5),
		color,
		1.0
	)


func _ensure_input_map() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"scan": [KEY_Q],
		"build": [KEY_B],
		"inventory": [KEY_I],
		"craft": [KEY_C],
		"ship": [KEY_H],
		"quests": [KEY_J],
		"compendium": [KEY_M],
		"pause": [KEY_ESCAPE]
	}
	for action in bindings.keys():
		if not InputMap.has_action(String(action)):
			InputMap.add_action(String(action))
		for keycode in bindings[action]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(keycode)
			InputMap.action_add_event(String(action), key_event)


func _start_fresh_state() -> void:
	base_seed = _rng.randi_range(100000, 99999999)
	current_planet_id = "ashlands"
	visited_planets = ["ashlands"]
	world_states.clear()
	inventory.setup(
		{
			"salvage_cutter": 1,
			"survey_scanner": 1,
			"scrap": 2,
			"ferrite": 1,
			"fiber": 1,
			"rations": 4,
			"medfoam": 1
		}
	)
	survival.setup()
	quest_system.setup()
	terraformer.setup()
	ship_state = {
		"integrity": 34,
		"engine_repaired": false,
		"coolant_installed": false,
		"thermal_lining": false,
		"cutter_upgraded": false,
		"cargo_frame": false,
		"scanner_lens": false,
		"iri_onboard": false,
		"storage": {}
	}
	discoveries = ["starsilk", "macros", "blood_ring", "tiger", "peripheral_log"]
	selected_hotbar = 0
	is_paused = false
	run_ended = false
	build_mode = false
	_touch_router.clear()


func _restore_state(data: Dictionary) -> void:
	base_seed = int(data.get("base_seed", 73920412))
	var saved_worlds: Variant = data.get("world_states", {})
	world_states = {}
	if saved_worlds is Dictionary:
		for raw_planet_id in saved_worlds.keys():
			var planet_id := String(raw_planet_id)
			var planet_state: Variant = saved_worlds[raw_planet_id]
			if TravelSystem.PLANETS.has(planet_id) and planet_state is Dictionary:
				world_states[planet_id] = _sanitize_planet_state(planet_state)
	var visited: Variant = data.get("visited_planets", ["ashlands"])
	visited_planets = []
	if visited is Array:
		for raw_planet_id in visited:
			var planet_id := String(raw_planet_id)
			if TravelSystem.PLANETS.has(planet_id) and not visited_planets.has(planet_id):
				visited_planets.append(planet_id)
	if not visited_planets.has("ashlands"):
		visited_planets.append("ashlands")
	var inventory_data: Variant = data.get("inventory", {})
	inventory.from_dict(inventory_data if inventory_data is Dictionary else {})
	var survival_data: Variant = data.get("survival", {})
	survival.setup(survival_data if survival_data is Dictionary else {})
	var quest_data: Variant = data.get("quests", {})
	quest_system.setup(quest_data if quest_data is Dictionary else {})
	ship_state = data.get("ship", {})
	if not ship_state is Dictionary:
		ship_state = {}
	ship_state["storage"] = _sanitize_storage(ship_state.get("storage", {}))
	for key in [
		"integrity",
		"engine_repaired",
		"coolant_installed",
		"thermal_lining",
		"cutter_upgraded",
		"cargo_frame",
		"scanner_lens",
		"iri_onboard"
	]:
		if not ship_state.has(key):
			ship_state[key] = false if key != "integrity" else 34
	ship_state["integrity"] = clampi(int(ship_state["integrity"]), 0, 100)
	if bool(ship_state.get("cargo_frame", false)):
		inventory.capacity = maxi(inventory.capacity, Inventory.DEFAULT_CAPACITY + 8)
	var requested_planet := String(data.get("current_planet", "ashlands"))
	current_planet_id = (
		requested_planet
		if (
			TravelSystem.PLANETS.has(requested_planet)
			and TravelSystem.is_unlocked(requested_planet, ship_state)
		)
		else "ashlands"
	)
	if not visited_planets.has(current_planet_id):
		visited_planets.append(current_planet_id)
	var raw_discoveries: Variant = data.get(
		"discoveries", ["starsilk", "macros", "blood_ring", "tiger", "peripheral_log"]
	)
	discoveries = []
	if raw_discoveries is Array:
		for raw_discovery in raw_discoveries:
			var discovery := String(raw_discovery)
			if Items.DISCOVERIES.has(discovery) and not discoveries.has(discovery):
				discoveries.append(discovery)
	var saved_hotbar: Variant = data.get("hotbar_items", hotbar_items)
	if saved_hotbar is Array:
		var valid_items: Array = []
		for raw_item_id in saved_hotbar:
			var item_id := String(raw_item_id)
			if Tiles.BUILD_ITEMS.has(item_id) and not valid_items.has(item_id):
				valid_items.append(item_id)
		if not valid_items.is_empty():
			hotbar_items = valid_items
	selected_hotbar = clampi(int(data.get("selected_hotbar", 0)), 0, hotbar_items.size() - 1)
	is_paused = false
	run_ended = bool(data.get("run_ended", false))
	build_mode = false
	_touch_router.clear()


func _sanitize_planet_state(raw_state: Dictionary) -> Dictionary:
	var state := raw_state.duplicate(true)
	for key in ["edits", "meta", "terraform"]:
		if not state.get(key, {}) is Dictionary:
			state[key] = {}
	state["storage"] = _sanitize_storage(state.get("storage", {}))
	if not state.get("pickups", []) is Array:
		state["pickups"] = []
	if not state.get("defeated_threats", []) is Array:
		state["defeated_threats"] = []
	if not state.get("player_position", []) is Array:
		state.erase("player_position")
	return state


func _sanitize_storage(raw_storage: Variant) -> Dictionary:
	var storage: Dictionary = {}
	if not raw_storage is Dictionary:
		return storage
	for raw_item_id in raw_storage.keys():
		var item_id := String(raw_item_id)
		var quantity := clampi(int(raw_storage[raw_item_id]), 0, 999999)
		if Items.ITEMS.has(item_id) and quantity > 0:
			storage[item_id] = quantity
	return storage


func _load_settings() -> void:
	settings = {
		"master_volume": 0.85,
		"music_volume": 0.42,
		"effects_volume": 0.82,
		"button_scale": 1.0,
		"left_handed": false,
		"reduced_shake": true,
		"reduced_flash": true
	}
	var save := SaveSystem.load_slot("settings")
	if bool(save.get("ok", false)):
		var loaded: Variant = save["data"].get("settings", {})
		if loaded is Dictionary:
			for key in settings.keys():
				if not loaded.has(key):
					continue
				match key:
					"master_volume", "music_volume", "effects_volume":
						settings[key] = clampf(float(loaded[key]), 0.0, 1.0)
					"button_scale":
						settings[key] = clampf(float(loaded[key]), 0.8, 1.4)
					"left_handed", "reduced_shake", "reduced_flash":
						settings[key] = bool(loaded[key])


func _mount_planet(planet_id: String) -> void:
	if world != null:
		_snapshot_current_world()
		if is_instance_valid(backdrop):
			remove_child(backdrop)
			backdrop.queue_free()
		if is_instance_valid(world):
			remove_child(world)
			world.queue_free()
		world = null
		if is_instance_valid(ship_sprite):
			ship_sprite.queue_free()
			ship_sprite = null
	current_planet_id = planet_id
	if not visited_planets.has(planet_id):
		visited_planets.append(planet_id)
	var definition: Dictionary = TravelSystem.PLANETS[planet_id]
	var state: Dictionary = world_states.get(planet_id, {})
	var saved_edits: Dictionary = state.get("edits", {})
	var saved_meta: Dictionary = state.get("meta", {})
	world = WorldGrid.new()
	world.name = "Planet_%s" % planet_id
	add_child(world)
	world.setup(
		planet_id,
		TravelSystem.planet_seed(base_seed, planet_id),
		int(definition["biome"]),
		saved_edits,
		saved_meta
	)
	backdrop = ParallaxBackdrop.new()
	backdrop.name = "PlanetAtmosphere"
	add_child(backdrop)
	backdrop.configure(int(definition["biome"]))
	var spawn_position := world.cell_to_world(world.spawn_cell)
	var saved_position: Variant = state.get("player_position", [])
	if saved_position is Array and saved_position.size() >= 2:
		var raw_x: Variant = saved_position[0]
		var raw_y: Variant = saved_position[1]
		if typeof(raw_x) in [TYPE_INT, TYPE_FLOAT] and typeof(raw_y) in [TYPE_INT, TYPE_FLOAT]:
			var saved_x := float(raw_x)
			var saved_y := float(raw_y)
			if is_finite(saved_x) and is_finite(saved_y):
				spawn_position = Vector2(
					clampf(saved_x, 0.0, world.world_width * TILE_SIZE),
					clampf(saved_y, 0.0, world.world_height * TILE_SIZE)
				)
	if player == null or not is_instance_valid(player):
		player = PlayerScene.instantiate() as SilkboundPlayer
		player.name = "FieldCaptain"
		add_child(player)
		player.configure(self, world, spawn_position)
		player.landed_hard.connect(_on_player_landed_hard)
	else:
		player.alive = true
		player.configure(self, world, spawn_position)
	if run_ended:
		player.alive = false
	_add_ship_visual()
	_terraformer_for_planet(state)
	_restore_saved_pickups(state)
	_spawn_npcs_and_threats(state)
	if planet_id == "glassfall" and quest_system.status("fault_survey") == "available":
		(
			quest_system
			. activate(
				"fault_survey",
				"The local scanner flagged a shifting fault. Record the transformed route after pressure peaks."
			)
		)
	_start_ambience()
	queue_redraw()


func _terraformer_for_planet(state: Dictionary) -> void:
	terraformer.setup(state.get("terraform", {}))


func _add_ship_visual() -> void:
	ship_sprite = Sprite2D.new()
	ship_sprite.name = "LandingShip"
	ship_sprite.texture = load("res://assets/ship/salvage_vessel.png")
	ship_sprite.scale = Vector2(1.2, 1.2)
	ship_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ship_sprite.z_index = 2
	ship_sprite.position = Vector2(5.2 * TILE_SIZE, world.surface_at(5) * TILE_SIZE - 78.0)
	world.add_child(ship_sprite)


func _spawn_npcs_and_threats(state: Dictionary) -> void:
	var defeated: Array = state.get("defeated_threats", [])
	if current_planet_id == "ashlands" and not bool(ship_state.get("iri_onboard", false)):
		var iri := SurvivorScene.instantiate() as SurvivorNPC
		world.add_child(iri)
		iri.configure(self, "iri", Vector2(37 * TILE_SIZE, world.surface_at(37) * TILE_SIZE - 16.0))
	if current_planet_id == "drowned" and not quest_system.is_complete("archive_delivery"):
		var vale := SurvivorScene.instantiate() as SurvivorNPC
		world.add_child(vale)
		vale.configure(
			self, "vale", Vector2(42 * TILE_SIZE, world.surface_at(42) * TILE_SIZE - 16.0)
		)
	var threat_data: Array[Dictionary] = []
	match current_planet_id:
		"ashlands":
			threat_data = [{"id": "ash_grazer", "kind": "scavenger", "x": 31, "above": 0}]
		"glassfall":
			threat_data = [
				{"id": "glass_scavenger", "kind": "scavenger", "x": 30, "above": 0},
				{"id": "admin_sentinel", "kind": "admin_drone", "x": 52, "above": 3}
			]
		"drowned":
			threat_data = [
				{"id": "brine_lurker", "kind": "brine_lurker", "x": 29, "above": 0},
				{"id": "archive_drone", "kind": "admin_drone", "x": 58, "above": 4}
			]
	for threat in threat_data:
		if defeated.has(threat["id"]):
			continue
		var enemy := EnemyScene.instantiate() as SilkboundEnemy
		world.add_child(enemy)
		var x := int(threat["x"])
		var spawn := Vector2(
			x * TILE_SIZE, (world.surface_at(x) - int(threat["above"])) * TILE_SIZE - 16.0
		)
		enemy.configure(self, String(threat["kind"]), spawn, String(threat["id"]))


func _restore_saved_pickups(state: Dictionary) -> void:
	var pickups: Array = state.get("pickups", [])
	for entry in pickups:
		if not entry is Dictionary:
			continue
		var raw_position: Variant = entry.get("position", [])
		if not raw_position is Array or raw_position.size() < 2:
			continue
		var position := Vector2(
			clampf(float(raw_position[0]), 0.0, world.world_width * TILE_SIZE),
			clampf(float(raw_position[1]), 0.0, world.world_height * TILE_SIZE)
		)
		var item_id := String(entry.get("item", "scrap"))
		var amount := clampi(int(entry.get("amount", 1)), 1, 999)
		spawn_pickup(item_id, amount, position)


func _snapshot_current_world() -> void:
	if world == null:
		return
	var state: Dictionary = world_states.get(current_planet_id, {})
	state["seed"] = world.world_seed
	state["edits"] = world.modifications.duplicate(true)
	state["meta"] = world.serialize_meta()
	state["visited"] = true
	state["storage"] = Dictionary(state.get("storage", {})).duplicate(true)
	if player != null and is_instance_valid(player):
		state["player_position"] = [player.global_position.x, player.global_position.y]
	var loose_items: Array[Dictionary] = []
	for pickup in get_tree().get_nodes_in_group("world_pickups"):
		if is_instance_valid(pickup) and world.is_ancestor_of(pickup):
			loose_items.append(
				{
					"item": String(pickup.get("item_id")),
					"amount": int(pickup.get("amount")),
					"position": [pickup.global_position.x, pickup.global_position.y]
				}
			)
	state["pickups"] = loose_items
	var defeated: Array = state.get("defeated_threats", [])
	state["defeated_threats"] = defeated
	if current_planet_id == "glassfall":
		state["terraform"] = terraformer.to_dict()
	world_states[current_planet_id] = state


func save_game() -> bool:
	if run_ended and player == null:
		return false
	_snapshot_current_world()
	var data := {
		"base_seed": base_seed,
		"current_planet": current_planet_id,
		"visited_planets": visited_planets.duplicate(true),
		"world_states": world_states.duplicate(true),
		"inventory": inventory.to_dict(),
		"survival": survival.to_dict(),
		"ship": ship_state.duplicate(true),
		"quests": quest_system.to_dict(),
		"discoveries": discoveries.duplicate(true),
		"hotbar_items": hotbar_items.duplicate(true),
		"selected_hotbar": selected_hotbar,
		"settings": settings.duplicate(true),
		"run_ended": run_ended
	}
	var ok := SaveSystem.save_slot(data, SAVE_SLOT)
	if ok:
		_last_auto_save_millis = Time.get_ticks_msec()
	return ok


func _save_settings() -> void:
	SaveSystem.save_slot({"settings": settings.duplicate(true)}, "settings")
	_apply_audio_settings()
	if hud != null:
		hud.apply_control_settings()


func objective_text() -> String:
	if run_ended:
		return "RUN CLOSED  /  A LIFE CANNOT BE RESTORED FROM ITS DATA."
	if not bool(ship_state.get("engine_repaired", false)):
		return "Recover 6 scrap + 4 ferrite. Repair the drive at your landing ship."
	if current_planet_id == "glassfall" and not terraformer.transformed:
		return (
			"Glassfall pressure: %s. Scan the fault when the terrain settles."
			% terraformer.phase_name()
		)
	if (
		current_planet_id == "glassfall"
		and terraformer.transformed
		and not quest_system.is_complete("fault_survey")
	):
		return "Scan the shear-glass fault; build a route around the changed ground."
	if current_planet_id == "ashlands" and not bool(ship_state.get("iri_onboard", false)):
		return "Iri is near the old shelter. Two field rations buy a safer ride home."
	if (
		bool(ship_state.get("engine_repaired", false))
		and not bool(ship_state.get("coolant_installed", false))
	):
		return "Glassfall is open. Recover crystal and glass; fabricate a coolant loop."
	if current_planet_id == "drowned" and not quest_system.is_complete("archive_delivery"):
		return "Find Vale and decide whether the archive salvage is worth carrying."
	return "Build a sheltered route, log the system, and keep the ship serviceable."


func planet_display_name() -> String:
	if TravelSystem.PLANETS.has(current_planet_id):
		return String(TravelSystem.PLANETS[current_planet_id]["name"])
	return "Unsurveyed"


func get_energy() -> float:
	return survival.energy


func spend_energy(amount: float) -> void:
	survival.energy = maxf(0.0, survival.energy - maxf(0.0, amount))


func is_action_held(action: String) -> bool:
	return _touch_router.is_held(action)


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if run_ended or amount <= 0.0:
		return
	if survival.take_damage(amount):
		_handle_final_death(false)
		return
	if player != null and is_instance_valid(player):
		if not bool(settings.get("reduced_shake", true)) and player.camera != null:
			var impact_direction := signf(player.global_position.x - source_position.x)
			if is_zero_approx(impact_direction):
				impact_direction = 1.0
			player.camera.offset = Vector2(
				impact_direction * 2.5 + _rng.randf_range(-3.0, 3.0),
				-1.0 + _rng.randf_range(-2.0, 2.0)
			)
			var tween := create_tween()
			tween.tween_property(player.camera, "offset", Vector2.ZERO, 0.22)
		if not bool(settings.get("reduced_flash", true)):
			player.modulate = Color(1.0, 0.66, 0.62, 1.0)
			var flash := create_tween()
			flash.tween_property(player, "modulate", Color.WHITE, 0.16)
	if hud != null:
		hud.show_message("Suit impact · %.0f%% integrity" % survival.health, 1.5)


func _handle_final_death(loading_ended_run: bool) -> void:
	if run_ended and _respawn_choice_open:
		return
	run_ended = true
	is_paused = true
	if player != null and is_instance_valid(player):
		player.die()
	if not loading_ended_run:
		save_game()
	if hud != null:
		_respawn_choice_open = true
		var options: Array[Dictionary] = [
			{"label": "Begin a new expedition (this captain is gone)", "action": "new_expedition"}
		]
		(
			hud
			. show_dialogue(
				"DEATH IS FINAL",
				"The suit record ends here. Stored data is not a surviving person. No recovery, clone or conscious remnant is available. A new expedition means a new life and a new seed.",
				options
			)
		)


func _on_player_landed_hard(_distance: float) -> void:
	if hud != null:
		hud.show_message("Hard landing · check suit integrity.", 1.8)


func _dispatch_action(action: String) -> void:
	if run_ended:
		return
	if is_paused and action != "pause":
		return
	match action:
		"jump":
			player.request_jump()
		"mine":
			_perform_mine()
		"attack":
			_perform_attack()
		"interact":
			_interact()
		"scan":
			_scan()
		"build":
			build_mode = not build_mode
			if build_mode:
				hud.show_message(
					"Build mode · select a stocked hotbar slot; MINE or click to place.", 3.0
				)
			else:
				hud.show_message("Build mode off.", 1.5)
			queue_redraw()
		"inventory":
			is_paused = true
			hud.show_inventory()
		"craft":
			is_paused = true
			hud.show_crafting()
		"ship":
			if _near_ship(250.0):
				is_paused = true
				hud.show_ship()
			else:
				hud.show_message("The ship console is beyond interaction range.", 2.0)
		"quests":
			is_paused = true
			hud.show_quests()
		"compendium":
			is_paused = true
			hud.show_compendium()
		"pause":
			_toggle_pause()


func _on_hud_action(action: String) -> void:
	if action == "close":
		if is_paused and not run_ended:
			is_paused = false
		return
	if action.begins_with("craft:"):
		var recipe_id := action.trim_prefix("craft:")
		var result := Crafting.craft(recipe_id, inventory)
		if bool(result["ok"]):
			play_sound("craft")
			hud.show_message("Fabricated %s." % Items.RECIPES[recipe_id]["name"], 2.2)
		else:
			hud.show_message(String(result["reason"]), 2.2)
		hud.refresh()
		hud.refresh_current_panel()
		return
	if action.begins_with("travel:"):
		_travel_to(action.trim_prefix("travel:"))
		return
	if action.begins_with("hotbar:"):
		selected_hotbar = clampi(int(action.trim_prefix("hotbar:")), 0, hotbar_items.size() - 1)
		if build_mode:
			hud.show_message(
				"Build selection · %s." % Items.item_name(String(hotbar_items[selected_hotbar])),
				1.5
			)
		hud.refresh()
		return
	if action.begins_with("use:"):
		_use_consumable(action.trim_prefix("use:"))
		hud.refresh_current_panel()
		return
	if action.begins_with("npc:"):
		_handle_npc_choice(action.trim_prefix("npc:"))
		return
	if action.begins_with("deposit:"):
		_transfer_storage(action.trim_prefix("deposit:"), true)
		return
	if action.begins_with("withdraw:"):
		_transfer_storage(action.trim_prefix("withdraw:"), false)
		return
	if action.begins_with("volume:"):
		var channel := action.trim_prefix("volume:")
		_adjust_volume(channel, 0.08)
		hud.show_settings()
		return
	if action.begins_with("volume_down:"):
		_adjust_volume(action.trim_prefix("volume_down:"), -0.08)
		hud.show_settings()
		return
	if action == "size:up":
		settings["button_scale"] = clampf(
			float(settings.get("button_scale", 1.0)) + 0.1, 0.78, 1.38
		)
		_save_settings()
		hud.show_settings()
		return
	if action == "size:down":
		settings["button_scale"] = clampf(
			float(settings.get("button_scale", 1.0)) - 0.1, 0.78, 1.38
		)
		_save_settings()
		hud.show_settings()
		return
	if action.begins_with("toggle:"):
		var setting_key := action.trim_prefix("toggle:")
		var settings_key: String = String(
			(
				{
					"left_handed": "left_handed",
					"reduced_shake": "reduced_shake",
					"reduced_flash": "reduced_flash"
				}
				. get(setting_key, setting_key)
			)
		)
		settings[settings_key] = not bool(settings.get(settings_key, false))
		_save_settings()
		hud.show_settings()
		return
	match action:
		"repair_engine":
			_repair_engine()
		"install_coolant":
			_install_coolant()
		"use_repair_kit":
			_use_repair_kit()
		"install_cutter":
			_install_upgrade(
				"field_coil",
				"cutter_upgraded",
				"The copper-crystal coil improves cutter and melee output."
			)
		"install_lining":
			_install_upgrade(
				"thermal_lining",
				"thermal_lining",
				"Thermal lining slows glassfall exposure accumulation."
			)
		"install_cargo":
			_install_cargo_frame()
		"install_scanner":
			_install_upgrade(
				"scanner_lens", "scanner_lens", "Scanner range and geological returns are improved."
			)
		"open_travel":
			hud.show_travel()
		"storage":
			_open_storage("ship")
		"resume":
			is_paused = false
			hud.hide_modal()
		"open_settings":
			hud.show_settings()
		"open_quests":
			hud.show_quests()
		"open_compendium":
			hud.show_compendium()
		"new_expedition":
			_begin_new_expedition()
		"close":
			if is_paused and not run_ended:
				is_paused = false


func _on_hud_touch_pressed(action: String, pointer_id: int) -> void:
	_last_action_was_touch = true
	_mouse_aim_active = false
	var newly_active := _touch_router.press(action, pointer_id)
	if newly_active:
		_dispatch_action(action)


func _on_hud_touch_released(action: String, pointer_id: int) -> void:
	_touch_router.release(action, pointer_id)


func _on_hud_stick_changed(axis: Vector2) -> void:
	_last_action_was_touch = true
	_mouse_aim_active = false
	if player != null:
		player.set_touch_axis(axis)


func _toggle_pause() -> void:
	if is_paused:
		is_paused = false
		hud.hide_modal()
	else:
		is_paused = true
		var options: Array[Dictionary] = [
			{"label": "Resume field operations", "action": "resume"},
			{"label": "Open the field log", "action": "open_quests"},
			{"label": "Open the field compendium", "action": "open_compendium"},
			{"label": "Accessibility and controls", "action": "open_settings"}
		]
		(
			hud
			. show_dialogue(
				"FIELD PAUSED",
				"World simulation is suspended while this panel is open. Autosave is local to this device.",
				options
			)
		)


func _perform_mine() -> void:
	if is_paused or run_ended or player == null or world == null:
		return
	player.animate_action("mine")
	if build_mode:
		_place_selected_building()
		return
	var cell := _mining_target_cell()
	if cell.x < 0:
		return
	var distance := player.global_position.distance_to(world.cell_to_world(cell))
	if distance > 188.0:
		hud.show_message("Out of cutter reach.", 1.0)
		return
	var cutter_power := 43.0 if bool(ship_state.get("cutter_upgraded", false)) else 30.0
	var result := world.mine_cell(cell.x, cell.y, cutter_power)
	if not bool(result.get("ok", false)):
		return
	if bool(result.get("broken", false)):
		play_sound("mine")
		var drop: Dictionary = result.get("drop", {})
		if not drop.is_empty():
			spawn_pickup(
				String(drop.get("item", "scrap")),
				int(drop.get("amount", 1)),
				world.cell_to_world(cell)
			)
	else:
		play_sound("mine")
		if float(result.get("progress", 0.0)) > 0.7:
			hud.show_message(
				(
					"Cutting %s · %d%%"
					% [
						Tiles.tile_name(int(result["tile"])),
						roundi(float(result["progress"]) * 100.0)
					]
				),
				0.8
			)
	queue_redraw()


func _perform_attack() -> void:
	if is_paused or run_ended or player == null:
		return
	player.animate_action("attack")
	play_sound("attack")
	var damage := 34.0 if bool(ship_state.get("cutter_upgraded", false)) else 22.0
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("hostile_threats"):
		if not is_instance_valid(enemy) or not world.is_ancestor_of(enemy):
			continue
		if Combat.can_hit_melee(
			player.global_position, enemy.global_position, player.facing, ATTACK_RANGE
		):
			enemy.call("take_damage", damage, player.global_position)
			hit_count += 1
	if hit_count == 0 and hud != null:
		hud.show_message("Cutter sweep · no contact.", 0.7)


func _mining_target_cell() -> Vector2i:
	if _mouse_aim_active and not _last_action_was_touch:
		var mouse_cell := world.world_to_cell(_last_mouse_world)
		if player.global_position.distance_to(world.cell_to_world(mouse_cell)) <= 188.0:
			return mouse_cell
	var base := world.world_to_cell(player.global_position)
	var best := Vector2i(-1, -1)
	var best_score := INF
	for x_offset in range(1, 4):
		for y_offset in range(-1, 4):
			var cell := Vector2i(base.x + player.facing * x_offset, base.y + y_offset)
			var tile_id := world.get_tile(cell.x, cell.y)
			if not Tiles.is_solid(tile_id):
				continue
			var score := player.global_position.distance_to(world.cell_to_world(cell))
			if (
				tile_id
				in [
					Tiles.Tile.SCRAP,
					Tiles.Tile.FERRITE,
					Tiles.Tile.COPPER,
					Tiles.Tile.CRYSTAL,
					Tiles.Tile.ARCHIVE,
					Tiles.Tile.FIBER
				]
			):
				score -= 70.0
			if score < best_score:
				best = cell
				best_score = score
	return best


func _build_target_cell() -> Vector2i:
	if _mouse_aim_active and not _last_action_was_touch:
		var target := world.world_to_cell(_last_mouse_world)
		if player.global_position.distance_to(world.cell_to_world(target)) <= 188.0:
			return target
	var base := world.world_to_cell(player.global_position)
	return Vector2i(base.x + player.facing * 2, base.y + 1)


func _place_selected_building() -> void:
	if selected_hotbar < 0 or selected_hotbar >= hotbar_items.size():
		return
	var item_id := String(hotbar_items[selected_hotbar])
	var tile_id := int(Tiles.BUILD_ITEMS.get(item_id, -1))
	if tile_id < 0:
		hud.show_message("Select a buildable hotbar item.", 1.5)
		return
	if inventory.count(item_id) < 1:
		hud.show_message(
			"No %s carried. Craft or recover one first." % Items.item_name(item_id), 2.0
		)
		return
	var cell := _build_target_cell()
	var result := world.place_building(cell.x, cell.y, tile_id, player.global_position)
	if not bool(result.get("ok", false)):
		hud.show_message(String(result.get("reason", "Placement failed.")), 1.2)
		return
	inventory.spend({item_id: 1})
	play_sound("craft")
	hud.show_message("Placed %s." % Items.item_name(item_id), 1.2)
	hud.refresh()
	queue_redraw()


func _interact() -> void:
	if is_paused or run_ended or player == null:
		return
	var survivor := _nearest_survivor(112.0)
	if survivor != null:
		is_paused = true
		survivor.call("interact")
		return
	if _near_ship(250.0):
		is_paused = true
		hud.show_ship()
		return
	if world.has_tile_near(player.global_position, Tiles.Tile.CRATE, 3):
		is_paused = true
		_open_storage("planet")
		return
	if world.has_tile_near(player.global_position, Tiles.Tile.BENCH, 3):
		is_paused = true
		hud.show_crafting()
		return
	if (
		world.has_tile_near(player.global_position, Tiles.Tile.LAMP, 3)
		or world.is_sheltered(player.global_position)
	):
		hud.show_message("Shelter holds. Air and suit exposure are recovering.", 2.0)
		return
	hud.show_message("No nearby console, survivor or storage cache.", 1.5)


func _nearest_survivor(radius: float) -> Node2D:
	if player == null:
		return null
	var nearest: Node2D
	var nearest_distance := radius
	for survivor in get_tree().get_nodes_in_group("silkbound_survivors"):
		if not is_instance_valid(survivor) or not world.is_ancestor_of(survivor):
			continue
		var distance := player.global_position.distance_to(survivor.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = survivor
	return nearest


func _near_ship(radius: float) -> bool:
	return (
		player != null
		and ship_sprite != null
		and player.global_position.distance_to(ship_sprite.global_position) <= radius
	)


func _scan() -> void:
	if world == null or player == null or is_paused:
		return
	var range_cells := 12 if bool(ship_state.get("scanner_lens", false)) else 9
	var result := world.scan_area(player.global_position, range_cells)
	_scan_highlight_clock = 8.0
	play_sound("scan")
	var first_record := not discoveries.has(current_planet_id)
	if first_record:
		discoveries.append(current_planet_id)
	var summary_parts: Array[String] = []
	for key in [
		"ferrite", "copper", "crystal", "glass", "wreckage", "archive", "fiber", "water", "fault"
	]:
		if int(result[key]) > 0:
			summary_parts.append("%s %d CELLS" % [String(key).to_upper(), int(result[key])])
	if current_planet_id == "glassfall" and terraformer.phase < 3:
		summary_parts.append("PRESSURE %s" % terraformer.phase_name())
	if current_planet_id == "glassfall" and terraformer.transformed and int(result["fault"]) > 0:
		quest_system.activate(
			"fault_survey",
			(
				"Fault registered: %d changed cells. A lamp or roof gives shelter from local heat."
				% terraformer.changed_cells
			)
		)
		if not quest_system.is_complete("fault_survey"):
			(
				quest_system
				. complete(
					"fault_survey",
					"The transformed route is logged. Avoid the shallow shear or bridge it; the alteration remains."
				)
			)
			_add_item_or_drop("crystal", 2, player.global_position)
			summary_parts.append("FAULT ROUTE LOGGED")
	if summary_parts.is_empty():
		summary_parts.append("NO LOCAL RESOURCE RETURNS")
	if first_record:
		summary_parts.append("FIELD RECORD STORED")
	hud.show_message("SCAN  /  " + "   ·   ".join(PackedStringArray(summary_parts)), 3.8)
	hud.refresh()


func _use_consumable(item_id: String) -> void:
	if not inventory.spend({item_id: 1}):
		hud.show_message("No %s carried." % Items.item_name(item_id), 1.5)
		return
	match item_id:
		"rations":
			survival.restore(16.0, 34.0, 0.0)
			play_sound("craft")
			hud.show_message("Field ration used · energy restored.", 1.6)
		"medfoam":
			survival.restore(38.0, 8.0, 0.0)
			play_sound("craft")
			hud.show_message("Medfoam sealed · suit integrity restored.", 1.6)
		_:
			inventory.add_item(item_id, 1)
			hud.show_message("That item needs a ship console or a build surface.", 1.8)
	hud.refresh()


func _travel_to(destination: String) -> void:
	if not TravelSystem.PLANETS.has(destination):
		hud.show_message("Route not surveyed.", 1.8)
		return
	var state := {
		"current_planet": current_planet_id, "visited_planets": visited_planets.duplicate(true)
	}
	var result := TravelSystem.travel(state, destination, ship_state)
	if not bool(result.get("ok", false)):
		hud.show_message(String(result.get("reason", "Travel denied.")), 2.0)
		return
	if destination == current_planet_id:
		hud.show_message("Already landed on this surveyed world.", 1.5)
		hud.show_travel()
		return
	if not visited_planets.has(destination):
		visited_planets.append(destination)
	is_paused = false
	hud.hide_modal()
	hud.show_message("Translation complete · local gravity acquired.", 2.0)
	_mount_planet(destination)
	save_game()
	hud.refresh()


func _repair_engine() -> void:
	if bool(ship_state.get("engine_repaired", false)):
		hud.show_message("The travel drive is serviceable.", 1.6)
		return
	var cost := {"scrap": 6, "ferrite": 4}
	if not inventory.spend(cost):
		hud.show_message("Engine patch needs 6 scrap and 4 ferrite.", 2.0)
		return
	ship_state["engine_repaired"] = true
	ship_state["integrity"] = mini(100, int(ship_state.get("integrity", 34)) + 31)
	(
		quest_system
		. complete(
			"ship_patch",
			"The drive is patched with ordinary salvage. Glassfall is now within the repaired route envelope."
		)
	)
	play_sound("craft")
	hud.show_message("Drive patched · Glassfall survey route unlocked.", 3.0)
	save_game()
	hud.show_ship()


func _install_coolant() -> void:
	if bool(ship_state.get("coolant_installed", false)):
		hud.show_message("The coolant loop is already fitted.", 1.5)
		return
	if not inventory.spend({"coolant_loop": 1}):
		hud.show_message("Fabricate a coolant loop from glass, crystal and ferrite first.", 2.0)
		return
	ship_state["coolant_installed"] = true
	ship_state["integrity"] = mini(100, int(ship_state.get("integrity", 34)) + 8)
	play_sound("craft")
	hud.show_message("Coolant loop fitted · Drowned Remnant route unlocked.", 2.6)
	save_game()
	hud.show_ship()


func _use_repair_kit() -> void:
	if int(ship_state.get("integrity", 34)) >= 100 or not inventory.spend({"repair_kit": 1}):
		hud.show_message("No repair kit, or the frame is already at full integrity.", 2.0)
		return
	ship_state["integrity"] = mini(100, int(ship_state.get("integrity", 34)) + 18)
	play_sound("craft")
	hud.show_message("Frame patched · integrity %d%%." % int(ship_state["integrity"]), 2.0)
	save_game()
	hud.show_ship()


func _install_upgrade(item_id: String, state_key: String, message: String) -> void:
	if bool(ship_state.get(state_key, false)):
		hud.show_message("That upgrade is already installed.", 1.5)
		return
	if not inventory.spend({item_id: 1}):
		hud.show_message("Fabricate %s before installing it." % Items.item_name(item_id), 2.0)
		return
	ship_state[state_key] = true
	if state_key == "thermal_lining":
		survival.exposure = minf(survival.exposure, 35.0)
	play_sound("craft")
	hud.show_message(message, 2.4)
	save_game()
	hud.show_ship()


func _install_cargo_frame() -> void:
	if bool(ship_state.get("cargo_frame", false)):
		hud.show_message("Cargo frame already installed.", 1.5)
		return
	if not inventory.spend({"cargo_frame": 1}):
		hud.show_message("Fabricate a cargo frame first.", 1.5)
		return
	ship_state["cargo_frame"] = true
	inventory.capacity += 8
	play_sound("craft")
	hud.show_message("Cargo rack fitted · inventory capacity increased by eight stacks.", 2.5)
	save_game()
	hud.show_ship()


func _open_storage(kind: String) -> void:
	current_storage_kind = kind
	hud.show_storage(
		_storage_for_current_mode(), "SHIP CARGO" if kind == "ship" else "PLANET CACHE"
	)


func _storage_for_current_mode() -> Dictionary:
	if current_storage_kind == "ship":
		if not ship_state.has("storage") or not ship_state["storage"] is Dictionary:
			ship_state["storage"] = {}
		return ship_state["storage"]
	var state: Dictionary = world_states.get(current_planet_id, {})
	if not state.has("storage") or not state["storage"] is Dictionary:
		state["storage"] = {}
		world_states[current_planet_id] = state
	return state["storage"]


func _transfer_storage(item_id: String, deposit: bool) -> void:
	var storage := _storage_for_current_mode()
	if deposit:
		if inventory.spend({item_id: 1}):
			storage[item_id] = int(storage.get(item_id, 0)) + 1
		else:
			hud.show_message("Nothing to deposit.", 1.3)
	else:
		if int(storage.get(item_id, 0)) < 1:
			hud.show_message("That crate has none of the selected item.", 1.3)
		else:
			var remainder := inventory.add_item(item_id, 1)
			if remainder == 0:
				storage[item_id] = int(storage[item_id]) - 1
				if int(storage[item_id]) <= 0:
					storage.erase(item_id)
			else:
				hud.show_message("Inventory is full.", 1.3)
	play_sound("pickup")
	save_game()
	_open_storage(current_storage_kind)


func interact_npc(survivor_id: String) -> void:
	if survivor_id == "iri":
		if quest_system.is_complete("iri_supplies") or bool(ship_state.get("iri_onboard", false)):
			var complete_options: Array[Dictionary] = [
				{"label": "Review the practical cost of the rescue", "action": "close"}
			]
			(
				hud
				. show_dialogue(
					"IRI / ASHLANDS",
					"Iri made it aboard. Two field rations paid for the trip; she transferred her remaining medfoam kit to the captain. The choice changed who gets the next seat, not the war.",
					complete_options
				)
			)
			return
		if quest_system.status("iri_supplies") == "available":
			quest_system.activate(
				"iri_supplies",
				"Iri asked for two field rations before she risks leaving the shelter."
			)
		var options: Array[Dictionary] = []
		if inventory.count("rations") >= 2:
			options.append(
				{"label": "Give Iri 2 rations · bring her aboard", "action": "npc:iri_rescue"}
			)
		else:
			options.append({"label": "I will return with two field rations", "action": "close"})
		(
			hud
			. show_dialogue(
				"IRI / ABANDONED SHELTER",
				"The air filter is failing. I can travel, but I will not leave without enough food for the trip. This is a material requirement, not a loyalty test.",
				options
			)
		)
	elif survivor_id == "vale":
		if quest_system.is_complete("archive_delivery"):
			hud.show_dialogue(
				"VALE / ARCHIVE DECK",
				"The recovered plates are bagged and inert. No preserved voice lives in them."
			)
			return
		if quest_system.status("archive_delivery") == "available":
			quest_system.activate(
				"archive_delivery",
				"Vale wants the three archive shards for a physical repair record."
			)
		var options: Array[Dictionary] = []
		if inventory.count("archive_shard") >= 3:
			options.append({"label": "Hand over 3 archive shards", "action": "npc:vale_archive"})
		else:
			options.append({"label": "Return when I have three shards", "action": "close"})
		(
			hud
			. show_dialogue(
				"VALE / FLOODED ARCHIVE",
				"These plates are damaged Administration equipment. There is no mind in the fragments. Three intact pieces can document the route and be traded for working copper.",
				options
			)
		)


func _handle_npc_choice(choice: String) -> void:
	if choice == "iri_rescue":
		if not inventory.spend({"rations": 2}):
			hud.show_message("Two field rations are still required.", 1.5)
			return
		ship_state["iri_onboard"] = true
		(
			quest_system
			. complete(
				"iri_supplies",
				"Two field rations covered the trip. Iri is aboard, and her remaining medfoam kit was transferred to the captain."
			)
		)
		for survivor in get_tree().get_nodes_in_group("silkbound_survivors"):
			if is_instance_valid(survivor) and survivor.get("survivor_id") == "iri":
				survivor.queue_free()
		_add_item_or_drop("medfoam", 1, player.global_position)
		hud.show_message("Iri is aboard · her medfoam kit is transferred to the captain.", 2.8)
	elif choice == "vale_archive":
		if not inventory.spend({"archive_shard": 3}):
			hud.show_message("Three archive shards are required.", 1.5)
			return
		quest_system.complete(
			"archive_delivery", "Three inert data plates were traded for copper and a repair map."
		)
		_add_item_or_drop("copper", 3, player.global_position)
		_add_item_or_drop("ferrite", 2, player.global_position)
		hud.show_message("Vale logs the route · copper and ferrite recovered.", 2.5)
	save_game()
	hud.show_quests()


func enemy_defeated(enemy: Node, loot: Dictionary) -> void:
	if world == null:
		return
	var state: Dictionary = world_states.get(current_planet_id, {})
	var defeated: Array = state.get("defeated_threats", [])
	var identity := String(enemy.get("spawn_id"))
	if not identity.is_empty() and not defeated.has(identity):
		defeated.append(identity)
	state["defeated_threats"] = defeated
	world_states[current_planet_id] = state
	for item_id in loot.keys():
		spawn_pickup(String(item_id), int(loot[item_id]), enemy.global_position)
	hud.show_message("Threat neutralized · salvage remains at the site.", 1.8)


func _add_item_or_drop(item_id: String, amount: int, at_position: Vector2) -> void:
	var remainder := inventory.add_item(item_id, amount)
	if remainder > 0:
		spawn_pickup(item_id, remainder, at_position)


func spawn_pickup(item_id: String, amount: int, at_position: Vector2) -> void:
	if world == null or not Items.ITEMS.has(item_id) or amount <= 0:
		return
	var pickup := PickupScene.instantiate() as WorldPickup
	world.add_child(pickup)
	pickup.configure(self, item_id, amount, at_position)


func collect_pickup(pickup: Node, item_id: String, amount: int) -> bool:
	var remainder := inventory.add_item(item_id, amount)
	var accepted := amount - remainder
	if accepted <= 0:
		if hud != null:
			hud.show_message("Inventory full · make room or build a storage crate.", 1.8)
		return false
	pickup.call("consume_amount", accepted)
	play_sound("pickup")
	if remainder == 0:
		hud.show_message("Recovered %s ×%d." % [Items.item_name(item_id), amount], 1.0)
		hud.refresh()
		return true
	hud.show_message(
		"Recovered %s ×%d · remainder stays on the ground." % [Items.item_name(item_id), accepted],
		1.4
	)
	hud.refresh()
	return false


func terraform_notice(stage: int) -> void:
	if stage == 1:
		hud.show_message(
			"SCANNER WARNING · repeatable ground motion is converging east of the landing shelf.",
			4.5
		)
		if not discoveries.has("glassfall"):
			discoveries.append("glassfall")
	elif stage == 2:
		play_sound("warning")
		hud.show_message(
			"PRESSURE ESCALATION · route markers are shifting. Move clear or construct cover.", 4.5
		)
	elif stage == 3:
		play_sound("warning")
		hud.show_message(
			(
				"TERRAIN TRANSFORMED · %d cells changed. A shallow shear now cuts the former route."
				% terraformer.changed_cells
			),
			5.0
		)
		var state: Dictionary = world_states.get("glassfall", {})
		state["terraform"] = terraformer.to_dict()
		world_states["glassfall"] = state
		if not discoveries.has("glassfall"):
			discoveries.append("glassfall")
		save_game()
	if hud != null:
		hud.refresh()


func _adjust_volume(channel: String, amount: float) -> void:
	var key := channel + "_volume"
	if settings.has(key):
		settings[key] = clampf(float(settings[key]) + amount, 0.0, 1.0)
		_save_settings()


func _apply_audio_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(
			master_bus, linear_to_db(maxf(0.0001, float(settings.get("master_volume", 0.85))))
		)
	if is_instance_valid(_ambience_player):
		_ambience_player.volume_db = linear_to_db(
			maxf(0.0001, float(settings.get("music_volume", 0.42)))
		)


func _start_ambience() -> void:
	if is_instance_valid(_ambience_player):
		_ambience_player.stop()
		_ambience_player.queue_free()
	var path := "res://assets/audio/ambience_ashlands.wav"
	if current_planet_id == "glassfall":
		path = "res://assets/audio/ambience_glassfall.wav"
	elif current_planet_id == "drowned":
		path = "res://assets/audio/ambience_drowned.wav"
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "PlanetAmbience"
	_ambience_player.stream = stream
	_ambience_player.volume_db = linear_to_db(
		maxf(0.0001, float(settings.get("music_volume", 0.42)))
	)
	add_child(_ambience_player)
	_ambience_player.play()


func play_sound(sound_id: String) -> void:
	if not SOUND_PATHS.has(sound_id) or float(settings.get("effects_volume", 0.82)) <= 0.001:
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = load(String(SOUND_PATHS[sound_id]))
	sound.volume_db = linear_to_db(float(settings.get("effects_volume", 0.82)))
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()


func _begin_new_expedition() -> void:
	if world != null and is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	if is_instance_valid(backdrop):
		remove_child(backdrop)
		backdrop.queue_free()
	backdrop = null
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.alive = true
	_start_fresh_state()
	SaveSystem.delete_slot(SAVE_SLOT)
	_mount_planet("ashlands")
	is_paused = false
	_respawn_choice_open = false
	hud.hide_modal()
	hud.configure(self)
	hud.show_message("New seed generated · a different captain, no recovered life.", 4.0)
	save_game()
