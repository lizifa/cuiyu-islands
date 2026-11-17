extends SceneTree
var passed := 0
var failed := 0
const State = preload("res://scripts/life/life_state.gd")
const World = preload("res://scripts/life/life_world.gd")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	root.add_child(view)
	var app = load("res://scenes/life_main.tscn").instantiate()
	view.add_child(app)
	app.set_process(false)
	app.inactive = false
	await process_frame
	await process_frame
	check(ResourceLoader.exists("res://assets/branding/qinggeng-yuhang-icon-v1.png"), "brand icon imported")
	var snapshot: Dictionary = app.state.snapshot()
	snapshot.erase("profile")
	var restored := State.new()
	check(restored.restore(snapshot) and not restored.profile.confirmed and restored.inventory == app.state.inventory, "legacy save migrates profile without changing progress")
	app._open_arrival()
	check(app.arrival.visible and not app.movement_enabled() and not app.joystick.visible, "arrival picker freezes gameplay")
	app.arrival.character_id = "skater_heart"
	app.arrival.pet = "cat"
	app.arrival.name_input.text = "海风"
	app.arrival.pet_name_input.text = "团子"
	app.arrival.refresh_preview()
	var preview_center: Vector2 = app.arrival.display.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.position = preview_center; touch.index = 0; touch.pressed = true
	view.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.position = preview_center + Vector2(50, 0); drag.index = 0
	view.push_input(drag, true)
	check(app.arrival.showcase_yaw > 0 and is_zero_approx(app.joystick.direction.length()), "native preview rotation does not move avatar")
	touch.pressed = false
	view.push_input(touch, true)
	var preview_yaw: float = app.arrival.showcase_yaw
	var mouse := InputEventMouseMotion.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = preview_center; mouse.relative = Vector2(50, 0); mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	view.push_input(mouse, true)
	check(app.arrival.showcase_yaw == preview_yaw, "emulated mouse does not duplicate native preview rotation")
	check(app.arrival.preview.get_child_count() == 2, "large real 3D character and pet preview")
	var coins: int = app.state.coins
	check(app.arrival.confirm(), "character creation commits")
	check(app.state.profile.character_id == "skater_heart" and app.state.profile.pet == "cat" and app.state.profile.name == "海风" and app.state.profile.pet_name == "团子", "character and named pet selected")
	check(not app.arrival.visible and app.movement_enabled() and app.state.coins == coins, "creation resumes without altering economy")
	check(app.world.player.visual != null and not app.world.player.walk_clip.is_empty(), "selected appearance retains skeletal movement")
	check(app.arrival.character_wheel.values.size() == preload("res://scripts/life/character_catalog.gd").CHARACTERS.size() and app.world.player.visual.find_children("*", "Skeleton3D", true, false).size() == 1, "all catalog appearances available with a rigged character")
	check(app.world.companion != null and app.world.companion.visual != null, "chosen pet spawned")
	var world: Node3D = app.world
	for i in range(80): world._process(0.05); world.orbit._process(0.05)
	var head: Vector2 = world.camera.unproject_position(world.player.position + Vector3(0, 2.2, 0))
	var feet: Vector2 = world.camera.unproject_position(world.player.position)
	print("Character projected height at 720p: ", head.distance_to(feet))
	check(head.distance_to(feet) > 75, "character has readable screen occupancy at default camera")
	check(world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "perspective camera allows horizon sky")
	world.orbit.target_pitch = deg_to_rad(-50)
	world.orbit._process(1)
	check(world.camera.position.y > world.player.position.y and (-world.camera.global_basis.z).y > 0.6, "upward look shows sky while camera remains above ground")
	world.orbit.reset_view()
	world.orbit._process(1)
	var tree_pos: Vector3 = world.forest.tree_positions[0]
	world.forest.reveal_player(tree_pos + Vector3(0, 3, 6), tree_pos + Vector3(0, 3, -6))
	check(world.forest.faded.values().has(true), "obstructing trees fade for player readability")
	world.forest.reveal_player(Vector3(1000, 1000, 1000), Vector3(1000, 1001, 1000))
	check(not world.forest.faded.values().has(true), "trees restore opacity when no longer obstructing")
	check(world.environment.environment.background_mode == Environment.BG_SKY and world.environment.environment.sky != null, "visible procedural sky includes solar disc")
	for season_index in range(4):
		var rise: float = [6.0, 5.0, 6.0, 7.0][season_index]
		var setting: float = [18.0, 20.0, 18.0, 17.0][season_index]
		check(World.solar_direction(rise, season_index).x > 0.99, "sun rises in world east")
		check(World.solar_direction(setting, season_index).x < -0.99, "sun sets in world west")
		check(World.solar_direction((rise + setting) / 2, season_index).y > 0.8, "sun climbs above horizon")
		check(World.solar_direction(0, season_index).y < 0, "sun below horizon at night")
	var profile: Dictionary = app.state.profile.duplicate(true)
	var restored2 := State.new()
	check(restored2.restore(app.state.snapshot()) and restored2.profile == profile, "profile and pet survive save restore")
	var profile_path := "user://test_arrival_profile.json"
	check(app.state.save_game(profile_path) == OK, "write named character and pet to disk")
	var from_disk := State.new()
	check(from_disk.load_game(profile_path) and from_disk.profile == profile, "named character and pet load from disk")
	DirAccess.remove_absolute(profile_path)
	DirAccess.remove_absolute(profile_path + ".bak")
	var invalid: Dictionary = app.state.snapshot()
	invalid.profile.pet = "dragon"
	check(not restored2.restore(invalid) and restored2.profile == profile, "invalid profile rejected atomically")
	app._open_arrival()
	app.arrival.character_id = "skater_coral"
	app._close_drawers()
	check(app.state.profile == profile, "cancelling preserves selected character")
	world.player.position = Vector3(0, 0.7, 3.2)
	world.companion.recover()
	world.player.allowed = true
	for step in range(20):
		world.player.position.x += 0.2
		world.companion._physics_process(0.1)
	check(world.companion.position.x > 0.2 and world.terrain_walkable(world.companion.position), "pet follows player path on dry ground")
	var pet_position: Vector3 = world.companion.position
	world.player.allowed = false
	world.companion._physics_process(1)
	check(world.companion.position == pet_position, "pet freezes during settings/pause")
	world.player.allowed = true
	world.player.boating = true
	world.player.position = World.MOORING
	world.companion._physics_process(0.1)
	check(world.companion.position.distance_to(world.player.position) < 1, "pet rides boat rather than walking through water")
	world.player.boating = false
	world.player.position = World.DOCK
	world.companion._physics_process(0.1)
	check(world.terrain_walkable(world.companion.position), "pet disembarks onto safe dock automatically")
	check(world.pet_companion(app.state), "petting interaction works")
	world.player.position = Vector3(0, 0.7, 3.2)
	app.state.profile.pet = "none"
	world.sync(app.state)
	check(world.companion == null, "optional no-pet selection removes companion")
	view.queue_free()
	await process_frame
	print("ARRIVAL AND SKY: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
