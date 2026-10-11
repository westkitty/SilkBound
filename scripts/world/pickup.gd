class_name WorldPickup
extends Area2D

const Items = preload("res://scripts/inventory/item_catalog.gd")
const ICONS = preload("res://assets/ui/item_icons.png")

var game: Node
var item_id: String = "scrap"
var amount: int = 1
var _age := 0.0
var _origin_y := 0.0
var _collected := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("world_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	_origin_y = position.y
	_build_icon()


func configure(owner_game: Node, item: String, quantity: int, at_position: Vector2) -> void:
	game = owner_game
	item_id = item
	amount = maxi(1, quantity)
	global_position = at_position
	_origin_y = position.y
	if is_node_ready():
		_build_icon()


func consume_amount(quantity: int) -> void:
	amount = maxi(0, amount - quantity)
	if amount <= 0:
		_collected = true
		queue_free()


func _process(delta: float) -> void:
	_age += delta
	position.y = _origin_y + sin(_age * 3.0) * 2.5


func _draw() -> void:
	draw_arc(
		Vector2.ZERO, 13.0 + sin(_age * 4.0) * 1.4, 0.0, TAU, 18, Color(0.25, 0.84, 0.91, 0.35), 1.3
	)


func _on_body_entered(body: Node2D) -> void:
	if _collected or game == null or body != game.get("player"):
		return
	if bool(game.call("collect_pickup", self, item_id, amount)):
		_collected = true
		queue_free()


func _build_icon() -> void:
	if sprite == null:
		return
	var icon_index := int(Items.ITEMS.get(item_id, {}).get("icon", 0))
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = Rect2((icon_index % 8) * 16, int(icon_index / 8) * 16, 16, 16)
	sprite.texture = atlas
	sprite.scale = Vector2(1.7, 1.7)
