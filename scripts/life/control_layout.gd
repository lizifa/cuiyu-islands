extends Control
## Touch-layout settings are independent from survival saves; drafts never mutate live controls.
signal changed
const STORE := "user://control_layout.cfg"
const IDS := ["stick", "context", "sprint", "build"]
const NAMES := {"stick": "移动摇杆", "context": "交互", "sprint": "奔跑 / 加速", "build": "建造", "group": "右侧按钮组"}
const SIZES := {"stick": 228.0, "context": 130.0, "sprint": 92.0, "build": 92.0}
var saved: Dictionary = {}
var draft: Dictionary = {}
var controls: Dictionary = {}
var skill_frame: Control
var editing := false
var selected := "group"
var finger := -1
var mouse_drag := false
var last_point := Vector2.ZERO
var toolbar: PanelContainer
var settings: PanelContainer
var message: Label
var selection: OptionButton
var scale_slider: HSlider
var alpha_slider: HSlider
var updating := false
var storage_path := STORE
var app: Node

func setup(owner_app: Node, mapped: Dictionary, path: String) -> void:
	app = owner_app
	controls = mapped
	skill_frame = owner_app.skill_frame
	storage_path = path
	name = "ControlLayoutSettings"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	owner_app.safe_root.add_child(self)
	var config := ConfigFile.new()
	if config.load(storage_path) == OK:
		var data: Variant = config.get_value("layout", "controls", {})
		if valid(data): saved = data.duplicate(true)
	settings = PanelContainer.new()
	settings.add_theme_stylebox_override("panel", owner_app.panel())
	settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings.offset_left = -240; settings.offset_right = 240
	settings.offset_top = -100; settings.offset_bottom = 100
	add_child(settings)
	var options := VBoxContainer.new()
	settings.add_child(options)
	var header:=HBoxContainer.new();options.add_child(header)
	var title:Label=owner_app.label("设置",26);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	owner_app.modal_close(header,cancel)
	owner_app.button(options, "重置游戏", owner_app._confirm_reset_game)
	toolbar = PanelContainer.new()
	toolbar.add_theme_stylebox_override("panel", owner_app.compact_panel(Color("142e35fa")))
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = 170
	add_child(toolbar)
	var rows := VBoxContainer.new()
	toolbar.add_child(rows)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	selection = OptionButton.new()
	selection.custom_minimum_size = Vector2(210, 54)
	for id: String in ["stick", "group"]: selection.add_item(NAMES[id])
	selection.item_selected.connect(func(index): select(["stick", "group"][index]))
	buttons.add_child(selection)
	owner_app.button(buttons, "保存", commit)
	owner_app.button(buttons, "取消", cancel)
	owner_app.button(buttons, "恢复默认", reset_draft)
	var sliders := HBoxContainer.new()
	rows.add_child(sliders)
	sliders.add_child(owner_app.label("大小", 18))
	scale_slider = HSlider.new()
	scale_slider.min_value = 85; scale_slider.max_value = 150; scale_slider.step = 1
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.custom_minimum_size = Vector2(180, 36)
	sliders.add_child(scale_slider)
	scale_slider.value_changed.connect(func(value): adjust("scale", value / 100))
	sliders.add_child(owner_app.label("透明度", 18))
	alpha_slider = HSlider.new()
	alpha_slider.min_value = 30; alpha_slider.max_value = 100; alpha_slider.step = 1
	alpha_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alpha_slider.custom_minimum_size = Vector2(180, 36)
	sliders.add_child(alpha_slider)
	alpha_slider.value_changed.connect(func(value): adjust("alpha", value / 100))
	message = owner_app.label("拖动整块技能栏或左侧摇杆，调整大小和透明度。", 16)
	rows.add_child(message)
	resized.connect(func(): apply(); queue_redraw())
	hide()

## 参考图 IMG_8412 的右下扇形：主按钮在右列上下两枚，辅助按钮在其左侧斜向拉开。
func defaults() -> Dictionary:
	var result := {}
	var centers := {"stick": Vector2(130, size.y - 130), "context": Vector2(size.x - 112, size.y - 132), "sprint": Vector2(size.x - 112, size.y - 276), "build": Vector2(size.x - 244, size.y - 276)}
	for id: String in IDS:
		result[id] = {"x": centers[id].x / maxf(size.x, 1), "y": centers[id].y / maxf(size.y, 1), "scale": 1.0, "alpha": 0.7 if id == "stick" else 1.0}
	return result

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 4: return false
	for id: String in IDS:
		if not data.has(id) or not data[id] is Dictionary: return false
		for key: String in ["x", "y", "scale", "alpha"]:
			if not data[id].has(key): return false
			var value: Variant = data[id][key]
			if not (value is float or value is int) or not is_finite(float(value)): return false
		if data[id].x < 0 or data[id].x > 1 or data[id].y < 0 or data[id].y > 1: return false
		if data[id].scale < 0.85 or data[id].scale > 1.5 or data[id].alpha < 0.3 or data[id].alpha > 1: return false
	return true

func rect_for(id: String, data: Dictionary) -> Rect2:
	var spec: Dictionary = data[id]
	var diameter: float = minf(SIZES[id] * spec.scale, minf(size.x, size.y - 184))
	var half := diameter / 2
	var center := Vector2(spec.x * size.x, spec.y * size.y)
	center.x = clampf(center.x, half, size.x - half)
	center.y = clampf(center.y, 180 + half, size.y - half)
	return Rect2(center - Vector2.ONE * half, Vector2.ONE * diameter)

func apply() -> void:
	if controls.is_empty() or size.y < 300: return
	var source:=defaults()
	# Right-side actions now use one fixed arc; preserve the independent movement stick.
	if not saved.is_empty():source.stick=saved.stick.duplicate(true)
	var data := rigid_layout(source)
	# Keep the saved preference, but use a usable fallback if a new aspect ratio crowds it.
	for i in range(IDS.size()):
		for j in range(i + 1, IDS.size()):
			if rect_for(IDS[i], data).grow(-4).intersects(rect_for(IDS[j], data).grow(-4)):
				data = defaults()
	for id: String in IDS:
		var control: Control = controls[id]
		var rect := rect_for(id, data)
		control.custom_minimum_size = Vector2.ZERO
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.size = rect.size
		control.global_position = global_position + rect.position
		control.self_modulate.a = 1.0
		control.modulate.a = data[id].alpha
	if skill_frame != null:
		var block := group_rect(data).intersection(Rect2(Vector2.ZERO, size))
		skill_frame.global_position = global_position + block.position
		skill_frame.size = block.size

func open_settings() -> void:
	app.layout_modal(settings)
	editing = false
	settings.show(); toolbar.hide()
	show()
	reset_gesture()
	changed.emit()
	queue_redraw()

func begin_edit() -> void:
	draft = rigid_layout(saved if not saved.is_empty() else defaults())
	editing = true
	settings.hide(); toolbar.show()
	select("group")
	reset_gesture()
	queue_redraw()

func select(id: String) -> void:
	selected = "stick" if id == "stick" else "group"
	id = selected
	updating = true
	selection.select(0 if id == "stick" else 1)
	scale_slider.editable = true
	alpha_slider.editable = true
	var sample := "context" if id == "group" else "stick"
	scale_slider.value = draft[sample].scale * 100
	alpha_slider.value = draft[sample].alpha * 100
	message.text = "已选：%s · 整块拖动，保存后生效。" % NAMES[id]
	updating = false
	queue_redraw()

func adjust(key: String, value: float) -> void:
	if updating or not editing: return
	if selected == "stick": draft.stick[key] = value
	else:
		var pivot := group_rect(draft).get_center()
		var factor: float = value / float(draft.context.scale) if key == "scale" else 1.0
		for id: String in ["context", "sprint", "build"]:
			var center := Vector2(draft[id].x * size.x, draft[id].y * size.y)
			center = pivot + (center - pivot) * factor
			draft[id].x = center.x / size.x
			draft[id].y = center.y / size.y
			draft[id][key] = value
		draft = rigid_layout(draft)
	queue_redraw()

func group_rect(data: Dictionary) -> Rect2:
	var bounds := rect_for("context", data)
	for id: String in ["sprint", "build"]: bounds = bounds.merge(rect_for(id, data))
	return bounds.grow(8)

func move_selected(delta: Vector2) -> void:
	var ids: Array = ["context", "sprint", "build"] if selected == "group" else [selected]
	var bounds := rect_for(ids[0], draft)
	for id: String in ids: bounds = bounds.merge(rect_for(id, draft))
	delta.x = clampf(delta.x, -bounds.position.x, size.x - bounds.end.x)
	delta.y = clampf(delta.y, 180 - bounds.position.y, size.y - bounds.end.y)
	for id: String in ids:
		var center := rect_for(id, draft).get_center() + delta
		draft[id].x = center.x / size.x
		draft[id].y = center.y / size.y
	queue_redraw()

func commit() -> bool:
	if not editing or not valid(draft): return false
	for i in range(IDS.size()):
		for j in range(i + 1, IDS.size()):
			if rect_for(IDS[i], draft).grow(-4).intersects(rect_for(IDS[j], draft).grow(-4)):
				message.text = "按钮不能重叠，请移开后再保存。"
				return false
	var config := ConfigFile.new()
	config.set_value("layout", "controls", draft)
	var temporary := storage_path + ".tmp"
	var error := config.save(temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary, storage_path)
	if error != OK:
		message.text = "布局保存失败：%s；请重试，或取消保留原布局。" % error_string(error)
		return false
	saved = draft.duplicate(true)
	apply()
	cancel()
	return true

func reset_draft() -> void:
	draft = defaults()
	select("group")
	message.text = "已恢复默认预览；点击保存才会生效。"
	queue_redraw()

func cancel() -> void:
	reset_gesture()
	editing = false
	draft.clear()
	hide()
	changed.emit()

func reset_gesture() -> void:
	finger = -1
	mouse_drag = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset_gesture()

func _input(event: InputEvent) -> void:
	if not visible or not editing: return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION: return
	var press: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if press:
		if not event.pressed:
			if (event is InputEventScreenTouch and event.index == finger) or (event is InputEventMouseButton and mouse_drag):
				reset_gesture()
				get_viewport().set_input_as_handled()
			return
		if finger >= 0 or mouse_drag: return
		var point: Vector2 = event.position - global_position
		var id := "stick" if rect_for("stick", draft).has_point(point) else "group"
		if id == "group" and not group_rect(draft).has_point(point): return
		select(id)
		last_point = event.position
		if event is InputEventScreenTouch: finger = event.index
		else: mouse_drag = true
		get_viewport().set_input_as_handled()
	elif (event is InputEventScreenDrag and event.index == finger) or (event is InputEventMouseMotion and mouse_drag):
		move_selected(event.position - last_point)
		last_point = event.position
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.08, 0.10, 0.78 if not editing else 0.35))
	if not editing: return
	var block := group_rect(draft)
	draw_style_box(_block_style(), block)
	draw_rect(block, Color("f0cf83") if selected == "group" else Color("8cbab3"), false, 3)
	for id: String in IDS:
		var rect := rect_for(id, draft)
		var highlight := selected == id or (selected == "group" and id != "stick")
		draw_circle(rect.get_center(), rect.size.x * 0.47, Color(0.23, 0.43, 0.40, draft[id].alpha))
		if id == "stick": draw_rect(rect, Color("f0cf83") if highlight else Color("8cbab3"), false, 3)
		var text: String = "奔跑" if id == "sprint" else NAMES[id]
		draw_string(get_theme_default_font(), rect.get_center() + Vector2(-rect.size.x * 0.4, 6), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.8, 17, Color.WHITE)

func _block_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("183d44bb")
	style.set_corner_radius_all(18)
	return style

func rigid_layout(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	var scale_value: float = data.context.scale
	var anchor := Vector2(data.context.x * size.x, data.context.y * size.y)
	var offsets := {"context": Vector2.ZERO, "sprint": Vector2(0,-144), "build": Vector2(-132,-144)}
	var bounds := Rect2()
	for id: String in ["context", "sprint", "build"]:
		var center: Vector2 = anchor + offsets[id] * scale_value
		var diameter: float = SIZES[id] * scale_value
		var rect := Rect2(center - Vector2.ONE * diameter / 2, Vector2.ONE * diameter)
		bounds = rect if id == "context" else bounds.merge(rect)
		data[id].x = center.x / maxf(size.x, 1)
		data[id].y = center.y / maxf(size.y, 1)
		data[id].scale = scale_value
		data[id].alpha = data.context.alpha
	var shift := Vector2.ZERO
	if bounds.position.x < 0: shift.x = -bounds.position.x
	elif bounds.end.x > size.x: shift.x = size.x - bounds.end.x
	if bounds.position.y < 180: shift.y = 180 - bounds.position.y
	elif bounds.end.y > size.y: shift.y = size.y - bounds.end.y
	for id: String in ["context", "sprint", "build"]:
		data[id].x += shift.x / maxf(size.x, 1)
		data[id].y += shift.y / maxf(size.y, 1)
	return data
