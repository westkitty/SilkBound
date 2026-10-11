class_name Crafting
extends RefCounted

const Items = preload("res://scripts/inventory/item_catalog.gd")


static func can_craft(recipe_id: String, inventory: Inventory) -> bool:
	if not Items.RECIPES.has(recipe_id):
		return false
	var recipe: Dictionary = Items.RECIPES[recipe_id]
	if not inventory.has_cost(recipe["cost"]):
		return false
	var trial := inventory.duplicate_inventory()
	if not trial.spend(recipe["cost"]):
		return false
	for raw_id in recipe["output"].keys():
		if not trial.can_add(String(raw_id), int(recipe["output"][raw_id])):
			return false
	return true


static func craft(recipe_id: String, inventory: Inventory) -> Dictionary:
	if not Items.RECIPES.has(recipe_id):
		return {"ok": false, "reason": "Unknown recipe."}
	var recipe: Dictionary = Items.RECIPES[recipe_id]
	if not can_craft(recipe_id, inventory):
		return {"ok": false, "reason": "Missing ingredients or no free inventory slot."}
	# Stage changes on a copy so a failed output can never consume ingredients.
	var trial := inventory.duplicate_inventory()
	if not trial.spend(recipe["cost"]):
		return {"ok": false, "reason": "Ingredients changed before crafting."}
	for raw_id in recipe["output"].keys():
		var item_id := String(raw_id)
		if trial.add_item(item_id, int(recipe["output"][raw_id])) != 0:
			return {"ok": false, "reason": "Inventory capacity is full."}
	inventory.stacks = trial.stacks
	return {"ok": true, "recipe": recipe_id, "output": recipe["output"].duplicate(true)}
