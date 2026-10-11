class_name VirtualStick
extends Control

signal axis_changed(axis: Vector2)

var _pointer_id := -999
var _mouse_active := false
var _axis := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _pointer_id == -999:
			_pointer_id = int(event.index)
			_update_axis(_to_local(event.position))
			accept_event()
		elif not event.pressed and int(event.index) == _pointer_id:
			_pointer_id = -999
			_reset_axis()
			accept_event()
	elif event is InputEventScreenDrag and int(event.index) == _pointer_id:
		_update_axis(_to_local(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_active = true
			_update_axis(get_local_mouse_position())
		else:
			_mouse_active = false
			_reset_axis()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_axis(get_local_mouse_position())
		accept_event()


func cancel_input() -> void:
	if _pointer_id == -999 and not _mouse_active and _axis == Vector2.ZERO:
		return
	_pointer_id = -999
	_mouse_active = false
	_reset_axis()


func _to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _update_axis(local_position: Vector2) -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var offset := (local_position - center).limit_length(radius)
	_knob = offset
	_axis = offset / maxf(1.0, radius)
	axis_changed.emit(_axis)
	queue_redraw()


func _reset_axis() -> void:
	_axis = Vector2.ZERO
	_knob = Vector2.ZERO
	axis_changed.emit(_axis)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_circle(center, radius, Color(0.04, 0.10, 0.16, 0.40))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.27, 0.72, 0.81, 0.62), 2.0)
	draw_circle(center + _knob, radius * 0.40, Color(0.09, 0.24, 0.34, 0.86))
	draw_arc(center + _knob, radius * 0.40, 0.0, TAU, 32, Color(0.49, 0.90, 0.86, 0.90), 2.0)
