extends SceneTree
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state = load("res://scripts/life/life_state.gd").new()
	var world = load("res://scripts/life/life_world.gd").new()
	root.add_child(world)
	world.sync(state)
	await physics_frame
	check(is_instance_valid(world.own_boat) and world.own_boat.visible, "ready boat visible from start")
	for z in range(5, 19):
		check(world.terrain_walkable(Vector3(3, 0.7, z)), "pier walkable at %d" % z)
	check(not world.board_boat(state), "boarding requires proximity")
	world.player.position = Vector3(3, 0.7, 5)
	var pier_right: Vector3 = world.camera.global_basis.x
	var pier_forward: Vector3 = -world.camera.global_basis.z
	pier_right.y = 0; pier_forward.y = 0
	world.player.move_input = Vector2(Vector3.FORWARD.dot(pier_right.normalized()), -Vector3.FORWARD.dot(pier_forward.normalized())) * -1
	world.player.manual_world_direction=Vector3.BACK
	for frame in range(300): await physics_frame
	world.player.manual_world_direction=Vector3.INF
	world.player.move_input = Vector2.ZERO
	check(world.player.position.z > 16 and world.player.position.y > 0.5, "real character walks entire pier without water fall or terrain blockage")
	world.player.position = world.DOCK
	check(world.nearby_action().kind == "boat" and world.nearby_action().title == "上船", "dock offers boarding")
	check(state.buildings.has("小船") and not state.buildings.has("木屋"), "boat available before house progression")
	check(state.count("木材")==0 and state.count("纤维")==0,"ready boat does not charge materials")
	world.sync(state)
	check(world.nearby_action().title == "上船", "ready boat offers boarding")
	state.hunger = 10
	check(not world.board_boat(state), "food safety gate")
	state.hunger = 90
	state.thirst = 90
	# Initial spring day is safe for departure; time after crafting is retained.
	check(world.board_boat(state), "board ready boat")
	for frame in range(120):await physics_frame
	check(world.player.boating and not world.own_boat.visible and world.player.boat_visual.visible, "boat follows embarked player, moored copy hidden")
	check(world.navigable_water(world.MOORING), "mooring is deep enough")
	var origin: Vector3 = world.player.position
	var direction := Vector3(0, 0, 1)
	var right: Vector3 = world.camera.global_basis.x
	var forward: Vector3 = -world.camera.global_basis.z
	right.y = 0; forward.y = 0
	world.player.move_input = Vector2(direction.dot(right.normalized()), -direction.dot(forward.normalized()))
	for i in range(90): await physics_frame
	check(world.player.position.z > origin.z + 3, "joystick drives actual boat into sea")
	check(absf(world.player.position.y - 0.05) < 0.01, "boat remains on water")
	check(world.can_labor("捕鱼") and not world.can_labor("伐木"), "sea allows fishing and blocks land gathering")
	check(not world.disembark_boat(), "cannot disembark into open sea")
	var saved: Vector3 = world.save_position()
	check(saved == world.DOCK, "sea save safely returns to berth")
	check(not world.navigable_water(Vector3(0, 0, 3)) and not world.navigable_water(Vector3(0, 0, 610)), "land and map boundary reject boat")
	world.player.move_input = Vector2.ZERO
	world.player.position = Vector3(5, 0.05, 34)
	check(world.nearby_action().kind == "town_route", "offshore buoy opens town route")
	world.player.position = world.MOORING
	world.player.velocity=Vector3.ZERO
	check(world.nearby_action().kind == "disembark" and world.disembark_boat(), "return and disembark at own dock")
	check(not world.player.boating and world.own_boat.visible and not world.player.boat_visual.visible, "walking restored and boat moored")
	check(world.player.position == world.DOCK and world.player.collision_mask == 1, "safe disembark with land collision restored")
	check(world.board_boat(state), "can reboard")
	check(state.travel("town"), "existing trade route remains usable")
	world.sync(state)
	check(not world.player.boating and world.player.collision_mask == 1, "town arrival exits sailing mode")
	world.queue_free()
	await process_frame
	print("BOATING: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
