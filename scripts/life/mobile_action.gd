extends Control
signal pressed
signal released
var title := "交互"
var badge := ""
var active := true:
	set(value):
		if active==value:return
		active=value
		if not active:reset()
		queue_redraw()
var finger := -1
var held := false
var caption: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color("fff9ed"))
	add_child(caption)
	set_title(title)

func set_title(value: String) -> void:
	if title==value and caption!=null and caption.text==value:return
	title = value
	if not value.is_empty():tooltip_text=""
	if caption != null: caption.text = value
	queue_redraw()

func set_badge(value: String) -> void:
	if badge==value:return
	badge=value
	queue_redraw()

func clear_skill() -> void:
	set_title("");set_badge("");active=false;tooltip_text="当前场景暂无对应技能"

func reset() -> void:
	if not held and finger < 0: return
	if held: released.emit()
	held = false
	finger = -1
	queue_redraw()

func hit(point: Vector2) -> bool:
	return get_global_rect().get_center().distance_to(point) <= minf(size.x, size.y) / 2

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset()
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():reset()

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.48
	var color := Color("203b3d38") if held else Color("203b3d12")
	if not active: color=Color("69757533")
	draw_circle(size / 2, radius, color)
	if held:draw_arc(size / 2, radius, 0, TAU, 64, Color(1,.98,.92,.18), 1.5, true)
	if caption != null:
		caption.offset_top = size.y*.65
		caption.offset_bottom = -size.y*.12
		caption.modulate.a = .8 if active else .3
	_draw_symbol(size*.5-Vector2(0,size.y*.10),radius*.55,Color(1,.98,.94,.95 if active else .3))

	if not badge.is_empty():
		var point := Vector2(size.x*.78,size.y*.22)
		if badge.ends_with("%"):
			var progress:float=clampf(float(badge.trim_suffix("%"))/100,0,1)
			if progress>0:draw_arc(size/2,radius*.91,-PI/2,-PI/2+TAU*progress,48,Color("e4c88c"),3,true)
			draw_circle(point,17,Color("e4c88c"))
			draw_string(get_theme_default_font(),point+Vector2(-17,4),badge,HORIZONTAL_ALIGNMENT_CENTER,34,10,Color("203c3c"))
		else:
			draw_circle(point,13,Color("e4c88c"))
			draw_string(get_theme_default_font(),point+Vector2(-10,5),badge,HORIZONTAL_ALIGNMENT_CENTER,20,14,Color("203c3c"))

func _stroke(points: Array, center: Vector2, scale_value: float, color: Color, width: float = 3.5) -> void:
	var path:=PackedVector2Array()
	for point: Vector2 in points: path.append(center+point*scale_value)
	draw_polyline(path,color,width,true)

func _draw_symbol(center: Vector2, r: float, color: Color) -> void:
	if title.is_empty():
		_stroke([Vector2(-.4,0),Vector2(.4,0)],center,r,color,2.5)
	elif title.contains("奔跑"):
		draw_circle(center+Vector2(.25,-.75)*r,r*.17,color)
		_stroke([Vector2(.15,-.45),Vector2(-.15,.05),Vector2(.35,.35),Vector2(.6,.85)],center,r,color)
		_stroke([Vector2(-.15,.05),Vector2(-.4,.5),Vector2(-.8,.6)],center,r,color)
		_stroke([Vector2(-.6,-.1),Vector2(-.2,-.4),Vector2(.4,-.15),Vector2(.75,-.4)],center,r,color)
	elif title.contains("建造"):
		_stroke([Vector2(-.7,-.1),Vector2(0,-.7),Vector2(.7,-.1)],center,r,color)
		_stroke([Vector2(-.5,-.25),Vector2(-.5,.7),Vector2(.5,.7),Vector2(.5,-.25)],center,r,color)
		_stroke([Vector2(-.15,.7),Vector2(-.15,.15),Vector2(.15,.15),Vector2(.15,.7)],center,r,color)
	elif title.contains("撒饵") or title.contains("制饵") or title.contains("已撒"):
		_stroke([Vector2(-.7,.2),Vector2(-.5,.65),Vector2(.3,.65),Vector2(.5,.2)],center,r,color)
		for point:Vector2 in [Vector2(-.1,-.5),Vector2(.3,-.7),Vector2(.65,-.3),Vector2(.8,.05)]:draw_circle(center+point*r,r*.08,color)
	elif title.contains("卸力"):
		_stroke([Vector2(-.7,-.35),Vector2(-.3,-.55),Vector2(.1,-.35),Vector2(.5,-.55)],center,r,color)
		_stroke([Vector2(0,-.2),Vector2(0,.7),Vector2(-.3,.4),Vector2(0,.7),Vector2(.3,.4)],center,r,color)
	elif title.contains("抄") or title.contains("网"):
		draw_arc(center+Vector2(.15,-.2)*r,r*.5,0,TAU,32,color,3,true)
		_stroke([Vector2(-.2,.2),Vector2(-.7,.85)],center,r,color)
		_stroke([Vector2(-.2,-.45),Vector2(.45,.05),Vector2(-.15,.1),Vector2(.4,-.45)],center,r,color,2)
	elif title.contains("吃") or title.contains("用餐") or title.contains("进食"):
		draw_arc(center,r*.55,0,TAU,32,color,3,true)
		_stroke([Vector2(-.8,-.6),Vector2(-.8,.7)],center,r,color)
		_stroke([Vector2(.8,-.6),Vector2(.8,.7)],center,r,color)
	elif title.contains("结束"):
		_stroke([Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5),Vector2(-.5,-.5)],center,r,color)
	elif title.contains("锻炼") or title.contains("训练") or title.contains("健身"):
		_stroke([Vector2(-.7,-.5),Vector2(-.7,.5),Vector2(-.4,.5),Vector2(-.4,-.5),Vector2(-.7,-.5)],center,r,color)
		_stroke([Vector2(.4,-.5),Vector2(.4,.5),Vector2(.7,.5),Vector2(.7,-.5),Vector2(.4,-.5)],center,r,color)
		_stroke([Vector2(-.4,0),Vector2(.4,0)],center,r,color)
	elif title.contains("竿") or title.contains("线") or title.contains("钓"):
		_stroke([Vector2(-.65,.75),Vector2(.05,-.75),Vector2(.55,-.45),Vector2(.65,.4)],center,r,color)
		draw_arc(center+Vector2(.43,.38)*r,r*.22,0,PI,16,color,3,true)
	elif title.contains("加速") or title.contains("继续航行"):
		for shift:float in [-.4,.25]:_stroke([Vector2(-.5+shift,-.6),Vector2(.1+shift,0),Vector2(-.5+shift,.6)],center,r,color)
	elif title=="停船":
		for shift:float in [-.35,.35]:_stroke([Vector2(shift,-.65),Vector2(shift,.65)],center,r,color,5)
	elif title.contains("船") or title.contains("返航") or title.contains("登岛") or title.contains("靠岸"):
		_stroke([Vector2(-.8,.2),Vector2(-.5,.65),Vector2(.5,.65),Vector2(.8,.2),Vector2(-.8,.2)],center,r,color)
		_stroke([Vector2(0,.15),Vector2(0,-.7),Vector2(.6,-.2),Vector2(0,-.2)],center,r,color)
	elif title.contains("起身") or title.contains("离开") or title.contains("楼"):
		_stroke([Vector2(-.7,.7),Vector2(-.7,.25),Vector2(-.2,.25),Vector2(-.2,-.2),Vector2(.3,-.2),Vector2(.3,-.65),Vector2(.7,-.65)],center,r,color)
	elif title.contains("喝") or title.contains("饮"):
		_stroke([Vector2(-.5,-.6),Vector2(-.4,.65),Vector2(.4,.65),Vector2(.5,-.6),Vector2(-.5,-.6)],center,r,color)
		_stroke([Vector2(.5,-.35),Vector2(.85,-.35),Vector2(.85,.2),Vector2(.45,.2)],center,r,color)
	else:
		# Open palm is the shared contextual interaction symbol; caption names the action.
		_stroke([Vector2(-.7,.1),Vector2(-.35,.55),Vector2(-.05,.75),Vector2(.4,.65),Vector2(.6,.25),Vector2(.6,-.35),Vector2(.4,-.35),Vector2(.4,.05),Vector2(.35,-.6),Vector2(.15,-.6),Vector2(.15,-.05),Vector2(.05,-.8),Vector2(-.15,-.8),Vector2(-.15,-.05),Vector2(-.3,-.55),Vector2(-.5,-.5),Vector2(-.4,.25),Vector2(-.7,-.1),Vector2(-.85,-.05),Vector2(-.7,.1)],center,r,color,3)

func _press() -> void:
	if not active or held: return
	held = true
	pressed.emit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and finger < 0 and hit(event.position):
			finger = event.index
			_press()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and held and finger < 0:
		reset()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(size / 2) <= size.x / 2: _press()
		else: reset()
		accept_event()
