class_name ParallaxBackdrop
extends CanvasLayer

const TEXTURES := {
	0: preload("res://assets/environments/ashlands_parallax.png"),
	1: preload("res://assets/environments/glassfall_parallax.png"),
	2: preload("res://assets/environments/drowned_parallax.png")
}

var image: TextureRect


func configure(biome: int) -> void:
	layer = -20
	follow_viewport_enabled = true
	follow_viewport_scale = 0.14
	image = TextureRect.new()
	image.name = "AtmosphericDepth"
	image.texture = TEXTURES.get(biome, TEXTURES[0])
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(image)
