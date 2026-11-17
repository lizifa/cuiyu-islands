extends SceneTree
const Main = preload("res://scenes/life_main.tscn")
const State = preload("res://scripts/life/life_state.gd")
var failures := 0
var checks := 0
var output := "/tmp/qinggeng-mobile"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		quit(1)
		return
	call_deferred("run")

func capture(viewport: SubViewport, name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		await process_frame
		return
	await create_timer(0.15).timeout
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(output.path_join(name_value + ".png"))

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = Vector2(960, 540)
	root.add_child(display)
	var app := Main.instantiate()
	viewport.add_child(app)
	# Fixed logical height models canvas_items + expand at each phone ratio.
	for spec: Array in [[1280, 720, "16-9"], [1560, 720, "19.5-9"], [1600, 720, "20-9"], [1280, 960, "tablet-4-3"]]:
		print("LAYOUT CASE: ", spec[2])
		viewport.size = Vector2i(spec[0], spec[1])
		app.state = State.new()
		app.test_safe_override = Vector4.ZERO
		app.action_drawer.hide()
		app.info_drawer.hide()
		app.world.last_location = ""
		app.paused = true
		app._refresh()
		await process_frame
		await process_frame
		app._layout_mobile()
		await process_frame
		check(app.ui_root.size.is_equal_approx(Vector2(viewport.size)), "viewport not filled: " + spec[2])
		var players: Array[Node] = app.world.find_children("Player", "Node3D", true, false)
		check(players.size() == 1, "opening must have exactly one person")
		check(not app.state.buildings.has("木屋") and app.state.buildings.has("小船"), "opening has a ready boat and no built house")
		check(not app.action_drawer.visible and not app.info_drawer.visible, "opening drawers should be closed")
		await capture(viewport, spec[2] + "-opening")
		app._select_tab("制造")
		await process_frame
		await process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(viewport.size))
		check(screen.encloses(app.action_drawer.get_global_rect()), "drawer clipped: " + spec[2])
		for node: Node in app.ui_root.find_children("*", "Button", true, false):
			if node.is_visible_in_tree(): check(node.size.y >= 64, "touch target too small: " + node.text)
		check(screen.encloses(app.safe_root.get_node("MobileToolbar").get_global_rect()), "toolbar clipped: " + spec[2])
		await capture(viewport, spec[2] + "-build")
		var inset: Vector4 = app.safe_insets(Vector2(viewport.size), Vector2(2400, 1080), Rect2(90, 0, 2220, 1032))
		check(inset.x > 0 and inset.z > 0 and inset.w > 0, "safe area scaling")
		app.test_safe_override = inset
		app._layout_mobile()
		await process_frame
		await process_frame
		check(app.safe_root.position.x >= inset.x and app.safe_root.size.x <= viewport.size.x - inset.x - inset.z, "notch inset did not apply")
		check(screen.encloses(app.action_drawer.get_global_rect()), "safe drawer clipped: " + spec[2])
		await capture(viewport, spec[2] + "-safe-area")
		if spec[2] == "19.5-9":
			app.action_drawer.hide()
			for stage: String in State.HOUSE_STAGES:
				app.state.inventory["木材"] = 24
				app.state.inventory["石材"] = 4
				app.state.inventory["纤维"] = 8
				check(app.state.craft(stage), "house visual stage")
				app.world.sync(app.state)
				app._refresh()
				await capture(viewport, "house-" + str(State.HOUSE_STAGES.find(stage) + 1))
	# Hit-test the actual Control rectangles using the mouse event that a touch emulates.
	app.test_safe_override = Vector4.ZERO
	app.paused = false
	app.state = State.new()
	app.world.player.position = Vector3(3, 0.7, -2.5)
	app._select_tab("劳作")
	await process_frame
	await process_frame
	var target: Button = app.action_box.get_child(0)
	var point := target.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		viewport.push_input(event, true)
		await process_frame
	check(app.state.count("木材") == 4, "emulated touch did not hit labor button")
	check(app.state.minute >= 525, "touch action did not advance simulation")
	viewport.queue_free()
	display.queue_free()
	await process_frame
	print("MOBILE LAYOUT: %d checks, %d failures; %s" % [checks, failures, "headless: rendering skipped" if DisplayServer.get_name() == "headless" else output])
	quit(1 if failures else 0)
