class_name Inventory
extends RefCounted

const Items = preload("res://scripts/inventory/item_catalog.gd")
const DEFAULT_CAPACITY := 24

var capacity: int = DEFAULT_CAPACITY
# Counts are aggregated by item ID; slot use is calculated from each item's stack limit.
var stacks: Dictionary = {}


func setup(initial: Dictionary = {}, slot_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = clampi(slot_capacity, 1, 128)
	stacks.clear()
	for raw_id in initial.keys():
		var item_id := String(raw_id)
		var quantity := maxi(0, int(initial[raw_id]))
		if quantity > 0 and Items.ITEMS.has(item_id):
			var remainder := add_item(item_id, quantity)
			if remainder > 0:
				push_warning("Inventory load exceeded capacity; excess %s was discarded." % item_id)


func count(item_id: String) -> int:
	return int(stacks.get(item_id, 0))


func has_cost(cost: Dictionary) -> bool:
	for raw_id in cost.keys():
		if count(String(raw_id)) < int(cost[raw_id]):
			return false
	return true


func can_add(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not Items.ITEMS.has(item_id):
		return false
	var stack_limit := Items.max_stack(item_id)
	var existing := count(item_id)
	var existing_slots := int(ceil(float(existing) / float(stack_limit))) if existing > 0 else 0
	var remaining_room := existing_slots * stack_limit - existing
	var remaining := amount - remaining_room
	if remaining <= 0:
		return true
	var slots_needed := int(ceil(float(remaining) / float(stack_limit)))
	return _used_slots() + slots_needed <= capacity


func add_item(item_id: String, amount: int = 1) -> int:
	if amount <= 0 or not Items.ITEMS.has(item_id):
		return amount
	var stack_limit := Items.max_stack(item_id)
	var existing := count(item_id)
	var existing_slots := int(ceil(float(existing) / float(stack_limit))) if existing > 0 else 0
	var free_slots := maxi(0, capacity - _used_slots())
	var item_capacity := existing_slots * stack_limit + free_slots * stack_limit
	var accepted := mini(amount, maxi(0, item_capacity - existing))
	if accepted > 0:
		stacks[item_id] = existing + accepted
	return amount - accepted


func spend(cost: Dictionary) -> bool:
	if not has_cost(cost):
		return false
	for raw_id in cost.keys():
		var item_id := String(raw_id)
		var new_count := int(stacks[item_id]) - int(cost[raw_id])
		if new_count <= 0:
			stacks.erase(item_id)
		else:
			stacks[item_id] = new_count
	return true


func duplicate_inventory() -> Inventory:
	var result := Inventory.new()
	result.capacity = capacity
	result.stacks = stacks.duplicate(true)
	return result


func to_dict() -> Dictionary:
	return {"capacity": capacity, "stacks": stacks.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	var raw_stacks: Variant = data.get("stacks", data)
	if raw_stacks is Dictionary:
		setup(raw_stacks, int(data.get("capacity", DEFAULT_CAPACITY)))
	else:
		setup()


func item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in stacks.keys():
		if int(stacks[item_id]) > 0:
			result.append(String(item_id))
	result.sort()
	return result


func _used_slots() -> int:
	var used := 0
	for raw_id in stacks.keys():
		var item_id := String(raw_id)
		var quantity := int(stacks[raw_id])
		if quantity > 0:
			used += int(ceil(float(quantity) / float(Items.max_stack(item_id))))
	return used
