extends SceneTree
var app: Node
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(message)
func frames(n: int) -> void:
	for i in range(n):app.inactive=false;await physics_frame
func steer(direction: Vector3) -> void:
	var right: Vector3=app.world.camera.global_basis.x
	var forward: Vector3=-app.world.camera.global_basis.z
	right.y=0;forward.y=0
	app.joystick.direction=Vector2(direction.dot(right.normalized()),-direction.dot(forward.normalized()))
func _initialize():call_deferred("run")
func run():
	Engine.time_scale=8;Engine.physics_ticks_per_second=120
	app=load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app);app.set_process(false)
	await frames(3)
	var world: Node3D=app.world
	var actor: CharacterBody3D=world.player
	var state: RefCounted=app.state
	check(world.seascape.find_children("DistantOcean*","MeshInstance3D",true,false).size()==4,"far sea ring covers horizon beyond near water")
	check(world.seascape.islands.size()==4,"four varied natural distant islands replace cone silhouettes")
	check(world.seascape.depth_texture!=null and world.camera.far>=2000,"shore depth texture and long horizon configured")
	var uniforms: Array=world.water_shader.shader.get_shader_uniform_list()
	check(uniforms.any(func(p):return p.name=="shore_depth"),"coastal shader parses depth-aware opacity")
	check(not world.seascape.far_material.shader.get_shader_uniform_list().is_empty(),"distant ocean shader compiles parameter layout")
	state.minute=12*60;world.sync(state)
	check(world.look_at_sun(state),"daytime sun view available")
	world.orbit._process(2);world.seascape._process(0)
	var sun_pos: Vector3=world.seascape.solar_disc.global_position
	check(world.seascape.solar_disc.visible and not world.camera.is_position_behind(sun_pos),"sun disc in front of sun-view camera")
	check(world.camera.get_viewport().get_visible_rect().has_point(world.camera.unproject_position(sun_pos)),"noon sun projects inside viewport")
	state.minute=0;world.sync(state)
	check(not world.seascape.solar_disc.visible and not world.look_at_sun(state),"night hides sun and does not invent daytime sun")
	state.minute=8*60;world.sync(state)
	for angle in range(0,360,30):
		for tilt in [-65,0,30,70]:
			world.orbit.target_yaw=deg_to_rad(angle);world.orbit.target_pitch=deg_to_rad(tilt)
			world.orbit._process(2)
			var pos: Vector3=world.camera.position
			var h: float=world.forest.height_at(pos.x,pos.z)
			check(pos.y>=.79 and (not is_finite(h) or pos.y>=h+.49),"camera remains above sea/terrain at %s %s"%[angle,tilt])
	world.orbit.reset_view();world.orbit._process(2)
	state.buildings["小船"]=true
	world.sync(state);actor.position=world.DOCK
	check(world.board_boat(state),"board for collision and return test")
	await frames(2)
	check(actor.hull_collider.disabled==false and actor.walking_shapes.all(func(c):return c.disabled),"boarding replaces walking footprint with full hull")
	var ambient: Array=world.forest.actors.filter(func(a):return a.get_meta("mode")=="boat")
	check(ambient.size()==2 and ambient.all(func(a):return a.collision_layer==4),"other boats have dedicated collision layer")
	var other: Node3D=ambient[0]
	actor.position=Vector3(other.position.x,.05,other.position.z-5)
	actor.boat_heading=0
	steer(Vector3(0,0,1))
	await frames(100)
	app.joystick.reset();await frames(2)
	var separation := absf(actor.position.z-other.position.z)
	check(separation>=3.14 and separation<3.19,"bow contact stops at actual combined hull lengths, without oversized box gap")
	check(world.boat_heading_is_clear(other.position+Vector3(1.3,.15,2.5),0),"diagonal empty water beside tapered bows remains passable")
	check(not world.boat_heading_is_clear(other.position+Vector3(0,.15,2.5),0),"actual overlapping hulls still block steering")
	world.orbit.target_pitch=deg_to_rad(-65)
	world.orbit._process(2)
	var screen_point: Vector2=world.camera.unproject_position(actor.position+Vector3.UP*.3)
	check(Rect2(Vector2.ZERO,world.camera.get_viewport().get_visible_rect().size).has_point(screen_point),"manual upward sailing view keeps boat in frame")
	world.orbit.reset_view();world.orbit._process(2)
	check(absf(actor.position.y-.05)<.001,"ship collision stays on water surface")
	var inventory: Dictionary=state.inventory.duplicate()
	actor.position=Vector3(20,.05,36)
	actor.velocity=Vector3.ZERO
	check(world.return_pilot.start(),"one tap plans safe return from open sea")
	for i in range(1800):
		await frames(1)
		if not world.return_pilot.active:break
	print("RETURN_RESULT ",world.return_pilot.status," at ",actor.position)
	check(not actor.boating and actor.position.distance_to(world.DOCK)<.3,"actual autopilot returns and disembarks at own dock")
	check(state.inventory==inventory,"automatic docking grants or spends no resources")
	actor.position=world.DOCK;world.board_boat(state);actor.position=Vector3(8,.05,30)
	check(world.return_pilot.start(),"can start another return")
	app.joystick.direction=Vector2.RIGHT
	await frames(2)
	check(not world.return_pilot.active and actor.boating,"joystick cancels autopilot while retaining manual sailing")
	app.joystick.reset()
	world._set_boating(false)
	var root_tree: Node3D
	for body: StaticBody3D in world.props.find_children("TreeObstacle","StaticBody3D",true,false):
		if body.get_parent().position.distance_to(Vector3(-5,.675,-2))<.2:root_tree=body.get_parent()
	check(root_tree!=null and root_tree.has_meta("root_radius"),"root-specific collision follows original tree geometry")
	if root_tree!=null:
		for i in range(8):
			var direction:=Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
			actor.position=root_tree.position+direction*1.6
			actor.position.y=world.terrain_height(actor.position.x,actor.position.z)+.03
			actor.velocity=Vector3.ZERO
			steer(-direction)
			await frames(35)
			app.joystick.reset()
			var offset: Vector3=actor.position-root_tree.position
			check(Vector2(offset.x,offset.z).length()>=float(root_tree.get_meta("root_radius"))+.37,"feet do not enter visible roots from direction %d"%i)
	if root_tree!=null:
		var root_position: Vector3=root_tree.position
		var root_radius: float=root_tree.get_meta("solid_radius")
		var saved_inventory: Dictionary=state.inventory.duplicate()
		state.player_position=[root_position.x,root_position.y,root_position.z]
		world.last_location=""
		world.sync(state)
		await frames(3)
		var offset: Vector3=actor.position-root_position
		var recovered_query := PhysicsShapeQueryParameters3D.new()
		var recovered_shape := CylinderShape3D.new();recovered_shape.radius=actor.TREE_RADIUS;recovered_shape.height=actor.TREE_HEIGHT
		recovered_query.shape=recovered_shape;recovered_query.collision_mask=8
		recovered_query.transform=Transform3D(Basis.IDENTITY,actor.position+Vector3.UP*(actor.TREE_HEIGHT*.5+.02))
		check(world.get_world_3d().direct_space_state.intersect_shape(recovered_query,1).is_empty() and offset.length()>.5,"old save relocates outside actual segmented tree geometry")
		check(state.inventory==saved_inventory and absf(actor.position.y-world.terrain_height(actor.position.x,actor.position.z))<.12,"recovery preserves inventory and does not leave character standing on invisible root proxy")
	app.queue_free();await process_frame
	print("MARINE WORLD: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
