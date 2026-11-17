extends SceneTree
var failures := 0
var passed := 0
func check(condition: bool, message: String) -> void:
	if condition: passed += 1
	else: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state = load("res://scripts/life/life_state.gd").new()
	var world = load("res://scripts/life/life_world.gd").new()
	root.add_child(world)
	world.sync(state)
	await physics_frame
	var forest: Node3D = world.forest
	print("Forest trees: ", forest.tree_positions.size(), "; actors: ", forest.actors.size())
	check(forest.tree_positions.size() == 37, "spaced forest and three garden trees are populated")
	check(forest.actors.size() == 43, "eight woodland animals, twenty-eight fish, two sharks, three birds and two boats")
	check(is_equal_approx(forest.height_at(0, 3.2), 0.675), "legacy spawn remains on graded homestead")
	check(forest.walkable(Vector3(10, 0, 0)), "larger island has traversable forest")
	check(not forest.walkable(Vector3(0, 0, 35)), "open sea is not walkable")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 10, 3.2), Vector3(0, -10, 3.2), 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y - forest.height_at(0, 3.2)) < 0.03, "physics collision matches graded terrain")
	for actor: Node3D in forest.actors:
		var center: Vector3 = actor.get_meta("center")
		var radius: Vector2 = actor.get_meta("radius")
		var mode: String = actor.get_meta("mode")
		var route_safe := true
		for step in range(64):
			var angle := TAU * step / 64
			var pos := center + Vector3(cos(angle) * radius.x, 0, sin(angle) * radius.y)
			if mode == "land" and not forest.walkable(pos): route_safe = false
			if mode in ["sea", "boat"] and forest.height_at(pos.x, pos.z) >= center.y - 0.4: route_safe = false
		check(route_safe, "animal/boat route stays in its habitat: %s %s" % [mode, center])
	forest.active = false
	var clock: float = forest.elapsed
	forest._process(1)
	check(forest.elapsed == clock, "pause freezes ambient motion")
	forest.active = true
	forest._process(1)
	check(forest.elapsed > clock, "ambient motion resumes")
	var identity: int = forest.get_instance_id()
	state.buildings["篝火"] = true
	world.sync(state)
	check(world.forest.get_instance_id() == identity and forest.actors.size() == 43, "construction preserves forest without duplication")
	state.location = "town"
	world.sync(state)
	check(not forest.visible and world.town_ground.visible, "town uses separate town ground")
	check(not forest.find_children("*", "StaticBody3D", true, false).any(func(body): return body.collision_layer != 0), "island collision disabled during town visit")
	state.location = "island"
	state.player_position = [0.0, -10.0, 35.0]
	world.sync(state)
	check(world.player.position.distance_to(Vector3(0, 0.705, 3.2)) < 0.1, "invalid ocean spawn recovers without resetting progress")
	var before: Vector3 = world.player.position
	world.player.allowed = true
	world.player.move_input = Vector2.RIGHT
	for frame in range(90): await physics_frame
	check(world.player.position.distance_to(before) > 1 and forest.walkable(world.player.position), "real player walks grounded on terrain")
	state.player_position = [10.0, forest.height_at(10, 0) + 0.03, 0.0]
	var restored = load("res://scripts/life/life_state.gd").new()
	check(restored.restore(state.snapshot()), "forest position survives save roundtrip")
	world.queue_free()
	await process_frame
	print("FOREST TESTS: %d passed, %d failed" % [passed, failures])
	quit(1 if failures else 0)
