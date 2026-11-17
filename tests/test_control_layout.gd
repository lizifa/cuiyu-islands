extends SceneTree
var passed := 0
var failed := 0
var app: Node
var view: SubViewport
const PATH := "user://test_custom_controls.cfg"
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await process_frame
func touch(point: Vector2, down: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point; event.pressed = down; event.index = index
	view.push_input(event, true)
func drag(point: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point; event.index = index
	view.push_input(event, true)
func run() -> void:
	DirAccess.remove_absolute(PATH)
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	root.add_child(view)
	app = load("res://scenes/life_main.tscn").instantiate()
	view.add_child(app)
	app.set_process(false)
	app.inactive = false
	await frame()
	var editor: Control = app.layout_editor
	editor.storage_path = PATH
	var before: Rect2 = app.joystick.get_global_rect()
	check(app.joystick.size.x>=228 and app.context_action.size.x>=130,"default stick and primary action enlarged for touch")
	check(app.sprint_action.size.x>=92 and app.build_action.size.x>=92,"secondary actions enlarged for touch")
	check(not app.sprint_action.get_global_rect().intersects(app.context_action.get_global_rect()),"enlarged action hit boxes remain separated")
	app._open_settings()
	check(editor.visible and not editor.editing and not app.movement_enabled(), "settings opens and stops gameplay")
	editor.begin_edit()
	check(not app.joystick.visible and not app.action_pad.visible and editor.editing, "editing uses previews, hides actual controls")
	var initial: Dictionary = editor.draft.duplicate(true)
	var point: Vector2 = editor.global_position + editor.rect_for("context", editor.draft).get_center()
	var yaw: float = app.world.orbit.target_yaw
	var minute: float = app.state.minute
	touch(point, true)
	drag(point + Vector2(-100, -25))
	touch(point, false)
	check(editor.draft.context.x < initial.context.x, "native finger moves whole skill block")
	check(editor.draft.sprint != initial.sprint and editor.draft.build != initial.build and editor.draft.stick == initial.stick, "all skills move together and joystick remains unchanged")
	check(app.joystick.direction == Vector2.ZERO and not app.sprinting and app.world.orbit.target_yaw == yaw, "editor does not activate gameplay or camera")
	app._process(1)
	check(app.state.minute == minute, "editing freezes game clock")
	editor.cancel()
	check(editor.saved.is_empty() and app.joystick.get_global_rect() == before, "cancel preserves live layout")
	app._open_settings(); editor.begin_edit()
	editor.select("group")
	var delta_before: Vector2 = editor.rect_for("context", editor.draft).get_center() - editor.rect_for("sprint", editor.draft).get_center()
	editor.move_selected(Vector2(-200, -100))
	var delta_after: Vector2 = editor.rect_for("context", editor.draft).get_center() - editor.rect_for("sprint", editor.draft).get_center()
	check(delta_after.is_equal_approx(delta_before) and editor.draft.stick == initial.stick, "group drag preserves relative positions and joystick")
	editor.select("build")
	editor.adjust("scale", 1.2)
	editor.adjust("alpha", 0.45)
	check(editor.commit(), "valid layout saves atomically")
	check(not editor.visible and app.movement_enabled(), "save resumes previous play state")
	check(is_equal_approx(app.build_action.size.x, 92 * 1.2) and is_equal_approx(app.build_action.modulate.a, 0.45), "size and transparency apply to live button")
	var config := ConfigFile.new()
	check(config.load(PATH) == OK and editor.valid(config.get_value("layout", "controls")), "saved layout reloads independently of game progress")
	var data: Dictionary = editor.saved.duplicate(true)
	var reloaded := load("res://scripts/life/control_layout.gd").new() as Control
	reloaded.setup(app, editor.controls, PATH)
	await frame()
	var restored: bool = reloaded.valid(reloaded.saved)
	for id: String in editor.IDS:
		for key: String in ["x","y","scale","alpha"]:
			restored = restored and is_equal_approx(reloaded.saved[id][key],data[id][key])
	check(restored, "new settings instance restores persistent preferences within float serialization precision")
	reloaded.queue_free()
	await frame()
	app._open_settings(); editor.begin_edit()
	editor.reset_draft(); editor.cancel()
	check(editor.saved == data, "reset is a cancellable draft")
	app._open_settings(); editor.begin_edit()
	editor.draft.context.x = editor.draft.sprint.x
	editor.draft.context.y = editor.draft.sprint.y
	check(not editor.commit() and editor.visible and editor.saved == data, "overlapping controls cannot overwrite saved layout")
	editor.reset_draft()
	editor.storage_path = "user://nonexistent_directory/controls.cfg"
	check(not editor.commit() and editor.saved == data, "write failure is recoverable and preserves saved layout")
	editor.storage_path = PATH
	editor.cancel()
	var invalid := data.duplicate(true)
	invalid.stick.scale = NAN
	check(not editor.valid(invalid) and not editor.valid({}), "malformed and nonfinite preferences rejected")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1600, 720), Vector2i(1280, 960)]:
		view.size = dimensions
		app.test_safe_override = Vector4(50, 0, 50, 30)
		await frame()
		app._layout_mobile()
		await frame()
		editor.apply()
		for control: Control in editor.controls.values():
			check(app.safe_root.get_global_rect().encloses(control.get_global_rect()), "custom controls respect screen and notch bounds")
	app.paused = true
	app._open_settings(); editor.begin_edit(); editor.cancel()
	check(app.paused, "closing settings preserves preexisting pause")
	app.paused = false
	app._sync_overlay_state()
	# Native touches use the saved, relocated hit box, not old coordinates.
	app._open_settings(); editor.begin_edit(); editor.reset_draft()
	editor.select("stick"); editor.move_selected(Vector2(150, -50))
	check(editor.commit(), "save relocated joystick")
	point = app.joystick.get_global_rect().get_center()
	touch(point + Vector2(45, 0), true)
	check(app.joystick.direction.x > 0, "relocated joystick accepts native input at new location")
	touch(point, false)
	check(app.joystick.direction == Vector2.ZERO, "relocated joystick release resets")
	DirAccess.remove_absolute(PATH)
	app.set_process(false)
	view.queue_free()
	await process_frame
	print("CONTROL LAYOUT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
