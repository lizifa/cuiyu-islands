extends SceneTree
const Platform = preload("res://scripts/life/fishing_platform.gd")
var app: Node
var passed := 0
var failed := 0
var observed_curve := 0.0
var observed_crank := 0.0
var left_hand_error := 0.0
func check(value: bool, message: String) -> void:
	if value: passed+=1
	else: failed+=1; push_error(message)
func frames(n: int) -> void:
	for i in range(n): app.inactive=false; await physics_frame
func walk_to(target: Vector3) -> void:
	for i in range(650):
		var offset: Vector3=target-app.world.player.position
		offset.y=0
		if offset.length()<.2: app.joystick.reset();return
		var right: Vector3=app.world.walk_camera.input_right if app.world.walk_camera.input_active else app.world.camera.global_basis.x
		var forward: Vector3=app.world.walk_camera.input_forward if app.world.walk_camera.input_active else -app.world.camera.global_basis.z
		right.y=0; forward.y=0
		app.joystick.direction=Vector2(offset.normalized().dot(right.normalized()),-offset.normalized().dot(forward.normalized()))
		await frames(1)
	app.joystick.reset()
	check(false,"platform route blocked at %s toward %s"%[app.world.player.position,target])
func until(stage: String, limit: int=400) -> void:
	for i in range(limit):
		if app.fishing_session.stage==stage:return
		await frames(1)
	check(false,"fishing did not reach "+stage+"; current "+app.fishing_session.stage)
func begin() -> void:
	app.state.energy=100
	app.state.minute=8*60
	await interact_ready()
func reel_success() -> void:
	app.fishing_session.fish_roll=.99
	await until("bite")
	await interact_ready()
	await until("reeling")
	for i in range(600):
		if app.fishing_session.stage!="reeling":break
		app.fishing_session.held=app.fishing_session.tension<.65
		await frames(1)
		if app.fishing_session.stage=="reeling":
			observed_curve=maxf(observed_curve,app.fishing_session.rod_segments[7].position.z)
			observed_crank=maxf(observed_crank,app.fishing_session.reel_angle)
			var actor: Node=app.world.player
			var left: Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("LeftHand")).origin
			var crank: Vector3=app.fishing_session.reel_handle.to_global(Vector3(0,.07,0))
			left_hand_error=maxf(left_hand_error,left.distance_to(crank))
	await until("result")
func interact_ready() -> void:
	app._nearby_interact()
	for frame in range(500):
		if not app.interaction_director.active:
			if app.fishing_session.active and app.fishing_session.stage=="ready":
				for i in range(600):
					if app.world.orbit.activity_view_ready("fishing"):break
					await frames(1)
				app.fishing_session.interact();await frames(3)
			return
		app.inactive=false
		await physics_frame
	check(false,"interaction approach did not finish")
func _initialize():call_deferred("run")
func run():
	Engine.time_scale=8
	Engine.physics_ticks_per_second=120
	app=load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	await frames(3)
	var session: Node=app.fishing_session
	var player: Node=app.world.player
	check(app.world.props.find_child("ShoreFishingPlatform",true,false)!=null,"fishing platform exists beside pier")
	check(not session.begin() and not session.active,"cannot fish remotely from home clearing")
	player.position=Vector3(1.7,.68,7) # Start on the paved route; a straight line from spawn intersects a solid tree.
	await frames(3)
	await walk_to(Vector3(3,.7,15.3))
	await walk_to(Vector3(-1,.68,15.7))
	check(app.world.nearby_action().kind=="shore_fish","walking from island reaches fishing entrance instead of boat action")
	check(absf(player.position.y-.65)<.1,"platform has solid floor at pier height")
	var before_time: float=app.state.minute
	var before_energy: float=app.state.energy
	await interact_ready()
	check(session.active and session.stage=="casting" and player.fishing_stage=="casting","interact starts actual casting pose")
	if not session.active:
		app.queue_free(); await process_frame; quit(1); return
	check(app.state.minute>=before_time+20 and is_equal_approx(app.state.energy,before_energy),"cast advances time without consuming energy")
	check(app.state.count("鲜鱼")==0,"casting alone awards no fish")
	await frames(5)
	check(Vector2(Platform.FLOAT.x-Platform.POINT.x,Platform.FLOAT.z-Platform.POINT.z).length()>=19.9,"sea rod casts twenty metres from station")
	var tip: Vector3=session.rod_segments[7].to_global(Vector3(0,.225,0))
	check(tip.distance_to(session.rod.position)>3.5,"visible sea rod extends over three and a half metres")
	check(session.line.get_surface_count()==1 and is_instance_valid(session.rod),"rod and actual fishing line render during cast")
	var hand: int=player._bone("RightHand")
	var wrist: Vector3=player.pose_skeleton.global_transform*player.pose_skeleton.get_bone_global_pose(hand).origin
	check(wrist.distance_to(session.rod.position)<.12,"rod follows actual wrist during cast")
	await until("waiting")
	check(not app.world.camera.is_position_behind(Platform.FLOAT) and app.world.camera.get_viewport().get_visible_rect().has_point(app.world.camera.unproject_position(Platform.FLOAT)),"casting camera frames the distant float")
	var clock: float=session.elapsed
	app.context_action.held=true
	app.paused=true
	await frames(10)
	check(session.elapsed==clock and not app.context_action.held,"pause freezes bite timer and releases held reel input")
	app.paused=false
	await reel_success()
	check(observed_curve>.2,"loaded rod visibly bends during reeling")
	check(observed_crank>1,"crank rotates while lowering rod to wind line")
	check(left_hand_error<.25,"reeling hand follows actual crank")
	check(session.landed and app.state.count("鲜鱼")==0 and app.state.kept_portions()==1,"timed hook and balanced reel lands exactly one fish")
	check(not session.fish.visible and app.state.kept_portions()==1 and session.progress_bar.value==100,"landed fish and completed progress are visible")
	await frames(20)
	check(app.state.count("鲜鱼")==0 and app.state.kept_portions()==1,"result frames cannot duplicate fish")
	var saved_distance: float=session.camera_state.distance
	session.cancel()
	check(app.world.orbit.activity_key=="" if app.world.orbit.stable_third_person else is_equal_approx(app.world.orbit.target_distance,28.0 if app.world.orbit.comfort_mode else saved_distance),"ending fishing releases its dedicated view or restores the legacy view")
	check(player.fishing_stage.is_empty() and player.pose_skeleton==null and player.collision_mask==1,"cancel restores idle bones and collision")
	await frames(2)
	check(app.world.find_child("ActiveFishingTackle",true,false)==null,"tackle is cleaned after ending session")
	await begin()
	await until("waiting")
	session.interact()
	check(session.stage=="result" and not session.landed and app.state.count("鲜鱼")==1,"early strike fails without fish reward")
	session.cancel();await begin()
	await until("bite")
	await until("result")
	check(not session.landed and "晚" in session.hint.text,"missed bite expires normally")
	session.cancel();await begin()
	await until("bite");session.interact();await until("reeling")
	session.held=true
	await until("result")
	check(not session.landed and "绷断" in session.hint.text,"holding continuously snaps line")
	session.cancel();await begin()
	await until("bite");session.interact();await until("reeling")
	session.held=false
	await until("result")
	check(not session.landed and "太松" in session.hint.text,"slack line lets fish escape")
	session.cancel();await begin()
	app.state.inventory["木材"]=app.state.capacity()
	await reel_success()
	check(not session.landed and app.state.count("鲜鱼")==1,"bag filling mid-cast releases fish without extra reward")
	check(not session.fish.visible,"released fish is not shown as landed")
	app.state.inventory["木材"]=0
	session.cancel();await begin()
	await frames(3)
	app.joystick.direction=Vector2.RIGHT
	await frames(3)
	app.joystick.reset()
	check(session.active and not player.fishing_stage.is_empty(),"joystick cannot accidentally cancel an explicit fishing activity")
	session.cancel()
	player.position=Vector3(-1,.68,15.7)
	app.state.inventory["木材"]=app.state.capacity()
	var minute: float=app.state.minute
	check(not session.begin() and app.state.minute==minute,"full bag blocks cast before charging time")
	app.state.inventory["木材"]=0
	app.state.energy=5
	check(session.begin() and app.state.energy==5,"low energy does not require resting before fishing")
	session.cancel()
	app.state.energy=100
	app.paused=true
	var paused_minute: float=app.state.minute
	check(not session.begin() and app.state.minute==paused_minute,"paused game cannot charge a new cast")
	app.paused=false
	await begin()
	app.state.profile.gender="female"
	app.world.sync(app.state)
	await frames(3)
	check(not session.active and player.fishing_stage.is_empty(),"changing character clears rod and old skeleton safely")
	player.position=Vector3(-1,.68,15.7)
	await begin()
	app.state.location="town"
	app.world.sync(app.state)
	await frames(3)
	check(not session.active,"location change cancels fishing without stale meshes")
	app.queue_free()
	await process_frame
	print("SHORE FISHING: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
