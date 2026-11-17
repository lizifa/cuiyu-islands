extends Node
const State = preload("res://scripts/life/life_state.gd")
const World = preload("res://scripts/life/life_world.gd")
var home_navigation:Button
var first_person_reticle:Control
var camera_return: Button
var camera_mode_button: Button
var task_menu_button:Button
var task_red_dot:Panel
var auto_task: Node
var large_map: Control
var minimap: Control
var task_drawer: PanelContainer
var map_drawer: PanelContainer
var task_entries: VBoxContainer
var task_entries_key := ""
var task_pause_button: Button
var task_resume_button: Button
var task_night_button: Button
var task_cancel_button: Button
var task_hint: Label
var task_status: Label
var arrival: Control
var layout_editor: Control
var boat_session:RefCounted
var boat_stop_action:Control
var boat_home_action:Control
var build_action: Control
var skill_frame: PanelContainer
var state = State.new()
var world: Node3D
var date_label: Label
var status_label: Label
var location_label: Label
var inventory_label: Label
var quest_label: Label
var note_label: Label
var ledger_label: Label
var action_box: VBoxContainer
var tab_label: Label
var help_label: Label
var pause_button: Button
var track_controls: HBoxContainer
var track_toggle: Button
var goal_button: Button
var tab := "劳作"
var paused := "--start-paused" in OS.get_cmdline_user_args()
var inactive := false
var elapsed := 0.0
var last_ui_day := -1
var last_market_open := false
var autosave_elapsed := 0.0
var confirmation:Control
var pending := Callable()
var ui_root: Control
var safe_root: Control
var action_drawer: PanelContainer
var info_drawer: PanelContainer
var test_safe_override := Vector4.ZERO
var joystick: Control
var action_pad: Control
var context_action: Control
var sprint_action: Control
var sprinting := false
var resume_button: Button
var menu_drawer: PanelContainer
var toast_panel: PanelContainer
var toast_remaining := 0.0
var last_notification := ""
var status_bars: Dictionary = {}
var status_values: Dictionary = {}
var performance_settings: Node
var haptics: Node
var interaction_director: Node
var fishing_session: Node
var bed_session: Node
var home_routine:Node
var exercise_session:Node
var sofa_session: Node
var perf_probe := OS.has_feature("perf_probe") or "--perf-probe" in OS.get_cmdline_user_args()
var test_mode := "--test-mode" in OS.get_cmdline_user_args()

func _ready() -> void:
	if not test_mode: state.load_game();state.stow_pending_fish()
	if state.location!="island":state.pack_keep_net()
	world = World.new()
	add_child(world)
	auto_task = preload("res://scripts/life/auto_tasks.gd").new()
	auto_task.app = self
	add_child(auto_task)
	interaction_director=preload("res://scripts/life/interaction_director.gd").new()
	interaction_director.app=self
	add_child(interaction_director)
	_build_ui()
	world.sync(state)
	sofa_session = preload("res://scripts/life/sofa_session.gd").new()
	add_child(sofa_session)
	sofa_session.setup(self)
	exercise_session=preload("res://scripts/life/exercise_session.gd").new();add_child(exercise_session);exercise_session.setup(self)
	home_routine=preload("res://scripts/life/home_routine.gd").new();add_child(home_routine);home_routine.setup(self)
	bed_session=preload("res://scripts/life/bed_session.gd").new()
	add_child(bed_session);bed_session.setup(self)
	haptics = preload("res://scripts/life/haptic_feedback.gd").new()
	add_child(haptics)
	haptics.setup(self)
	fishing_session = preload("res://scripts/life/fishing_session.gd").new()
	add_child(fishing_session)
	fishing_session.setup(self)
	if OS.get_environment("QGYH_AUTOPILOT") == "fishing":
		var fish_demo := preload("res://scripts/life/fish_autopilot.gd").new()
		add_child(fish_demo)
		fish_demo.setup(self)
		print("FISHDEMO autopilot mounted")
	performance_settings = preload("res://scripts/life/mobile_performance.gd").new()
	add_child(performance_settings)
	performance_settings.setup(self)
	if perf_probe:
		var probe := preload("res://scripts/life/perf_probe.gd").new()
		add_child(probe)
	world.orbit.can_start = _camera_can_drag
	if world.orbit.first_person or world.orbit.stable_third_person:
		first_person_reticle=preload("res://scripts/life/first_person_reticle.gd").new();safe_root.add_child(first_person_reticle);first_person_reticle.setup(self)
		home_navigation=preload("res://scripts/life/home_navigation.gd").new();safe_root.add_child(home_navigation);home_navigation.setup(self)
	pause_button.text = "继续" if paused else "暂停"
	_refresh()
	_actions()
	get_tree().auto_accept_quit = false
	get_tree().root.gui_embed_subwindows = true
	auto_task.changed.connect(_update_task_status)
	arrival = preload("res://scripts/life/arrival_screen.gd").new()
	arrival.setup(self)
	arrival.completed.connect(_on_arrival_completed)
	if not test_mode and not state.profile.confirmed: _open_arrival.call_deferred()
	_normalize_on_open.call_deferred()

## 打开游戏时的姿态归一：不管上一局是躺着、坐着还是被打断，进来一定是站姿、站在地面上。
func _normalize_on_open() -> void:
	if world == null or world.player == null: return
	var actor: CharacterBody3D = world.player
	if bed_session != null and bed_session.active: bed_session.cancel()
	if actor.bed_stage != "":
		actor.cancel_bed()
		actor.bed_stage = ""
	actor.cancel_pet()
	actor.velocity = Vector3.ZERO
	actor.visual.rotation = Vector3.ZERO
	if actor.animator != null:
		actor.animator.speed_scale = 1
		actor.animator.play(actor.idle_clip, .2)
	if state.location == "villa" and state.home_floor == 1:
		# 存档落在主卧床边时，别把人在床上「放」出来：挪到二层过道的空地站好。
		var bed: Vector3 = world.Villa.BED_ANCHOR
		if Vector2(actor.position.x - bed.x, actor.position.z - bed.z).length() < 2.4:
			actor.position = Vector3(clampf(actor.position.x, -6.5, 6.5), world.Villa.Dimensions.UPPER_FLOOR + .03, .8)
	world.orbit.reset_view()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: inactive = true
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: inactive = false
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()

func _process(delta: float) -> void:
	if not is_instance_valid(world) or date_label == null: return
	if not perf_probe and not paused and not inactive and not confirmation.visible and not _drawers_open():
		# One real second = one game minute; large frame stalls never advance a day.
		state.advance(minf(delta, 1.0), world.player.sofa_seated or world.player.bed_stage!="", fishing_session.active)
	elapsed += delta
	autosave_elapsed += delta
	if elapsed >= 0.5:
		if state.day() != last_ui_day or state.market_open() != last_market_open:
			last_ui_day = state.day()
			last_market_open = state.market_open()
			_actions()
		_refresh()
		elapsed = 0
	if autosave_elapsed >= 30:
		_save(false)
		autosave_elapsed = 0
	world.sync(state)
	_update_context()
	toast_remaining = maxf(0, toast_remaining - delta)
	toast_panel.modulate.a = 1.0 if not state.save_error.is_empty() else minf(1, toast_remaining)
	_sync_overlay_state()

func panel(color: Color = Color("142e35e8")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color("91b4a433")
	style.shadow_color = Color("071e2444")
	style.shadow_size = 5
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func label(text: String, font_size: int = 17, color: Color = Color("eceddf")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func section(parent: Node, title: String) -> void:
	parent.add_child(label(title, 14, Color("b4c5ac")))

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(74, 64)
	node.add_theme_font_size_override("font_size", 21)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)
	var theme := Theme.new()
	theme.default_font_size = 20
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {2003265652: 500.0}
	theme.default_font = font
	for name_value: String in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(name_value, "Button", panel({"normal": Color("294b4bbf"), "hover": Color("41685edd"), "pressed": Color("87764ddd"), "disabled": Color("35444899")}[name_value]))
	ui_root.theme = theme
	safe_root = Control.new()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(safe_root)
	# Three compact, independent HUD regions leave the world visible between them.
	var clock := PanelContainer.new()
	clock.name = "MobileHeader"
	clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock.offset_left = -190
	clock.offset_right = 190
	clock.add_theme_stylebox_override("panel", compact_panel(Color("142e3599")))
	safe_root.add_child(clock)
	var dates := VBoxContainer.new()
	dates.add_theme_constant_override("separation", 2)
	clock.add_child(dates)
	date_label = label("", 20)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	dates.add_child(date_label)
	location_label = label("", 14, Color("b5c7be"))
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	dates.add_child(location_label)
	var quick := HBoxContainer.new()
	quick.name = "QuickAccess"
	quick.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quick.offset_left = -254
	quick.add_theme_constant_override("separation", 8)
	safe_root.add_child(quick)
	task_menu_button=button(quick, "任务", _open_tasks)
	task_menu_button.name="TaskMenuButton"
	task_red_dot=Panel.new();task_red_dot.name="TaskPendingDot";task_red_dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var dot_style:=StyleBoxFlat.new();dot_style.bg_color=Color("ef635c");dot_style.set_corner_radius_all(6)
	task_red_dot.add_theme_stylebox_override("panel",dot_style)
	task_menu_button.add_child(task_red_dot);task_red_dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	task_red_dot.offset_left=-16;task_red_dot.offset_right=-5;task_red_dot.offset_top=5;task_red_dot.offset_bottom=16
	button(quick, "背包", _toggle_inventory)
	button(quick, "设置", _open_settings).tooltip_text = "设置"
	camera_return=button(safe_root,"镜头回正",func():world.orbit.return_to_player())
	camera_return.name="ReturnToPlayer";camera_return.custom_minimum_size=Vector2(112,64)
	camera_return.add_theme_font_size_override("font_size",17)
	camera_return.position=Vector2(164,8);camera_return.hide()
	var status_card := PanelContainer.new()
	status_card.name = "MobileStatus"
	status_card.custom_minimum_size.x = 208
	status_card.add_theme_stylebox_override("panel", compact_panel(Color("142e3599")))
	status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.add_child(status_card)
	status_card.position.y = 160
	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", 3)
	status_card.add_child(vitals)
	for spec: Array in [["energy", "精力", Color("d5bc78")], ["hunger", "饱食", Color("95bb85")], ["thirst", "饮水", Color("7fb1c0")]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vitals.add_child(row)
		var vital_name := label(spec[1], 14, Color("bfcec4"))
		vital_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		vital_name.custom_minimum_size.x = 32
		row.add_child(vital_name)
		var meter := ProgressBar.new()
		meter.custom_minimum_size = Vector2(94, 7)
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.show_percentage = false
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_theme_stylebox_override("background", compact_panel(Color("ffffff18"), 0))
		meter.add_theme_stylebox_override("fill", compact_panel(spec[2], 0))
		row.add_child(meter)
		status_bars[spec[0]] = meter
		var value := label("100", 14)
		value.custom_minimum_size.x = 28
		row.add_child(value)
		status_values[spec[0]] = value
	status_label = label("")
	status_label.hide()
	safe_root.add_child(status_label)
	goal_button = button(safe_root, "任务", _open_tasks)
	goal_button.name = "MobileTask"
	goal_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	goal_button.offset_left = -254
	goal_button.offset_right = 0
	goal_button.offset_top = 76
	goal_button.offset_bottom = 122
	goal_button.custom_minimum_size.x = 254
	goal_button.add_theme_font_size_override("font_size", 16)
	goal_button.add_theme_stylebox_override("normal", compact_panel(Color("142e3566")))
	goal_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	goal_button.clip_text=true
	track_controls=HBoxContainer.new()
	track_controls.name="TaskTrackControls"
	safe_root.add_child(track_controls)
	track_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	track_controls.offset_left=-254;track_controls.offset_top=126;track_controls.offset_bottom=174
	track_controls.add_theme_constant_override("separation",8)
	track_toggle=button(track_controls,"暂停",func():
		if auto_task.running:auto_task.pause_job("已暂停，可继续执行。")
		else:auto_task.resume_job()
		_update_task_status();_sync_overlay_state())
	button(track_controls,"取消",_cancel_tracked_task)
	track_controls.hide()
	task_hint = label("", 16, Color("f3d99d"))
	task_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	task_hint.offset_left = -254
	task_hint.offset_right = 0
	task_hint.offset_top = 202
	task_hint.offset_bottom = 270
	task_hint.max_lines_visible = 3
	safe_root.add_child(task_hint)
	# Details are accessed intentionally, never laid across the playing field.
	info_drawer = PanelContainer.new()
	info_drawer.name = "InventoryDrawer"
	info_drawer.add_theme_stylebox_override("panel", panel(Color("142e35f5")))
	info_drawer.hide()
	safe_root.add_child(info_drawer)
	var inventory_rows:=VBoxContainer.new();info_drawer.add_child(inventory_rows)
	var inventory_header:=HBoxContainer.new();inventory_rows.add_child(inventory_header)
	var inventory_title:=label("背包",22,Color("f3d99d"));inventory_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inventory_header.add_child(inventory_title)
	modal_close(inventory_header,_close_drawers)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	inventory_rows.add_child(scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	scroll.add_child(info)
	button(info,"生活 · 制作 · 航行",func():_close_drawers();_toggle_menu())
	section(info, "身体与资产")
	status_label.reparent(info)
	status_label.show()
	section(info, "行囊")
	inventory_label = label("", 19)
	info.add_child(inventory_label)
	section(info, "当前任务")
	quest_label = label("", 19)
	info.add_child(quest_label)
	button(info, "领取里程碑", func(): _act(state.claim))
	section(info, "生活账本")
	ledger_label = label("", 17)
	info.add_child(ledger_label)
	action_drawer = PanelContainer.new()
	action_drawer.name = "ActionDrawer"
	action_drawer.hide()
	action_drawer.add_theme_stylebox_override("panel", panel(Color("142e35f5")))
	safe_root.add_child(action_drawer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	action_drawer.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	tab_label = label("", 21, Color("f3d99d"))
	tab_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(tab_label)
	modal_close(heading,_close_drawers)
	var action_scroll := ScrollContainer.new();action_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(action_scroll)
	action_box = VBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 10)
	action_scroll.add_child(action_box)
	menu_drawer = PanelContainer.new()
	menu_drawer.name = "MobileToolbar" # Retained node name for older layout checks.
	menu_drawer.add_theme_stylebox_override("panel", panel(Color("142e35f5")))
	menu_drawer.hide()
	safe_root.add_child(menu_drawer)
	var menu_rows:=VBoxContainer.new();menu_drawer.add_child(menu_rows)
	var menu_heading := HBoxContainer.new();menu_rows.add_child(menu_heading)
	var menu_scroll := ScrollContainer.new();menu_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_rows.add_child(menu_scroll)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation", 12)
	menu_scroll.add_child(menu)
	var game_title := label("晴耕雨航", 24, Color("f3d99d"))
	game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_heading.add_child(game_title)
	modal_close(menu_heading,_close_drawers)
	section(menu, "生活与生产")
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 10)
	tools.add_theme_constant_override("v_separation", 10)
	menu.add_child(tools)
	for name_value: String in ["劳作", "制造", "生活", "航行", "集市", "日历"]:
		var entry := button(tools, "建房" if name_value == "制造" else name_value, _select_tab.bind(name_value))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section(menu, "设置与帮助")
	var system := GridContainer.new()
	system.columns = 2
	system.add_theme_constant_override("h_separation", 10)
	system.add_theme_constant_override("v_separation", 10)
	menu.add_child(system)
	pause_button = button(system, "暂停", _toggle_pause)
	button(system, "保存进度", func(): _save(); _refresh())
	button(system,"看太阳",func(): world.look_at_sun(state); _close_drawers())
	button(system, "视角归位", func(): world.orbit.reset_view();world.indoor_camera.reset(); _close_drawers())
	camera_mode_button=button(system,"旋转视角",_toggle_camera_mode)
	if world.orbit.first_person or world.orbit.stable_third_person:camera_mode_button.hide()
	button(system, "游戏说明", _show_help)
	button(system,"钓具与操作",_show_fishing_help)
	button(system, "素材鸣谢", _show_credits)
	for child: Button in system.get_children(): child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_panel = PanelContainer.new()
	toast_panel.name = "MobileToast"
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_left = -280
	toast_panel.offset_right = 280
	toast_panel.offset_top = -104
	toast_panel.offset_bottom = -24
	toast_panel.add_theme_stylebox_override("panel", compact_panel(Color("142e35b0")))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.add_child(toast_panel)
	note_label = label("", 17, Color("f3d99d"))
	note_label.max_lines_visible = 2
	toast_panel.add_child(note_label)
	help_label = label("")
	help_label.hide()
	safe_root.add_child(help_label)
	_build_tasks_ui()
	_build_movement_controls()
	layout_editor = preload("res://scripts/life/control_layout.gd").new()
	layout_editor.setup(self, {"stick": joystick, "context": context_action, "sprint": sprint_action, "build": build_action}, "user://test_layout_unused.cfg" if test_mode else "user://control_layout.cfg")
	layout_editor.changed.connect(_sync_overlay_state)
	layout_editor.apply()
	resume_button = button(safe_root, "继续游戏", _toggle_pause)
	resume_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	resume_button.offset_left = -90
	resume_button.offset_right = 90
	resume_button.offset_top = 88
	resume_button.offset_bottom = 152
	resume_button.visible = paused
	confirmation=preload("res://scripts/life/game_dialog.gd").new();safe_root.add_child(confirmation);confirmation.setup(self,true)
	confirmation.title = "出发前看一眼"
	confirmation.theme = theme
	confirmation.get_ok_button().custom_minimum_size.y = 64
	confirmation.confirmed.connect(func():
		if pending.is_valid(): pending.call())
	ui_root.resized.connect(_layout_mobile)
	_layout_mobile.call_deferred()

func modal_close(parent:Node,action:Callable)->Button:
	var close:Button=preload("res://scripts/life/modal_close.gd").new();parent.add_child(close);close.pressed.connect(action);return close

func modal_size()->Vector2:
	return Vector2(minf(860,maxf(280,safe_root.size.x-32)),minf(580,maxf(220,safe_root.size.y-32)))

func layout_modal(control:Control)->void:
	var dimensions:Vector2=modal_size()
	control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	control.offset_left=-dimensions.x*.5;control.offset_right=dimensions.x*.5
	control.offset_top=-dimensions.y*.5;control.offset_bottom=dimensions.y*.5

func crisp_panel(color: Color, padding: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = compact_panel(color, padding)
	style.shadow_size = 0
	style.shadow_color = Color(0, 0, 0, 0)
	style.border_color = Color("8fb3a755")
	return style

func compact_panel(color: Color, padding: int = 12) -> StyleBoxFlat:
	var style := panel(color)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _drawers_open() -> bool:
	return menu_drawer.visible or info_drawer.visible or action_drawer.visible or (layout_editor != null and layout_editor.visible) or (arrival != null and arrival.visible) or (task_drawer != null and task_drawer.visible) or (map_drawer != null and map_drawer.visible)

func _sync_overlay_state() -> void:
	if home_navigation!=null:home_navigation.refresh()
	var open := _drawers_open()
	var fishing: bool=fishing_session!=null and fishing_session.active
	if camera_return!=null:camera_return.visible=not open and not paused and world.orbit.is_away()
	if open or inactive:world.orbit.cancel_drag()
	joystick.visible = not open and not paused
	action_pad.visible = not open and not paused and not confirmation.visible
	if skill_frame != null: skill_frame.visible = false
	if minimap != null: minimap.visible = not open
	var resting: bool=world.player.bed_stage!="" or world.player.sofa_seated
	var tracked: bool=not auto_task.job.is_empty() and not auto_task._completed()
	goal_button.visible = not open and not paused and not fishing and not resting and tracked
	if track_controls!=null:track_controls.visible=goal_button.visible
	if task_hint != null:task_hint.hide()
	_update_context()
	resume_button.visible = paused and not open
	toast_panel.visible = (not open and not fishing and toast_remaining > 0) or not state.save_error.is_empty()

func _close_drawers() -> void:
	if task_drawer != null: task_drawer.hide()
	if map_drawer != null: map_drawer.hide()
	if arrival != null: arrival.hide()
	if layout_editor != null: layout_editor.cancel()
	menu_drawer.hide()
	info_drawer.hide()
	action_drawer.hide()
	_sync_overlay_state()

func _toggle_camera_mode() -> void:
	world.orbit.set_rotation_mode(not world.orbit.rotation_mode)
	_close_drawers()
func _toggle_menu() -> void:
	var opening := not menu_drawer.visible
	_close_drawers()
	menu_drawer.visible = opening
	camera_mode_button.text="平移观察" if world.orbit.rotation_mode else "旋转视角"
	_sync_overlay_state()

func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "继续" if paused else "暂停"
	if not paused: _close_drawers()
	_refresh()

func _open_goal() -> void:
	var quest: Dictionary = state.current_quest()
	if not quest.is_empty() and state.quest_done(quest.id): _act(state.claim)
	else: _toggle_inventory()

func safe_insets(view_size: Vector2, screen_size: Vector2, safe: Rect2) -> Vector4:
	if screen_size.x <= 0 or screen_size.y <= 0: return Vector4.ZERO
	var ratio := view_size / screen_size
	return Vector4(maxf(0, safe.position.x) * ratio.x, maxf(0, safe.position.y) * ratio.y, maxf(0, screen_size.x - safe.end.x) * ratio.x, maxf(0, screen_size.y - safe.end.y) * ratio.y)

func _layout_mobile() -> void:
	if not is_instance_valid(safe_root): return
	var inset := Vector4.ZERO
	if OS.get_name() in ["Android", "iOS"]:
		inset = safe_insets(ui_root.size, Vector2(DisplayServer.window_get_size()), Rect2(DisplayServer.get_display_safe_area()))
	if test_safe_override != Vector4.ZERO: inset = test_safe_override
	safe_root.offset_left = inset.x + 14
	safe_root.offset_top = inset.y + 12
	safe_root.offset_right = -inset.z - 14
	safe_root.offset_bottom = -inset.w - 12
	for drawer:PanelContainer in [action_drawer,info_drawer,menu_drawer,task_drawer,map_drawer]:
		if drawer!=null:layout_modal(drawer)
	if layout_editor!=null and layout_editor.settings!=null:layout_modal(layout_editor.settings)
	if confirmation!=null:confirmation._layout()
	if large_map!=null and map_drawer!=null:
		var side:float=maxf(120,minf(modal_size().x-56,modal_size().y-150))
		large_map.custom_minimum_size=Vector2(side,side)
		large_map.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	if layout_editor != null: layout_editor.apply.call_deferred()
	world.camera.fov = world.orbit.VIEW_FOV if world.orbit.first_person else (world.orbit.THIRD_FOV if world.orbit.stable_third_person else (world.indoor_camera.lens(world) if state.location=="villa" else 44.0))

func _toggle_inventory() -> void:
	var opening := not info_drawer.visible
	_close_drawers()
	info_drawer.visible = opening
	_sync_overlay_state()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _drawers_open(): _close_drawers()
		else: _toggle_pause()

func _select_tab(name_value: String) -> void:
	_close_drawers()
	action_drawer.show()
	tab = name_value
	_actions()
	_sync_overlay_state()

func _act(action: Callable) -> void:
	if world.player.home_busy:
		state.say("先完成当前动作，或点击取消。");return
	if auto_task != null and auto_task.running: auto_task.stop("已切换为手动操作。")
	if paused:
		state.say("游戏已暂停，点击「继续」后行动。")
	else:
		var success: Variant = false
		var arguments: Array = action.get_bound_arguments()
		if action.get_method() == &"labor" and not arguments.is_empty() and not world.can_labor(str(arguments[0])):
			state.say("先走近对应资源，再进行%s。" % str(arguments[0]))
		else:
			success = action.call()
		if success:
			world.sync(state)
			world.pulse()
		_save(false)
	last_notification = ""
	_refresh()
	_actions()

func _save(show_message: bool = true) -> void:
	if test_mode or perf_probe: return
	if world != null and world.player != null:
		var position: Vector3 = world.save_position()
		state.player_position = [position.x, position.y, position.z]
	var error: Error = state.save_game()
	state.save_error = "" if error == OK else "存档失败：%s；进度暂留内存，请重试。" % error_string(error)
	if show_message and error == OK:
		state.last_message = "已保存。下次回来，时间停在此刻。"
		last_notification = ""

func _refresh() -> void:
	date_label.text = "%s %d日 · %s %02d:%02d%s" % [State.SEASONS[state.season()], state.day() % 14 + 1, State.WEEKDAYS[state.weekday()], int(state.hour()), int(state.minute) % 60, " · 暂停" if paused else ""]
	location_label.text = "%s · %s · %s" % [("群岛海域" if world.player.boating else state.place_name().split(" · ")[0]), state.weather(), "双休" if state.weekend() else "工作日"] + " · 朝" + _camera_heading()
	for key: String in status_bars:
		var value := int(state.get(key))
		status_bars[key].value = value
		status_values[key].text = str(value)
		status_values[key].modulate = Color("f2ad82") if value < 25 else Color.WHITE
	status_label.text = "健康 %d · 贝币 %d" % [state.health, state.coins]
	var lines := PackedStringArray()
	for item: String in State.ITEMS:
		if state.count(item) > 0: lines.append("%s  ×%d" % [item, state.count(item)])
	inventory_label.text = "行囊 %d / %d\n%s" % [state.load_count(), state.capacity(), "\n".join(lines)]
	var quest: Dictionary = state.current_quest()
	var completed := 0
	for stage: String in State.HOUSE_STAGES:
		if state.buildings.has(stage): completed += 1
	goal_button.text = _tracked_task_text()
	_update_task_status()
	quest_label.text = "生活继续，城市已在航线里。" if quest.is_empty() else "%s\n%s\n%s" % [quest.name, quest.hint, "已达成，可以领取" if state.quest_done(quest.id) else "按自己的节奏完成"]
	ledger_label.text = "余额 %d\n本周劳动收入 %d / 支出 %d\n累计收入 %d / 支出 %d\n补助单独发放，不计劳动收入" % [state.coins, state.week_income, state.week_spending, state.income, state.spending]
	var message: String = state.save_error if not state.save_error.is_empty() else state.last_message
	if message != last_notification:
		last_notification = message
		note_label.text = message
		toast_remaining = 4.0
	_sync_overlay_state()

func _actions() -> void:
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	tab_label.text = {"劳作": "亲手做，慢慢积累", "制造": "亲手建起自己的家", "生活": "吃饭、喝水，也要歇息", "航行": "带货去镇上，日落前归家", "集市": "出售 · 换物 · 手艺订单", "日历": "四季有序，周末双休"}[tab]
	match tab:
		"劳作":
			for kind: String in ["伐木", "拾石", "采纤维", "采果", "捕鱼"]:
				button(action_box, "%s  ·  %s" % [kind, "1小时" if kind == "捕鱼" else "45分钟"], func(): _act(state.labor.bind(kind)))
			button(action_box, "播种 · 种子×1", func(): _act(state.plant))
			button(action_box, "收获蔬菜", func(): _act(state.harvest))
			if state.crop_ready >= 0:
				action_box.add_child(label("作物%s" % ["已成熟，随时收获" if state.minute >= state.crop_ready else "还需 %.1f 游戏小时" % ((state.crop_ready - state.minute) / 60.0)], 14))
		"制造":
			for recipe: String in State.RECIPES:
				var costs := PackedStringArray()
				for item: String in State.RECIPES[recipe]: costs.append("%s%d" % [item, State.RECIPES[recipe][item]])
				var node := button(action_box, "%s · %s" % [recipe, " + ".join(costs)], func(): _act(state.craft.bind(recipe)))
				node.disabled = state.buildings.has(recipe)
		"生活":
			if state.location=="villa" and state.home_floor==0:
				button(action_box,"去餐桌坐下",func():
					_close_drawers();interaction_director.request(world.find_interaction("villa_eat"),func():_act(sofa_session.begin_dining)))
			else:button(action_box, "吃东西 · 10分钟", func(): _act(state.eat))
			button(action_box, "取水喝水 · 免费", func(): _act(state.drink))
			if state.location == "villa" and state.home_floor == 0:
				button(action_box, "到沙发旁坐下休息", func(): _act(sofa_session.begin))
			elif state.location=="villa" and state.home_floor==1:
				button(action_box,"到床边躺下休息",func():
					_close_drawers()
					var point=world.find_interaction("villa_sleep")
					interaction_director.request(point,func():_act(bed_session.begin)))
			else:
				button(action_box, "短休两小时 · 免费", func(): _act(state.rest.bind(false)))
			button(action_box, "睡到次日06:00 · 18:00后", _sleep_from_life_menu)
			button(action_box, "在镇上喝应急热粥 · 免费", func():
				_act(func():
					if state.location not in ["town", "city"]: return state.say("镇上码头才有应急热粥。别墅厨房可食用行囊中的食物。")
					state.hunger = maxf(state.hunger, 60)
					state.advance(15)
					state.log_event("一碗热粥暖了身子，不必担心没钱回家。")
					return true))
			action_box.add_child(label("篝火旁可短休；庇护所可过夜。周末休息不扣信誉，作物不会枯死。", 15))
		"航行":
			action_box.add_child(label("驾船可前往周围四座自然岛屿。靠近可登陆的岸边，点击右下「登岛」。\n登岛后点击「返回船上」回到停船处；船上点击「返航主岛」自动靠岸。\n小船开局可用，主岛泊位在营地南侧；南侧金色浮标通往青湾镇。", 15))
			for destination: String in ["town", "island", "city"]:
				var names := {"town": "去青湾镇", "island": "返晴屿", "city": "去临海城"}
				var travel_button := button(action_box, names[destination], _confirm_travel.bind(destination))
				travel_button.disabled = state.location == destination
			action_box.add_child(label("小镇每程1小时；城市每程2小时。\n营业 08:00—18:00。\n城市：菜地 + 船舱 + 小镇订单。\n大风雷雨暂停出港，返岛始终可用。", 15))
		"集市":
			action_box.add_child(label("当前%s · 高价需求剩余%d件\n需求用完按六折保底收购" % ["营业" if state.market_open() else "休息 / 尚未到集市", state.demand], 14))
			for item: String in State.BASE_PRICES:
				button(action_box, "出售%s ×1 · %d贝币" % [item, state.price(item) if state.demand > 0 else maxi(1, int(state.price(item) * 0.6))], func(): _act(state.sell.bind(item, 1)))
			button(action_box, "换物：鱼干4 → 种子1", func(): _act(state.barter))
			for product: String in ["种子", "好鱼竿", "船舱"]:
				button(action_box, "购买%s · %d贝币" % [product, {"种子": 40, "好鱼竿": 80, "船舱": 120}[product]], func(): _act(state.buy.bind(product)))
			button(action_box, "接取手艺订单 · 工作日", func(): _act(state.accept_order))
			button(action_box, "交付当前订单", func(): _act(state.deliver_order))
			if not state.order.is_empty():
				action_box.add_child(label("%s×%d → %d贝币\n%s" % [state.order.item, state.order.amount, state.order.reward, "首单无期限" if state.order.first else "剩余%d工作日" % state.workdays_left(int(state.order.due))], 15))
				button(action_box, "取消订单 · 不扣钱", func(): _act(func(): state.order = {}; state.log_event("取消订单，货物与贝币均保留。"); return true))
		"日历":
			action_box.add_child(label("每季14天 · 每年56天\n周一至周五劳作，周六周日双休\n夏日长，冬夜长；四季各有生计。", 16))
			for offset in range(7):
				var d: int = state.day() + offset
				action_box.add_child(label("%s · %s季%d日 · %s %s" % [State.WEEKDAYS[d % 7], State.SEASONS[int(d / 14.0) % 4], d % 14 + 1, state.weather(d), "双休" if d % 7 >= 5 else "工作"], 15))
			action_box.add_child(label("春：播种 · 夏：遮阴储水\n秋：备粮 · 冬：保暖慢生活\n周末无生产打卡，订单跳过休息日。", 15))
			section(action_box, "最近的生活")
			for line: Variant in state.journal.slice(0, 8): action_box.add_child(label(str(line), 13))

func _confirm_travel(destination: String) -> void:
	confirmation.title = "出发前看一眼"
	confirmation.get_ok_button().text = "出发"
	pending = func(): _act(state.travel.bind(destination))
	var duration := 2 if destination == "city" or state.location == "city" else 1
	confirmation.dialog_text = "当前 %s\n航行约 %d 小时 · 天气%s\n饱食 %d / 饮水 %d · 携货 %d/%d\n集市08:00—18:00；晚到可免费借宿。\n确认出发？" % [state.date_text(), duration, state.weather(), state.hunger, state.thirst, state.load_count(), state.capacity()]
	confirmation.popup_centered()

func _show_fishing_help() -> void:
	_show_help("钓具与操作", "右下主按钮：咬钩时提竿、长按收线、松开卸力，鱼收近后抄网。\n右下辅助按钮：制饵或撒饵、收竿离开。制饵消耗浆果1，获得饵料3。\n\n钓位只保留凳子。海竿、纺车轮、鱼线、浮漂、钩坠、抄网与鱼护在钓鱼时使用。\n\n大鱼上钩后会起身，收至岸边点击抄网，再摘钩装入鱼护；收竿离开时自动装进背包。钓鱼不消耗精力。\n\n岸钓：海鲈鱼、鲷鱼、石斑鱼、银鲳、黄花鱼。出海：马鲛鱼、金枪鱼、旗鱼。")

func _show_help(title: String="晴耕雨航 · 从一无所有到安居乐业", text: String="") -> void:
	var dialog:Control=preload("res://scripts/life/game_dialog.gd").new();safe_root.add_child(dialog);dialog.setup(self,false)
	dialog.title = title
	dialog.dialog_text = "左下摇杆移动，右下按钮与附近对象交互。\n生产、生活与航行等详细功能在背包的「生活 · 制作 · 航行」中。\n1. 独自开局，采木拾石；临时庇护后，分四步建自己的木屋。\n2. 驾船，捕鱼加工，带货去青湾镇出售或换种子。\n3. 建菜地、完成订单、升级船舱，解锁临海城。\n\n默认稳定第三人称：左下摇杆移动，右侧空白处滑动 / 鼠标左键拖动观察人物四周；松手停止，不自动弹回。靠近物体显示对应操作，坐卧和钓鱼时用明确按钮起身或离开。菜单可将镜头回正或看太阳。东方日出、西方日落。\n每秒1游戏分钟；菜单说明、失焦、暂停时停止时间。\n精力靠睡眠恢复；食水免费有来源。夜间可以活动。\n周末不接生产订单，四季改变昼长、天气和收入。\n\n素材：Polyfork，CC BY 4.0，详见 assets/polyfork/manifest.json。\n当前不是最终动作操控、美术或商业版本，没有真实充值。"
	if not text.is_empty():dialog.dialog_text=text
	dialog.theme = ui_root.theme
	dialog.get_ok_button().custom_minimum_size.y = 64
	var previously_paused := paused
	paused = true
	pause_button.text = "继续"
	dialog.confirmed.connect(func(): paused = previously_paused; pause_button.text = "继续" if paused else "暂停"; dialog.queue_free(); _sync_overlay_state())
	dialog.canceled.connect(func(): paused = previously_paused; pause_button.text = "继续" if paused else "暂停"; dialog.queue_free(); _sync_overlay_state())
	dialog.popup_centered()

func _camera_can_drag(point: Vector2) -> bool:
	if paused:return false
	if not world.orbit.first_person and not world.orbit.stable_third_person and (world.player.stair_active or world.player.bed_stage!="" or world.home_camera.owner_key!=""):return false
	if (world.orbit.first_person or world.orbit.stable_third_person) and point.x<get_viewport().get_visible_rect().size.x*.4:return false
	if _drawers_open() or inactive or confirmation.visible or (layout_editor != null and layout_editor.visible) or (arrival != null and arrival.visible): return false
	for control: Control in [context_action, sprint_action, build_action,boat_stop_action,boat_home_action]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return false
	# Also guard native touch before its compatibility mouse event reaches the GUI.
	for node: Node in safe_root.get_children():
		if node is Control and node.visible and node != fishing_session.panel and (node is PanelContainer or node is Button or node is Container or node == joystick or node == minimap):
			if node.get_global_rect().has_point(point): return false
	return true

func _build_movement_controls() -> void:
	boat_session=preload("res://scripts/life/boat_session.gd").new();boat_session.setup(self)
	joystick = preload("res://scripts/life/mobile_stick.gd").new()
	joystick.name = "MovementStick"
	safe_root.add_child(joystick)
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 4
	joystick.offset_right = 194
	joystick.offset_top = -200
	joystick.offset_bottom = -10
	joystick.self_modulate.a = 0.7
	skill_frame = PanelContainer.new()
	skill_frame.name = "SkillBlockFrame"
	skill_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_frame.add_theme_stylebox_override("panel", compact_panel(Color("14363d66"), 0))
	safe_root.add_child(skill_frame)
	action_pad = Control.new()
	action_pad.name = "ActionPad"
	action_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.add_child(action_pad)
	action_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	context_action = _round_action("交互", Vector2(0, 0), 108)
	context_action.pressed.connect(func():
		if world.player.boating:boat_session.cast_or_haul()
		else:_nearby_interact())
	sprint_action = _round_action("奔跑", Vector2(0, 0), 76)
	sprint_action.pressed.connect(func():
		if not world.player.boating and _prefab_slot(1):return
		if fishing_session!=null and fishing_session.active:
			fishing_session.auxiliary()
			return
		if sofa_session!=null and sofa_session.active and sofa_session.mode=="balcony":sofa_session.toggle_rocking();return
		if sofa_session!=null and sofa_session.active and sofa_session.mode=="dining":sofa_session.finish();_sync_overlay_state();return
		if auto_task.running: auto_task.stop("已切换为手动操作。")
		sprinting = true)
	sprint_action.released.connect(func(): sprinting = false)
	build_action = _round_action("建造", Vector2(0, 0), 76)
	build_action.pressed.connect(func():
		if not world.player.boating and _prefab_slot(2):return
		if sofa_session!=null and sofa_session.active and sofa_session.mode=="balcony":sofa_session.stretch();return
		if world.player.boating:boat_session.dock();return
		if not state.island_visit.is_empty():_open_boat_status();return
		if fishing_session!=null and fishing_session.active:fishing_session.cancel()
		else:_select_tab("制造"))

	boat_stop_action=_round_action("停船",Vector2(0,0),54)
	boat_stop_action.pressed.connect(func():
		if not world.player.boating and _prefab_slot(3,_prefab_point):return
		if fishing_session!=null and fishing_session.active:fishing_session.show_keep();return
		if world.player.boating and world.sea_giants!=null and world.sea_giants.repel_ready():
			world.sea_giants.repel();return
		if world.player.boating:boat_session.toggle_stop())
	boat_home_action=_round_action("返航主岛",Vector2(0,0),58)
	boat_home_action.pressed.connect(func():
		if not world.player.boating:
			if _prefab_slot(4):return
			if _prefab_point.is_empty() and movement_enabled():home_routine.begin_wave()
			return
		if boat_session.busy():return
		boat_session.stopped=false;_open_boat_status())

func _round_action(title: String, pos: Vector2, diameter: float) -> Control:
	var node := preload("res://scripts/life/mobile_action.gd").new()
	node.title = title
	node.position = pos
	node.size = Vector2.ONE * diameter
	action_pad.add_child(node)
	return node

func _sleep_from_life_menu() -> void:
	if state.location!="villa":_act(state.rest.bind(true));return
	if state.home_floor!=1:
		state.say("先沿楼梯到二楼卧室，再上床睡觉。")
		_refresh();return
	_close_drawers()
	interaction_director.request(world.find_interaction("villa_sleep"),func():
		if bed_session.begin():bed_session.auto_sleep=true)

func movement_enabled() -> bool:
	return not paused and not inactive and not confirmation.visible and not _drawers_open()

func _physics_process(delta: float) -> void:
	if world == null or world.player == null or joystick == null: return
	var enabled := movement_enabled()
	boat_session.tick(delta)
	if enabled and is_instance_valid(fishing_session) and not fishing_session.active and (not state.fish_keep.is_empty() or not state.pending_fish.is_empty()) and (state.location!="island" or world.player.boating or world.player.position.distance_to(preload("res://scripts/life/fishing_platform.gd").POINT)>5):
		state.pack_keep_net();_save(false)
	world.player.allowed = enabled
	world.orbit.motion_enabled=enabled
	if not enabled:
		joystick.reset()
		sprint_action.reset()
	var manual: Vector2 = (joystick.direction + Input.get_vector("player_left", "player_right", "player_up", "player_down")).limit_length() if enabled else Vector2.ZERO
	if (world.orbit.first_person or world.orbit.stable_third_person) and (fishing_session.active or world.player.sofa_seated or world.player.bed_stage!=""):
		manual=Vector2.ZERO;joystick.reset()
	world.walk_camera.follow_requested=enabled and (manual.length()>.08 or interaction_director.active or auto_task.running)
	world.player.manual_stair_input=manual
	world.player.manual_world_direction=world.walk_camera.map_input(world,manual) if enabled and not world.player.boating else Vector3.INF
	if enabled:
		if world.player.bed_stage!="":world.player.move_input=Vector2.ZERO
		elif world.player.boating:world.player.move_input=Vector2.ZERO if boat_session.locked() else world.return_pilot.tick(delta,manual)
		elif interaction_director.active:world.player.move_input=interaction_director.tick(delta,manual)
		else:world.player.move_input=auto_task.tick(delta,manual)
	else:world.player.move_input=Vector2.ZERO
	world.player.sprint = sprinting and not boat_session.locked() and state.energy >= 10 and enabled and not world.return_pilot.active and not interaction_director.active and not fishing_session.active and not world.player.stair_active and world.player.bed_stage=="" and (not world.player.boating or world.player.rowing_pose==null or world.player.rowing_pose.ready())
	if world.player.sprint and world.player.move_input.length() > 0.05:
		state.energy = maxf(0, state.energy - delta)
	if enabled and manual.length()>.15 and world.player.manual_world_direction.is_finite():
		if world.try_walk_exit(state,world.player.manual_world_direction):
			world.player.move_input=Vector2.ZERO;_save(false)
	var pos: Vector3 = world.save_position()
	state.player_position = [pos.x, pos.y, pos.z]

## 右下扇形技能布局：数值照参考图 IMG_8412 的像素比例（2436×1125）换算，
## 以屏幕右下安全角为原点，按钮直径按屏幕高度比例缩放，换手机分辨率不跑位。
## 两个主按钮竖排在右侧（右上最大、右下略大），两个辅助按钮在左侧斜向拉开，
## 最右侧留一个灰色不可用位——和参考图的疏密一致。
const SKILL_SLOTS := ["context", "build", "sprint", "stop", "home"]
const SKILL_LAYOUT := {
	# 参考图 IMG_8412 的五圆斜带：三个大圆沿右下到右上排开，两个小圆在内侧。
	"context": {"dx": -0.335, "dy": -0.265, "d": 0.141},  # 主按钮·右下
	"build":   {"dx": -0.200, "dy": -0.360, "d": 0.141},  # 次主按钮·上
	"sprint":  {"dx": -0.375, "dy": -0.470, "d": 0.141},  # 大按钮·右上
	"stop":    {"dx": -0.560, "dy": -0.330, "d": 0.086},  # 小按钮·内左上
	"home":    {"dx": -0.525, "dy": -0.140, "d": 0.086},  # 小按钮·内左下
}

func _layout_skill(key: String) -> void:
	var control: Control = _skill_control(key)
	if control == null: return
	# 玩家在布局设置里拖过按钮就以玩家位置为准，否则用参考图的扇形默认值。

	var area: Vector2 = action_pad.size if action_pad != null else Vector2.ZERO
	if area.x <= 0 or area.y <= 0: area = get_viewport().get_visible_rect().size
	if area.x <= 0 or area.y <= 0: return
	var spec: Dictionary = SKILL_LAYOUT[key]
	# 参考图是 2436×1125（宽高比约 2.165）。竖屏/4:3/iPad 这类屏幕如果直接按
	# area.y 缩放，按钮会被撑大并溢出右下安全区，所以先按参考宽高比取一个等比基准，
	# 再把圆心夹回安全区内。
	var aspect: float = maxf(area.x / maxf(area.y, 1.0), .4)
	var base: float = minf(area.y, area.x / 2.165)
	if aspect < 1.6: base = minf(base, area.x / aspect * .62)
	var diameter: float = clampf(base * float(spec.d), 40.0, base * .34)
	var center := Vector2(area.x + base * float(spec.dx), area.y + base * float(spec.dy))
	var margin := 4.0
	center.x = minf(center.x, area.x - diameter * .5 - margin)
	center.y = minf(center.y, area.y - diameter * .5 - margin)
	if control.size != Vector2.ONE * diameter: control.size = Vector2.ONE * diameter
	control.position = center - Vector2.ONE * diameter * .5

func _skill_control(key: String) -> Control:
	match key:
		"context": return context_action
		"build": return build_action
		"sprint": return sprint_action
		"stop": return boat_stop_action
		"home": return boat_home_action
	return null

## 固定五技能规范（build92 起）：每个预制体/交互状态都把五个槽位填满。
## 槽位：0 主操作、1 辅助、2 情境、3 查看、4 离开或补充；没有真实动作的槽位保留灰色占位和原因。
var _prefab_last := ""
var _prefab_point:Dictionary={}
func _prefab_context() -> String:
	if home_routine!=null and home_routine.phase=="fridge":return "fridge"
	if exercise_session!=null and exercise_session.active:return "gym"
	if world.player.bed_stage!="":return "bed"
	if sofa_session!=null and sofa_session.active:return str(sofa_session.mode)
	if world.player.sofa_seated:return "sofa"
	return ""
func _fill(control:Control,title:String,active:bool,reason:String="")->void:
	control.set_title(title)
	control.set_badge("")
	control.active=active
	control.tooltip_text="" if active else reason
func _toggle_meal_plate() -> bool:
	if not is_instance_valid(world.villa_room):return false
	var plate:Node3D=world.villa_room.get_node_or_null("DiningMealPlate")
	if plate==null:return false
	var placed:bool=not bool(world.villa_room.get_meta("meal_placed",false))
	world.villa_room.set_meta("meal_placed",placed);plate.visible=placed
	state.say("把餐盘摆上桌，面包也放好了。" if placed else "把餐具收回厨房。")
	return true
func _toggle_bedside_lamp() -> bool:
	if not is_instance_valid(world.villa_room):return false
	var lamp:Node3D=world.villa_room.get_node_or_null("BedsideLampLight")
	if lamp==null:return false
	var on:bool=not bool(world.villa_room.get_meta("bedside_lamp_on",false))
	world.villa_room.set_meta("bedside_lamp_on",on);lamp.visible=on
	state.say("床头灯已打开。" if on else "床头灯已关掉。")
	return true
func _clock_text() -> String:
	var minute:int=int(state.minute)
	return "%02d:%02d"%[int(minute/60.0)%24,minute%60]
func _inspect(ctx:String,point:Dictionary={}) -> bool:
	var title:String=str(point.get("title",_prefab_label(ctx)))
	if title.is_empty():return false
	state.say("%s · 现在 %s · 精力 %d%% · %s"%[title,_clock_text(),int(state.energy),_inspect_hint(ctx)])
	return true
func _prefab_label(ctx:String) -> String:
	match ctx:
		"fridge":return "冰箱"
		"bed":return "床"
		"sofa","rest":return "沙发"
		"dining":return "餐桌"
		"balcony":return "摇摇椅"
		"gym":return "健身器材"
	return ""
func _inspect_hint(ctx:String) -> String:
	match ctx:
		"fridge":return "冰箱饮料 %d 瓶、背包 %d 瓶"%[state.home_drinks,state.count("饮料")]
		"bed":return "躺下后可以短休，18:00 后能睡到清晨"
		"sofa","rest":return "坐在这里可以看客厅电视，或起身去别处"
		"dining":return "坐下后可以吃东西，吃完记得起身"
		"balcony":return "摇摇椅可以轻摇、静躺或伸懒腰"
		"gym":return "锻炼中，点主按钮结束训练"
	return "点主按钮使用这个物件"
## 五个槽位逐项填表：有真实动作的写名字，没有的留空并给出原因。
func _apply_prefab_skills() -> bool:
	var ctx:String=_prefab_context()
	if ctx.is_empty():return false
	var ready:bool=movement_enabled()
	var night:bool=state.hour()>=18 or state.hour()<6
	match ctx:
		"fridge":
			_fill(context_action,"离开冰箱",ready)
			_fill(sprint_action,"取饮料",ready and state.home_drinks>0,"冰箱已经空了，先补货")
			_fill(build_action,"喝饮料",ready and state.count("饮料")>0,"背包里没有饮料，先取一瓶")
			_fill(boat_stop_action,"查看储藏",true)
			_fill(boat_home_action,"补货",ready and state.home_drinks<12,"冰箱已经满了")
		"bed":
			_fill(context_action,"起床",ready)
			_fill(sprint_action,"睡到清晨" if night else "短休两小时",ready and world.player.bed_stage=="resting","躺稳之后才能休息" if ready else "动作进行中")
			var lamp_on:bool=bool(world.villa_room.get_meta("bedside_lamp_on",false)) if is_instance_valid(world.villa_room) else false
			_fill(build_action,"关床头灯" if lamp_on else "开床头灯",ready and is_instance_valid(world.villa_room) and world.villa_room.has_node("BedsideLampLight"),"这间屋子的床头灯还没接好")
			_fill(boat_stop_action,"查看",true)
			var bed_tidy:bool=bool(world.villa_room.get_meta("bed_tidy",true)) if is_instance_valid(world.villa_room) else true
			_fill(boat_home_action,"整理床铺",ready and not bed_tidy,"被子已经是平的，不用整理")
		"sofa","rest":
			_fill(context_action,"起身",ready)
			_fill(sprint_action,"关闭电视" if world.home_tv_on else "打开电视",ready)
			_fill(build_action,"喝饮料",ready and state.count("饮料")>0,"背包里没有饮料，先去冰箱取一瓶")
			_fill(boat_stop_action,"查看",true)
			_fill(boat_home_action,"小憩",ready,"现在没法打盹")
		"dining":
			_fill(context_action,"进食中" if sofa_session.food_time>=0 else "吃东西",ready and sofa_session.food_time<0,"正在进食，等这一口吃完")
			_fill(sprint_action,"起身",ready)
			_fill(build_action,"喝饮料",ready and state.count("饮料")>0,"背包里没有饮料，先去冰箱取一瓶")
			_fill(boat_stop_action,"查看",true)
			var meal:bool=bool(world.villa_room.get_meta("meal_placed",false)) if is_instance_valid(world.villa_room) else false
			_fill(boat_home_action,"收拾餐具" if meal else "摆放餐食",ready and is_instance_valid(world.villa_room) and world.villa_room.has_node("DiningMealPlate"),"这间屋子的餐桌还没接好")
		"balcony":
			_fill(context_action,"起身",ready)
			_fill(sprint_action,"静躺" if sofa_session.rocking else "轻摇",ready)
			_fill(build_action,"伸懒腰",ready and sofa_session.stretch_time<0,"正在伸展")
			_fill(boat_stop_action,"查看",true)
			_fill(boat_home_action,"打盹",ready,"现在没法在海风里打盹")
		"gym":
			_fill(context_action,"结束锻炼",true)
			_fill(sprint_action,"加强度" if exercise_session.intensity<3 else "已最高强度",exercise_session.intensity<3,"强度已经到最大了")
			_fill(build_action,"减强度" if exercise_session.intensity>1 else "已最低强度",exercise_session.intensity>1,"强度已经是最低")
			_fill(boat_stop_action,"查看",true)
			_fill(boat_home_action,"继续" if exercise_session.paused else "暂停",true)
	world.show_interaction({})
	return true
## 槽位点击派发：返回 true 表示这一槽在当前预制体里已有真实动作并已执行。
func _prefab_slot(index:int,point:Dictionary={}) -> bool:
	var ctx:String=_prefab_context()
	var ready:bool=movement_enabled()
	match ctx:
		"fridge":
			match index:
				1:home_routine.take();return true
				2:home_routine.drink();return true
				4:home_routine.restock();return true
		"bed":
			if index==1 and ready:
				if state.hour()>=18 or state.hour()<6:bed_session.sleep_to_morning()
				else:bed_session.nap()
				return true
			if index==2 and ready:return _toggle_bedside_lamp()
			if index==4 and ready:return bed_session.tidy()
		"sofa","rest":
			if index==1 and ready:
				world.set_home_tv(not world.home_tv_on);state.say("电视已打开" if world.home_tv_on else "电视已关闭");_update_context();return true
			if index==2 and ready:return state.drink_beverage()
			if index==4 and ready:return state.nap_on_sofa()
		"dining":
			if index==1 and ready:sofa_session.finish();_sync_overlay_state();return true
			if index==2 and ready:return state.drink_beverage()
			if index==4 and ready:return _toggle_meal_plate()
		"balcony":
			if index==1 and ready:sofa_session.toggle_rocking();return true
			if index==2 and ready:sofa_session.stretch();return true
			if index==4 and ready:return state.nap_in_rocker()
		"gym":
			if index==1:exercise_session.set_intensity(exercise_session.intensity+1);return true
			if index==2:exercise_session.set_intensity(exercise_session.intensity-1);return true
			if index==4:exercise_session.toggle_pause();return true
	if index==3:return _inspect(ctx,point)
	return false
func _update_context() -> void:
	if context_action == null: return
	for slot_key in SKILL_SLOTS:
		_layout_skill(slot_key)
	for slot:Control in [context_action,sprint_action,build_action,boat_stop_action,boat_home_action]:slot.show()
	if not world.player.boating:
		boat_stop_action.clear_skill();boat_home_action.clear_skill()
	if world.player.boating:
		var ready:bool=world.player.rowing_pose!=null and world.player.rowing_pose.ready()
		var enabled:bool=movement_enabled() and ready
		context_action.set_title(boat_session.title() if ready else "拿起船桨")
		context_action.active=enabled and boat_session.phase in ["","soak"] and not world.return_pilot.active
		context_action.set_badge(str(int(boat_session.soak/20*100))+"%" if boat_session.phase=="soak" else "")
		sprint_action.set_title("加速");sprint_action.active=enabled and not boat_session.locked() and not world.return_pilot.active
		var dock:Dictionary=world.nearby_action()
		build_action.set_title("登岛" if dock.get("kind")=="remote_land" else "主岛靠岸" if dock.get("kind")=="disembark" else "靠岸")
		# 登岛只要求船能开、港区命中；不再等「船桨已拿起」，否则刚上船时登岛是灰的。
		build_action.active=movement_enabled() and not boat_session.busy() and dock.get("kind") in ["remote_land","disembark"]
		# 鲨鱼贴近时，同一槽位（停船位）临时切成「驱赶鲨鱼」：槽位数量与位置不变，只换名称和动作。
		var giants:Node=world.sea_giants
		var threatened:bool=giants!=null and giants.shark_threat()<=12.0
		if threatened:
			boat_stop_action.set_title("驱赶鲨鱼");boat_stop_action.active=enabled and giants.repel_ready()
		else:
			boat_stop_action.set_title("继续航行" if boat_session.stopped else "停船");boat_stop_action.active=enabled and not boat_session.busy() and not world.return_pilot.active
		boat_home_action.set_title("取消返航" if world.return_pilot.active else "返航主岛");boat_home_action.active=enabled and not boat_session.busy()
		world.show_interaction({});return
	context_action.set_badge("")
	if home_routine!=null and home_routine.phase=="fridge":
		if _apply_prefab_skills():return
	if exercise_session!=null and exercise_session.active:
		# 固定五技能规范：五个槽位都填，锻炼中不能用的槽位置灰并写明原因。
		if _apply_prefab_skills():return
	if sofa_session!=null and sofa_session.active and sofa_session.mode=="dining":
		if _apply_prefab_skills():return
	if sofa_session!=null and sofa_session.active and sofa_session.mode=="balcony":
		if _apply_prefab_skills():return
	if world.player.sofa_seated:
		if _apply_prefab_skills():return
	if world.player.home_busy:
		sprint_action.clear_skill();build_action.clear_skill();context_action.set_title("取消动作");context_action.active=movement_enabled();world.show_interaction({});return
	if world.player.bed_stage!="":
		if _apply_prefab_skills():return
	if world.player.stair_active:
		sprint_action.clear_skill();build_action.clear_skill();context_action.set_title("上下楼中" if world.player.stair_active else "休息中")
		context_action.active=false;world.show_interaction({});return
	if fishing_session != null and fishing_session.active:
		fishing_session.sync_controls()
		world.show_interaction({})
		return
	var speed_title := "加速" if world.player.boating else "奔跑"
	if sprint_action.title != speed_title: sprint_action.set_title(speed_title)
	sprint_action.set_badge("");sprint_action.active=movement_enabled()
	var auxiliary_title:String=("取消返航" if world.return_pilot.active else "返航主岛") if world.player.boating else ("返回船上" if not state.island_visit.is_empty() else "建造")
	if build_action.title!=auxiliary_title:build_action.set_title(auxiliary_title)
	build_action.active=movement_enabled()
	if interaction_director!=null and interaction_director.active:
		context_action.set_title("取消就位");context_action.active=movement_enabled()
		world.show_interaction(interaction_director.point)
		return
	var point: Dictionary = world.nearby_action()
	world.show_interaction(auto_task.point if movement_enabled() and auto_task.running and auto_task.stage=="walk" else {})
	var title := "看向物体" if world.orbit.first_person else "交互"
	if not point.is_empty():
		title = point.title
		if point.kind == "house":
			title = "休息"
			for stage: String in State.HOUSE_STAGES:
				if not state.buildings.has(stage):
					title = "建" + stage
					break
	if context_action.title != title: context_action.set_title(title)
	if point.get("kind")=="villa_computer":
		var media:Node=world.villa_room.get_node_or_null("HomeComputer")
		context_action.set_title("关闭电脑" if media!=null and media.enabled else "打开电脑")
	# 站在任意预制体旁，第四槽都提供真实的「查看」：报出对象名、当前时刻和你的精力。
	_prefab_point = point
	if not world.player.boating:
		if point.is_empty():
			_fill(boat_stop_action,"",false,"附近没有可查看的物件")
			_fill(boat_home_action,"打招呼",movement_enabled() and home_routine.ready_actor(),"当前动作结束后才能打招呼")
		else:
			_fill(boat_stop_action,"查看",movement_enabled())
	var active := movement_enabled() and not point.is_empty()
	if context_action.active != active:
		context_action.active = active
		context_action.queue_redraw()

func _land_on_island(site:Dictionary) -> bool:
	if not world.exploration.land(site):return false
	joystick.reset();sprint_action.reset();sprinting=false
	return true
func _return_to_parked_boat() -> bool:
	interaction_director.cancel();auto_task.stop("")
	if not world.exploration.return_to_boat():return false
	joystick.reset();sprint_action.reset();sprinting=false
	return true

func _toggle_computer() -> bool:
	if state.location!="villa" or state.home_floor!=1:return false
	var media:Node=world.villa_room.get_node_or_null("HomeComputer")
	if media==null:return false
	media.set_enabled(not media.enabled)
	state.log_event("打开电脑，开始播放视频。" if media.enabled else "关闭电脑。")
	return true

func _nearby_interact() -> void:
	if not movement_enabled() or world.player.stair_active:return
	if world.orbit.first_person and home_routine!=null and home_routine.phase=="fridge":home_routine.cancel();return
	if exercise_session!=null and exercise_session.active:exercise_session.finish();return
	if world.player.home_busy:home_routine.cancel();return
	if world.player.bed_stage!="":bed_session.finish();return
	if world.player.sofa_seated:
		if sofa_session.mode=="dining":sofa_session.begin_eating()
		else:sofa_session.finish()
		return
	if fishing_session.active:
		fishing_session.interact()
		return
	if interaction_director.active:
		interaction_director.cancel("已取消就位。")
		return
	var point: Dictionary = world.nearby_action()
	if point.is_empty(): return
	var skip: bool=world.player.boating or point.kind in ["pet","villa_stairs","remote_return"] or (point.kind=="boat" and (not world.boarding_block_reason(state).is_empty()))
	if skip or not point.has("anchor"):_execute_interaction(point)
	else:interaction_director.request(point,func():_execute_interaction(point))

func _execute_interaction(point: Dictionary) -> void:
	match str(point.kind):
		"shore_fish": _act(fishing_session.begin)
		"villa_entry": _act(world.enter_villa.bind(state))
		"villa_exit": _act(world.leave_villa.bind(state))
		"villa_computer": _act(_toggle_computer)
		"villa_balcony_rest": _act(sofa_session.begin_balcony)
		"villa_balcony": _act(world.visit_balcony.bind(state))
		"villa_balcony_return": _act(world.return_from_balcony.bind(state))
		"villa_stairs": _act(world.change_home_floor.bind(state))
		"villa_tv":
			world.set_home_tv(not world.home_tv_on);state.say("电视已打开" if world.home_tv_on else "电视已关闭")
		"villa_rest": _act(sofa_session.begin)
		"villa_sleep": _act(bed_session.begin)
		"villa_water": _act(home_routine.begin_sink.bind("water"))
		"villa_eat": _act(sofa_session.begin_dining.bind(point.get("seat")))
		"gym_treadmill","gym_bike","gym_weights","gym_yoga": _act(exercise_session.begin.bind(point))
		"villa_fridge": _act(home_routine.open_fridge)
		"villa_bin": _act(home_routine.begin_discard)
		"villa_cook": _act(home_routine.begin_sink.bind("cooking"))
		"villa_bath": _act(state.bathe_at_home)
		"villa_storage": _toggle_inventory()
		"house":
			for stage: String in State.HOUSE_STAGES:
				if not state.buildings.has(stage):
					_act(state.craft.bind(stage))
					return
			_act(state.rest.bind(state.hour() >= 18 or state.hour() < 6))
		"pet": _act(world.pet_companion.bind(state))
		"cook": _act(state.craft.bind("鱼干"))
		"market": _select_tab("集市")
		"sail": _select_tab("航行")
		"boat":
			if world.boarding_block_reason(state).is_empty():_act(world.board_boat.bind(state))
			else:_open_boat_status()
		"remote_land": _act(_land_on_island.bind(point.site))
		"remote_return": _act(_return_to_parked_boat)
		"disembark": _act(world.disembark_boat)
		"sea_fish": _act(state.catch_sea_species)
		"town_route": _confirm_travel("town")
		_: _act(state.labor.bind(str(point.kind)))

func _show_credits() -> void:
	var dialog:Control=preload("res://scripts/life/game_dialog.gd").new();safe_root.add_child(dialog);dialog.setup(self,false)
	dialog.title = "素材鸣谢 · Polyfork"
	dialog.dialog_text = "Polyfork · CC BY 4.0\nhttps://creativecommons.org/licenses/by/4.0/\n\n素材调整：缩放、放置、顶点色；森林地形局部平整及法线重算。\nPolyfork 不为本游戏背书。\n\n"
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/polyfork/manifest.json"))
	if manifest is Array:
		for item: Dictionary in manifest: dialog.dialog_text += str(item.source) + "\n"
	dialog.theme = ui_root.theme
	dialog.get_label().add_theme_font_size_override("font_size", 14)
	dialog.get_ok_button().custom_minimum_size.y = 56
	var previously_paused := paused
	paused = true
	pause_button.text = "继续"
	dialog.confirmed.connect(func(): paused = previously_paused; pause_button.text = "继续" if paused else "暂停"; dialog.queue_free(); _sync_overlay_state())
	dialog.canceled.connect(func(): paused = previously_paused; pause_button.text = "继续" if paused else "暂停"; dialog.queue_free(); _sync_overlay_state())
	dialog.popup_centered()

func _open_settings() -> void:
	_close_drawers()
	joystick.reset()
	context_action.reset()
	sprint_action.reset()
	build_action.reset()
	world.orbit.cancel_drag()
	layout_editor.open_settings()

func _on_arrival_completed() -> void:
	world.orbit.commit_spawn_view()
	_sync_overlay_state()
	_update_context()

func _open_arrival() -> void:
	_close_drawers()
	joystick.reset()
	context_action.reset()
	sprint_action.reset()
	world.orbit.cancel_drag()
	arrival.open()
	_sync_overlay_state()

func _camera_heading() -> String:
	var forward: Vector3 = -world.camera.global_basis.z
	var index := posmod(roundi(atan2(forward.x, -forward.z) / (PI / 4)), 8)
	return ["北", "东北", "东", "东南", "南", "西南", "西", "西北"][index]

func _confirm_reset_game() -> void:
	pending = _reset_game
	confirmation.title = "重新开始岛屿生活"
	confirmation.get_ok_button().text = "确认重置"
	confirmation.dialog_text = "将清除人物、宠物、房屋、背包、任务和货币，从第一天重新开始。操作布局保留。\n此操作无法撤销，确定重置吗？"
	confirmation.popup_centered()

func _reset_game() -> bool:
	boat_session.reset()
	interaction_director.cancel()
	auto_task.cancel_job()
	auto_task.status = "游戏已重置，重新安排任务。"
	if exercise_session!=null:exercise_session.finish()
	if sofa_session!=null:sofa_session.finish()
	if fishing_session!=null:fishing_session.cancel(false)
	world.return_pilot.cancel()
	if home_routine!=null:home_routine.cancel()
	if bed_session!=null:bed_session.cancel()
	world.player.cancel_stairs()
	var fresh := State.new()
	var entrance:Vector3=world.Villa.OUTSIDE_SPAWN
	fresh.location="island"
	fresh.home_floor=0
	fresh.player_position=[entrance.x,entrance.y,entrance.z]
	if not test_mode:
		# Stage the fresh save before touching the current one.
		var error := fresh.save_game("user://life.reset")
		if error != OK: state.save_error = "重置失败：" + error_string(error); return false
		for path: String in ["user://life.json.bak", "user://life.json.tmp"]:
			if FileAccess.file_exists(path):
				error = DirAccess.remove_absolute(path)
				if error != OK: state.save_error = "重置失败：" + error_string(error); return false
		error = DirAccess.rename_absolute("user://life.reset", "user://life.json")
		if error != OK: state.save_error = "重置失败：" + error_string(error); return false
	if not world.player.pet_stage.is_empty(): world.player.cancel_pet()
	if world.player.boating: world._set_boating(false)
	state = fresh
	paused = false
	world.last_location = ""
	world.last_profile = ""
	world.sync(state)
	world.player.move_input=Vector2.ZERO;world.player.manual_world_direction=Vector3.INF;world.player.velocity=Vector3.ZERO
	sprinting=false;joystick.reset();context_action.reset();sprint_action.reset();build_action.reset()
	world.player.position=entrance
	world.player.visual.rotation.y=0
	world.orbit.reset_for_new_game(-PI*.55)
	_refresh()
	_open_arrival()
	return true

func _build_tasks_ui() -> void:
	minimap = preload("res://scripts/life/island_minimap.gd").new()
	minimap.setup(self)
	minimap.position.x=-8
	minimap.expanded.connect(_open_map)
	task_drawer = PanelContainer.new()
	task_drawer.name = "TaskDrawer"
	task_drawer.add_theme_stylebox_override("panel", panel(Color("142e35f5")))
	safe_root.add_child(task_drawer)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	task_drawer.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := label("任务 · 安排今天的工作", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	modal_close(header,_close_drawers)
	task_status = label("", 17, Color("f3d99d"))
	rows.add_child(task_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	task_entries = VBoxContainer.new()
	task_entries.add_theme_constant_override("separation", 8)
	list.add_child(task_entries)
	list.add_child(label("人物会自行寻找材料、走到目标处并动手。建房按地基、墙体、屋顶、门与床依次完成。", 16))
	task_pause_button = button(list, "暂停任务", func(): auto_task.pause_job())
	task_resume_button = button(list, "继续执行", func(): auto_task.resume_job(); _close_drawers())
	task_night_button = button(list, "继续夜间劳作", func(): auto_task.resume_job(true); _close_drawers())
	task_cancel_button = button(list, "取消任务", func(): auto_task.cancel_job())
	button(list, "领取已完成的里程碑", func(): _act(state.claim))
	task_drawer.hide()
	map_drawer = PanelContainer.new()
	map_drawer.name = "ExpandedMap"
	map_drawer.add_theme_stylebox_override("panel", panel(Color("142e35fa")))
	map_drawer.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	map_drawer.offset_left = -270; map_drawer.offset_right = 270
	map_drawer.offset_top = -310; map_drawer.offset_bottom = 310
	safe_root.add_child(map_drawer)
	var map_rows := VBoxContainer.new()
	map_drawer.add_child(map_rows)
	var map_caption=label("北朝上 · 点击地图还原",17)
	map_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var map_header:=HBoxContainer.new();map_rows.add_child(map_header);map_caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_header.add_child(map_caption);modal_close(map_header,_close_drawers)
	large_map = preload("res://scripts/life/island_minimap.gd").new()
	large_map.setup(self)
	large_map.reparent(map_rows)
	large_map.expanded.connect(_close_drawers)
	large_map.tooltip_text="点击还原小地图"
	large_map.custom_minimum_size = Vector2(420, 420)
	large_map.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	map_rows.add_child(label("白箭头：人物 · 金点：自己的船与码头\n米黄色：家 / 商铺 · 紫点：宠物 · 黄圈：任务目标", 16))
	map_drawer.hide()

func _open_tasks() -> void:
	_close_drawers()
	task_drawer.show()
	_update_task_status()
	_sync_overlay_state()

func _start_task(id: String) -> void:
	interaction_director.cancel()
	if not world.player.pet_stage.is_empty(): world.player.cancel_pet()
	if auto_task.start(id): _close_drawers()
	else: _update_task_status()

func _cancel_tracked_task() -> void:
	auto_task.stop();auto_task.job="";auto_task.point={}
	_update_task_status();_sync_overlay_state()

func _tracked_task_text() -> String:
	if auto_task.job.is_empty() or auto_task._completed():return ""
	var title: String=auto_task.JOBS.get(auto_task.job,"当前任务")
	if not auto_task.item.is_empty():title="%s %d/%d"%[auto_task.item,state.daily_count(auto_task.job),auto_task.goal_count]
	elif auto_task.job=="house":
		var count := 0
		for stage: String in State.HOUSE_STAGES:
			if state.buildings.has(stage):count+=1
		title="建房 %d/4"%count
	return title+(" · 执行中 ▾" if auto_task.running else " · 已暂停 ▾")

func _has_task_pending() -> bool:
	state.ensure_daily()
	for id:String in State.DAILY_TARGETS:
		if not state.daily_done(id):return true
	for building:String in ["篝火","庇护所","木屋"]:
		if building=="庇护所" and state.buildings.has("木屋"):continue
		if not state.buildings.has(building):return true
	var quest:Dictionary=state.current_quest()
	return not quest.is_empty() and state.quest_done(quest.id)

func _update_task_status() -> void:
	if task_red_dot!=null:task_red_dot.visible=_has_task_pending()
	if task_status == null: return
	_refresh_task_entries()
	goal_button.text=_tracked_task_text()
	if track_toggle!=null:track_toggle.text="暂停" if auto_task.running else "继续"
	if task_pause_button != null:
		task_pause_button.disabled = not auto_task.running
		var can_resume: bool = not auto_task.job.is_empty() and not auto_task.running and not auto_task._completed()
		task_resume_button.disabled = not can_resume
		task_night_button.disabled = not can_resume
		task_cancel_button.disabled = auto_task.job.is_empty()
	var progress := ""
	if auto_task.job == "house":
		var count := 0
		for step: String in State.HOUSE_STAGES:
			if state.buildings.has(step): count += 1
		progress = "\n建房阶段 %d/4" % count
	elif not auto_task.item.is_empty(): progress = "\n%s %d/%d" % [auto_task.item,state.daily_count(auto_task.job),auto_task.goal_count]
	if task_hint != null: task_hint.text = auto_task.status + progress
	task_status.text = auto_task.status + progress + "\n木材 %d · 石材 %d · 纤维 %d" % [state.count("木材"),state.count("石材"),state.count("纤维")]
	var milestone: Dictionary = state.current_quest()
	if not milestone.is_empty(): task_status.text += "\n里程碑：%s · 补助 %d 贝币" % [milestone.name, milestone.reward]

func _open_map() -> void:
	_close_drawers()
	map_drawer.show()
	_sync_overlay_state()

func _refresh_task_entries() -> void:
	if task_entries == null: return
	state.ensure_daily()
	var key: String = str(state.daily) + str(state.buildings) + str(world.player.boating) + state.location + str(state.island_visit) + str(state.claimed) + str(state.flags)
	if key == task_entries_key: return
	task_entries_key = key
	for child in task_entries.get_children():
		task_entries.remove_child(child)
		child.queue_free()
	var milestone:Dictionary=state.current_quest()
	if not milestone.is_empty() and state.quest_done(milestone.id):
		button(task_entries,"领取里程碑奖励 · "+str(milestone.name),func():_act(state.claim)).name="ClaimMilestone"
	section(task_entries, "我的家")
	if state.location == "island": button(task_entries, "回家 · 海景别墅",_start_task.bind("villa"))
	elif state.location == "villa": task_entries.add_child(label("沿楼梯下楼，走到一楼正门出门。",15))
	task_entries.add_child(label("一楼：客厅、厨房餐厅、书房；二楼：卧室、浴室、阳台。靠近门、楼梯和家具即可交互。",15))
	section(task_entries, "每日固定任务 · 游戏次日刷新")
	var remaining := 0
	for id: String in State.DAILY_TARGETS:
		if state.daily_done(id): continue
		remaining += 1
		button(task_entries, "%s · %d/%d · 执行" % [auto_task.JOBS[id],state.daily_count(id),State.DAILY_TARGETS[id]], _start_task.bind(id)).name = "Daily_" + id
	if remaining == 0: task_entries.add_child(label("今日任务已全部完成，清单已清空。明天再来，安心休息吧。", 17, Color("b4c5ac")))
	section(task_entries, "建设目标 · 完成后移除")
	for id: String in ["fire", "shelter", "house"]:
		var building: String = {"fire": "篝火", "shelter": "庇护所", "house": "木屋", "boat": "小船"}[id]
		if state.buildings.has(building) or (id == "shelter" and state.buildings.has("木屋")): continue
		var execute: Callable = _open_boat_status if id == "boat" else _start_task.bind(id)
		button(task_entries, auto_task.JOBS[id] + " · 执行", execute).name = "Build_" + id
		var costs := {"fire": "木材3 · 石材2", "shelter": "木材8 · 纤维6", "house": "四阶段共需木材24 · 石材4 · 纤维8", "boat": "木材12 · 纤维8"}
		task_entries.add_child(label(costs[id] + "，缺材自动采集。",15,Color("b4c5ac")))
	if state.location == "island" and state.buildings.has("小船") and not world.player.boating:
		section(task_entries, "码头出海")
		if not state.island_visit.is_empty():
			button(task_entries,"返回停靠的船",func():_close_drawers();_act(_return_to_parked_boat)).name="ReturnParkedBoat"
		else:
			button(task_entries,"前往码头并自动上船",_start_task.bind("embark")).name = "EmbarkBoat"
			task_entries.add_child(label("走到栈道尽头后自动登船；上船后用摇杆划船。恶劣天气或缺食水会提示原因。",15))

func _open_boat_status() -> void:
	if state.location == "villa": _act(world.leave_villa.bind(state)); return
	if not world.player.boating and not state.island_visit.is_empty():_act(_return_to_parked_boat);return
	if world.player.boating:
		if boat_session.busy():state.say("先收好渔网或完成靠岸，再返航。");return
		boat_session.stopped=false
		if world.return_pilot.active:world.return_pilot.cancel("已取消自动靠岸。")
		else:_act(world.return_pilot.start)
		return
	confirmation.title = "我的船 · 可出海"
	var distance := Vector2(world.player.position.x - world.DOCK.x, world.player.position.z - world.DOCK.z).length()
	var reason: String = world.boarding_block_reason(state)
	if not reason.is_empty():
		confirmation.dialog_text = reason + "\n可在生活菜单补充食水，天气转好后再出海。"
		confirmation.get_ok_button().text = "打开生活菜单"
		pending = func(): _select_tab("生活")
		confirmation.popup_centered()
	else:
		if distance <= world.BOARD_RADIUS: interaction_director.request(world.find_interaction("boat"),func():_act(world.board_boat.bind(state)))
		else: _start_task("embark")
