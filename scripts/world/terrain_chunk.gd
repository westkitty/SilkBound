extends Node2D

const Tiles = preload("res://scripts/world/tile_catalog.gd")
const TILE_SIZE := 32
const ATLAS_COLUMNS := 8
const ATLAS_VARIANTS := 4
const ATLAS_VARIANT_STRIDE := 22
const TEXTURE := preload("res://assets/tiles/terrain_atlas.png")
const SCAN_COLORS := {
	"ferrite": Color(0.19, 0.84, 0.91, 0.82),
	"copper": Color(1.0, 0.63, 0.32, 0.88),
	"crystal": Color(0.72, 0.86, 1.0, 0.9),
	"wreckage": Color(1.0, 0.78, 0.38, 0.9),
	"glass": Color(1.0, 0.42, 0.67, 0.88),
	"archive": Color(0.48, 1.0, 0.82, 0.9),
	"fiber": Color(0.7, 0.95, 0.46, 0.9),
	"fault": Color(1.0, 0.28, 0.42, 0.95)
}

var grid: Object
var chunk_index: int = 0
var first_x: int = 0
var end_x: int = 0


func configure(owner_grid: Node, index: int, start_x: int, finish_x: int) -> void:
	grid = owner_grid
	chunk_index = index
	first_x = start_x
	end_x = finish_x
	position.x = first_x * TILE_SIZE
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var world_height := int(grid.get("world_height"))
	var cracks: Dictionary = grid.get("cracks")
	var highlights: Dictionary = grid.get("scan_highlights")
	var phase := int(grid.get("fault_warning_phase"))
	var variation_seed := int(grid.get("world_seed")) & 3
	var preview_active := int(grid.get("biome")) == 1 and phase in [1, 2]
	for y in range(world_height):
		for x in range(first_x, end_x):
			var tile_id := int(grid.call("get_tile", x, y))
			if tile_id == Tiles.Tile.AIR:
				continue
			# Four deterministic visual variants preserve game logic, tile IDs,
			# serialized edits, collisions and the first atlas group's offsets.
			var variant := (x * 13 + y * 7 + (x >> 2) * (y >> 2) * 3 + variation_seed) & 3
			var visual_index := tile_id + variant * ATLAS_VARIANT_STRIDE
			var source := Rect2(
				(visual_index % ATLAS_COLUMNS) * 16,
				int(visual_index / ATLAS_COLUMNS) * 16,
				16,
				16
			)
			var destination := Rect2((x - first_x) * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var tint := Color.WHITE
			if tile_id == Tiles.Tile.WATER:
				tint = Color(0.77, 0.92, 1.0, 0.86)
			elif tile_id == Tiles.Tile.GLASS or tile_id == Tiles.Tile.FAULT:
				tint = Color(1.0, 0.88, 0.94, 1.0)
			draw_texture_rect_region(TEXTURE, destination, source, tint)
			if (
				preview_active
				and abs(x - WorldGrid.GLASSFALL_FAULT_X) <= WorldGrid.GLASSFALL_FAULT_RADIUS
				and y == int(grid.call("surface_at", x))
			):
				# Geological survey evidence, not an invented magical effect.
				var trace_color := (
					Color(0.94, 0.71, 0.38, 0.88)
					if phase == 1
					else Color(0.97, 0.39, 0.43, 0.98)
				)
				draw_line(
					destination.position + Vector2(2, 3),
					destination.position + Vector2(30, 3),
					trace_color,
					2.0
				)
				if phase == 2:
					draw_line(
						destination.position + Vector2(16, 3),
						destination.position + Vector2(16, 15),
						trace_color,
						2.0
					)
			var cell_index := int(grid.call("cell_index", x, y))
			if cracks.has(cell_index):
				var amount := float(cracks[cell_index])
				var shade := Color(0.07, 0.10, 0.16, clampf(amount / 95.0, 0.16, 0.76))
				draw_line(
					destination.position + Vector2(9, 5),
					destination.position + Vector2(16, 13),
					shade,
					2.0
				)
				draw_line(
					destination.position + Vector2(16, 13),
					destination.position + Vector2(11, 23),
					shade,
					2.0
				)
			var scan_category := String(highlights.get(str(cell_index), ""))
			if SCAN_COLORS.has(scan_category):
				var scan_color: Color = SCAN_COLORS[scan_category]
				draw_rect(destination.grow(-3.0), scan_color, false, 2.0)
