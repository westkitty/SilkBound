class_name QuestSystem
extends RefCounted

const QUESTS := {
	"ship_patch":
	{
		"title": "Keep the hull together",
		"brief": "Recover 6 scrap and 4 ferrite, then repair the drive at the ship console.",
		"source": "Ship console"
	},
	"iri_supplies":
	{
		"title": "A seat for Iri",
		"brief": "Iri needs 2 field rations before she will risk the trip back to your ship.",
		"source": "Iri, Ashlands"
	},
	"fault_survey":
	{
		"title": "Map the shear",
		"brief": "Scan the transformed fault on Glassfall and record a safe route around it.",
		"source": "Survey scanner"
	},
	"archive_delivery":
	{
		"title": "Paper without a reader",
		"brief": "Bring 3 archive shards to Vale on the Drowned Remnant.",
		"source": "Vale, Drowned Remnant"
	}
}

var states: Dictionary = {}


func setup(saved: Dictionary = {}) -> void:
	states.clear()
	for raw_quest_id in QUESTS.keys():
		var quest_id := String(raw_quest_id)
		var default_status := "active" if quest_id == "ship_patch" else "available"
		var raw_entry: Variant = saved.get(quest_id, {})
		var status_value := default_status
		var note := (
			"The ship console is waiting for recoverable plate and ferrite."
			if quest_id == "ship_patch"
			else ""
		)
		if raw_entry is Dictionary:
			var saved_status := String(raw_entry.get("status", default_status))
			if saved_status in ["available", "active", "complete"]:
				status_value = saved_status
			var saved_note: Variant = raw_entry.get("note", note)
			if saved_note is String:
				note = saved_note
		states[quest_id] = {"status": status_value, "note": note}


func status(quest_id: String) -> String:
	var entry: Variant = states.get(quest_id, {})
	return String(entry.get("status", "available")) if entry is Dictionary else "available"


func activate(quest_id: String, note: String = "") -> bool:
	if not QUESTS.has(quest_id) or status(quest_id) == "complete":
		return false
	states[quest_id] = {"status": "active", "note": note}
	return true


func complete(quest_id: String, note: String = "") -> bool:
	if not QUESTS.has(quest_id) or status(quest_id) == "complete":
		return false
	states[quest_id] = {"status": "complete", "note": note}
	return true


func set_note(quest_id: String, note: String) -> void:
	if not states.has(quest_id):
		activate(quest_id)
	var entry: Dictionary = states[quest_id]
	entry["note"] = note
	states[quest_id] = entry


func is_complete(quest_id: String) -> bool:
	return status(quest_id) == "complete"


func to_dict() -> Dictionary:
	return states.duplicate(true)
