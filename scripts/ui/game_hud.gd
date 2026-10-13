class_name GameHUD
extends CanvasLayer

signal action_requested(action: String)
signal touch_action_pressed(action: String, pointer_id: int)
signal touch_action_released(action: String, pointer_id: int)
signal touch_stick_changed(axis: Vector2)

const Items = preload("res://scripts/inventory/item_catalog.gd")
const ItemIcons = preload("res://assets/ui/item_icons.png")
const ActionButton = preload("res://scripts/ui/touch_action_button.gd")
const Stick = preload("res://scripts/ui/virtual_stick.gd")
const MESSAGE_SAFE_BOTTOM := 120.0
const MESSAGE_MIN_HEIGHT := 50.0
const MESSAGE_MAX_HEIGHT := 134.0
const MESSAGE_CHARS_PER_LINE := 64.0
const MESSAGE_LINE_HEIGHT := 21.0

var game: Node
var root: Control
var status_label: Label
var location_label: Label
var objective_label: Label
var hotbar_label: Label
var message_label: Label
var message_timer := 0.0
var hotbar_buttons: Array[Button] = []
var _hotbar_scroll: ScrollContainer
var _hotbar_row: HBoxContainer
var _last_hotbar_selection := -1
var modal: PanelContainer
var modal_title: Label
var modal_rows: VBoxContainer
var stick: VirtualStick
var action_buttons: Array[TouchActionButton] = []
var _item_icon_cache: Dictionary = {}
var _panel_kind := ""
var _panel_history: Array[String] = []
var _restoring_panel := false
var _panel_dismissible := true
var _panel_close_button: Button
var _title_curtain: ColorRect
var _last_refresh := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_layout()
	# Input hitboxes follow physical window changes without changing world
	# coordinates or the per-pointer action ownership contract.
	get_window().size_changed.connect(_rebuild_touch_controls)


func configure(owner_game: Node) -> void:
	game = owner_game
	if is_node_ready():
		refresh()
		apply_control_settings()


func refresh() -> void:
	if game == null or status_label == null:
		return
	var survival: SurvivalSystem = game.get("survival")
	var hp := 100
	var energy := 100
	var oxygen := 100
	var exposure := 0
	if survival != null:
		hp = roundi(survival.health)
		energy = roundi(survival.energy)
		oxygen = roundi(survival.oxygen)
		exposure = roundi(survival.exposure)
	status_label.text = "CAPTAIN  /  SUIT %03d   POWER %03d   AIR %03d" % [hp, energy, oxygen]
	var planet_name := String(game.call("planet_display_name"))
	var seed_value := int(game.get("base_seed"))
	var ship_state: Dictionary = game.get("ship_state")
	var ship_text := (
		"DRIVE STABLE" if bool(ship_state.get("engine_repaired", false)) else "DRIVE DAMAGED"
	)
	location_label.text = (
		"%s   /   SEED %08d   /   %s%s"
		% [
			planet_name.to_upper(),
			seed_value,
			ship_text,
			"   /   EXPOSURE %02d" % exposure if exposure > 0 else ""
		]
	)
	var guide := String(game.call("field_guide_hint"))
	objective_label.text = guide if not guide.is_empty() else String(game.call("objective_text"))
	var inventory: Inventory = game.get("inventory")
	var quick_items: Array[String] = []
	if inventory != null:
		for item_id in inventory.item_ids().slice(0, 4):
			quick_items.append("%s ×%d" % [Items.item_name(item_id), inventory.count(item_id)])
	hotbar_label.text = (
		"FIELD LOAD  |  " + "    /    ".join(PackedStringArray(quick_items))
		if not quick_items.is_empty()
		else "FIELD LOAD  |  empty"
	)
	_update_hotbar_buttons()
	_last_refresh = 0.0


func show_message(text: String, seconds: float = 3.0) -> void:
	message_label.text = text
	var estimated_lines := 0
	for text_line in text.split("\n"):
		estimated_lines += maxi(1, ceili(float(text_line.length()) / MESSAGE_CHARS_PER_LINE))
	var estimated_height := clampf(
		float(estimated_lines) * MESSAGE_LINE_HEIGHT + 8.0, MESSAGE_MIN_HEIGHT, MESSAGE_MAX_HEIGHT
	)
	message_label.offset_bottom = -MESSAGE_SAFE_BOTTOM
	message_label.offset_top = -(MESSAGE_SAFE_BOTTOM + estimated_height)
	message_label.visible = true
	message_timer = seconds


func show_inventory(rebuild: bool = true) -> void:
	if rebuild:
		_begin_panel("FIELD INVENTORY", "inventory")
		var inventory: Inventory = game.get("inventory")
		if inventory == null or inventory.stacks.is_empty():
			_add_row("No recoverable material carried.", "", true)
		else:
			for item_id in inventory.item_ids():
				var usable := item_id in ["rations", "medfoam"]
				_add_row(
					(
						"%s    × %d    ·    %s"
						% [
							Items.item_name(item_id),
							inventory.count(item_id),
							Items.ITEMS[item_id]["description"]
						]
					),
					"use:" + item_id if usable else "",
					not usable
				)
				var inventory_row := modal_rows.get_child(modal_rows.get_child_count() - 1) as Button
				inventory_row.icon = _icon_for_item(item_id)
				inventory_row.expand_icon = true
				inventory_row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_add_row("Close field inventory", "close", false)


func show_crafting() -> void:
	_begin_panel("FIELD FABRICATION", "crafting")
	var inventory: Inventory = game.get("inventory")
	for recipe_id in Items.RECIPES.keys():
		var recipe: Dictionary = Items.RECIPES[recipe_id]
		var cost_parts: Array[String] = []
		for item_id in recipe["cost"].keys():
			cost_parts.append(
				"%s %d" % [Items.item_name(String(item_id)), int(recipe["cost"][item_id])]
			)
		var enabled := Crafting.can_craft(String(recipe_id), inventory)
		var text := "%s   —   %s" % [String(recipe["name"]), ", ".join(cost_parts)]
		_add_row(text, "craft:" + String(recipe_id), not enabled)
		var outputs: Dictionary = recipe["output"]
		if not outputs.is_empty():
			var first_item_id := String(outputs.keys()[0])
			var crafting_row := modal_rows.get_child(modal_rows.get_child_count() - 1) as Button
			crafting_row.icon = _icon_for_item(first_item_id)
			crafting_row.expand_icon = true
			crafting_row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_row("Close fabrication", "close", false)


func show_travel() -> void:
	_begin_panel("NAVIGATION / SURVEYED ROUTES", "travel")
	var ship: Dictionary = game.get("ship_state")
	var visited: Array = game.get("visited_planets")
	for row in TravelSystem.destination_rows(ship, visited):
		var marker := "VISITED" if bool(row["visited"]) else "UNVISITED"
		var enabled := bool(row["unlocked"])
		var name := String(row["name"])
		var suffix := (
			marker
			if enabled
			else (
				"LOCKED · repair drive"
				if row["requirement"] == "engine"
				else "LOCKED · fit coolant" if row["requirement"] == "coolant" else marker
			)
		)
		_add_row("%s    /    %s" % [name, suffix], "travel:" + String(row["id"]), not enabled)
	_add_row("Close navigation", "close", false)


func show_ship() -> void:
	_begin_panel("SALVAGE VESSEL / SERVICE BAY", "ship")
	var ship: Dictionary = game.get("ship_state")
	var inventory: Inventory = game.get("inventory")
	var integrity := int(ship.get("integrity", 34))
	_add_row(
		(
			"FRAME INTEGRITY  %d%%    ·    DRIVE %s"
			% [integrity, "REPAIRED" if ship.get("engine_repaired", false) else "DAMAGED"]
		),
		"",
		true
	)
	_add_row(
		"ENGINE PATCH  —  6 scrap + 4 ferrite",
		"repair_engine",
		(
			bool(ship.get("engine_repaired", false))
			or not (inventory.count("scrap") >= 6 and inventory.count("ferrite") >= 4)
		)
	)
	_add_row(
		"FIT COOLANT LOOP  —  1 coolant loop",
		"install_coolant",
		bool(ship.get("coolant_installed", false)) or inventory.count("coolant_loop") < 1
	)
	_add_row(
		"Use repair kit  —  restore 18% frame",
		"use_repair_kit",
		inventory.count("repair_kit") < 1 or integrity >= 100
	)
	_add_row(
		"Install field coil · upgrade cutter",
		"install_cutter",
		bool(ship.get("cutter_upgraded", false)) or inventory.count("field_coil") < 1
	)
	_add_row(
		"Install thermal lining · slow heat exposure",
		"install_lining",
		bool(ship.get("thermal_lining", false)) or inventory.count("thermal_lining") < 1
	)
	_add_row(
		"Install cargo frame · +8 inventory stacks",
		"install_cargo",
		bool(ship.get("cargo_frame", false)) or inventory.count("cargo_frame") < 1
	)
	_add_row(
		"Install scanner lens · wider geological sweep",
		"install_scanner",
		bool(ship.get("scanner_lens", false)) or inventory.count("scanner_lens") < 1
	)
	_add_row("Storage transfer", "storage", false)
	_add_row("Navigate to a planet", "open_travel", false)
	_add_row("Close service bay", "close", false)


func show_storage(storage: Dictionary, title: String = "FIELD STORAGE") -> void:
	_begin_panel(title.to_upper(), "storage")
	var inventory: Inventory = game.get("inventory")
	_add_row("Transfer is one item at a time. The cache stays in this save slot.", "", true)
	for item_id in inventory.item_ids():
		_add_row(
			"Store 1 × %s   (carried %d)" % [Items.item_name(item_id), inventory.count(item_id)],
			"deposit:" + item_id,
			false
		)
	var stored_count := 0
	for item_id in storage.keys():
		var quantity := int(storage[item_id])
		if quantity > 0:
			stored_count += 1
			_add_row(
				"Take 1 × %s   (stored %d)" % [Items.item_name(String(item_id)), quantity],
				"withdraw:" + String(item_id),
				false
			)
	if stored_count == 0:
		_add_row("The cache is empty.", "", true)
	_add_row("Close storage", "close", false)


func hide_modal() -> void:
	if modal != null:
		modal.visible = false
	_panel_kind = ""
	_panel_history.clear()
	_panel_dismissible = true
	if _title_curtain != null:
		_title_curtain.visible = false


func current_panel_kind() -> String:
	return _panel_kind


func set_title_curtain(enabled: bool) -> void:
	if _title_curtain == null:
		return
	_title_curtain.visible = enabled
	if enabled:
		root.move_child(_title_curtain, root.get_child_count() - 1)
		if modal.visible:
			root.move_child(modal, root.get_child_count() - 1)


func navigate_back() -> bool:
	# Terminal screens cannot be dismissed into a paused, unusable world.
	if not _panel_dismissible:
		return true
	if not _panel_history.is_empty():
		var previous: String = _panel_history.pop_back()
		_restoring_panel = true
		match previous:
			"pause":
				game.call("_show_pause_menu")
			"title":
				game.call("_show_title_menu")
			"inventory":
				show_inventory()
			"crafting":
				show_crafting()
			"ship":
				show_ship()
			"travel":
				show_travel()
			"storage":
				var kind := String(game.get("current_storage_kind"))
				show_storage(
					game.call("_storage_for_current_mode"),
					"SHIP CARGO" if kind == "ship" else "PLANET CACHE"
				)
			"quests":
				show_quests()
			"compendium":
				show_compendium()
			"guide":
				show_field_guide()
			_:
				_restoring_panel = false
				hide_modal()
				return false
		_restoring_panel = false
		return true
	hide_modal()
	return false


func show_quests() -> void:
	_begin_panel("FIELD LOG / SURVIVORS", "quests")
	for quest_id in QuestSystem.QUESTS.keys():
		var definition: Dictionary = QuestSystem.QUESTS[quest_id]
		var entry: Dictionary = game.get("quest_system").states.get(
			quest_id, {"status": "available", "note": ""}
		)
		_add_row(
			(
				"%s  [%s]\n%s\n%s"
				% [
					definition["title"],
					String(entry.get("status", "available")).to_upper(),
					definition["brief"],
					String(entry.get("note", ""))
				]
			),
			"",
			true
		)
	_add_row("Close field log", "close", false)


func show_compendium() -> void:
	_begin_panel("FIELD COMPENDIUM", "compendium")
	var known: Array = game.get("discoveries")
	for discovery_id in known:
		if Items.DISCOVERIES.has(String(discovery_id)):
			var entry: Dictionary = Items.DISCOVERIES[String(discovery_id)]
			_add_row("%s\n%s" % [entry["label"], entry["text"]], "", true)
	if known.is_empty():
		_add_row(
			"No field notes yet. Use the scanner near geology, ruins or active hazards.", "", true
		)
	_add_row("Close compendium", "close", false)


func show_settings() -> void:
	_begin_panel("ACCESSIBILITY / CONTROLS", "settings")
	var settings: Dictionary = game.get("settings")
	_add_row(
		(
			"Master volume: %d%%  · tap to increase"
			% roundi(float(settings.get("master_volume", 0.8)) * 100.0)
		),
		"volume:master",
		false
	)
	_add_row("Master volume down", "volume_down:master", false)
	_add_row(
		(
			"Music volume: %d%%  · tap to increase"
			% roundi(float(settings.get("music_volume", 0.45)) * 100.0)
		),
		"volume:music",
		false
	)
	_add_row("Music volume down", "volume_down:music", false)
	_add_row(
		(
			"Effects volume: %d%%  · tap to increase"
			% roundi(float(settings.get("effects_volume", 0.8)) * 100.0)
		),
		"volume:effects",
		false
	)
	_add_row("Effects volume down", "volume_down:effects", false)
	_add_row(
		(
			"Touch target size: %d%%  · tap to enlarge"
			% roundi(float(settings.get("button_scale", 1.0)) * 100.0)
		),
		"size:up",
		false
	)
	_add_row("Touch target size down", "size:down", false)
	_add_row(
		"Left-handed layout: %s" % ("ON" if settings.get("left_handed", false) else "OFF"),
		"toggle:left_handed",
		false
	)
	_add_row(
		"Reduced screen shake: %s" % ("ON" if settings.get("reduced_shake", true) else "OFF"),
		"toggle:reduced_shake",
		false
	)
	_add_row(
		"Reduced visual flash: %s" % ("ON" if settings.get("reduced_flash", true) else "OFF"),
		"toggle:reduced_flash",
		false
	)
	_add_row("Close settings", "close", false)


func show_dialogue(
	title: String,
	text: String,
	options: Array[Dictionary] = [],
	kind: String = "dialogue",
	dismissible: bool = true
) -> void:
	_begin_panel(title.to_upper(), kind, dismissible)
	_add_row(text, "", true)
	for option in options:
		_add_row(
			String(option.get("label", "Continue")),
			String(option.get("action", "close")),
			bool(option.get("disabled", false))
		)
	if dismissible:
		_add_row("Back / close", "close", false)


func show_title(has_active_save: bool, ended: bool, destination: String, seed: int) -> void:
	_begin_panel("SILKBOUND / THE OUTER REACHES", "title", false)
	var artwork := TextureRect.new()
	artwork.texture = preload("res://assets/ship/salvage_vessel.png")
	artwork.custom_minimum_size = Vector2(0.0, 126.0)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_rows.add_child(artwork)
	_add_row("BLOOD ECLIPSE WAR  /  PERIPHERAL SALVAGE OPERATIONS", "", true)
	if ended:
		_add_row("EXPEDITION ENDED  /  The last captain cannot return.", "", true)
		_add_row("Begin as a new captain", "title_new_confirm", false)
	elif has_active_save:
		_add_row("SAVED EXPEDITION  /  %s  /  SEED %08d" % [destination.to_upper(), seed], "", true)
		_add_row("Continue expedition", "title_continue", false)
		_add_row("Begin a different expedition (replaces current save)", "title_new_confirm", false)
	else:
		_add_row("The vessel is damaged. The people and the geological evidence are real.", "", true)
		_add_row("Begin first expedition", "title_begin", false)
	_add_row("Accessibility, sound and controls", "title_settings", false)
	_add_row("Field guide / how to play", "title_guide", false)
	_add_row("Offline, single-player, non-canon Starsilk simulation.", "", true)


func show_field_guide() -> void:
	_begin_panel("FIELD GUIDE / FIRST EXPEDITION", "guide")
	_add_row("Salvage, build shelter, and repair the ship. No raw Starsilk handling.", "", true)
	var step := int(game.get("onboarding_step"))
	for index in range(int(game.call("onboarding_total"))):
		var status := "LATER  "
		if index < step:
			status = "DONE   "
		elif index == step:
			status = "NEXT   "
		_add_row(status + String(game.call("field_guide_step", index)), "", true)
	_add_row("JUMP / SPACE · BAG / I · MAKE / C · BUILD / B · SCAN / Q", "", true)
	_add_row("Repair the drive at the ship console: 6 scrap + 4 ferrite.", "", true)
	if not bool(game.get("_title_open")) and step < int(game.call("onboarding_total")):
		_add_row("Skip guided steps (keep this guide in the Pause menu)", "guide_skip", false)
	_add_row("Back", "close", false)


func show_new_expedition_confirmation() -> void:
	show_dialogue(
		"REPLACE SAVED EXPEDITION?",
		"Beginning another expedition permanently replaces this captain's local save. A dead captain cannot be recovered. Nothing is erased by choosing Back.",
		[
			{"label": "Back to the title (keep save)", "action": "close"},
			{"label": "Confirm: begin new expedition", "action": "title_new_confirmed"}
		],
		"title_confirm",
		true
	)


func refresh_current_panel() -> void:
	match _panel_kind:
		"inventory":
			show_inventory()
		"crafting":
			show_crafting()
		"travel":
			show_travel()
		"ship":
			show_ship()
		"storage":
			var kind := String(game.get("current_storage_kind"))
			show_storage(
				game.call("_storage_for_current_mode"),
				"SHIP CARGO" if kind == "ship" else "PLANET CACHE"
			)
		"quests":
			show_quests()
		"settings":
			show_settings()


func _input(event: InputEvent) -> void:
	# Finger-up events outside the original Control still release only the
	# owning pointer. Never clear another finger's movement or held action.
	if event is InputEventScreenTouch and not event.pressed:
		var pointer_id := int(event.index)
		for button in action_buttons:
			if is_instance_valid(button):
				button.release_pointer(pointer_id)
		if is_instance_valid(stick):
			stick.release_pointer(pointer_id)
	elif (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		for button in action_buttons:
			if is_instance_valid(button):
				button.release_pointer(-1)
		if is_instance_valid(stick):
			stick.release_mouse()


func cancel_live_controls() -> void:
	for button in action_buttons:
		if is_instance_valid(button):
			button.cancel_input()
	if is_instance_valid(stick):
		stick.cancel_input()


func apply_control_settings() -> void:
	if game == null or root == null:
		return
	_rebuild_touch_controls()


func _process(delta: float) -> void:
	message_timer = maxf(0.0, message_timer - delta)
	message_label.visible = message_timer > 0.0
	_last_refresh += delta
	if _last_refresh >= 0.25:
		refresh()


func _build_layout() -> void:
	root = Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)
	_build_status_panel()
	_build_modal()
	message_label = Label.new()
	message_label.name = "FieldMessage"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", Color(0.86, 0.96, 0.94))
	message_label.add_theme_color_override("font_shadow_color", Color(0.01, 0.04, 0.08, 1.0))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 1.0
	message_label.anchor_bottom = 1.0
	message_label.offset_left = -340
	message_label.offset_right = 340
	message_label.offset_top = -(MESSAGE_SAFE_BOTTOM + MESSAGE_MIN_HEIGHT)
	message_label.offset_bottom = -MESSAGE_SAFE_BOTTOM
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.visible = false
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(message_label)
	_build_hotbar()
	_rebuild_touch_controls()


func _build_hotbar() -> void:
	# A clipped, swipeable rail retains all eight crafting slots without
	# shrinking their physical hit targets on compact Android landscape.
	_hotbar_scroll = ScrollContainer.new()
	_hotbar_scroll.name = "TouchHotbar"
	_hotbar_scroll.anchor_left = 0.5
	_hotbar_scroll.anchor_right = 0.5
	_hotbar_scroll.anchor_top = 1.0
	_hotbar_scroll.anchor_bottom = 1.0
	_hotbar_scroll.offset_left = -288
	_hotbar_scroll.offset_right = 288
	_hotbar_scroll.offset_top = -69
	_hotbar_scroll.offset_bottom = -15
	_hotbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hotbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hotbar_scroll.scroll_deadzone = 8
	_hotbar_scroll.follow_focus = true
	_hotbar_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_hotbar_scroll)
	_hotbar_row = HBoxContainer.new()
	_hotbar_row.name = "TouchHotbarItems"
	_hotbar_row.add_theme_constant_override("separation", 3)
	_hotbar_scroll.add_child(_hotbar_row)
	for index in range(8):
		var button := Button.new()
		button.custom_minimum_size = Vector2(68, 54)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("h_separation", 2)
		button.pressed.connect(_on_panel_action.bind("hotbar:%d" % index))
		_hotbar_row.add_child(button)
		hotbar_buttons.append(button)


func _layout_hotbar(scale_value: float) -> void:
	if _hotbar_scroll == null:
		return
	var slot_height := 54.0 * scale_value
	_hotbar_scroll.offset_top = -slot_height - 15.0
	_hotbar_scroll.offset_bottom = -15.0
	for button in hotbar_buttons:
		button.custom_minimum_size = Vector2(68.0 * scale_value, slot_height)
		button.add_theme_font_size_override("font_size", roundi(12.0 * minf(1.4, scale_value)))
	_last_hotbar_selection = -1


func _icon_for_item(item_id: String) -> Texture2D:
	if not Items.ITEMS.has(item_id):
		return null
	if _item_icon_cache.has(item_id):
		return _item_icon_cache[item_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = ItemIcons
	var icon_index := int(Items.ITEMS[item_id]["icon"])
	atlas.region = Rect2((icon_index % 8) * 16, int(icon_index / 8) * 16, 16, 16)
	_item_icon_cache[item_id] = atlas
	return atlas


func _update_hotbar_buttons() -> void:
	if game == null or hotbar_buttons.is_empty():
		return
	var inventory: Inventory = game.get("inventory")
	var hotbar: Array = game.get("hotbar_items")
	var selected := int(game.get("selected_hotbar"))
	for index in range(hotbar_buttons.size()):
		if index >= hotbar.size():
			hotbar_buttons[index].icon = null
			hotbar_buttons[index].text = "%d   —" % (index + 1)
			hotbar_buttons[index].disabled = true
			continue
		var item_id := String(hotbar[index])
		var quantity := inventory.count(item_id) if inventory != null else 0
		var button := hotbar_buttons[index]
		button.icon = _icon_for_item(item_id)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.text = "%d ×%d" % [index + 1, quantity]
		button.tooltip_text = "%s · %d carried" % [Items.item_name(item_id), quantity]
		button.disabled = quantity <= 0
		hotbar_buttons[index].modulate = (
			Color(0.45, 0.93, 0.89) if index == selected else Color.WHITE
		)
	if selected != _last_hotbar_selection and selected >= 0 and selected < hotbar_buttons.size():
		_last_hotbar_selection = selected
		# Only move the rail for a changed selection; otherwise a swipe
		# would be reset on each quarter-second HUD refresh.
		_hotbar_scroll.call_deferred("ensure_control_visible", hotbar_buttons[selected])


func _build_status_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 22
	panel.offset_top = 18
	panel.offset_right = 510
	panel.offset_bottom = 161
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.025, 0.065, 0.105, 0.83), Color(0.22, 0.57, 0.66, 0.8))
	)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	status_label = _make_label("SUIT  100   POWER  100   AIR  100", 18, Color(0.69, 0.96, 0.92))
	location_label = _make_label(
		"ASHLANDS   /   SEED 00000000   /   DRIVE DAMAGED", 14, Color(0.69, 0.83, 0.88)
	)
	objective_label = _make_label(
		"Recover local materials. Keep clear of the shear.", 15, Color(0.94, 0.78, 0.54)
	)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.clip_text = false
	hotbar_label = _make_label("FIELD LOAD  |  Salvage cutter", 14, Color(0.77, 0.87, 0.90))
	column.add_child(status_label)
	column.add_child(location_label)
	column.add_child(objective_label)
	column.add_child(hotbar_label)


func _build_modal() -> void:
	modal = PanelContainer.new()
	modal.name = "MissionPanel"
	modal.anchor_left = 0.5
	modal.anchor_right = 0.5
	modal.anchor_top = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -320
	modal.offset_right = 320
	modal.offset_top = -280
	modal.offset_bottom = 280
	modal.custom_minimum_size = Vector2(560, 480)
	modal.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.025, 0.055, 0.09, 0.96), Color(0.29, 0.76, 0.82, 0.92))
	)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	# The existing authored planet backdrop remains visible, but inert,
	# behind the mission-control entry screen and its settings.
	_title_curtain = ColorRect.new()
	_title_curtain.name = "TitleCurtain"
	_title_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_curtain.color = Color(0.005, 0.015, 0.035, 0.84)
	_title_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_curtain.visible = false
	root.add_child(_title_curtain)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	modal.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	modal_title = _make_label("SILKBOUND", 21, Color(0.62, 0.94, 0.90))
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(modal_title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 42)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(_on_panel_action.bind("close"))
	header.add_child(close_button)
	_panel_close_button = close_button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	modal_rows = VBoxContainer.new()
	modal_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(modal_rows)


func _rebuild_touch_controls(simulated_window: Vector2i = Vector2i.ZERO) -> void:
	if root == null:
		return
	cancel_live_controls()
	if is_instance_valid(stick):
		stick.queue_free()
	for button in action_buttons:
		if is_instance_valid(button):
			button.queue_free()
	action_buttons.clear()
	if game == null:
		return
	var settings: Dictionary = game.get("settings")
	var left_handed := bool(settings.get("left_handed", false))
	# The canvas remains 1280 logical pixels wide. A smaller output
	# surface shrinks native touch circles unless their logical bounds grow.
	var width_pixels := float(
		simulated_window.x if simulated_window.x > 0 else get_window().size.x
	)
	var screen_compensation := maxf(1.0, 1280.0 / maxf(720.0, width_pixels))
	var scale_value := clampf(
		float(settings.get("button_scale", 1.0)) * screen_compensation,
		0.78,
		1.6
	)
	_layout_hotbar(scale_value)
	stick = Stick.new()
	stick.name = "VirtualMovementStick"
	var stick_size := 160.0 * scale_value
	if left_handed:
		stick.anchor_left = 1.0
		stick.anchor_right = 1.0
		stick.anchor_top = 1.0
		stick.anchor_bottom = 1.0
		stick.offset_left = -stick_size - 26.0
		stick.offset_right = -26.0
		stick.offset_top = -stick_size - 25.0
		stick.offset_bottom = -25.0
	else:
		stick.anchor_left = 0.0
		stick.anchor_right = 0.0
		stick.anchor_top = 1.0
		stick.anchor_bottom = 1.0
		stick.offset_left = 26.0
		stick.offset_right = 26.0 + stick_size
		stick.offset_top = -stick_size - 25.0
		stick.offset_bottom = -25.0
	stick.axis_changed.connect(_on_stick_changed)
	root.add_child(stick)
	var action_anchor_x := 0.0 if left_handed else 1.0
	var horizontal_sign := 1.0 if left_handed else -1.0
	# Separate hitboxes remain disjoint at both normal and maximum scale.
	# Below the viewport's 1280 logical reference width, these give at least
	# 50 physical pixels per action on a 720-pixel landscape.
	_add_action(
		"jump", "JUMP", action_anchor_x, 1.0, horizontal_sign * 112.0, -100.0, 78.0 * scale_value
	)
	_add_action(
		"mine", "MINE", action_anchor_x, 1.0, horizontal_sign * 244.0, -100.0, 78.0 * scale_value
	)
	_add_action(
		"attack", "HIT", action_anchor_x, 1.0, horizontal_sign * 112.0, -248.0, 72.0 * scale_value
	)
	_add_action(
		"interact", "USE", action_anchor_x, 1.0, horizontal_sign * 244.0, -248.0, 72.0 * scale_value
	)
	# Six utilities occupy individual 100px columns above the field,
	# leaving the left status panel clear even at maximum button scale.
	var utility_actions := ["scan", "build", "inventory", "craft", "ship", "pause"]
	var utility_captions := ["SCAN", "BUILD", "BAG", "MAKE", "SHIP", "MENU"]
	for index in range(utility_actions.size()):
		_add_action(
			String(utility_actions[index]),
			String(utility_captions[index]),
			1.0, 0.0, -90.0 - 110.0 * index, 82.0, 62.0 * scale_value
		)


func _add_action(
	action: String,
	caption: String,
	anchor_x: float,
	anchor_y: float,
	center_x_offset: float,
	center_y_offset: float,
	diameter: float
) -> void:
	var button := ActionButton.new()
	button.name = "Action_" + action
	button.configure(action, caption)
	button.anchor_left = anchor_x
	button.anchor_right = anchor_x
	button.anchor_top = anchor_y
	button.anchor_bottom = anchor_y
	button.offset_left = center_x_offset - diameter * 0.5
	button.offset_right = center_x_offset + diameter * 0.5
	button.offset_top = center_y_offset - diameter * 0.5
	button.offset_bottom = center_y_offset + diameter * 0.5
	button.action_pressed.connect(_on_action_pressed)
	button.action_released.connect(_on_action_released)
	root.add_child(button)
	action_buttons.append(button)


func _begin_panel(title: String, kind: String, dismissible: bool = true) -> void:
	if modal.visible and _panel_kind != kind and not _restoring_panel:
		if _panel_kind != "" and _panel_kind != "death":
			_panel_history.append(_panel_kind)
	_panel_kind = kind
	_panel_dismissible = dismissible
	_panel_close_button.visible = dismissible
	modal_title.text = title
	modal.visible = true
	root.move_child(modal, root.get_child_count() - 1)
	for child in modal_rows.get_children():
		modal_rows.remove_child(child)
		child.queue_free()


func _add_row(text: String, action: String, disabled: bool) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	var estimated_lines := 0
	for text_line in text.split("\n"):
		estimated_lines += maxi(1, ceili(float(text_line.length()) / 64.0))
	button.custom_minimum_size = Vector2(0, maxf(44.0, float(estimated_lines) * 21.0 + 14.0))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.87, 0.94, 0.94))
	button.add_theme_color_override("font_disabled_color", Color(0.70, 0.80, 0.85))
	button.pressed.connect(_on_panel_action.bind(action))
	modal_rows.add_child(button)


func _on_action_pressed(action: String, pointer_id: int) -> void:
	touch_action_pressed.emit(action, pointer_id)


func _on_action_released(action: String, pointer_id: int) -> void:
	touch_action_released.emit(action, pointer_id)


func _on_stick_changed(axis: Vector2) -> void:
	touch_stick_changed.emit(axis)


func _on_panel_action(action: String) -> void:
	if action == "close" and not _panel_dismissible:
		return
	action_requested.emit(action)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
