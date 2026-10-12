class_name SaveSystem
extends RefCounted

const SAVE_VERSION := 1
const SAVE_DIRECTORY := "user://saves"
const VALID_SLOT_CHARACTERS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"


static func save_slot(data: Dictionary, slot: String = "slot_01") -> bool:
	if not _valid_slot(slot):
		push_error("Refusing an invalid SilkBound save slot name.")
		return false
	var absolute_directory := ProjectSettings.globalize_path(SAVE_DIRECTORY)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create the local save directory: %s" % error_string(mkdir_error))
		return false
	var target := "%s/%s.json" % [SAVE_DIRECTORY, slot]
	var temporary := target + ".tmp"
	var backup := target + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "data": data}, "\t"))
	file.flush()
	file.close()
	var target_abs := ProjectSettings.globalize_path(target)
	var temp_abs := ProjectSettings.globalize_path(temporary)
	var backup_abs := ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(target):
		if (
			not bool(_read_save(target).get("ok", false))
			and bool(_read_save(backup).get("ok", false))
		):
			# Recovery must not rotate a damaged primary over the last valid backup.
			var remove_error := DirAccess.remove_absolute(target_abs)
			if remove_error != OK:
				DirAccess.remove_absolute(temp_abs)
				push_error("Could not remove the damaged save: %s" % error_string(remove_error))
				return false
		else:
			if FileAccess.file_exists(backup):
				var backup_remove_error := DirAccess.remove_absolute(backup_abs)
				if backup_remove_error != OK:
					DirAccess.remove_absolute(temp_abs)
					push_error("Could not rotate the save backup: %s" % error_string(backup_remove_error))
					return false
			var backup_error := DirAccess.rename_absolute(target_abs, backup_abs)
			if backup_error != OK:
				DirAccess.remove_absolute(temp_abs)
				push_error("Could not preserve the last good save: %s" % error_string(backup_error))
				return false
	var commit_error := DirAccess.rename_absolute(temp_abs, target_abs)
	if commit_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup_abs, target_abs)
		push_error("Could not finish the atomic save: %s" % error_string(commit_error))
		return false
	return true


static func load_slot(slot: String = "slot_01") -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "data": {}, "reason": "Invalid slot name."}
	var primary := "%s/%s.json" % [SAVE_DIRECTORY, slot]
	var result := _read_save(primary)
	if bool(result.get("ok", false)):
		return result
	var backup := _read_save(primary + ".bak")
	if bool(backup.get("ok", false)):
		backup["recovered"] = true
		backup["recovery_source"] = "backup"
		return backup
	# A process can terminate after flushing the new save, but before the
	# final rename. Recover a complete staged generation only when neither
	# the primary nor the last known-good backup can be read.
	var staged := _read_save(primary + ".tmp")
	if bool(staged.get("ok", false)):
		staged["recovered"] = true
		staged["recovery_source"] = "temporary"
		return staged
	return {
		"ok": false, "data": {}, "reason": String(result.get("reason", "No local save exists."))
	}


static func delete_slot(slot: String = "slot_01") -> void:
	if not _valid_slot(slot):
		return
	for suffix in [".json", ".json.bak", ".json.tmp"]:
		var path := "%s/%s%s" % [SAVE_DIRECTORY, slot, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "reason": "No local save exists."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "reason": "The save file could not be opened."}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"ok": false, "data": {}, "reason": "The save data is malformed."}
	var version := int(parsed.get("version", -1))
	if version != SAVE_VERSION or not parsed.get("data", null) is Dictionary:
		return {"ok": false, "data": {}, "reason": "Unsupported or incomplete save version."}
	return {"ok": true, "data": parsed["data"], "version": version, "recovered": false}


static func _valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 24:
		return false
	for character in slot:
		if VALID_SLOT_CHARACTERS.find(character) < 0:
			return false
	return true
