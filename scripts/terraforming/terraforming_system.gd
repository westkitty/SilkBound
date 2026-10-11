class_name TerraformingSystem
extends RefCounted

var phase: int = 0
var phase_timer: float = 0.0
var elapsed: float = 0.0
var transformed: bool = false
var center_cell := Vector2i(-1, -1)
var changed_cells: int = 0


func setup(saved: Dictionary = {}) -> void:
	phase = clampi(int(saved.get("phase", 0)), 0, 3)
	phase_timer = maxf(0.0, float(saved.get("phase_timer", 0.0)))
	elapsed = maxf(0.0, float(saved.get("elapsed", 0.0)))
	transformed = bool(saved.get("transformed", phase >= 3))
	var saved_center: Variant = saved.get("center", [-1, -1])
	if saved_center is Array and saved_center.size() >= 2:
		center_cell = Vector2i(int(saved_center[0]), int(saved_center[1]))
	changed_cells = int(saved.get("changed_cells", 0))


func tick(delta: float, game: Node) -> void:
	if String(game.get("current_planet_id")) != "glassfall" or transformed:
		return
	elapsed += delta
	phase_timer += delta
	if phase == 0 and phase_timer >= 8.0:
		phase = 1
		phase_timer = 0.0
		game.call("terraform_notice", 1)
	elif phase == 1 and phase_timer >= 14.0:
		phase = 2
		phase_timer = 0.0
		game.call("terraform_notice", 2)
	elif phase == 2 and phase_timer >= 18.0:
		var world: WorldGrid = game.get("world")
		if world == null:
			return
		var result := world.apply_terraform(
			WorldGrid.GLASSFALL_FAULT_X, WorldGrid.GLASSFALL_FAULT_RADIUS
		)
		center_cell = Vector2i(result["center"])
		changed_cells = int(result["changed"])
		phase = 3
		phase_timer = 0.0
		transformed = true
		game.call("terraform_notice", 3)


func phase_name() -> String:
	match phase:
		0:
			return "UNSTABLE BASELINE"
		1:
			return "WARNING / GEOLOGICAL SHIFT"
		2:
			return "ESCALATION / ROUTE FAILURE"
		3:
			return "TRANSFORMED / SHEAR ACTIVE"
	return "UNKNOWN"


func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"phase_timer": phase_timer,
		"elapsed": elapsed,
		"transformed": transformed,
		"center": [center_cell.x, center_cell.y],
		"changed_cells": changed_cells
	}
