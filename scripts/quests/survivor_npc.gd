class_name SurvivorNPC
extends Node2D

var game: Node
var survivor_id: String = "iri"
var display_name: String = "Iri"
var _pulse := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var marker: Label = $InteractMarker


func _ready() -> void:
	z_index = 4
	add_to_group("silkbound_survivors")
	_build_portrait()


func configure(owner_game: Node, identity: String, at_position: Vector2) -> void:
	game = owner_game
	survivor_id = identity
	display_name = "Iri" if identity == "iri" else "Vale"
	global_position = at_position
	if is_node_ready():
		_build_portrait()


func interact() -> void:
	if game != null:
		game.call("interact_npc", survivor_id)


func _process(delta: float) -> void:
	_pulse += delta
	if game == null or not is_instance_valid(game.get("player")):
		marker.visible = false
		return
	marker.visible = global_position.distance_to(game.get("player").global_position) < 110.0
	queue_redraw()


func _draw() -> void:
	draw_arc(
		Vector2(0, -33),
		19.0 + sin(_pulse * 3.0) * 1.4,
		0.0,
		TAU,
		20,
		Color(0.25, 0.82, 0.89, 0.74),
		1.7
	)


func _build_portrait() -> void:
	if sprite == null:
		return
	sprite.texture = load(
		(
			"res://assets/characters/iri.png"
			if survivor_id == "iri"
			else "res://assets/characters/vale.png"
		)
	)
	sprite.position = Vector2(0, -23)
	sprite.scale = Vector2(1.35, 1.35)
	marker.text = "E"
	marker.position = Vector2(-8, -69)
	marker.add_theme_color_override("font_color", Color(0.55, 0.95, 0.92))
	marker.add_theme_color_override("font_shadow_color", Color(0.02, 0.05, 0.10, 1.0))
	marker.add_theme_constant_override("shadow_offset_x", 1)
	marker.add_theme_constant_override("shadow_offset_y", 1)
