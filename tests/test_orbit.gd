extends SceneTree
const Main = preload("res://scenes/life_main.tscn")
var passed := 0
var failed := 0
var view: SubViewport
var app: Node

func check(ok: bool, description: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(description)

func mouse_button(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	view.push_input(event, true)

func motion(point: Vector2, relative: Vector2, down: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	view.push_input(event, true)

func touch(point: Vector2, down: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = down
	event.index = index
	view.push_input(event, true)

func finger_drag(point: Vector2, relative: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.relative = relative
	event.index = index
	view.push_input(event, true)

func _initialize() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	app = Main.instantiate()
	view.add_child(app)
	app.paused = true
	await process_frame
	await process_frame
	var rig: Node = app.world.orbit
	rig.set_rotation_mode(true)
	var origin: Vector3 = app.world.camera.position
	var yaw: float = rig.target_yaw
	mouse_button(Vector2(640, 360), true)
	motion(Vector2(642, 360), Vector2(2, 0))
	check(is_equal_approx(rig.target_yaw, yaw), "tiny jitter ignored")
	motion(Vector2(800, 400), Vector2(158, 40))
	check(not is_equal_approx(rig.target_yaw, yaw), "mouse drag orbits")
	check(rig.target_pitch > rig.initial_pitch, "vertical drag changes elevation")
	await create_timer(0.1).timeout
	check(not app.world.camera.position.is_equal_approx(origin), "camera transform follows drag")
	check(is_equal_approx((app.world.camera.position - rig.focus).length(), rig.distance), "orbit preserves distance")
	mouse_button(Vector2(100, 50), false)
	check(not rig.mouse_dragging, "release over UI cancels drag")
	yaw = rig.target_yaw
	motion(Vector2(700, 360), Vector2(60, 0), false)
	check(is_equal_approx(rig.target_yaw, yaw), "hover never orbits")
	mouse_button(Vector2(640, 360), true)
	motion(Vector2(640, 400), Vector2(0, 10000))
	check(is_equal_approx(rig.target_pitch, rig.MAX_PITCH), "upper pitch clamp")
	motion(Vector2(640, 360), Vector2(0, -10000))
	check(is_equal_approx(rig.target_pitch, rig.MIN_PITCH), "lower pitch clamp")
	mouse_button(Vector2(640, 360), false)
	rig.reset_view()
	check(is_equal_approx(rig.target_yaw, rig.initial_yaw) and is_equal_approx(rig.target_pitch, rig.initial_pitch), "reset targets initial view")
	rig.set_rotation_mode(true)
	touch(Vector2(640, 360), true)
	finger_drag(Vector2(760, 370), Vector2(120, 10))
	check(not is_equal_approx(rig.target_yaw, rig.initial_yaw), "native finger orbits")
	yaw = rig.target_yaw
	touch(Vector2(800, 360), true, 1)
	finger_drag(Vector2(900, 360), Vector2(100, 0), 1)
	check(is_equal_approx(rig.target_yaw, yaw), "second finger ignored")
	touch(Vector2(800, 360), false, 1)
	check(rig.touch_id == 0, "second release retains first finger")
	touch(Vector2(760, 370), false)
	check(rig.touch_id == -1, "finger release cancels")
	var fake := InputEventMouseButton.new()
	fake.device = InputEvent.DEVICE_ID_EMULATION
	fake.button_index = MOUSE_BUTTON_LEFT
	fake.pressed = true
	fake.position = Vector2(640, 360)
	view.push_input(fake, true)
	check(not rig.mouse_dragging, "touch emulation cannot double orbit")
	# Start over the real bottom toolbar, then leave it: no gesture may begin on UI.
	yaw = rig.target_yaw
	mouse_button(Vector2(100, 50), true)
	motion(Vector2(700, 360), Vector2(60, -300))
	mouse_button(Vector2(700, 360), false)
	check(is_equal_approx(rig.target_yaw, yaw), "mouse UI drag does not orbit")
	touch(Vector2(100, 50), true)
	finger_drag(Vector2(700, 360), Vector2(60, -300))
	touch(Vector2(700, 360), false)
	check(is_equal_approx(rig.target_yaw, yaw), "touch UI drag does not orbit")
	check(app.state.minute == 480 and app.state.load_count() == 4, "camera does not change game progress")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("/tmp/qinggeng-orbit")
		for i in range(3):
			rig.target_yaw = rig.initial_yaw + i * TAU / 3.0
			rig.yaw = rig.target_yaw
			rig.pitch = rig.initial_pitch
			rig.target_pitch = rig.initial_pitch
			rig._process(1.0)
			await process_frame
			RenderingServer.force_draw(false)
			view.get_texture().get_image().save_png("/tmp/qinggeng-orbit/view-%d.png" % i)
	print("ORBIT TESTS: %d passed, %d failed" % [passed, failed])
	view.queue_free()
	await process_frame
	quit(1 if failed else 0)
