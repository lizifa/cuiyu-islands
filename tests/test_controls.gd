extends SceneTree
const Main = preload("res://scenes/life_main.tscn")
const State = preload("res://scripts/life/life_state.gd")
var app: Node
var view: SubViewport
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func touch(point: Vector2, down: bool, index: int) -> void:
	app.inactive = false
	app._update_context()
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = down
	event.index = index
	view.push_input(event, true)

func drag(point: Vector2, relative: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.relative = relative
	event.index = index
	view.push_input(event, true)

func frames(n: int, foreground: bool = true) -> void:
	for i in range(n):
		if foreground: app.inactive = false
		await physics_frame

func finish_interaction() -> void:
	for i in range(600):
		if not app.interaction_director.active:return
		await frames(1)
	check(false,"native interaction did not reach its anchor")

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _initialize() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		quit(1)
		return
	call_deferred("run" if DisplayServer.get_name() == "headless" else "render_fixture")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.grab_focus()
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var display := TextureRect.new()
	display.texture = view.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = Vector2(960, 540)
	root.add_child(display)
	app = Main.instantiate()
	view.add_child(app)
	app.paused = false
	app.inactive = false
	await process_frame
	await process_frame
	await frames(3)
	var stick: Control = app.joystick
	var player: CharacterBody3D = app.world.player
	var center: Vector2 = stick.get_global_rect().get_center()
	var origin: Vector3 = player.position
	var camera_revision: int = app.world.orbit.manual_revision
	app._act(app.state.labor.bind("伐木"))
	check(app.state.count("木材") == 0, "menu cannot gather distant resources")
	touch(center, true, 0)
	drag(center + Vector2(2, 0), Vector2(2, 0), 0)
	await frames(5)
	check(stick.direction == Vector2.ZERO, "stick deadzone")
	check(flat_distance(player.position, origin) < 0.01, "deadzone does not move actor")
	drag(center + Vector2(70, 0), Vector2(68, 0), 0)
	await frames(20)
	check(flat_distance(player.position, origin) > 0.15, "left native stick moves real CharacterBody3D")
	check(camera_revision==app.world.orbit.manual_revision, "stick is movement input rather than a manual orbit gesture")
	check(not player.walk_clip.is_empty(), "walking animation available")
	var sprint_point: Vector2 = app.sprint_action.get_global_rect().get_center()
	touch(sprint_point, true, 1)
	await frames(3)
	check(app.sprinting and player.sprint, "right finger enables sprint while left moves")
	check(stick.finger == 0 and stick.direction.length() > 0, "right action retains movement finger")
	touch(sprint_point, false, 1)
	await frames(3)
	check(not app.sprinting and not player.sprint, "sprint release stops sprint")
	var yaw:float=app.world.orbit.target_yaw
	var stable_yaw:float=app.world.orbit.requested_yaw if app.world.orbit.get("stable_third_person")==true else 0.0
	touch(Vector2(670, 350), true, 1)
	drag(Vector2(730, 350), Vector2(60, 0), 1)
	if app.world.orbit.get("stable_third_person")==true:
		check(not is_equal_approx(app.world.orbit.requested_yaw,stable_yaw) and stick.finger==0 and stick.knob==Vector2.ZERO, "independent look finger turns view while the fixed-center movement stick retains ownership")
	else:
		check(is_equal_approx(app.world.orbit.target_yaw,yaw) and app.world.orbit.manual_revision>camera_revision and app.world.orbit.target_pan.length()>.1 and stick.finger == 0, "movement plus independent pan finger preserves bearing")
	touch(Vector2(730, 350), false, 1)
	touch(center + Vector2(70, 0), false, 0)
	await frames(3)
	var stopped: Vector3 = player.position
	await frames(8)
	check(flat_distance(stopped, player.position) < 0.01 and stick.direction == Vector2.ZERO, "release stops locomotion")
	app.world.orbit.reset_view()
	await frames(20)
	origin = player.position
	Input.action_press("player_up")
	await frames(10)
	Input.action_release("player_up")
	await frames(2)
	check(flat_distance(player.position, origin) > 0.1, "named keyboard movement action")
	app.paused = true
	origin = player.position
	stick.direction = Vector2.RIGHT
	await frames(10)
	check(flat_distance(player.position, origin) < 0.01, "pause disables motion")
	app.paused = false
	app.inactive = true
	stick.direction = Vector2.RIGHT
	await frames(6, false)
	check(flat_distance(player.position, origin) < 0.01 and stick.direction == Vector2.ZERO, "background disables and clears movement")
	app.inactive = false
	app._select_tab("制造")
	stick.direction = Vector2.RIGHT
	await frames(10)
	check(flat_distance(player.position, origin) < 0.01 and stick.direction == Vector2.ZERO, "drawer disables and resets stick")
	app.action_drawer.hide()
	player.position = Vector3(2.3, 0.7, 3.0)
	await frames(2)
	app._update_context()
	check(app.context_action.title == "采果", "context finds nearby resource")
	var berries: int = app.state.count("浆果")
	var action_point: Vector2 = app.context_action.get_global_rect().get_center()
	touch(action_point, true, 1)
	touch(action_point, false, 1)
	await finish_interaction()
	check(app.state.count("浆果") == berries + 4, "right native context actually gathers")
	var identity := player.get_instance_id()
	app.state.inventory["木材"] = 6
	app.state.inventory["石材"] = 4
	player.position = Vector3(-2.5, 0.7, 1.2)
	await frames(2)
	app._update_context()
	check(app.context_action.title == "建地基", "context detects unfinished home")
	touch(action_point, true, 1)
	touch(action_point, false, 1)
	await finish_interaction()
	await frames(3)
	check(app.state.buildings.has("地基"), "context builds and charges materials")
	check(app.world.player.get_instance_id() == identity, "construction preserves player instance")
	player.position = Vector3(-2.5, 0.7, 1.2)
	var forward: Vector3 = -app.world.camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right: Vector3 = app.world.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	var desired := Vector3(0, 0, -1)
	stick.direction = Vector2(desired.dot(right), -desired.dot(forward))
	await frames(55)
	check(player.position.z > 0.35, "built house blocks passage")
	stick.reset()
	player.position = Vector3(6.3, 0.7, 0)
	desired = Vector3.RIGHT
	stick.direction = Vector2(desired.dot(right), -desired.dot(forward))
	await frames(30)
	check(app.world.terrain_walkable(player.position) and Vector2(player.position.x, player.position.z).length() > 6.35, "expanded island allows exploration beyond the old shore")
	stick.reset()
	await frames(3)
	var snapshot: Dictionary = app.state.snapshot()
	var restored = State.new()
	check(restored.restore(snapshot) and restored.player_position == snapshot.player_position, "position save roundtrip")
	snapshot.erase("player_position")
	check(restored.restore(snapshot) and restored.player_position == [0.0, 0.7, 3.2], "old save migration retains compatibility")
	if DisplayServer.get_name() != "headless":
		player.position = Vector3(0, 0.7, 3.2)
		app.world.orbit.reset_view()
		await frames(25)
		DirAccess.make_dir_recursive_absolute("/tmp/qinggeng-controls")
		RenderingServer.force_draw(false)
		view.get_texture().get_image().save_png("/tmp/qinggeng-controls/controls.png")
	print("MOBILE CONTROLS: %d passed, %d failed" % [passed, failed])
	view.queue_free()
	await process_frame
	quit(1 if failed else 0)

func render_fixture() -> void:
	# OS focus can cancel held touches, so visual capture uses a paused, isolated fixture.
	root.mode = Window.MODE_WINDOWED
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var display := TextureRect.new()
	display.texture = view.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = Vector2(960, 540)
	root.add_child(display)
	app = Main.instantiate()
	view.add_child(app)
	app.paused = true
	app.state.inventory["木材"] = 6
	app.state.inventory["石材"] = 4
	app.state.craft("地基")
	app.world.sync(app.state)
	app._refresh()
	app._update_context()
	await process_frame
	await create_timer(0.2).timeout
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("/tmp/qinggeng-controls")
	view.get_texture().get_image().save_png("/tmp/qinggeng-controls/controls.png")
	print("CONTROLS RENDER: paused fixture captured; functional checks run with --headless")
	view.queue_free()
	await process_frame
	quit(0)
