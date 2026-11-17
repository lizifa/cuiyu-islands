extends SceneTree
var app: Node
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func frames(n: int) -> void:
	for i in range(n): app.inactive = false; await physics_frame
func steer(direction: Vector3) -> void:
	var right: Vector3 = app.world.camera.global_basis.x
	var forward: Vector3 = -app.world.camera.global_basis.z
	right.y = 0; forward.y = 0
	app.joystick.direction = Vector2(direction.dot(right.normalized()), -direction.dot(forward.normalized()))
func _initialize(): call_deferred("run")
func run():
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 120
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	root.add_child(view)
	app = load("res://scenes/life_main.tscn").instantiate()
	view.add_child(app)
	app.set_process(false)
	await frames(3)
	app.performance_settings.mobile = true
	app.performance_settings.set_saver(true)
	var player: CharacterBody3D = app.world.player
	check(player.BODY_RADIUS >= 0.4, "torso clearance is represented by player capsule")
	check(app.world.forest.trees.all(func(tree): return tree.has_meta("solid_radius") and tree.find_child("TreeObstacle",true,false) != null), "all landscape trees have scaled solid geometry")
	check(app.world.forest.find_children("PropObstacle","StaticBody3D",true,false).size() > 0, "scattered rocks are solid")
	for center: Vector3 in [Vector3(-5,0,-2), Vector3(3,0,-4), Vector3(-5,0,4.8),Vector3(.5,0,-4.5),Vector3(-4.8,0,2.8)]:
		player.position = center + Vector3(0,0,2)
		player.position.y = app.world.terrain_height(player.position.x,player.position.z) + .03
		player.velocity = Vector3.ZERO
		steer(Vector3(0,0,-1))
		await frames(100)
		app.joystick.reset()
		var distance := Vector2(player.position.x-center.x,player.position.z-center.z).length()
		check(distance > .55, "manual movement cannot enter resource center: %s, distance %.2f" % [center,distance])
	player.position = Vector3(0,.7,3.2)
	player.velocity = Vector3.ZERO
	for id: String in ["wood","stone","fiber"]:
		app.state.energy = 100; app.state.hunger = 100; app.state.thirst = 100; app.state.minute = 8*60
		app._start_task(id)
		var work_samples := 0
		var min_clearance := INF
		for i in range(4000):
			await frames(1)
			if player.working:
				work_samples += 1
				var target: Dictionary = app.auto_task.point
				var offset: Vector3 = player.position - target.pos
				min_clearance = minf(min_clearance, Vector2(offset.x,offset.z).length()-float(target.get("min_range",0)))
			if not app.auto_task.running: break
		check(app.state.daily_done(id) and work_samples > 0, "actual task still completes: " + id)
		check(min_clearance >= -.03, "all animation frames keep safe target clearance: " + id)
	app.world.player.position = preload("res://scripts/life/villa_scene.gd").ENTRY
	check(app.world.enter_villa(app.state), "enter home after outdoor tasks")
	await frames(3)
	check(app.world.props.find_children("PropObstacle","StaticBody3D",true,false).size() > 10, "furniture and dining chairs have geometry collisions")
	app.queue_free()
	await process_frame
	print("PROP COLLISION: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
