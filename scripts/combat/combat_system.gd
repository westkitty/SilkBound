class_name CombatSystem
extends RefCounted


static func can_hit_melee(
	attacker_position: Vector2, target_position: Vector2, facing: int, reach: float
) -> bool:
	var offset := target_position - attacker_position
	return offset.length() <= reach and signf(offset.x) == float(facing)


static func apply_damage(current_health: float, damage_amount: float) -> Dictionary:
	var applied := maxf(0.0, damage_amount)
	var remaining := maxf(0.0, current_health - applied)
	return {
		"applied": minf(maxf(0.0, current_health), applied),
		"health": remaining,
		"defeated": remaining <= 0.0
	}
