class_name SurvivalSystem
extends RefCounted

var health: float = 100.0
var energy: float = 100.0
var oxygen: float = 100.0
var exposure: float = 0.0
var _damage_clock: float = 0.0


func setup(saved: Dictionary = {}) -> void:
	health = clampf(float(saved.get("health", 100.0)), 0.0, 100.0)
	energy = clampf(float(saved.get("energy", 100.0)), 0.0, 100.0)
	oxygen = clampf(float(saved.get("oxygen", 100.0)), 0.0, 100.0)
	exposure = clampf(float(saved.get("exposure", 0.0)), 0.0, 100.0)
	_damage_clock = 0.0


func tick(delta: float, environment: Dictionary) -> bool:
	var underwater := bool(environment.get("underwater", false))
	var sheltered := bool(environment.get("sheltered", false))
	var thermal_stress := bool(environment.get("thermal_stress", false))
	var sprinting := bool(environment.get("sprinting", false))
	if underwater:
		oxygen = maxf(0.0, oxygen - delta * 13.0)
	else:
		oxygen = minf(100.0, oxygen + delta * (28.0 if sheltered else 16.0))
	if thermal_stress and not sheltered:
		exposure = minf(100.0, exposure + delta * 4.2)
	else:
		exposure = maxf(0.0, exposure - delta * (5.5 if sheltered else 2.0))
	if sprinting:
		energy = maxf(0.0, energy - delta * 7.0)
	else:
		energy = minf(100.0, energy + delta * (4.0 if sheltered else 1.4))
	if sheltered and oxygen > 25.0 and exposure < 45.0:
		health = minf(100.0, health + delta * 0.8)
	_damage_clock += delta
	if _damage_clock >= 1.0:
		_damage_clock = 0.0
		if oxygen <= 0.0 or exposure >= 100.0:
			health = maxf(0.0, health - 5.0)
	return health <= 0.0


func take_damage(amount: float) -> bool:
	health = maxf(0.0, health - maxf(0.0, amount))
	return health <= 0.0


func restore(health_amount: float, energy_amount: float, oxygen_amount: float = 0.0) -> void:
	health = minf(100.0, health + maxf(0.0, health_amount))
	energy = minf(100.0, energy + maxf(0.0, energy_amount))
	oxygen = minf(100.0, oxygen + maxf(0.0, oxygen_amount))


func to_dict() -> Dictionary:
	return {"health": health, "energy": energy, "oxygen": oxygen, "exposure": exposure}
