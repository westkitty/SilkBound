class_name SilkboundPlayer
extends CharacterBody2D

signal landed_hard(distance: float)

const TILE_SIZE := 32
const SPEED_WALK := 235.0
const SPEED_SPRINT := 345.0
const GROUND_ACCEL := 1850.0
const AIR_ACCEL := 1020.0
const JUMP_SPEED := 470.0
const GRAVITY := 1220.0

var game: Node
var world: WorldGrid
var touch_axis := Vector2.ZERO
var alive := true
var facing := 1
var animation_state := "idle"
var _jump_request := false
var _jump_was_held := false
var _highest_fall_speed := 0.0
var _mine_animation_timer := 0.0
var _attack_animation_timer := 0.0
var _hurt_animation_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(48.0)
	_build_animations()
	sprite.play("idle")
	if camera != null:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 7.0
		camera.zoom = Vector2.ONE


func configure(owner_game: Node, owner_world: WorldGrid, spawn_position: Vector2) -> void:
	game = owner_game
	world = owner_world
	global_position = spawn_position
	if is_node_ready():
		_configure_camera_limits()


func bind_world(owner_world: WorldGrid, spawn_position: Vector2) -> void:
	world = owner_world
	global_position = spawn_position
	velocity = Vector2.ZERO
	touch_axis = Vector2.ZERO
	_highest_fall_speed = 0.0
	_jump_request = false
	_jump_was_held = false
	_mine_animation_timer = 0.0
	_attack_animation_timer = 0.0
	if is_node_ready():
		_configure_camera_limits()


func set_touch_axis(value: Vector2) -> void:
	touch_axis = value.limit_length(1.0)


func request_jump() -> void:
	_jump_request = true


func animate_action(action: String) -> void:
	if action == "mine":
		_mine_animation_timer = 0.28
	elif action == "attack":
		_attack_animation_timer = 0.32


func take_knockback(direction: Vector2, force: float) -> void:
	velocity = Vector2(direction.x * force, -force * 0.38)
	_hurt_animation_timer = 0.28


func die() -> void:
	alive = false
	velocity = Vector2.ZERO
	animation_state = "death"
	if sprite != null:
		sprite.play("death")


func _physics_process(delta: float) -> void:
	if not alive or game == null or bool(game.get("is_paused")):
		return
	_mine_animation_timer = maxf(0.0, _mine_animation_timer - delta)
	_attack_animation_timer = maxf(0.0, _attack_animation_timer - delta)
	_hurt_animation_timer = maxf(0.0, _hurt_animation_timer - delta)
	var was_on_floor := is_on_floor()
	var key_axis := Input.get_axis("move_left", "move_right")
	var axis := key_axis
	if absf(touch_axis.x) > 0.12:
		axis = touch_axis.x
	if absf(axis) > 0.1:
		facing = 1 if axis > 0.0 else -1
	var sprinting := (
		Input.is_action_pressed("sprint") or bool(game.call("is_action_held", "sprint"))
	)
	var can_sprint := float(game.call("get_energy")) > 1.0
	var max_speed := SPEED_SPRINT if sprinting and can_sprint else SPEED_WALK
	var acceleration := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, axis * max_speed, acceleration * delta)

	var in_water := world != null and world.is_underwater(global_position)
	if not is_on_floor():
		velocity.y += GRAVITY * (0.48 if in_water else 1.0) * delta
		_highest_fall_speed = maxf(_highest_fall_speed, velocity.y)
	else:
		_highest_fall_speed = 0.0

	var jump_held := Input.is_action_pressed("jump") or bool(game.call("is_action_held", "jump"))
	if (
		_jump_request
		or (Input.is_action_just_pressed("jump") or (jump_held and not _jump_was_held))
	):
		if is_on_floor() and float(game.call("get_energy")) > 0.0:
			velocity.y = -JUMP_SPEED * (0.9 if in_water else 1.0)
			game.call("spend_energy", 2.0)
			game.call("play_sound", "jump")
		_jump_request = false
	if not jump_held and _jump_was_held and velocity.y < -120.0:
		velocity.y *= 0.54
	_jump_was_held = jump_held
	if in_water:
		velocity.x = move_toward(velocity.x, axis * max_speed * 0.72, acceleration * delta * 0.62)
		velocity.y = minf(velocity.y, 310.0)
	move_and_slide()
	if not was_on_floor and is_on_floor() and _highest_fall_speed > 720.0:
		var damage := (_highest_fall_speed - 650.0) / 22.0
		landed_hard.emit(damage)
		game.call("take_damage", damage, global_position)
		_highest_fall_speed = 0.0
	_update_animation(axis)


func _update_animation(axis: float) -> void:
	if not alive:
		animation_state = "death"
	elif _hurt_animation_timer > 0.0:
		animation_state = "hurt"
	elif _attack_animation_timer > 0.0:
		animation_state = "attack"
	elif _mine_animation_timer > 0.0:
		animation_state = "mine"
	elif not is_on_floor():
		animation_state = "jump" if velocity.y < -70.0 else "fall"
	elif absf(axis) > 0.12:
		animation_state = "run"
	else:
		animation_state = "idle"
	if sprite.animation != animation_state:
		sprite.play(animation_state)
	if absf(axis) > 0.12:
		sprite.flip_h = facing < 0


func _configure_camera_limits() -> void:
	if world == null or camera == null:
		return
	camera.limit_left = 0
	camera.limit_right = world.world_width * TILE_SIZE
	camera.limit_top = -150
	camera.limit_bottom = world.world_height * TILE_SIZE


func _build_animations() -> void:
	var sheet: Texture2D = load("res://assets/characters/rover_sheet.png")
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_animation(frames, "idle", sheet, [0, 0], 2.0, true)
	_add_animation(frames, "run", sheet, [1, 2, 1, 3], 9.0, true)
	_add_animation(frames, "jump", sheet, [3], 1.0, false)
	_add_animation(frames, "fall", sheet, [3], 1.0, false)
	_add_animation(frames, "mine", sheet, [4, 4], 10.0, false)
	_add_animation(frames, "attack", sheet, [5, 5], 9.0, false)
	_add_animation(frames, "hurt", sheet, [6], 1.0, false)
	_add_animation(frames, "death", sheet, [7], 1.0, false)
	sprite.sprite_frames = frames
	sprite.animation = "idle"


func _add_animation(
	frames: SpriteFrames,
	animation_name: String,
	sheet: Texture2D,
	frame_indices: Array,
	speed: float,
	loops: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in frame_indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(int(frame_index) * 32, 0, 32, 48)
		frames.add_frame(animation_name, atlas)
