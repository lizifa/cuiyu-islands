extends SceneTree
const State = preload("res://scripts/life/life_state.gd")
var failures := 0
var app: Node
var evidence := "/tmp/qinggeng-evidence"

func _initialize() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		push_error("UI smoke requires -- --test-mode to protect real saves")
		quit(1)
		return
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func press(text: String) -> void:
	for node in app.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			node.pressed.emit()
			return
	if text in ["暂停", "继续", "劳作", "建房", "生活", "航行", "集市", "日历"]:
		app._toggle_menu()
		for node in app.menu_drawer.find_children("*", "Button", true, false):
			if node.text == text and node.is_visible_in_tree():
				node.pressed.emit()
				return
	check(false, "Visible button missing: " + text)

func photo(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		await process_frame
		return
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	RenderingServer.force_draw(false)
	var img := root.get_texture().get_image()
	img.save_png(evidence.path_join(name_value + ".png"))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	press("暂停")
	var t: float = app.state.minute
	await process_frame
	check(app.state.minute == t, "paused time moved")
	press("继续")
	app.world.player.position = Vector3(-5, 0.7, -0.8)
	press("劳作")
	press("伐木  ·  45分钟")
	check(app.state.count("木材") == 4, "labor button failed")
	press("建房")
	check(app.tab == "制造", "craft tab navigation")
	press("篝火 · 木材3 + 石材2")
	check(not app.state.buildings.has("篝火"), "craft accepted missing stone")
	# State fixtures are used only for visual scenes; commerce tests cover earned progression.
	app.state.inventory["木材"] = 30
	app.state.inventory["石材"] = 8
	app.state.inventory["纤维"] = 25
	press("篝火 · 木材3 + 石材2")
	check(app.state.buildings.has("篝火"), "build button failed")
	app.state.craft("庇护所")
	app.state.inventory["木材"] = 40
	app.state.inventory["石材"] = 8
	app.state.inventory["纤维"] = 20
	for stage: String in State.HOUSE_STAGES: app.state.craft(stage)
	app.state.craft("菜地")
	app.state.craft("小船")
	app.state.minute = 9 * 60
	app._refresh()
	press("劳作")
	await photo("01-island-day")
	app.state.minute = 20 * 60
	app._refresh()
	press("生活")
	await photo("02-island-night")
	press("睡到次日06:00 · 18:00后")
	check(app.state.day() == 1 and app.state.hour() < 6.1, "sleep button failed")
	app.state.minute = 4 * 1440 + 9 * 60
	app.state.hunger = 100
	app.state.thirst = 100
	press("航行")
	press("去青湾镇")
	check(app.confirmation.visible, "travel confirmation missing")
	app.confirmation.hide()
	app.pending.call()
	check(app.state.location == "town", "travel confirm path failed")
	app.state.inventory["鱼干"] = 10
	press("集市")
	press("出售鱼干 ×1 · 15贝币")
	check(app.state.coins == 15, "market UI payment")
	press("换物：鱼干4 → 种子1")
	check(app.state.count("种子") == 1, "barter button")
	await photo("03-town-market")
	app.state.minute = 5 * 1440 + 10 * 60
	app._refresh()
	press("日历")
	check(app.location_label.text.contains("双休"), "weekend header")
	await photo("04-weekend")
	app.state.location = "island"
	app.state.minute = 42 * 1440 + 17 * 60
	app._refresh()
	press("建房")
	await photo("05-winter-evening")
	app.state.location = "city"
	app.state.minute = 14 * 1440 + 10 * 60
	app._refresh()
	press("集市")
	await photo("06-city-summer")
	print("UI SMOKE: %d failures; %s" % [failures, "headless: rendering skipped" if DisplayServer.get_name() == "headless" else "screenshots: " + evidence])
	quit(1 if failures else 0)
