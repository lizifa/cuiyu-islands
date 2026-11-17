extends SceneTree
const State = preload("res://scripts/life/life_state.gd")
var app: Node
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func frames(n: int) -> void:
	for i in range(n): app.inactive = false; await physics_frame
func walk_to(target: Vector3, max_frames: int = 3000) -> void:
	for i in range(max_frames):
		app.inactive = false
		var offset: Vector3 = target - app.world.player.position
		offset.y = 0
		if offset.length() < 0.25: app.joystick.reset(); return
		var right: Vector3 = app.world.camera.global_basis.x
		var forward: Vector3 = -app.world.camera.global_basis.z
		right.y = 0; forward.y = 0
		app.joystick.direction = Vector2(offset.normalized().dot(right.normalized()), -offset.normalized().dot(forward.normalized()))
		await physics_frame
	app.joystick.reset()
	check(false,"interior route blocked: %s at %s" % [target,app.world.player.position])
func interact_ready() -> void:
	app._nearby_interact()
	for frame in range(7200):
		if not app.interaction_director.active and not app.world.player.stair_active and not app.world.player.home_busy:return
		app.inactive=false
		await physics_frame
	check(false,"interaction approach did not finish")
func await_bed(target: String) -> void:
	for i in range(3200):
		if app.world.player.bed_stage==target:return
		await frames(1)
	check(false,"bed sequence did not reach "+target)
func _initialize(): call_deferred("run")
func run():
	Engine.time_scale = 1 # Camera pacing must use real gameplay time.
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
	check(app.world.props.find_child("SeaviewVillaExterior",true,false) != null, "large villa exterior exists on island")
	check(not app.world.enter_villa(app.state), "enter requires reaching real front porch")
	var original_inventory: Dictionary = app.state.inventory.duplicate()
	app.state.energy = 0
	app.state.minute = 20*60
	app._start_task("villa")
	for frame in range(4000):
		app.inactive = false
		await physics_frame
		if not app.auto_task.running: break
	print("Return home: ", app.auto_task.status, " at ", app.world.player.position)
	check(app.state.location == "villa", "nighttime exhausted player can auto walk home and enter")
	check(app.state.inventory == original_inventory and app.state.buildings.is_empty(), "villa access preserves original materials and wooden-house progress")
	check(not app.world.forest.visible and not app.world.town_ground.visible, "outdoor geometry hidden indoors")
	check(app.world.outside_surfaces.all(func(node): return not node.visible), "ocean hidden inside home")
	check(app.world.forest.find_children("*","StaticBody3D",true,false).all(func(body): return body.collision_layer == 0), "forest collision disabled indoors")
	check(app.world.interaction_points.any(func(point): return point.kind == "villa_water") and app.world.interaction_points.any(func(point): return point.kind == "villa_cook"), "working kitchen and drinking-water interactions")
	check(not app.world.rain.emitting, "rain does not fall through living room")
	check(app.world.camera.fov == app.world.indoor_camera.COMFORT_FOV and app.world.orbit.distance <= 9.0, "indoor camera keeps character visible")
	await walk_to(Vector3(-2,.7,16.5))
	await walk_to(Vector3(-2,.7,7.5))
	await walk_to(Vector3(-4.2,.7,7.5))
	await walk_to(app.world.Villa.SOFA_STAND)
	check(app.world.nearby_action().kind == "villa_rest", "living-room sofa accessible")
	await interact_ready()
	check(app.sofa_session.active and app.world.player.sofa_seated, "sofa interaction starts visible seated rest")
	app.sofa_session.finish()
	app.state.energy = 30
	await walk_to(Vector3(-4.2,.7,7.5))
	await walk_to(Vector3(0,.7,7.5))
	await walk_to(Vector3(0,0.7,4.3))
	await walk_to(Vector3(0,0.7,3))
	await walk_to(Vector3(0,0.7,-2.2))
	await walk_to(Vector3(-6,0.7,-2.2))
	await walk_to(Vector3(-6,0.7,-3))
	check(app.world.nearby_action().kind == "villa_water", "character physically reaches kitchen sink")
	app.state.thirst = 20
	await interact_ready()
	check(app.state.thirst > 60, "sink refills water by normal rules")
	await walk_to(Vector3(-3.4,0.7,-3.2))
	app.state.inventory["鲜鱼"] = 2
	await interact_ready()
	check(app.state.count("鱼干") == 1 and app.state.count("鲜鱼") == 0, "villa stove cooks without an outdoor campfire")
	await walk_to(Vector3(0,0.7,-2.2))
	await walk_to(Vector3(6,0.7,-2.2))
	await walk_to(Vector3(6,0.7,2))
	check(app.world.nearby_action().kind == "villa_stairs", "stairs reachable from living room")
	await interact_ready()
	check(app.state.home_floor == 1 and app.world.last_home_floor == 1, "stair interaction switches to furnished upper floor")
	check(app.world.interaction_points.any(func(point): return point.kind == "villa_sleep") and app.world.interaction_points.any(func(point): return point.kind == "villa_bath"), "bedroom and bathroom usable upstairs")
	await walk_to(Vector3(5,0.7,-2.5))
	check(app.world.nearby_action().kind == "villa_bath", "bathroom is physically reachable")
	app.state.energy = 40
	await interact_ready()
	check(app.state.flags.get("villa_bath",false) and app.state.energy > 40, "bath interaction has household effect")
	check(not app.state.bathe_at_home(), "bath benefit cannot be repeatedly farmed")
	await walk_to(Vector3(5,0.7,1))
	await walk_to(Vector3(-3,0.7,1))
	await walk_to(Vector3(-3,0.7,-1.45))
	check(app.world.nearby_action().kind == "villa_sleep", "master bed can be reached around walls")
	app.state.minute = 22*60
	app.state.energy = 10
	await interact_ready()
	check(app.bed_session.active,"bed interaction starts visible rest")
	await await_bed("resting")
	app.bed_session.sleep_to_morning()
	for i in range(2400):
		await frames(1)
		if app.state.hour()==6:break
	check(app.state.hour() == 6 and app.state.energy > 90, "own bedroom sleeps visibly to morning without temporary shelter")
	app.bed_session.finish();await await_bed("")
	var saved: Dictionary = app.state.snapshot()
	var restored := State.new()
	check(restored.restore(saved) and restored.location == "villa" and restored.home_floor == 1, "indoor floor persists in save")
	var disk_path := "user://test_villa_room.json"
	check(app.state.save_game(disk_path) == OK and restored.load_game(disk_path) and restored.home_floor == 1 and restored.location == "villa", "upstairs location survives actual JSON disk load")
	DirAccess.remove_absolute(disk_path)
	DirAccess.remove_absolute(disk_path + ".bak")
	saved.erase("home_floor")
	check(restored.restore(saved) and restored.home_floor == 0, "legacy saves default safely to first floor")
	check(not app.state.travel("town"), "cannot silently sail straight from bedroom")
	app.state.minute = app.state.day() * 1440 + 10*60
	check(not app.state.market_open() and not app.state.sell("鱼干") and not app.state.accept_order(), "home is not a remote market or order station")
	app._open_boat_status()
	check(app.state.location == "island" and app.world.forest.visible, "exit shortcut returns to island front porch")
	check(app.world.player.position.distance_to(app.world.Villa.OUTSIDE_SPAWN) < 0.4, "outside return position is safe")
	app.world.player.position = app.world.Villa.ENTRY + Vector3(0,0,0.5)
	check(app.world.enter_villa(app.state), "can re-enter normally through door")
	app.world.player.position = Vector3(0,0.7,17.1)
	check(app.world.nearby_action().kind == "villa_exit", "front foyer provides physical exit")
	await interact_ready()
	check(app.state.location == "island", "front door exit works")
	view.queue_free()
	await process_frame
	print("VILLA: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
