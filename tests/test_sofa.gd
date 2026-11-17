extends SceneTree
var app: Node
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func frames(n: int) -> void:
	for i in range(n): app.inactive = false; await physics_frame
func interact_ready() -> void:
	app._nearby_interact()
	for frame in range(500):
		if not app.interaction_director.active:return
		app.inactive=false
		await physics_frame
	check(false,"interaction approach did not finish")
func _initialize(): call_deferred("run")
func run():
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 120
	app = load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	await frames(3)
	app.world.player.position = preload("res://scripts/life/villa_scene.gd").ENTRY
	app.world.enter_villa(app.state)
	app.world.player.position = preload("res://scripts/life/villa_scene.gd").SOFA_STAND
	app.state.energy = 10
	app.state.health = 50
	var start_time: float = app.state.minute
	await interact_ready()
	check(app.sofa_session.active and app.world.player.sofa_seated,"sit instead of instant rest reward")
	check(app.state.energy >= 10 and app.state.energy < 10.1 and app.state.minute == start_time,"sitting down creates no instant reward or time jump")
	var standing: Vector3 = app.world.player.sofa_return
	await frames(15)
	var actor: Node = app.world.player
	check(actor.position.distance_to(app.world.Villa.SOFA_SEAT) < .02,"body reaches actual cushion position")
	var hip: int = actor._bone("Hips")
	var thigh: int = actor._bone("RightUpLeg")
	check(hip >= 0 and thigh >= 0,"seat pose resolves real character bones")
	var hip_world: Vector3 = actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(hip).origin
	var foot_world: Vector3 = actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("RightFoot")).origin
	check(hip_world.y > app.world.villa_room.sofa_surface()+.15 and hip_world.y < app.world.villa_room.sofa_surface()+.4,"pelvis meets cushion without floating above seat")
	check(foot_world.y >= .69,"seated foot stays above floor")
	check(actor.pose_skeleton.get_bone_pose_position(hip).y < actor.pose_positions[hip].y-.4,"hips descend onto sofa")
	check(actor.pose_skeleton.get_bone_pose_rotation(thigh).angle_to(actor.pose_rotations[thigh]) > 1.4,"thighs bend into seated pose")
	var energy: float = app.state.energy
	app.paused = true
	await frames(15)
	check(app.state.energy == energy,"pause freezes rest recovery and animation")
	app.paused = false
	app.sofa_session.toggle_tv()
	check(app.world.home_tv_on and app.world.villa_room.get_node("HomeTelevision").enabled,"seated user can turn on animated TV")
	app.sofa_session.toggle_tv()
	check(not app.world.home_tv_on and not app.world.villa_room.get_node("HomeTelevision").enabled,"TV can be turned off")
	app.sofa_session._physics_process(60)
	check(is_equal_approx(app.state.energy-energy,10),"one active minute earns exactly ten energy")
	check(app.world.save_position().distance_to(standing) < .01,"save records safe standing position outside sofa")
	app.sofa_session.finish()
	check(not actor.sofa_seated and actor.collision_mask == 1 and actor.position.distance_to(standing)<.01,"standing restores physics and clear position")
	check(actor.pose_skeleton == null and actor.pose_positions.is_empty(),"standing clears all pose overrides")
	check(not app.sofa_session.panel.visible,"stand dismisses rest controls")
	check(app.sofa_session.begin(),"can sit again")
	app.joystick.direction = Vector2.RIGHT
	await frames(3)
	check(not app.sofa_session.active and not actor.sofa_seated,"manual movement stands up and takes control")
	app.joystick.reset()
	actor.position = preload("res://scripts/life/villa_scene.gd").SOFA_STAND
	app.sofa_session.begin()
	app.state.profile.gender = "female"
	app.world.sync(app.state)
	await frames(3)
	check(not app.sofa_session.active and not actor.sofa_seated,"changing character safely clears old seated skeleton")
	actor.position = preload("res://scripts/life/villa_scene.gd").SOFA_STAND
	app.sofa_session.begin()
	await frames(15)
	var female_foot: Vector3 = actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("RightFoot")).origin
	check(female_foot.y >= .69,"female seated foot also stays above floor")
	app.world.leave_villa(app.state)
	await frames(3)
	check(not app.sofa_session.active and actor.collision_mask == 1,"leaving home cancels pose without disabling collision outside")
	app.queue_free()
	await process_frame
	print("SOFA: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
