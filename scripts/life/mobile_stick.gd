extends Control
## One native finger owns the stick; another finger remains available for actions/orbit.
var direction := Vector2.ZERO
var finger := -1
var mouse_down := false
var knob := Vector2.ZERO
const INNER_COLOR := Color("eee8da99")
const OUTER_FILL := Color("302b2448")
const OUTER_EDGE := Color("fff8e526")
const DEADZONE := 0.16

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(190, 190)
	focus_mode = Control.FOCUS_NONE

func reset() -> void:
	if direction == Vector2.ZERO and knob == Vector2.ZERO and finger < 0 and not mouse_down: return
	direction = Vector2.ZERO
	knob = Vector2.ZERO
	finger = -1
	mouse_down = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset()

func _draw() -> void:
	if size.x<1 or size.y<1:return
	var center := size / 2
	var radius := minf(size.x, size.y) * 0.46
	var fill:=OUTER_FILL;var edge:=OUTER_EDGE
	if not is_engaged():fill.a*=.5;edge.a*=.5
	draw_circle(center,radius,fill)
	draw_arc(center,radius,0,TAU,64,edge,2,true)
	draw_circle(center,radius*.36,INNER_COLOR)
	for axis: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		var side:=Vector2(-axis.y,axis.x)
		var tip:=center+axis*radius*.86
		var highlighted:=is_engaged() and direction.dot(axis)>.35
		var marker_color:=Color(1,.98,.92,.95 if highlighted else .38)
		draw_colored_polygon(PackedVector2Array([tip+axis*radius*.055,tip-axis*radius*.035+side*radius*.055,tip-axis*radius*.035-side*radius*.055]),marker_color)
func is_engaged() -> bool:
	return finger>=0 or mouse_down

func _set_point(point: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	var radius := minf(size.x, size.y) * 0.46
	var raw := (local - size / 2) / radius
	var length := minf(raw.length(), 1)
	knob = Vector2.ZERO
	direction = Vector2.ZERO if length < DEADZONE else raw.normalized() * ((length - DEADZONE) / (1 - DEADZONE))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and finger < 0 and get_global_rect().has_point(event.position):
			finger = event.index
			_set_point(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_set_point(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and mouse_down:
		reset()
	elif event is InputEventMouseMotion and mouse_down:
		_set_point(event.position)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down = true
			_set_point(get_global_transform_with_canvas() * event.position)
		else: reset()
		accept_event()
