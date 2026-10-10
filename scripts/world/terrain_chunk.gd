extends Node2D

const Tiles = preload("res://scripts/world/tile_catalog.gd")
const TILE_SIZE := 32
const ATLAS_COLUMNS := 8
const TEXTURE := preload("res://assets/tiles/terrain_atlas.png")

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
	for y in range(world_height):
		for x in range(first_x, end_x):
			var tile_id := int(grid.call("get_tile", x, y))
			if tile_id == Tiles.Tile.AIR:
				continue
			var source := Rect2(
				(tile_id % ATLAS_COLUMNS) * 16, int(tile_id / ATLAS_COLUMNS) * 16, 16, 16
			)
			var destination := Rect2((x - first_x) * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var tint := Color.WHITE
			if tile_id == Tiles.Tile.WATER:
				tint = Color(0.77, 0.92, 1.0, 0.86)
			elif tile_id == Tiles.Tile.GLASS or tile_id == Tiles.Tile.FAULT:
				tint = Color(1.0, 0.88, 0.94, 1.0)
			draw_texture_rect_region(TEXTURE, destination, source, tint)
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
			if highlights.has(str(cell_index)):
				draw_rect(destination.grow(-3.0), Color(0.19, 0.84, 0.91, 0.72), false, 2.0)
