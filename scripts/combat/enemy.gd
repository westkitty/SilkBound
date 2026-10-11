class_name SilkboundEnemy
extends CharacterBody2D

const Combat = preload("res://scripts/combat/combat_system.gd")
const GRAVITY := 900.0

var game: Node
var kind: String = "scavenger"
var spawn_id: String = ""
var health: float = 34.0
var damage: float = 9.0
var move_speed: float = 56.0
var attack_range: float = 52.0
var _attack_cooldown := 0.0
var _telegraph := 0.0
var _hover_phase := 0.0
var _defeated := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("hostile_threats")
	_build_sprite()


func configure(
	owner_game: Node, enemy_kind: String, at_position: Vector2, identity: String = ""
) -> void:
	game = owner_game
	kind = enemy_kind
	spawn_id = identity
	global_position = at_position
	match kind:
		"admin_drone":
			health = 46.0
			damage = 13.0
			move_speed = 92.0
			attack_range = 164.0
			_hover_phase = global_position.x * 0.014
		"brine_lurker":
			health = 52.0
			damage = 15.0
			move_speed = 72.0
			attack_range = 58.0
		_:
			health = 34.0
			damage = 9.0
			move_speed = 56.0
			attack_range = 52.0
	if is_node_ready():
		_build_sprite()


func take_damage(amount: float, hit_from: Vector2) -> void:
	if _defeated:
		return
	var damage_result := Combat.apply_damage(health, amount)
	health = float(damage_result["health"])
	take_knockback(Vector2(signf(global_position.x - hit_from.x), -0.12), 92.0)
	if sprite != null:
		sprite.modulate = Color(1.0, 0.48, 0.43, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	if health <= 0.0:
		_defeated = true
		var loot := {"organic_gel": 2} if kind in ["scavenger", "brine_lurker"] else {"scrap": 2}
		if game != null:
			game.call("enemy_defeated", self, loot)
			game.call("play_sound", "mine")
		queue_free()


func take_knockback(direction: Vector2, force: float) -> void:
	if kind == "admin_drone":
		velocity += direction.normalized() * force * 0.45
	else:
		velocity.x = direction.normalized().x * force
		velocity.y = -force * 0.32


func _physics_process(delta: float) -> void:
	if _defeated or game == null or bool(game.get("is_paused")):
		return
	var player: Node2D = game.get("player")
	if not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if kind == "admin_drone":
		_hover_and_aim(player, delta, distance)
	else:
		_ground_hunt(player, delta, distance)
	if _telegraph > 0.0:
		_telegraph -= delta
		queue_redraw()
		if _telegraph <= 0.0 and distance <= attack_range + 14.0:
			game.call("take_damage", damage, global_position)
			if player.has_method("take_knockback"):
				player.call(
					"take_knockback", (player.global_position - global_position).normalized(), 260.0
				)
			_attack_cooldown = 1.4 if kind == "admin_drone" else 1.8
		if _telegraph < 0.0:
			_telegraph = 0.0
	elif distance <= attack_range and _attack_cooldown <= 0.0:
		_telegraph = 0.68 if kind == "admin_drone" else 0.52
		queue_redraw()


func _ground_hunt(player: Node2D, delta: float, distance: float) -> void:
	var target_x := 0.0
	if distance < 360.0 and distance > attack_range * 0.8:
		target_x = signf(player.global_position.x - global_position.x)
	velocity.x = move_toward(velocity.x, target_x * move_speed, 360.0 * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	if (
		distance < 98.0
		and is_on_floor()
		and absf(player.global_position.y - global_position.y) > 40.0
	):
		velocity.y = -300.0
	move_and_slide()
	if absf(target_x) > 0.1:
		sprite.flip_h = target_x < 0.0


func _hover_and_aim(player: Node2D, delta: float, distance: float) -> void:
	_hover_phase += delta * 2.0
	var desired := (
		player.global_position
		+ Vector2(
			-signf(player.global_position.x - global_position.x) * 120.0,
			-92.0 + sin(_hover_phase) * 17.0
		)
	)
	if distance < 520.0:
		velocity = (desired - global_position).limit_length(move_speed * 1.6)
	else:
		velocity = Vector2.ZERO
	move_and_collide(velocity * delta)
	sprite.flip_h = player.global_position.x < global_position.x


func _draw() -> void:
	if _telegraph > 0.0:
		var color := Color(1.0, 0.28, 0.34, 0.72 if int(_telegraph * 10.0) % 2 == 0 else 0.28)
		if kind == "admin_drone":
			draw_line(Vector2(0, 8), Vector2(-attack_range, 180), color, 3.0)
		else:
			draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 24, color, 2.5)


func _build_sprite() -> void:
	if sprite == null:
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var texture_path := "res://assets/characters/crystal_scavenger_sheet.png"
	var frame_width := 32
	var frame_count := 4
	if kind == "admin_drone":
		texture_path = "res://assets/characters/admin_drone_sheet.png"
		frame_count = 3
	var sheet: Texture2D = load(texture_path)
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 5.0)
	frames.set_animation_loop("idle", true)
	for frame in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame * frame_width, 0, frame_width, 32)
		frames.add_frame("idle", atlas)
	sprite.sprite_frames = frames
	sprite.play("idle")
	if kind == "brine_lurker":
		sprite.modulate = Color(0.58, 0.82, 0.93, 1.0)
	elif kind == "admin_drone":
		sprite.modulate = Color(1.0, 0.82, 0.76, 1.0)
