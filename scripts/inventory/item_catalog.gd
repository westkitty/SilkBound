class_name ItemCatalog
extends RefCounted

const ITEMS := {
	"scrap":
	{
		"name": "Hull scrap",
		"icon": 0,
		"stack": 99,
		"description": "Recoverable plate and fasteners from abandoned equipment."
	},
	"ferrite":
	{
		"name": "Ferrite",
		"icon": 1,
		"stack": 99,
		"description": "Common structural ore. The cutter can separate it from basalt."
	},
	"copper":
	{
		"name": "Copper",
		"icon": 2,
		"stack": 99,
		"description": "Conductive ore for lamps, coils and ship systems."
	},
	"glass":
	{
		"name": "Volcanic glass",
		"icon": 3,
		"stack": 99,
		"description": "Sharp, heat-resistant geological glass. Not a gateway material."
	},
	"crystal":
	{
		"name": "Silicate crystal",
		"icon": 4,
		"stack": 99,
		"description": "A stable mineral with useful optical and thermal properties."
	},
	"fiber":
	{
		"name": "Resin fiber",
		"icon": 5,
		"stack": 99,
		"description": "Tough surface growth, useful for seals and simple rations."
	},
	"organic_gel":
	{
		"name": "Organic gel",
		"icon": 6,
		"stack": 99,
		"description": "A locally produced nutrient and medical binder."
	},
	"archive_shard":
	{
		"name": "Archive shard",
		"icon": 7,
		"stack": 99,
		"description":
		"Damaged Administration data hardware. It contains no surviving consciousness."
	},
	"silt":
	{
		"name": "Packed silt",
		"icon": 8,
		"stack": 99,
		"description": "Stable fill for patching a sheltered floor."
	},
	"rations":
	{
		"name": "Field ration",
		"icon": 9,
		"stack": 20,
		"description": "Restores energy and a small amount of health."
	},
	"medfoam":
	{
		"name": "Medfoam",
		"icon": 10,
		"stack": 20,
		"description": "A compact emergency sealant for suit and wound repairs."
	},
	"salvaged_brick":
	{
		"name": "Salvaged brick",
		"icon": 11,
		"stack": 99,
		"description": "Reusable masonry cut from ruined shelters."
	},
	"wall":
	{
		"name": "Shelter wall",
		"icon": 12,
		"stack": 99,
		"description": "A buildable pressure-panel segment."
	},
	"floor":
	{
		"name": "Decking",
		"icon": 13,
		"stack": 99,
		"description": "A stable platform tile for a field shelter."
	},
	"door":
	{
		"name": "Pressure door",
		"icon": 14,
		"stack": 20,
		"description": "A compact, passable shelter entrance."
	},
	"lamp":
	{
		"name": "Survey lamp",
		"icon": 15,
		"stack": 20,
		"description": "A placed lamp marks shelter and emits a low blue work light."
	},
	"crate":
	{
		"name": "Storage crate",
		"icon": 16,
		"stack": 20,
		"description": "A persistent field cache for transferring items."
	},
	"workbench":
	{
		"name": "Field workbench",
		"icon": 17,
		"stack": 10,
		"description": "A compact engineering surface and visible shelter fixture."
	},
	"reinforced_panel":
	{
		"name": "Reinforced panel",
		"icon": 18,
		"stack": 99,
		"description": "A stronger wall segment for a high-pressure site."
	},
	"repair_kit":
	{
		"name": "Repair kit",
		"icon": 19,
		"stack": 20,
		"description": "Repairs the ship's damaged frame when used at its console."
	},
	"field_coil":
	{
		"name": "Field coil",
		"icon": 20,
		"stack": 10,
		"description":
		"An ordinary copper-and-crystal ship component; it does not manipulate Starsilk."
	},
	"coolant_loop":
	{
		"name": "Coolant loop",
		"icon": 21,
		"stack": 10,
		"description": "A conventional heat exchanger for a second safe travel envelope."
	},
	"thermal_lining":
	{
		"name": "Thermal lining",
		"icon": 18,
		"stack": 10,
		"description": "A conventional suit layer that slows heat exposure near shear-glass."
	},
	"cargo_frame":
	{
		"name": "Cargo frame",
		"icon": 16,
		"stack": 10,
		"description": "An installable rack that expands local stack capacity."
	},
	"scanner_lens":
	{
		"name": "Scanner lens",
		"icon": 20,
		"stack": 10,
		"description": "A copper-and-glass optic that widens the scanner sweep."
	},
	"salvage_cutter":
	{
		"name": "Salvage cutter",
		"icon": 22,
		"stack": 1,
		"description": "Starter tool calibrated for local stone, ore and wreckage."
	},
	"survey_scanner":
	{
		"name": "Survey scanner",
		"icon": 23,
		"stack": 1,
		"description": "Reads geology, atmosphere, ruins and bounded pressure changes."
	}
}

const RECIPES := {
	"field_ration":
	{"name": "Field rations ×2", "cost": {"fiber": 2, "organic_gel": 1}, "output": {"rations": 2}},
	"medfoam":
	{"name": "Medfoam", "cost": {"fiber": 1, "organic_gel": 2}, "output": {"medfoam": 1}},
	"shelter_wall":
	{"name": "Shelter walls ×2", "cost": {"scrap": 2, "fiber": 1}, "output": {"wall": 2}},
	"decking": {"name": "Decking ×2", "cost": {"ferrite": 2, "scrap": 1}, "output": {"floor": 2}},
	"pressure_door":
	{"name": "Pressure door", "cost": {"scrap": 2, "ferrite": 1}, "output": {"door": 1}},
	"survey_lamp":
	{"name": "Survey lamp", "cost": {"copper": 1, "glass": 1}, "output": {"lamp": 1}},
	"storage_crate":
	{"name": "Storage crate", "cost": {"scrap": 4, "fiber": 2}, "output": {"crate": 1}},
	"field_workbench":
	{"name": "Field workbench", "cost": {"scrap": 5, "copper": 2}, "output": {"workbench": 1}},
	"reinforced_panel":
	{
		"name": "Reinforced panels ×2",
		"cost": {"ferrite": 2, "scrap": 2, "glass": 1},
		"output": {"reinforced_panel": 2}
	},
	"repair_kit":
	{
		"name": "Ship repair kit",
		"cost": {"scrap": 4, "ferrite": 3, "copper": 1},
		"output": {"repair_kit": 1}
	},
	"field_coil":
	{
		"name": "Field coil",
		"cost": {"copper": 3, "scrap": 2, "crystal": 2},
		"output": {"field_coil": 1}
	},
	"coolant_loop":
	{
		"name": "Coolant loop",
		"cost": {"ferrite": 4, "glass": 3, "crystal": 2},
		"output": {"coolant_loop": 1}
	},
	"thermal_lining":
	{
		"name": "Thermal lining",
		"cost": {"glass": 3, "fiber": 3, "ferrite": 2},
		"output": {"thermal_lining": 1}
	},
	"cargo_frame":
	{
		"name": "Cargo frame",
		"cost": {"scrap": 4, "ferrite": 4, "fiber": 2},
		"output": {"cargo_frame": 1}
	},
	"scanner_lens":
	{"name": "Scanner lens", "cost": {"glass": 2, "copper": 2}, "output": {"scanner_lens": 1}}
}

const DISCOVERIES := {
	"starsilk":
	{
		"label": "CANON CONTEXT — Starsilk",
		"text":
		"Starsilk is literal programmable cosmological material. Extracting it from a star causes immediate gravitational collapse into a black hole. It is not ordinary ore and is never offered as a player resource."
	},
	"macros":
	{
		"label": "CANON CONTEXT — Macros",
		"text":
		"Macros are repeatable executable reality operations, not generic spells. This peripheral salvage simulation gives the player no Starsilk manipulation."
	},
	"blood_ring":
	{
		"label": "CANON CONTEXT — Blood Rings",
		"text":
		"Blood Rings are red vitrified-glass propaganda structures, not magical gateways. No such structure is used as a travel shortcut here."
	},
	"tiger":
	{
		"label": "CANON CONTEXT — Shard-God Tiger",
		"text":
		"Tiger is controlled, calculating, pragmatic and deliberately cruel. This operational simulation does not invent a boss encounter or randomized powers for him."
	},
	"peripheral_log":
	{
		"label": "SIMULATION RECORD — Peripheral survey",
		"text":
		"These generated planets, survivors, ship and outcomes are non-canon operational inventions set during Years 7–120 of the Blood Eclipse War."
	},
	"ashlands":
	{
		"label": "SIMULATION RECORD — Ashlands",
		"text":
		"The collapsed horizon gantry appears older than the salvage vessel; no crew ID or date survived. Ferrite and hull scrap cluster along a shallow shelf. This is an invented survey site, not a named canon location."
	},
	"glassfall":
	{
		"label": "SIMULATION RECORD — Glassfall",
		"text":
		"The distant shards read as a volcanic-glass ridge, not a structure. A local shear can overwrite a route and remain after travel. This generated pressure event is not a named catastrophe site."
	},
	"glassfall_before":
	{
		"label": "SIMULATION RECORD — Glassfall / Before",
		"text":
		"Survey readings show stressed, still-intact layers beneath the volcanic-glass ridge. A practical route exists here now; pressure can erase it. These measurements describe an invented survey event, not a named canon attack."
	},
	"glassfall_after":
	{
		"label": "SIMULATION RECORD — Glassfall / After",
		"text":
		"At the same survey coordinates, pressure has turned intact strata into a permanent open shear and an exposed fault. The before/after evidence changes the route, not the nature of Starsilk. The terrain and its damage persist on return."
	},
	"drowned":
	{
		"label": "SIMULATION RECORD — Drowned Remnant",
		"text":
		"Survey pylons and torn hull break the waterline; waterlogged passages hold inert archive hardware, not a surviving mind. This invented ruin field has an ordinary oxygen hazard. No named catastrophe is implied."
	}
}


static func item_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return String(ITEMS[item_id]["name"])
	return item_id.capitalize()


static func max_stack(item_id: String) -> int:
	if ITEMS.has(item_id):
		return int(ITEMS[item_id]["stack"])
	return 99
