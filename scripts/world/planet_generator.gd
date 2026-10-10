class_name PlanetGenerator
extends RefCounted

enum Biome { ASHLANDS, GLASSFALL, DROWNED_REMNANT }

const Tiles = preload("res://scripts/world/tile_catalog.gd")

const DEFAULT_WIDTH := 288
const DEFAULT_HEIGHT := 88
const SPAWN_X := 10


static func generate(
	world_seed: int, biome: int, width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var cells := PackedInt32Array()
	cells.resize(width * height)
	cells.fill(Tiles.Tile.AIR)
	var surface := PackedInt32Array()
	surface.resize(width)
	var rolling := float(height) * 0.31
	var phase := float(abs(world_seed) % 1000) * 0.017

	for x in range(width):
		rolling = clampf(rolling + rng.randf_range(-0.78, 0.78), 20.0, 31.0)
		var surface_y := clampi(
			int(
				(
					rolling
					+ sin(float(x) * 0.047 + phase) * 2.1
					+ sin(float(x) * 0.13 + phase * 0.5) * 0.9
				)
			),
			18,
			34
		)
		surface[x] = surface_y
		for y in range(surface_y, height):
			var depth := y - surface_y
			var material := _stratum_for(biome, depth, rng)
			cells[y * width + x] = material
		# Sparse surface growth makes fiber gathering available without a tool upgrade.
		if x > 16 and x % rng.randi_range(9, 17) == 0 and rng.randf() < 0.78:
			cells[(surface_y - 1) * width + x] = Tiles.Tile.FIBER

	# Irregular cavern pockets are deterministic and always stay below the thin crust.
	var cave_count := maxi(14, int(width / 16))
	for cave_index in range(cave_count):
		var cx := rng.randi_range(5, width - 6)
		var cy := rng.randi_range(surface[cx] + 5, mini(height - 8, surface[cx] + 31))
		var rx := rng.randi_range(3, 10)
		var ry := rng.randi_range(2, 5)
		for y in range(maxi(1, cy - ry), mini(height - 1, cy + ry + 1)):
			for x in range(maxi(1, cx - rx), mini(width - 1, cx + rx + 1)):
				var normalized := (
					pow(float(x - cx) / float(rx), 2.0) + pow(float(y - cy) / float(ry), 2.0)
				)
				if normalized <= 1.0 and y > surface[x] + 2:
					var is_pool := (
						biome == Biome.DROWNED_REMNANT and rng.randf() < 0.18 and y > cy - 1
					)
					cells[y * width + x] = Tiles.Tile.WATER if is_pool else Tiles.Tile.AIR

	# Ore clusters and wreckage are placed after caverns so their outlines remain discoverable.
	var deposit_types: Array[int]
	match biome:
		Biome.ASHLANDS:
			deposit_types = [
				Tiles.Tile.FERRITE, Tiles.Tile.COPPER, Tiles.Tile.SCRAP, Tiles.Tile.ARCHIVE
			]
		Biome.GLASSFALL:
			deposit_types = [
				Tiles.Tile.FERRITE,
				Tiles.Tile.COPPER,
				Tiles.Tile.CRYSTAL,
				Tiles.Tile.GLASS,
				Tiles.Tile.SCRAP
			]
		_:
			deposit_types = [
				Tiles.Tile.FERRITE,
				Tiles.Tile.COPPER,
				Tiles.Tile.ARCHIVE,
				Tiles.Tile.CRYSTAL,
				Tiles.Tile.SILT
			]
	for vein_index in range(42):
		var vx := rng.randi_range(3, width - 4)
		var vy := rng.randi_range(surface[vx] + 3, height - 4)
		var ore: int = deposit_types[rng.randi_range(0, deposit_types.size() - 1)]
		var radius := rng.randi_range(1, 3)
		for y in range(maxi(1, vy - radius), mini(height - 1, vy + radius + 1)):
			for x in range(maxi(1, vx - radius), mini(width - 1, vx + radius + 1)):
				if (
					abs(x - vx) + abs(y - vy) <= radius + 1
					and cells[y * width + x] != Tiles.Tile.AIR
				):
					cells[y * width + x] = ore

	# Deliberately small, climbable salvage shelters: generated terrain, not decorative set dressing.
	var structures: Array[Dictionary] = []
	var structure_count := 3
	for structure_index in range(structure_count):
		var sx := 37 + structure_index * 69 + rng.randi_range(-8, 8)
		if sx < 24 or sx + 10 >= width:
			continue
		var sy := surface[sx]
		var span := 7 + rng.randi_range(0, 2)
		for dx in range(span):
			cells[(sy - 1) * width + sx + dx] = Tiles.Tile.BRICK
		for wall_y in range(sy - 5, sy - 1):
			cells[wall_y * width + sx] = Tiles.Tile.BRICK
			cells[wall_y * width + sx + span - 1] = Tiles.Tile.BRICK
		for dx in range(2, span - 2):
			if rng.randf() < 0.7:
				cells[(sy - 5) * width + sx + dx] = Tiles.Tile.BRICK
		cells[(sy - 2) * width + sx + 1] = Tiles.Tile.ARCHIVE
		structures.append({"x": sx, "y": sy - 1, "kind": "salvage_shelter"})

	# A clear, level landing shelf guarantees safe spawning and a visible way back to the ship.
	var landing_y := surface[SPAWN_X]
	for x in range(2, 20):
		surface[x] = landing_y
		for y in range(landing_y - 5, landing_y):
			cells[y * width + x] = Tiles.Tile.AIR
		cells[landing_y * width + x] = (
			Tiles.Tile.ASH
			if biome == Biome.ASHLANDS
			else (Tiles.Tile.GLASS if biome == Biome.GLASSFALL else Tiles.Tile.SILT)
		)

	# Place the guaranteed salvage after clearing the shelf so no seed can erase it.
	var guaranteed_x := 15
	var guaranteed_y := surface[guaranteed_x]
	cells[guaranteed_y * width + guaranteed_x] = Tiles.Tile.SCRAP
	cells[(guaranteed_y + 1) * width + guaranteed_x] = Tiles.Tile.FERRITE
	cells[(guaranteed_y + 1) * width + guaranteed_x + 1] = Tiles.Tile.COPPER
	cells[(guaranteed_y + 2) * width + guaranteed_x] = Tiles.Tile.FERRITE
	cells[(guaranteed_y + 2) * width + guaranteed_x + 1] = Tiles.Tile.SCRAP
	if biome == Biome.GLASSFALL:
		cells[(guaranteed_y + 1) * width + guaranteed_x + 2] = Tiles.Tile.CRYSTAL
		cells[(guaranteed_y + 2) * width + guaranteed_x + 2] = Tiles.Tile.CRYSTAL
	elif biome == Biome.DROWNED_REMNANT:
		cells[(guaranteed_y + 1) * width + guaranteed_x + 2] = Tiles.Tile.ARCHIVE

	return {
		"seed": world_seed,
		"biome": biome,
		"width": width,
		"height": height,
		"cells": cells,
		"surface": surface,
		"structures": structures,
		"spawn": Vector2i(SPAWN_X, landing_y - 2)
	}


static func _stratum_for(biome: int, depth: int, rng: RandomNumberGenerator) -> int:
	if depth == 0:
		match biome:
			Biome.ASHLANDS:
				return Tiles.Tile.ASH
			Biome.GLASSFALL:
				return Tiles.Tile.GLASS if rng.randf() < 0.72 else Tiles.Tile.BASALT
			_:
				return Tiles.Tile.SILT
	if depth < 4:
		if biome == Biome.DROWNED_REMNANT and rng.randf() < 0.15:
			return Tiles.Tile.WATER
		return Tiles.Tile.SOIL if biome != Biome.GLASSFALL else Tiles.Tile.BASALT
	if biome == Biome.GLASSFALL:
		return Tiles.Tile.BASALT if rng.randf() < 0.72 else Tiles.Tile.GLASS
	if biome == Biome.DROWNED_REMNANT:
		return Tiles.Tile.BASALT if rng.randf() < 0.55 else Tiles.Tile.SILT
	return Tiles.Tile.BASALT if rng.randf() < 0.84 else Tiles.Tile.SOIL
