class_name TouchActionButton
extends Control

signal action_pressed(action: String, pointer_id: int)
signal action_released(action: String, pointer_id: int)

var action_name := ""
var caption := ""
var active_pointers: Dictionary = {}


func configure(action: String, text: String) -> void:
	action_name = action
	caption = text
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func release_pointer(pointer_id: int) -> bool:
	if not active_pointers.has(pointer_id):
		return false
	active_pointers.erase(pointer_id)
	action_released.emit(action_name, pointer_id)
	queue_redraw()
	return true


func cancel_input() -> void:
	for pointer_id in active_pointers.keys():
		release_pointer(int(pointer_id))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pointer_id := int(event.index)
		if event.pressed:
			if not active_pointers.has(pointer_id):
				active_pointers[pointer_id] = true
				action_pressed.emit(action_name, pointer_id)
		else:
			release_pointer(pointer_id)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer_id := -1
		if event.pressed:
			if not active_pointers.has(pointer_id):
				active_pointers[pointer_id] = true
				action_pressed.emit(action_name, pointer_id)
				queue_redraw()
		else:
			release_pointer(pointer_id)
		accept_event()
	elif event is InputEventScreenDrag and active_pointers.has(int(event.index)):
		accept_event()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.48
	var pressed := not active_pointers.is_empty()
	var fill := Color(0.04, 0.10, 0.17, 0.78 if not pressed else 0.94)
	var rim := Color(0.28, 0.78, 0.86, 0.86 if not pressed else 1.0)
	draw_circle(center, radius, fill)
	draw_arc(center, radius - 1.0, 0.0, TAU, 40, rim, 2.5)
	draw_arc(center, radius - 7.0, -0.45, 1.95, 18, Color(0.90, 0.72, 0.45, 0.70), 1.0)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			Vector2(0, center.y + 6),
			caption,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			clampi(roundi(15.0 * minf(1.45, size.x / 62.0)), 15, 22),
			Color(0.91, 0.97, 0.97)
		)
