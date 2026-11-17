extends SceneTree
const State = preload("res://scripts/life/life_state.gd")
var passed := 0
var failed := 0
var app: Node
func check(value: bool, message: String):
	if value: passed += 1
	else: failed += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var state := State.new()
	check(state.daily_count("wood") == 0 and not state.daily_done("wood"), "fresh fixed daily tasks")
	state.labor("伐木"); state.labor("伐木"); state.labor("伐木")
	check(state.daily_done("wood") and state.daily_count("wood") == 12, "actual manual gathering completes daily task")
	state.inventory["木材"] = 0
	check(state.daily_done("wood"), "spending resources does not reopen completed task")
	var restored := State.new()
	check(restored.restore(state.snapshot()) and restored.daily_done("wood"), "daily completion survives restore")
	var path := "user://test_daily_progress.json"
	check(state.save_game(path) == OK and restored.load_game(path) and restored.daily_done("wood"), "daily completion survives real disk reload")
	DirAccess.remove_absolute(path); DirAccess.remove_absolute(path + ".bak")
	state.minute = 1439
	state.advance(2)
	check(state.day() == 1 and state.daily_count("wood") == 0, "next game day refreshes fixed task")
	var old := state.snapshot()
	old.erase("daily")
	check(restored.restore(old) and restored.daily_count("wood") == 0, "legacy save gains daily tracker")
	var bad := state.snapshot()
	bad.daily.counts.wood = -1
	check(not restored.restore(bad), "invalid daily progress rejected")
	Engine.time_scale = 10
	Engine.physics_ticks_per_second = 120
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	root.add_child(view)
	app = load("res://scenes/life_main.tscn").instantiate()
	view.add_child(app)
	app.set_process(false)
	app.inactive = false
	for frame in range(3): await physics_frame
	app._open_tasks()
	check(app.task_entries.has_node("Daily_wood"), "unfinished daily row displayed")
	for i in range(3): app.state.labor("伐木")
	app._update_task_status()
	check(not app.task_entries.has_node("Daily_wood") and app.task_entries.has_node("Daily_stone"), "completed row removed without removing unfinished tasks")
	check(not app.auto_task.start("wood"), "completed daily task cannot be repeatedly restarted")
	for i in range(2): app.state.labor("拾石"); app.state.labor("采纤维")
	app._update_task_status()
	check(not app.task_entries.has_node("Daily_wood") and not app.task_entries.has_node("Daily_stone") and not app.task_entries.has_node("Daily_fiber"), "all completed daily rows cleared")
	app.state.minute = 1440 + 8*60
	app._update_task_status()
	check(app.task_entries.has_node("Daily_wood"), "row reappears on new day")
	app.state.buildings["小船"] = true
	app.world.sync(app.state)
	app._update_task_status()
	check(not app.task_entries.has_node("Build_boat") and app.task_entries.has_node("EmbarkBoat"), "repair row clears and boarding entry appears")
	app._close_drawers()
	app.world.player.position = Vector3(3,0.7,14.1)
	check(app.world.nearby_action().kind == "boat", "boarding interaction takes priority on pier")
	check(app.world.board_boat(app.state), "manual boarding works from reachable pier")
	app.world.disembark_boat()
	app.world.player.position = Vector3(0,0.7,3.2)
	app.state.hunger = 100; app.state.thirst = 100
	app._start_task("embark")
	for frame in range(3500):
		app.inactive = false
		await physics_frame
		if not app.auto_task.running: break
	print("Embark result: ",app.auto_task.status," position ",app.world.player.position)
	check(app.world.player.boating and "已上船" in app.auto_task.status, "automated route reaches pier and actually boards")
	check(app.world.player.boat_visual.visible and not app.world.own_boat.visible, "boarding switches to driven boat visual")
	check(app.state.location == "island", "boarding does not silently travel to town")
	app.world.disembark_boat()
	app.state.hunger = 5
	app.world.player.position = app.world.DOCK
	check(not app.world.board_boat(app.state) and "吃饭" in app.state.last_message, "boarding explains insufficient supplies")
	check(not app.auto_task.start("embark") and "吃饭" in app.auto_task.status, "automated boarding checks supplies before walking")
	app.state.hunger = 100
	app.state.minute = 1440*18 + 8*60
	check(not app.world.board_boat(app.state) and "风浪" in app.state.last_message, "storm boarding explains weather block")
	check(not app.auto_task.start("embark") and "风浪" in app.auto_task.status, "automated boarding checks weather before walking")
	app.state.minute = 19*60
	app.world.player.position = app.world.DOCK
	app._start_task("embark")
	for frame in range(150):
		app.inactive = false
		await physics_frame
		if not app.auto_task.running: break
	check(app.world.player.boating, "boarding at night remains allowed without labor sunset restriction")
	app.world.disembark_boat()
	app.state.minute = 1440 + 8*60
	app.world.player.position = Vector3(0,0.7,3.2)
	app._start_task("wood")
	app.state.minute += 1440
	for frame in range(3): app.inactive = false; await physics_frame
	check(not app.auto_task.running and "新的一天" in app.auto_task.status, "cross-day daily work pauses for refreshed checklist")
	view.queue_free()
	await process_frame
	print("DAILY AND EMBARK: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
