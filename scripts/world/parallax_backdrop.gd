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
	# A following CanvasLayer scales all children, shrinking a full-screen
	# TextureRect to 14% of the viewport. Keep the atmosphere in screen space.
	# World-space camera parallax is supplied by the scene layers in the future;
	# the backdrop itself must cover the entire Android landscape.
	follow_viewport_enabled = false
	follow_viewport_scale = 1.0
	image = TextureRect.new()
	image.name = "AtmosphericDepth"
	image.texture = TEXTURES.get(biome, TEXTURES[0])
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(image)
