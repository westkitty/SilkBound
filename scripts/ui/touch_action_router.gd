class_name TouchActionRouter
extends RefCounted

# Keeps independent pointer identities per action. Releasing one finger never cancels
# another action or a virtual-stick pointer.
var _holders: Dictionary = {}


func press(action: String, pointer_id: int) -> bool:
	if not _holders.has(action):
		_holders[action] = {}
	var holders: Dictionary = _holders[action]
	var was_active := not holders.is_empty()
	holders[pointer_id] = true
	_holders[action] = holders
	return not was_active


func release(action: String, pointer_id: int) -> bool:
	if not _holders.has(action):
		return false
	var holders: Dictionary = _holders[action]
	holders.erase(pointer_id)
	var still_active := not holders.is_empty()
	if not still_active:
		_holders.erase(action)
	else:
		_holders[action] = holders
	return not still_active


func is_held(action: String) -> bool:
	return _holders.has(action) and not Dictionary(_holders[action]).is_empty()


func clear() -> void:
	_holders.clear()
