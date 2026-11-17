extends SceneTree
const Main = preload("res://scenes/life_main.tscn")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _initialize() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var app := Main.instantiate()
	viewport.add_child(app)
	app.set_process(false)
	app.paused = false
	app.inactive = false
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1600, 720), Vector2i(1280, 960)]:
		viewport.size = dimensions
		app.test_safe_override = Vector4.ZERO
		app._close_drawers()
		app._refresh()
		await process_frame
		await process_frame
		app._layout_mobile()
		await process_frame
		var safe: Rect2 = app.safe_root.get_global_rect()
		var clock: Control = app.safe_root.get_node("MobileHeader")
		var status: Control = app.safe_root.get_node("MobileStatus")
		var quick: Control = app.safe_root.get_node("QuickAccess")
		check(not app.menu_drawer.visible and not app.action_drawer.visible and not app.info_drawer.visible, "drawers default closed")
		check(not clock.get_global_rect().intersects(status.get_global_rect()), "clock overlaps vitals")
		check(not clock.get_global_rect().intersects(quick.get_global_rect()), "clock overlaps quick actions")
		check(app.action_pad.get_child_count() == 3, "only three right thumb actions")
		var visible_buttons := 0
		for node in app.ui_root.find_children("*", "Button", true, false):
			if node.is_visible_in_tree(): visible_buttons += 1
		check(visible_buttons == 4, "HUD has tasks, backpack, settings and boat; idle tracking is hidden")
		for control: Control in [clock, status, quick, app.goal_button, app.joystick, app.action_pad]:
			check(safe.encloses(control.get_global_rect()), "HUD element outside safe area")
		app._toggle_menu()
		await process_frame
		check(app.menu_drawer.visible and not app.joystick.visible and not app.action_pad.visible, "menu replaces controls")
		check(not app.movement_enabled(), "menu stops movement")
		check(safe.encloses(app.menu_drawer.get_global_rect()), "menu stays on-screen")
		app._select_tab("制造")
		check(not app.menu_drawer.visible and app.action_drawer.visible, "one drawer at a time")
		app._toggle_inventory()
		check(app.info_drawer.visible and not app.action_drawer.visible, "backpack replaces action drawer")
		app._close_drawers()
		check(app.joystick.visible and app.action_pad.visible, "close restores controls")
		app.toast_remaining = 0
		app._sync_overlay_state()
		check(not app.toast_panel.visible, "notification does not remain on screen")
		app.state.save_error = "test failure"
		app._refresh()
		check(app.toast_panel.visible, "save failure stays visible")
		app.state.save_error = ""
		app.paused = true
		app._sync_overlay_state()
		check(app.resume_button.visible and not app.joystick.visible, "paused game has visible resume")
		app._toggle_pause()
		check(not app.paused and not app.resume_button.visible, "resume restores game")
		app.state.energy = 20
		app._refresh()
		check(app.status_bars.energy.value == 20 and app.status_values.energy.text == "20", "compact vitals reflect state")
		app.test_safe_override = Vector4(50, 0, 50, 30)
		app._layout_mobile()
		await process_frame
		check(app.safe_root.position.x >= 50, "notch insets preserved")
	var old_messages: Array[Node] = app.world.find_children("*", "Label3D", true, false)
	var visible_world_text := 0
	for node: Label3D in old_messages:
		if node.is_visible_in_tree(): visible_world_text += 1
	check(visible_world_text <= 1, "only contextual boat status may be shown")
	viewport.queue_free()
	await process_frame
	print("HUD CHECKS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
