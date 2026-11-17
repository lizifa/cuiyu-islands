extends SceneTree
var passed := 0
var failed := 0
var app: Node
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		app.inactive = false
		await physics_frame
func finish(limit: int = 2500) -> void:
	for i in range(limit):
		app.inactive = false
		await physics_frame
		if not app.auto_task.running: return
	check(false,"task exceeded execution limit")
func _initialize(): call_deferred("run")
func run():
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
	await frames(3)
	check(not app.skill_frame.visible, "skill frame absent during normal play")
	check(app.minimap.size == Vector2(152,152), "compact corner minimap")
	app._open_tasks()
	check(app.task_drawer.visible and not app.movement_enabled(), "task drawer pauses game")
	app._start_task("wood")
	check(app.auto_task.running and not app.task_drawer.visible, "execute closes drawer and starts task")
	var origin: Vector3 = app.world.player.position
	await finish()
	print("Wood result: ", app.auto_task.status," inventory ", app.state.inventory)
	check(app.state.count("木材") == 12 and "完成" in app.auto_task.status, "auto wood earns three actual harvest batches")
	check(app.world.player.position.distance_to(origin) > 1, "real character walked to resource")
	check(is_equal_approx(app.state.energy,78.25) and app.state.minute == 615, "normal labor time and energy costs apply")
	check(not app.world.player.working, "completed task restores idle")
	app._sync_overlay_state()
	check(not app.task_hint.visible, "completed daily task clears persistent HUD hint")
	app._start_task("house")
	await finish(6000)
	print("House result: ", app.auto_task.status," buildings ",app.state.buildings," position ",app.world.player.position)
	check(app.state.buildings.has("木屋"), "house gathers missing materials and builds all stages")
	check(app.state.count("木材") == 0 and app.state.count("石材") == 0 and app.state.count("纤维") == 0, "construction consumes exact gathered materials")
	check(app.state.coins == 0 and app.state.income == 0, "automation creates no free money")
	app.state.minute = 1440 + 8*60
	app.state.ensure_daily()
	app.state.energy = 5
	app._start_task("wood")
	await frames(2)
	check(not app.auto_task.running and "精力" in app.auto_task.status, "low energy pauses with reason")
	app.state.energy = 100
	app.state.minute = 1440 + 19*60
	app._start_task("wood")
	await frames(2)
	check(not app.auto_task.running and "天黑" in app.auto_task.status, "sunset pauses new work")
	app.auto_task.resume_job(true)
	await frames(3)
	check(app.auto_task.running, "explicit night work allowed")
	app.joystick.direction = Vector2.RIGHT
	await frames(2)
	check(not app.auto_task.running and not app.world.player.working, "joystick takes over and cancels work")
	app.joystick.reset()
	app.state.minute = 1440 + 8*60
	app.state.inventory["木材"] = 80
	app._start_task("wood")
	await frames(3)
	check(not app.auto_task.running and "背包" in app.auto_task.status, "full bag pauses without losing resources")
	app.state.inventory["木材"] = 0
	app.state.energy = 100
	app.state.hunger = 100
	app.state.thirst = 100
	app.auto_task.start("wood")
	app.auto_task.graph_key = str(app.state.buildings)
	for x in range(-40,41):
		for z in range(-40,41): app.auto_task.grid.set_point_solid(Vector2i(x,z))
	await frames(3)
	check(not app.auto_task.running and app.state.count("木材") == 0 and "可达" in app.auto_task.status, "blocked route pauses without awarding resources")
	for id: String in ["fire","shelter"]:
		app._reset_game()
		app._close_drawers()
		await frames(3)
		app._start_task(id)
		await finish(3500)
		var expected: String = {"fire":"篝火","shelter":"庇护所","boat":"小船"}[id]
		check(app.state.buildings.has(expected), "complete automated goal " + expected)
		check(not app.world.player.boating, "construction never automatically sails")
	app._open_map()
	check(app.map_drawer.visible and not app.movement_enabled(), "expanded map pauses world")
	app._close_drawers()
	check(not app.map_drawer.visible and app.movement_enabled(), "close map restores controls")
	app.state.location = "town"
	check(not app.auto_task.start("wood"), "automation cannot labor in town")
	view.queue_free()
	await process_frame
	print("AUTO TASKS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
