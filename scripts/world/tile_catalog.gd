class_name TileCatalog
extends RefCounted

# IDs match their cells in assets/tiles/terrain_atlas.png.
enum Tile {
	AIR,
	ASH,
	SOIL,
	BASALT,
	FERRITE,
	COPPER,
	SCRAP,
	GLASS,
	CRYSTAL,
	WATER,
	SILT,
	ARCHIVE,
	FIBER,
	BRICK,
	WALL,
	FLOOR,
	DOOR,
	LAMP,
	CRATE,
	BENCH,
	REINFORCED,
	FAULT
}

const TILE_NAMES := {
	Tile.AIR: "Open air",
	Tile.ASH: "Ash crust",
	Tile.SOIL: "Packed regolith",
	Tile.BASALT: "Basalt",
	Tile.FERRITE: "Ferrite seam",
	Tile.COPPER: "Copper seam",
	Tile.SCRAP: "Hull scrap",
	Tile.GLASS: "Volcanic glass",
	Tile.CRYSTAL: "Silicate crystal",
	Tile.WATER: "Floodwater",
	Tile.SILT: "Waterlogged silt",
	Tile.ARCHIVE: "Archive alloy",
	Tile.FIBER: "Resinous growth",
	Tile.BRICK: "Salvaged brick",
	Tile.WALL: "Shelter wall",
	Tile.FLOOR: "Decking",
	Tile.DOOR: "Pressure door",
	Tile.LAMP: "Survey lamp",
	Tile.CRATE: "Storage crate",
	Tile.BENCH: "Field workbench",
	Tile.REINFORCED: "Reinforced panel",
	Tile.FAULT: "Shear glass"
}

const HARDNESS := {
	Tile.ASH: 0.65,
	Tile.SOIL: 0.8,
	Tile.BASALT: 1.55,
	Tile.FERRITE: 1.25,
	Tile.COPPER: 1.2,
	Tile.SCRAP: 0.9,
	Tile.GLASS: 1.35,
	Tile.CRYSTAL: 1.45,
	Tile.SILT: 0.7,
	Tile.ARCHIVE: 1.6,
	Tile.FIBER: 0.35,
	Tile.BRICK: 0.9,
	Tile.WALL: 1.1,
	Tile.FLOOR: 1.0,
	Tile.DOOR: 1.0,
	Tile.LAMP: 0.5,
	Tile.CRATE: 0.75,
	Tile.BENCH: 1.0,
	Tile.REINFORCED: 1.8,
	Tile.FAULT: 1.15
}

const BUILD_ITEMS := {
	"wall": Tile.WALL,
	"floor": Tile.FLOOR,
	"door": Tile.DOOR,
	"lamp": Tile.LAMP,
	"crate": Tile.CRATE,
	"workbench": Tile.BENCH,
	"reinforced_panel": Tile.REINFORCED,
	"salvaged_brick": Tile.BRICK
}


static func tile_name(tile_id: int) -> String:
	return String(TILE_NAMES.get(tile_id, "Unknown material"))


static func hardness(tile_id: int) -> float:
	return float(HARDNESS.get(tile_id, 1.0))


static func is_solid(tile_id: int) -> bool:
	return (
		tile_id != Tile.AIR
		and tile_id != Tile.WATER
		and tile_id != Tile.FIBER
		and tile_id != Tile.LAMP
		and tile_id != Tile.DOOR
	)


static func item_drop(tile_id: int) -> Dictionary:
	match tile_id:
		Tile.ASH:
			return {"item": "silt", "amount": 1}
		Tile.SOIL, Tile.SILT:
			return {"item": "silt", "amount": 1}
		Tile.BASALT:
			return {"item": "ferrite", "amount": 1}
		Tile.FERRITE:
			return {"item": "ferrite", "amount": 2}
		Tile.COPPER:
			return {"item": "copper", "amount": 2}
		Tile.SCRAP:
			return {"item": "scrap", "amount": 2}
		Tile.GLASS, Tile.FAULT:
			return {"item": "glass", "amount": 1}
		Tile.CRYSTAL:
			return {"item": "crystal", "amount": 1}
		Tile.ARCHIVE:
			return {"item": "archive_shard", "amount": 1}
		Tile.FIBER:
			return {"item": "fiber", "amount": 1}
		Tile.BRICK:
			return {"item": "salvaged_brick", "amount": 1}
		Tile.WALL:
			return {"item": "wall", "amount": 1}
		Tile.FLOOR:
			return {"item": "floor", "amount": 1}
		Tile.DOOR:
			return {"item": "door", "amount": 1}
		Tile.LAMP:
			return {"item": "lamp", "amount": 1}
		Tile.CRATE:
			return {"item": "crate", "amount": 1}
		Tile.BENCH:
			return {"item": "workbench", "amount": 1}
		Tile.REINFORCED:
			return {"item": "reinforced_panel", "amount": 1}
		_:
			return {}


static func is_building(tile_id: int) -> bool:
	return (
		tile_id
		in [
			Tile.WALL,
			Tile.FLOOR,
			Tile.DOOR,
			Tile.LAMP,
			Tile.CRATE,
			Tile.BENCH,
			Tile.REINFORCED,
			Tile.BRICK
		]
	)
