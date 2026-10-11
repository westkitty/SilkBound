class_name TravelSystem
extends RefCounted

const PLANETS := {
	"ashlands": {"name": "Ashlands", "biome": 0, "seed_offset": 101, "requirement": "starter"},
	"glassfall":
	{"name": "Glassfall Survey", "biome": 1, "seed_offset": 307, "requirement": "engine"},
	"drowned": {"name": "Drowned Remnant", "biome": 2, "seed_offset": 911, "requirement": "coolant"}
}


static func is_unlocked(planet_id: String, ship: Dictionary) -> bool:
	if not PLANETS.has(planet_id):
		return false
	match String(PLANETS[planet_id]["requirement"]):
		"starter":
			return true
		"engine":
			return bool(ship.get("engine_repaired", false))
		"coolant":
			return (
				bool(ship.get("engine_repaired", false))
				and bool(ship.get("coolant_installed", false))
			)
	return false


static func travel(state: Dictionary, planet_id: String, ship: Dictionary) -> Dictionary:
	if not is_unlocked(planet_id, ship):
		return {"ok": false, "reason": "That route is outside the ship's repaired envelope."}
	if not PLANETS.has(planet_id):
		return {"ok": false, "reason": "No surveyed destination matches that route."}
	var saved_visited: Variant = state.get("visited_planets", ["ashlands"])
	var visited: Array = saved_visited if saved_visited is Array else ["ashlands"]
	if not planet_id in visited:
		visited.append(planet_id)
	state["visited_planets"] = visited
	state["current_planet"] = planet_id
	return {"ok": true, "planet": planet_id}


static func planet_seed(base_seed: int, planet_id: String) -> int:
	if not PLANETS.has(planet_id):
		return 0
	return base_seed + int(PLANETS[planet_id]["seed_offset"])


static func destination_rows(ship: Dictionary, visited: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for planet_id in PLANETS.keys():
		rows.append(
			{
				"id": planet_id,
				"name": String(PLANETS[planet_id]["name"]),
				"unlocked": is_unlocked(String(planet_id), ship),
				"visited": planet_id in visited,
				"requirement": String(PLANETS[planet_id]["requirement"])
			}
		)
	return rows
