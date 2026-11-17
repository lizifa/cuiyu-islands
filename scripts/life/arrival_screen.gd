extends Control
signal completed
var app: Node
const Characters = preload("res://scripts/life/character_catalog.gd")
var character_id := Characters.DEFAULT
var pet := "dog"
var name_input: LineEdit
var pet_name_input: LineEdit
var preview: Node3D
var preview_root: Node3D
var preview_camera: Camera3D
var hint: Label
var character_wheel:Control
var pet_wheel:Control
var selection_caption:Label
var confirm_button:Button
var display: TextureRect
var preview_view: SubViewport
var mouse_preview_drag := false
var swipe_id := -1
var last_touch := Vector2.ZERO
var showcase_yaw := 0.0
var content:HBoxContainer
func setup(owner_app: Node) -> void:
	app = owner_app
	name = "ArrivalCharacterSelection"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	app.safe_root.add_child(self)
	var backdrop := ColorRect.new()
	backdrop.color = Color("103b3ffb")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	content = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 24; content.offset_right = -24
	content.offset_top = 18; content.offset_bottom = -18
	content.add_theme_constant_override("separation", 18)
	add_child(content)
	var left := VBoxContainer.new()
	left.name="ArrivalPreviewColumn"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio=1.0
	content.add_child(left)
	var heading := HBoxContainer.new()
	left.add_child(heading)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/qinggeng-yuhang-icon-v1.png")
	logo.custom_minimum_size = Vector2(64, 64)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(logo)
	var wordmark := VBoxContainer.new()
	wordmark.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(wordmark)
	var title:Label=app.label("晴耕雨航",32,Color("f5d99e"));title.autowrap_mode=TextServer.AUTOWRAP_OFF;wordmark.add_child(title)
	var subtitle:Label=app.label("晴日耕作，雨后远航",16);subtitle.autowrap_mode=TextServer.AUTOWRAP_OFF;wordmark.add_child(subtitle)
	display = TextureRect.new()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	display.custom_minimum_size = Vector2(240, 240)
	var showcase:=PanelContainer.new();showcase.name="CharacterShowcase"
	showcase.size_flags_vertical=Control.SIZE_EXPAND_FILL
	showcase.add_theme_stylebox_override("panel",app.compact_panel(Color("20545aff"),18));left.add_child(showcase);showcase.add_child(display)
	preview_view = SubViewport.new()
	preview_view.size = Vector2i(480, 480)
	preview_view.own_world_3d = true
	preview_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if DisplayServer.get_name() == "headless" else SubViewport.UPDATE_WHEN_VISIBLE
	display.add_child(preview_view)
	display.texture = preview_view.get_texture()
	display.resized.connect(func(): preview_view.size = Vector2i(maxi(1, int(display.size.x)), maxi(1, int(display.size.y))))
	preview_root = Node3D.new()
	preview_view.add_child(preview_root)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17494c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f2debd")
	environment.environment.ambient_light_energy = 0.75
	preview_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.2
	preview_root.add_child(light)
	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(.3,1.3,4.6)
	preview_camera.fov = 36
	preview_root.add_child(preview_camera)
	preview_camera.look_at(Vector3(.25,1.05,0))
	var plinth:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=1.25;cylinder.bottom_radius=1.3;cylinder.height=.07;cylinder.radial_segments=48;plinth.mesh=cylinder;plinth.material_override=app.world.material(Color("397877"));plinth.position=Vector3(.2,-.045,0);preview_root.add_child(plinth)
	selection_caption=app.label("",20,Color("f5d99e"));selection_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;left.add_child(selection_caption)
	left.add_child(app.label("左右拖动人物，查看不同角度",14))
	var panel := PanelContainer.new()
	panel.name="ArrivalSelectionPanel"
	panel.custom_minimum_size.x = 560
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio=2.0
	panel.add_theme_stylebox_override("panel", app.panel())
	content.add_child(panel)
	var right:=VBoxContainer.new();right.add_theme_constant_override("separation",12);panel.add_child(right)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
	right.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 9)
	scroll.add_child(form)
	form.add_child(app.label("开启岛屿生活", 26, Color("f3d99d")))
	form.add_child(app.label("你的名字", 17))
	name_input = LineEdit.new()
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 54
	form.add_child(name_input)
	var wheels:=HBoxContainer.new();wheels.name="ArrivalDualWheels";wheels.add_theme_constant_override("separation",16);form.add_child(wheels)
	var people_column:=VBoxContainer.new();people_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;wheels.add_child(people_column)
	people_column.add_child(app.label("选择模样",17,Color("f3d99d")))
	character_wheel=preload("res://scripts/life/selection_wheel.gd").new();character_wheel.name="CharacterWheel";people_column.add_child(character_wheel)
	var people:Dictionary={}
	for value:String in Characters.CHARACTERS:people[value]=Characters.CHARACTERS[value].label
	character_wheel.configure(people);character_wheel.selected.connect(_select_character)
	var pet_column:=VBoxContainer.new();pet_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;wheels.add_child(pet_column)
	pet_column.add_child(app.label("同行伙伴",17,Color("f3d99d")))
	pet_wheel=preload("res://scripts/life/selection_wheel.gd").new();pet_wheel.name="CompanionWheel";pet_column.add_child(pet_wheel)
	pet_wheel.configure(preload("res://scripts/life/companion_catalog.gd").NAMES);pet_wheel.selected.connect(_select_pet)
	form.add_child(app.label("分别上下滑动两列 · 中间高亮项即为选中项",14))
	pet_name_input = LineEdit.new()
	pet_name_input.max_length = 24
	pet_name_input.placeholder_text = "给伙伴起个名字"
	pet_name_input.custom_minimum_size.y = 54
	form.add_child(pet_name_input)
	hint = app.label("",14)
	form.add_child(hint)
	confirm_button=app.button(right,"出发 · 开始岛屿生活",confirm);confirm_button.name="ConfirmArrival"
	var close:Button=app.modal_close(self,func():hide();completed.emit())
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);close.offset_left=-52;close.offset_right=-4;close.offset_top=4;close.offset_bottom=52

	name_input.text_changed.connect(func(value:String):confirm_button.disabled=value.strip_edges().is_empty())
	visibility_changed.connect(func():
		if not visible: clear_preview())
	hide()
func open() -> void:
	var profile: Dictionary = app.state.profile
	character_id = Characters.from_profile(profile)
	pet = profile.pet
	name_input.text = profile.name
	pet_name_input.text = profile.pet_name
	pet_name_input.editable = pet != "none"
	confirm_button.text="保存人物与伙伴" if profile.confirmed else "出发 · 开始岛屿生活"
	hint.text="更换模样与伙伴，会保留房屋、背包和任务进度。" if profile.confirmed else "选择喜欢的模样，带一位伙伴去生活。"
	character_wheel.set_value(character_id)
	pet_wheel.set_value(pet)
	show()
	refresh_preview()
func refresh_preview() -> void:
	if character_wheel.get_value()!=character_id:character_wheel.set_value(character_id)
	if pet_wheel.get_value()!=pet:pet_wheel.set_value(pet)
	selection_caption.text=Characters.CHARACTERS[character_id].label+" · "+(preload("res://scripts/life/companion_catalog.gd").NAMES[pet]+("同行" if pet!="none" else ""))
	pet_name_input.editable=pet!="none";pet_name_input.modulate.a=1.0 if pet!="none" else .5
	clear_preview()
	preview = Node3D.new()
	preview_root.add_child(preview)
	var character: Node3D = app.world.character_model(character_id)
	preview.add_child(character)
	for animation: AnimationPlayer in character.find_children("*", "AnimationPlayer", true, false):
		for clip: StringName in animation.get_animation_list():
			if str(clip).to_lower().ends_with("idle"):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animation.play(clip)
	if pet != "none":
		var animal:Node3D=preload("res://scripts/life/companion_catalog.gd").make_visual(pet,app.world)
		animal.position = Vector3(0.8, .65 if pet in preload("res://scripts/life/companion_catalog.gd").FLOATING else 0.0, 0.2)
		preview.add_child(animal)
		for animator:AnimationPlayer in animal.find_children("*","AnimationPlayer",true,false):
			if animator.has_animation("Idle"):animator.play("Idle")
	preview.rotation.y = showcase_yaw
func confirm() -> bool:
	character_wheel.settle()
	pet_wheel.settle()
	var profile := {"name": name_input.text.strip_edges(), "character_id": character_id, "pet": pet, "pet_name": pet_name_input.text.strip_edges(), "confirmed": true}
	if profile.pet_name.is_empty(): profile.pet_name = "小麦"
	if not app.state.valid_profile(profile): hint.text = "请填写人物名字，最多24个字。"; return false
	var previous: Dictionary = app.state.profile.duplicate(true)
	app.state.profile = profile
	app.world.sync(app.state)
	app._save(false)
	if not app.state.save_error.is_empty():
		app.state.profile = previous
		app.world.sync(app.state)
		hint.text = app.state.save_error + "；可重试保存。"
		return false
	hide()
	completed.emit()
	return true
func _input(event: InputEvent) -> void:
	if not visible: return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: mouse_preview_drag = false
		elif display.get_global_rect().has_point(event.position):
			mouse_preview_drag = true
			get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		if event.pressed and display.get_global_rect().has_point(event.position) and swipe_id < 0:
			swipe_id = event.index; last_touch = event.position; get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == swipe_id: swipe_id = -1
	elif event is InputEventScreenDrag and event.index == swipe_id:
		showcase_yaw += (event.position.x - last_touch.x) * 0.012
		last_touch = event.position
		preview.rotation.y = showcase_yaw
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_preview_drag and event.button_mask & MOUSE_BUTTON_MASK_LEFT and display.get_global_rect().has_point(event.position):
		showcase_yaw += event.relative.x * 0.012
		preview.rotation.y = showcase_yaw
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		swipe_id = -1
		mouse_preview_drag = false

func clear_preview() -> void:
	swipe_id = -1
	mouse_preview_drag = false
	if not is_instance_valid(preview): return
	for animation: AnimationPlayer in preview.find_children("*", "AnimationPlayer", true, false):
		animation.stop()
		animation.clear_caches()
	app.world.clear_visual_materials(preview)
	preview_root.remove_child(preview)
	preview.queue_free()
	preview = null

func _select_character(value:String) -> void:
	character_id=value;refresh_preview()
func _select_pet(value:String) -> void:
	pet=value;refresh_preview()
