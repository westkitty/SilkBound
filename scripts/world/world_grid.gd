class_name WorldGrid
extends Node2D

const Generator = preload("res://scripts/world/planet_generator.gd")
const Tiles = preload("res://scripts/world/tile_catalog.gd")
const CHUNK_WIDTH := 32
const TILE_SIZE := 32
const GLASSFALL_FAULT_X := 62
const GLASSFALL_FAULT_RADIUS := 7

var planet_id: String = "ashlands"
var biome: int = Generator.Biome.ASHLANDS
var world_seed: int = 0
var world_width: int = 0
var world_height: int = 0
var base_cells := PackedInt32Array()
var surface_heights := PackedInt32Array()
var structures: Array = []
var modifications: Dictionary = {}
var cracks: Dictionary = {}
var scan_highlights: Dictionary = {}
var chunk_views: Dictionary = {}
var collision_chunks: Dictionary = {}
var spawn_cell := Vector2i(10, 20)
var _batching := false
var _dirty_chunks: Dictionary = {}
var fault_warning_phase := 0
var _environment_revision := 0
var _sampled_revision := -1
var _sampled_cell := Vector2i(-9999, -9999)
var _sampled_shelter := false
var _sampled_thermal := false
var environment_sample_count := 0


func setup(
	id: String,
	seed_value: int,
	biome_value: int,
	saved_modifications: Dictionary = {},
	saved_meta: Dictionary = {}
) -> void:
	planet_id = id
	world_seed = seed_value
	biome = biome_value
	fault_warning_phase = 0
	_environment_revision = 0
	_sampled_revision = -1
	_sampled_cell = Vector2i(-9999, -9999)
	environment_sample_count = 0
	var generated := Generator.generate(seed_value, biome_value)
	world_width = int(generated["width"])
	world_height = int(generated["height"])
	base_cells = generated["cells"]
	surface_heights = generated["surface"]
	structures = generated["structures"]
	spawn_cell = generated["spawn"]
	modifications.clear()
	for raw_index in saved_modifications.keys():
		var index_text := String(raw_index)
		if not index_text.is_valid_int():
			continue
		var index := int(index_text)
		var tile_id := int(saved_modifications[raw_index])
		if (
			index >= 0
			and index < world_width * world_height
			and tile_id >= Tiles.Tile.AIR
			and tile_id <= Tiles.Tile.FAULT
		):
			modifications[index_text] = tile_id
	var saved_spawn: Variant = saved_meta.get("spawn", [])
	if saved_spawn is Array and saved_spawn.size() >= 2:
		var x := int(saved_spawn[0])
		var y := int(saved_spawn[1])
		if x >= 0 and x < world_width and y >= 0 and y < world_height:
			spawn_cell = Vector2i(x, y)
	_build_chunks()


func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= world_width or y < 0:
		return Tiles.Tile.BASALT
	if y >= world_height:
		return Tiles.Tile.BASALT
	var index := y * world_width + x
	var key := str(index)
	if modifications.has(key):
		return int(modifications[key])
	return int(base_cells[index])


func cell_index(x: int, y: int) -> int:
	return y * world_width + x


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * TILE_SIZE, (float(cell.y) + 0.5) * TILE_SIZE)


func surface_at(x: int) -> int:
	if surface_heights.is_empty():
		return 24
	return int(surface_heights[clampi(x, 0, surface_heights.size() - 1)])


func get_tile_world(point: Vector2) -> int:
	var cell := world_to_cell(point)
	return get_tile(cell.x, cell.y)


func captain_space_clear(point: Vector2) -> bool:
	# Bounds for the existing 18x38 character capsule. Inspect saved tiles,
	# including constructed walls; do not change the generated terrain.
	if not point.is_finite():
		return false
	var low := world_to_cell(point - Vector2(10.0, 18.0))
	var high := world_to_cell(point + Vector2(10.0, 18.0))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if Tiles.is_solid(get_tile(x, y)):
				return false
	return true


func safe_reentry_position(preferred: Vector2, fallback: Vector2) -> Vector2:
	if captain_space_clear(preferred):
		return preferred
	# Recheck the actual modified landscape; prefer the same neighborhood
	# and fall back to a near-ship shelf only if local ground is obstructed.
	for raw_anchor in [preferred, fallback]:
		var anchor: Vector2 = raw_anchor
		if not anchor.is_finite():
			continue
		var origin_x := world_to_cell(anchor).x
		for radius in range(16):
			var candidates: Array[int] = [origin_x]
			if radius > 0:
				candidates = [origin_x - radius, origin_x + radius]
			for x in candidates:
				if x < 1 or x >= world_width - 1:
					continue
				var ground_y := surface_at(x)
				if not Tiles.is_solid(get_tile(x, ground_y)):
					continue
				for rise in range(2, 6):
					var candidate := cell_to_world(Vector2i(x, ground_y - rise))
					if captain_space_clear(candidate):
						return candidate
	if captain_space_clear(fallback):
		return fallback
	return preferred


func set_tile(x: int, y: int, tile_id: int) -> bool:
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return false
	var index := cell_index(x, y)
	var key := str(index)
	if get_tile(x, y) == tile_id:
		return false
	if tile_id == int(base_cells[index]):
		modifications.erase(key)
	else:
		modifications[key] = tile_id
	cracks.erase(index)
	_environment_revision += 1
	_refresh_cell(x, y)
	return true


func mine_cell(x: int, y: int, tool_power: float = 30.0) -> Dictionary:
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return {"ok": false, "reason": "Out of range."}
	var tile_id := get_tile(x, y)
	if tile_id == Tiles.Tile.AIR or tile_id == Tiles.Tile.WATER or tile_id == Tiles.Tile.LAMP:
		return {"ok": false, "reason": "There is no solid material to cut."}
	var cell_id := cell_index(x, y)
	var hardness := Tiles.hardness(tile_id)
	var progress := float(cracks.get(cell_id, 0.0)) + maxf(1.0, tool_power) / hardness
	var threshold := 100.0
	if progress < threshold:
		cracks[cell_id] = progress
		var chunk := int(x / CHUNK_WIDTH)
		if chunk_views.has(chunk):
			(chunk_views[chunk] as CanvasItem).queue_redraw()
		return {"ok": true, "broken": false, "progress": progress / threshold, "tile": tile_id}
	cracks.erase(cell_id)
	set_tile(x, y, Tiles.Tile.AIR)
	return {"ok": true, "broken": true, "tile": tile_id, "drop": Tiles.item_drop(tile_id)}


func place_building(x: int, y: int, tile_id: int, player_position: Vector2) -> Dictionary:
	if not Tiles.is_building(tile_id):
		return {"ok": false, "reason": "That object is not placeable."}
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return {"ok": false, "reason": "Outside the buildable area."}
	if get_tile(x, y) != Tiles.Tile.AIR:
		return {"ok": false, "reason": "That cell is occupied."}
	var cell_center := cell_to_world(Vector2i(x, y))
	if (
		absf(cell_center.x - player_position.x) < 20.0
		and absf(cell_center.y - player_position.y) < 35.0
	):
		return {"ok": false, "reason": "Move clear of the placement cell."}
	var supported := false
	for offset in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if Tiles.is_solid(get_tile(x + offset.x, y + offset.y)):
			supported = true
			break
	if not supported and Tiles.is_solid(tile_id):
		return {"ok": false, "reason": "Place against a supporting surface."}
	if not set_tile(x, y, tile_id):
		return {"ok": false, "reason": "The terrain did not accept that placement."}
	return {"ok": true, "tile": tile_id}


func apply_terraform(center_x: int, radius: int = 6) -> Dictionary:
	var clamped_center := clampi(center_x, 3, world_width - 4)
	var center_surface := surface_at(clamped_center)
	var changed := 0
	_batching = true
	for x in range(
		clampi(clamped_center - radius, 2, world_width - 3),
		clampi(clamped_center + radius + 1, 3, world_width - 2)
	):
		var surface_y := surface_at(x)
		for y in range(surface_y, mini(world_height - 2, surface_y + 4)):
			var old_tile := get_tile(x, y)
			var next_tile := Tiles.Tile.GLASS if abs(x - clamped_center) > 1 else Tiles.Tile.FAULT
			if old_tile != next_tile:
				_set_tile_batched(x, y, next_tile)
				changed += 1
		# A narrow, bounded shear removes a shallow route rather than making the planet unlivable.
		if x == clamped_center:
			for y in range(center_surface, mini(world_height - 2, center_surface + 5)):
				if get_tile(x, y) != Tiles.Tile.AIR:
					_set_tile_batched(x, y, Tiles.Tile.AIR)
					changed += 1
			_set_tile_batched(x, center_surface + 5, Tiles.Tile.FAULT)
	_batching = false
	_refresh_dirty_chunks()
	return {
		"changed": changed, "center": Vector2i(clamped_center, center_surface), "radius": radius
	}


func scan_area(center: Vector2, radius_cells: int = 9) -> Dictionary:
	var origin := world_to_cell(center)
	var counts := {
		"ore": 0,
		"ferrite": 0,
		"copper": 0,
		"crystal": 0,
		"wreckage": 0,
		"water": 0,
		"glass": 0,
		"archive": 0,
		"fiber": 0,
		"fault": 0
	}
	scan_highlights.clear()
	for y in range(
		maxi(0, origin.y - radius_cells), mini(world_height, origin.y + radius_cells + 1)
	):
		for x in range(
			maxi(0, origin.x - radius_cells), mini(world_width, origin.x + radius_cells + 1)
		):
			if Vector2(x - origin.x, y - origin.y).length() > float(radius_cells):
				continue
			var tile_id := get_tile(x, y)
			var category := ""
			match tile_id:
				Tiles.Tile.FERRITE:
					category = "ferrite"
				Tiles.Tile.COPPER:
					category = "copper"
				Tiles.Tile.CRYSTAL:
					category = "crystal"
				Tiles.Tile.SCRAP:
					category = "wreckage"
				Tiles.Tile.WATER:
					category = "water"
				Tiles.Tile.GLASS:
					category = "glass"
				Tiles.Tile.ARCHIVE:
					category = "archive"
				Tiles.Tile.FIBER:
					category = "fiber"
				Tiles.Tile.FAULT:
					category = "fault"
			if category.is_empty():
				continue
			counts[category] = int(counts[category]) + 1
			if category in ["ferrite", "copper", "crystal"]:
				counts["ore"] = int(counts["ore"]) + 1
			if (
				category
				in [
					"ferrite", "copper", "crystal", "wreckage", "glass", "archive", "fiber", "fault"
				]
			):
				scan_highlights[str(cell_index(x, y))] = category
	for chunk in chunk_views.values():
		(chunk as CanvasItem).queue_redraw()
	return counts


func is_underwater(world_position: Vector2) -> bool:
	var cell := world_to_cell(world_position + Vector2(0, 8))
	if get_tile(cell.x, cell.y) == Tiles.Tile.WATER:
		return true
	return get_tile(cell.x, cell.y + 1) == Tiles.Tile.WATER


func is_thermal_zone(world_position: Vector2) -> bool:
	_sample_environment(world_to_cell(world_position))
	return _sampled_thermal


func is_sheltered(world_position: Vector2) -> bool:
	_sample_environment(world_to_cell(world_position))
	return _sampled_shelter


func _sample_environment(cell: Vector2i) -> void:
	# The HUD consults both hazards every frame. Reuse one bounded sample until
	# movement or a real terrain edit changes the answer.
	if cell == _sampled_cell and _sampled_revision == _environment_revision:
		return
	_sampled_cell = cell
	_sampled_revision = _environment_revision
	environment_sample_count += 1
	_sampled_thermal = false
	if biome == Generator.Biome.GLASSFALL:
		for y in range(cell.y - 1, cell.y + 2):
			for x in range(cell.x - 1, cell.x + 2):
				if get_tile(x, y) == Tiles.Tile.FAULT:
					_sampled_thermal = true
					break
			if _sampled_thermal:
				break
	var walls := 0
	var floor_found := false
	var nearby_lamp := false
	for y in range(maxi(0, cell.y - 4), mini(world_height, cell.y + 5)):
		for x in range(maxi(0, cell.x - 5), mini(world_width, cell.x + 6)):
			var tile_id := get_tile(x, y)
			if tile_id == Tiles.Tile.LAMP:
				nearby_lamp = true
				break
			if tile_id in [Tiles.Tile.WALL, Tiles.Tile.REINFORCED, Tiles.Tile.BRICK]:
				walls += 1
			if tile_id in [Tiles.Tile.FLOOR, Tiles.Tile.BRICK]:
				floor_found = true
		if nearby_lamp:
			break
	_sampled_shelter = nearby_lamp or (walls >= 3 and floor_found)


func set_fault_warning_phase(next_phase: int) -> void:
	if biome != Generator.Biome.GLASSFALL:
		return
	var phase_value := clampi(next_phase, 0, 3)
	if fault_warning_phase == phase_value:
		return
	fault_warning_phase = phase_value
	# Preview art changes; no collision rebuild or terrain edit is required.
	var first_chunk := int((GLASSFALL_FAULT_X - GLASSFALL_FAULT_RADIUS) / CHUNK_WIDTH)
	var last_chunk := int((GLASSFALL_FAULT_X + GLASSFALL_FAULT_RADIUS) / CHUNK_WIDTH)
	for index in range(first_chunk, last_chunk + 1):
		if chunk_views.has(index):
			(chunk_views[index] as CanvasItem).queue_redraw()


func has_tile_near(world_position: Vector2, tile_id: int, radius: int = 3) -> bool:
	var origin := world_to_cell(world_position)
	for y in range(origin.y - radius, origin.y + radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			if get_tile(x, y) == tile_id:
				return true
	return false


func serialize_meta() -> Dictionary:
	return {"spawn": [spawn_cell.x, spawn_cell.y]}


func _set_tile_batched(x: int, y: int, tile_id: int) -> void:
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	var index := cell_index(x, y)
	var key := str(index)
	if tile_id == int(base_cells[index]):
		modifications.erase(key)
	else:
		modifications[key] = tile_id
	cracks.erase(index)
	var chunk_index := int(x / CHUNK_WIDTH)
	_dirty_chunks[chunk_index] = true


func _refresh_cell(x: int, _y: int) -> void:
	var chunk_index := int(x / CHUNK_WIDTH)
	if _batching:
		_dirty_chunks[chunk_index] = true
		return
	_refresh_chunk(chunk_index)


func _refresh_dirty_chunks() -> void:
	if not _dirty_chunks.is_empty():
		_environment_revision += 1
	for chunk_index in _dirty_chunks.keys():
		_refresh_chunk(int(chunk_index))
	_dirty_chunks.clear()


func _refresh_chunk(chunk_index: int) -> void:
	if chunk_views.has(chunk_index):
		(chunk_views[chunk_index] as CanvasItem).queue_redraw()
	if not is_inside_tree():
		return
	var old_body: StaticBody2D = collision_chunks.get(chunk_index)
	if is_instance_valid(old_body):
		remove_child(old_body)
		old_body.queue_free()
	var start_x := chunk_index * CHUNK_WIDTH
	var end_x := mini(world_width, start_x + CHUNK_WIDTH)
	var body := StaticBody2D.new()
	body.name = "CollisionChunk_%d" % chunk_index
	body.collision_layer = 1
	body.collision_mask = 1
	body.position.x = start_x * TILE_SIZE
	for y in range(world_height):
		var run_start := -1
		for x in range(start_x, end_x + 1):
			var solid := x < end_x and Tiles.is_solid(get_tile(x, y))
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - run_start) * TILE_SIZE, TILE_SIZE)
				var collision := CollisionShape2D.new()
				collision.shape = shape
				collision.position = Vector2(
					(run_start - start_x + (x - run_start) * 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE
				)
				body.add_child(collision)
				run_start = -1
	add_child(body)
	collision_chunks[chunk_index] = body


func _build_chunks() -> void:
	for node in chunk_views.values():
		if is_instance_valid(node):
			node.queue_free()
	for node in collision_chunks.values():
		if is_instance_valid(node):
			node.queue_free()
	chunk_views.clear()
	collision_chunks.clear()
	if not is_inside_tree():
		return
	var total_chunks := int(ceil(float(world_width) / float(CHUNK_WIDTH)))
	for chunk_index in range(total_chunks):
		var start_x := chunk_index * CHUNK_WIDTH
		var end_x := mini(world_width, start_x + CHUNK_WIDTH)
		var view := Node2D.new()
		view.name = "TerrainChunk_%d" % chunk_index
		view.set_script(load("res://scripts/world/terrain_chunk.gd"))
		add_child(view)
		view.call("configure", self, chunk_index, start_x, end_x)
		chunk_views[chunk_index] = view
		_refresh_chunk(chunk_index)
