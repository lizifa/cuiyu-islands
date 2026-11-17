extends Node3D
## A compact diorama rebuilt from authoritative state, never from UI animation.
var balcony_view_active:=false
var seascape: Node3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var camp_light: OmniLight3D
var grass: StandardMaterial3D
var sea: StandardMaterial3D
var water_shader: ShaderMaterial
var outside_surfaces: Array[Node3D] = []
var props: Node3D
var rain: GPUParticles3D
const Villa = preload("res://scripts/life/villa_scene.gd")
const PLAYABLE_CHARACTER_SCALE:=2.0/3.0
var last_home_floor := -1
var home_tv_on := false
var camera_clearance := 1.0
var camera_clear_hold := 0.0
var camera_last_focus := Vector3.INF
var walk_camera=preload("res://scripts/life/walk_camera.gd").new()
var shore_lights:Node3D
var fish_keeper:Node3D
var home_camera=preload("res://scripts/life/home_camera.gd").new()
var indoor_camera = preload("res://scripts/life/interior_camera.gd").new()
var villa_rooms: Array[Node3D] = []
var stair_origin := Vector3.ZERO
var stair_target_floor := -1
var villa_room: Node3D
var last_location := ""
var last_buildings := ""
var last_lighting_key := ""
var current_season := -1
var camera: Camera3D
var orbit: Node
var focus_ring: MeshInstance3D
var player: CharacterBody3D
const BOARD_RADIUS := 3.0
const FishingPlatform = preload("res://scripts/life/fishing_platform.gd")
const DOCK := Vector3(3, 0.7, 17)
const MOORING := Vector3(5, 0.05, 18)
var fishing_sign: Label3D
var boat_status_label: Label3D
var return_pilot = preload("res://scripts/life/boat_return.gd").new()
var exploration:RefCounted
var boat_wake:Node3D
var sea_giants:Node3D
var bridges:Node3D
var own_boat: Node3D
var companion: Node3D
var last_profile := ""
var sky_material: ProceduralSkyMaterial
var navigation_state: RefCounted
var forest: Node3D
var town_ground: Node3D
var interaction_points: Array[Dictionary] = []

func _ready() -> void:
	return_pilot.world=self
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 5.0
	var cloud_noise := FastNoiseLite.new()
	cloud_noise.frequency = 0.025
	var cloud_ramp := Gradient.new()
	cloud_ramp.offsets = PackedFloat32Array([0.0, 0.48, 0.7, 1.0])
	cloud_ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(0.9, 0.95, 1, 0.5), Color(0.7, 0.8, 0.87, 0.9)])
	var cloud_texture := NoiseTexture2D.new()
	cloud_texture.width = 256
	cloud_texture.height = 128
	cloud_texture.seamless = true
	cloud_texture.noise = cloud_noise
	cloud_texture.color_ramp = cloud_ramp
	sky_material.sky_cover = cloud_texture
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = sky_material
	environment.environment.tonemap_mode = 2
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a9c8d4")
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(8, 11, 12)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 44.0
	camera.far=2400
	camera.size = 28
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))
	camera.current = true
	orbit = preload("res://scripts/life/orbit_camera.gd").new() if OS.get_cmdline_user_args().has("--third-person-camera") else preload("res://scripts/life/stable_third_person_camera.gd").new()
	add_child(orbit)
	orbit.setup(camera)
	orbit.resolve_position=safe_camera_position
	orbit.constrain_focus=func(point:Vector3)->Vector3:
		return indoor_camera.bound_focus(point) if orbit.comfort_mode and navigation_state!=null and navigation_state.location=="villa" else point
	orbit.present_view=_present_indoor_view
	orbit.frame_subject=func()->Vector3:
		return player.position+Vector3.UP*(1.8 if player.stair_active else 1.95) if player!=null and navigation_state!=null and navigation_state.location=="villa" and not orbit.is_away() and player.bed_stage=="" and not player.sofa_seated and not player.home_busy else Vector3.INF
	orbit.resolve_observation=safe_observation_position
	focus_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.53
	ring.rings = 12
	ring.ring_segments = 24
	focus_ring.mesh = ring
	var highlight := material(Color("d5bc78"))
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	focus_ring.material_override = highlight
	focus_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	focus_ring.visible = false
	add_child(focus_ring)
	props = Node3D.new()
	add_child(props)
	# Persistent water and land are independent of the model props.
	sea = material(Color("388f9e"))
	sea.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.albedo_color.a = 0.65

	var ocean := MeshInstance3D.new()
	var surface := PlaneMesh.new()
	surface.size = Vector2(160, 160)
	surface.subdivide_width = 64
	surface.subdivide_depth = 64
	ocean.mesh = surface
	ocean.position.y = -0.25
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_shader = ShaderMaterial.new()
	water_shader.shader = preload("res://shaders/coastal_water.gdshader")
	ocean.material_override = water_shader
	add_child(ocean)
	outside_surfaces.append(ocean)
	grass = material(Color("809c58"))
	town_ground = Node3D.new()
	add_child(town_ground)
	var sand := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 8
	cylinder.bottom_radius = 8.7
	cylinder.height = 0.8
	cylinder.radial_segments = 40
	sand.mesh = cylinder
	sand.material_override = material(Color("dfca94"))
	town_ground.add_child(sand)
	var ground := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 6.8
	top.bottom_radius = 7.5
	top.height = 0.35
	top.radial_segments = 36
	ground.mesh = top
	ground.position.y = 0.5
	ground.material_override = grass
	town_ground.add_child(ground)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_cylinder := CylinderShape3D.new()
	floor_cylinder.radius = 7.4
	floor_cylinder.height = 0.35
	floor_shape.shape = floor_cylinder
	floor_body.position.y = 0.5
	floor_body.add_child(floor_shape)
	town_ground.add_child(floor_body)
	boat_wake=preload("res://scripts/life/boat_wake.gd").new();add_child(boat_wake);boat_wake.setup(self)
	forest = preload("res://scripts/life/forest_scene.gd").new()
	add_child(forest)
	forest.setup(self)
	camp_light = OmniLight3D.new()
	camp_light.position = Vector3(-1, 2.5, 2)
	camp_light.light_color = Color("ffba67")
	camp_light.omni_range = 10
	add_child(camp_light)
	rain = GPUParticles3D.new()
	rain.amount = 200
	rain.lifetime = 1.5
	rain.position = Vector3(0, 8, 0)
	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(9, 1, 9)
	rain_process.direction = Vector3(0, -1, 0)
	rain_process.spread = 5
	rain_process.initial_velocity_min = 6
	rain_process.initial_velocity_max = 9
	rain_process.gravity = Vector3(0, -2, 0)
	rain.process_material = rain_process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.22, 0.025)
	drop.material = material(Color("accddd"))
	rain.draw_pass_1 = drop
	add_child(rain)
	seascape=preload("res://scripts/life/seascape.gd").new()
	add_child(seascape)
	seascape.setup(self)
	sea_giants=preload("res://scripts/life/sea_giants.gd").new()
	add_child(sea_giants)
	sea_giants.setup(self)
	bridges=preload("res://scripts/life/island_bridges.gd").new()
	add_child(bridges)
	bridges.setup(self)
	outside_surfaces.append(seascape)
	exploration=preload("res://scripts/life/island_exploration.gd").new();exploration.setup(self)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.srgb_to_linear()
	mat.roughness = 0.9
	return mat

## 通用木栈桥：主岛与所有远岛共用同一套模型（大平台 + 窄栈道 + 端台 + 四排立柱 + 可走碰撞）。
func build_pier(parent: Node3D, shore: Vector3, heading: float, wood: Material) -> Node3D:
	var pier := Node3D.new()
	pier.name = "Pier"
	parent.add_child(pier)
	var direction := Vector3(sin(heading), 0, cos(heading))
	var side := Vector3(direction.z, 0, -direction.x)
	# 与主岛同一组三段：8 米大平台、贴边伸出的 5 米窄栈道、1 米端台。
	for segment: Array in [[0.0, 4.6, 8.0, 0.0], [6.5, 1.0, 5.0, 1.8], [12.0, 4.6, 2.0, 0.0]]:
		var offset: float = float(segment[0])
		var width: float = float(segment[1])
		var span: float = float(segment[2])
		var lateral: float = float(segment[3])
		var center := shore + direction * offset + side * lateral
		var slab := box(pier, Vector3(center.x, shore.y, center.z), Vector3(width, .3, span), wood)
		slab.rotation.y = heading
		var body := StaticBody3D.new()
		body.position = Vector3(center.x, shore.y, center.z)
		body.rotation.y = heading
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, .3, span)
		collision.shape = shape
		body.add_child(collision)
		pier.add_child(body)
	# 立柱：四排两根，和主岛一样高 1.6、居中 y0。
	for post_offset: float in [0.0, 4.0, 8.0, 12.0]:
		for sign_side: float in [-1.0, 1.0]:
			var at := shore + direction * post_offset + side * (1.95 * sign_side)
			var post := box(pier, Vector3(at.x, 0, at.z), Vector3(.16, 1.6, .16), wood)
			post.rotation.y = heading
	return pier
func box(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	# 小于半米的小道具不投影：阴影 pass 里它们只贡献绘制调用，几乎看不到影子。
	if maxf(dimensions.x, maxf(dimensions.y, dimensions.z)) < .5:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func model(id: String, pos: Vector3, scale_value: float = 1) -> Node3D:
	var path := "res://assets/polyfork/%s.glb" % id
	if not ResourceLoader.exists(path): return null
	var packed := load(path) as PackedScene
	if packed == null: return null
	var node := packed.instantiate() as Node3D
	node.position = pos
	node.scale = Vector3.ONE * scale_value
	props.add_child(node)
	_apply_vertex_colors(node)
	return node

func signpost(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.visible = false # World names and resource explanations live in the HUD/menu.
	label.font_size = 38
	label.pixel_size = 0.012
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	props.add_child(label)

func rebuild(state: RefCounted) -> void:
	if exploration!=null:exploration.activate(null)
	home_camera.reset();walk_camera.reset()
	if player != null:
		player.cancel_stairs()
		player.cancel_bed()
		player.leave_sofa()
		player.end_fishing()
	navigation_state = state
	if player != null and player.boating and last_location != state.location:
		_set_boating(false)

	for tree: Node3D in forest.extra_trees:
		if is_instance_valid(tree):forest.faded.erase(tree.get_instance_id())
	forest.extra_trees.clear()
	for child in props.get_children():
		props.remove_child(child)
		child.queue_free()
	interaction_points.clear()
	for surface: Node3D in outside_surfaces: surface.visible = state.location != "villa"
	forest.visible = state.location == "island"
	forest.process_mode = Node.PROCESS_MODE_INHERIT if forest.visible else Node.PROCESS_MODE_DISABLED
	# Hidden physics must also be disabled while visiting town.
	for body: CollisionObject3D in forest.find_children("*", "CollisionObject3D", true, false):
		if not body.has_meta("world_collision_layer"):body.set_meta("world_collision_layer",body.collision_layer)
		body.collision_layer = int(body.get_meta("world_collision_layer")) if forest.visible else 0
	town_ground.visible = state.location in ["town", "city"]
	for body: StaticBody3D in town_ground.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 1 if town_ground.visible else 0
	var wood := material(Color("937250"))
	if state.location in ["town", "city"]:
		box(props, Vector3(3, 0.6, 7), Vector3(2, 0.3, 5), wood)
		model("rowboat-c42d85", Vector3(5, -0.62, 8), 1.1)
	if state.location == "island":
		var residence := Villa.new()
		props.add_child(residence)
		residence.setup(self)
		residence.exterior()
		var fishing_platform := FishingPlatform.new()
		props.add_child(fishing_platform)
		fishing_platform.setup(self)
		# 主岛码头：所有岛共用这一套构件（build_pier），只有湖岸位置不同。
		build_pier(props, Vector3(1.7, .5, 5.0), 0.0, wood)
		own_boat = model("rowboat-c42d85", MOORING - Vector3(0, 0.62, 0), 1.1)
		own_boat.visible = player == null or not player.boating
		boat_status_label = Label3D.new()
		boat_status_label.text = "我的船 · 可出海"
		boat_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		boat_status_label.font = load("res://assets/fonts/NotoSansSC.ttf")
		boat_status_label.font_size = 30
		boat_status_label.pixel_size = 0.009
		boat_status_label.position = MOORING + Vector3(0,1.6,0)
		props.add_child(boat_status_label)
		# 去青湾镇的金色浮标：圆润浮体 + 白色水线带 + 短杆小旗，替代原来的方块加黑杆。
		var buoy := MeshInstance3D.new()
		var buoy_mesh := SphereMesh.new();buoy_mesh.radius = .46;buoy_mesh.height = .92;buoy_mesh.radial_segments = 14;buoy_mesh.rings = 7
		buoy.mesh = buoy_mesh;buoy.material_override = material(Color("e8b457"))
		buoy.position = Vector3(5, 0.16, 34)
		props.add_child(buoy)
		var band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new();band_mesh.top_radius = .44;band_mesh.bottom_radius = .44;band_mesh.height = .14;band_mesh.radial_segments = 14
		band.mesh = band_mesh;band.material_override = material(Color("f4ead6"))
		band.position = Vector3(5, 0.40, 34)
		props.add_child(band)
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new();mast_mesh.top_radius = .025;mast_mesh.bottom_radius = .035;mast_mesh.height = .85;mast_mesh.radial_segments = 8
		mast.mesh = mast_mesh;mast.material_override = material(Color("5b4a3a"))
		mast.position = Vector3(5, 0.95, 34)
		props.add_child(mast)
		box(props, Vector3(5.16, 1.30, 34), Vector3(0.32, 0.20, 0.03), material(Color("e9705f")))
		signpost("晴耕雨航\n晴屿 · 我的家", Vector3(-1, 3, -5))
		for p: Vector3 in [Vector3(-5, 0.7, -2), Vector3(3, 0.7, -4), Vector3(-5, 0.7, 4.8)]:
			p.y = forest.height_at(p.x,p.z)
			var tree := model("broad-canopy-shade-tree-e7c4a2", p, 0.65)
			preload("res://scripts/life/prop_collision.gd").tree(tree, "broad-canopy-shade-tree-e7c4a2")
			forest.extra_trees.append(tree)
		_build_house(state)
		if state.buildings.has("庇护所") and not state.buildings.has("木屋"):
			preload("res://scripts/life/prop_collision.gd").convex(model("canvas-ridge-tent-f0df0d", Vector3(3, 0.7, 0), 0.8))
		if state.buildings.has("篝火"):
			model("campfire-4390aa", Vector3(-1, 0.7, 2), 1.5)
			_solid(Vector3(-1, 0.95, 2), Vector3(0.9, 0.5, 0.9))
		if state.buildings.has("木屋"):
			preload("res://scripts/life/prop_collision.gd").convex(model("loot-crate-23dd3b", Vector3(1, 0.7, 1), 1.3))
		if state.buildings.has("菜地"):
			box(props, Vector3(3, 0.8, 2), Vector3(2.6, 0.2, 2.2), material(Color("72543d")))
			for x in range(3):
				box(props, Vector3(2.2 + x * 0.7, 1.0, 2), Vector3(0.2, 0.35, 1.5), material(Color("5f8d48")))
		if state.buildings.has("遮阴棚"):
			box(props, Vector3(0, 2.8, -2), Vector3(3, 0.2, 2), wood)
		if state.buildings.has("储水桶"):
			box(props, Vector3(-4, 1, 3), Vector3(0.8, 0.8, 0.8), wood)
			_solid(Vector3(-4, 1, 3), Vector3(0.8, 0.8, 0.8))
	elif state.location == "villa":
		villa_rooms.clear()
		for floor_index in range(2):
			var room := Villa.new()
			props.add_child(room)
			room.position.y=floor_index*Villa.Dimensions.RISE
			room.setup(self);room.interior(floor_index)
			room.visible=floor_index==state.home_floor
			villa_rooms.append(room)
		villa_room=villa_rooms[state.home_floor]
		var stairwell=preload("res://scripts/life/villa_stairwell.gd").new()
		props.add_child(stairwell);stairwell.setup(self)
		var envelope=preload("res://scripts/life/interior_shell.gd").new()
		props.add_child(envelope);envelope.setup(self)
		var balcony=preload("res://scripts/life/home_balcony.gd").new();props.add_child(balcony);balcony.setup(self)
	else:
		var city: bool = state.location == "city"
		signpost("临海城 · 手艺人的远方" if city else "青湾镇 · 周末也开集", Vector3(0, 4.5, -4))
		for i in range(3):
			var x := -4.0 + i * 4.0
			box(props, Vector3(x, 1.8, -1), Vector3(3, 2.2 if city else 1.4, 2.4), material(Color("e5d4b4")))
			box(props, Vector3(x, 3.2 if city else 2.6, -1), Vector3(3.4, 0.25, 2.9), material([Color("71968c"), Color("ba7657"), Color("7586a2")][i]))
			model("loot-crate-23dd3b", Vector3(x, 0.7, 1.5), 1.5)
			signpost(["鱼贩 · 收购", "杂货 · 换物", "工坊 · 订单"][i], Vector3(x, 2, 2))
	_ensure_player(state)
	player.manual_stair_entry=Callable()
	player.stair_view_ready=func(target:Vector3)->bool:
		if orbit.stable_third_person:return orbit.stair_ready(target)
		if orbit.first_person or not orbit.comfort_mode:return true
		var next:Vector3=player.position+(target-player.position).limit_length(.16)+Vector3.UP*1.8
		if camera.is_position_behind(next):return false
		var pixel:Vector2=camera.unproject_position(next)
		var size:Vector2=camera.get_viewport().get_visible_rect().size
		return Rect2(size*.10,size*.80).has_point(pixel)
	if last_profile != str(state.profile): _sync_profile(state)
	var lighting_key := "%s:%d:%d:%s"%[state.location,state.home_floor,int(state.minute*4),last_buildings]
	if lighting_key==last_lighting_key:return
	last_lighting_key=lighting_key
	_build_interactions(state)
	if last_location != state.location:
		if orbit.comfort_mode and last_location!="":orbit.fade_cut()
		orbit.cut_focus=Vector3.INF
		orbit.motion_reset=true
		orbit.yaw_speed=0;orbit.pitch_speed=0
		orbit.clear_observation(true)
		orbit.target_distance=-1
		camera.near=.04 if orbit.first_person else (.12 if state.location=="villa" else .05)
		camera.far=45 if state.location=="villa" else 2400
		orbit.distance = indoor_camera.FOLLOW_DISTANCE if state.location == "villa" else Vector3(8,11,12).length()
		if state.location == "villa":
			camera.fov=orbit.VIEW_FOV if orbit.first_person else (orbit.THIRD_FOV if orbit.stable_third_person else (indoor_camera.lens(self) if orbit.comfort_mode else home_camera.fov))
			orbit.yaw = 0
			orbit.target_yaw = orbit.yaw
			orbit.pitch = indoor_camera.COMFORT_PITCH if orbit.comfort_mode else deg_to_rad(55)
			orbit.target_pitch = orbit.pitch
		else:
			camera.fov=orbit.VIEW_FOV if orbit.first_person else (orbit.THIRD_FOV if orbit.stable_third_person else 44.0)
			orbit.yaw=orbit.initial_yaw;orbit.target_yaw=orbit.initial_yaw
			orbit.pitch=orbit.initial_pitch;orbit.target_pitch=orbit.initial_pitch
		orbit.focus = player.position + Vector3.UP
		indoor_camera.reset()
	last_home_floor = state.home_floor
	last_location = state.location
	last_buildings = str(state.buildings)

var _sky_clock := 0.0
func sync(state: RefCounted) -> void:
	if last_location != state.location or last_buildings != str(state.buildings): rebuild(state)
	elif last_home_floor != state.home_floor:
		if state.location=="villa" and villa_rooms.size()==2:
			for i in range(2):villa_rooms[i].visible=i==state.home_floor
			villa_room=villa_rooms[state.home_floor]
			interaction_points.clear();_build_interactions(state)
			last_home_floor=state.home_floor
		else:rebuild(state)
	if last_profile != str(state.profile): _sync_profile(state)
	if exploration!=null:exploration.sync(state)
	_sync_indoor_visibility()
	if _sky_clock > 0.0:
		_sky_clock -= get_process_delta_time()
		return
	_sky_clock = .1
	var daylight: float = state.daylight()
	var solar := solar_direction(state.hour(), state.season())
	sun.position = solar * 100
	sun.look_at(Vector3.ZERO, Vector3.FORWARD if absf(solar.y) > 0.98 else Vector3.UP)
	sky_material.sky_top_color = Color("081523").lerp(Color("70b5d3"), daylight)
	var dusk := 1.0 - absf(daylight * 2.0 - 1.0)
	sky_material.sky_horizon_color = Color("152c41").lerp(Color("e5d8b2").lerp(Color("f4ab79"), dusk), daylight)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color("143b45")
	var overcast: bool = state.weather() in ["春雨", "雷雨", "冷雨", "海雾"]
	sky_material.sky_cover_modulate = Color(1, 1, 1, 1.0 if overcast else 0.25)
	sun.light_energy = (0.05 + daylight * 0.8) * (0.4 if overcast else 1.0)
	sun.light_color = Color("ffc88a").lerp(Color("fff4d9"), daylight)
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.background_color = Color("e9e4ce").srgb_to_linear() if state.location == "villa" else Color("142936").lerp(Color("a8c9ce"), daylight).srgb_to_linear()
	if state.location == "villa" and not on_balcony(): sun.light_energy *= 0.3
	environment.environment.fog_enabled = state.location != "villa" or on_balcony()
	environment.environment.fog_density = 0.015 if state.weather()=="海雾" else .0008
	environment.environment.fog_light_color=sky_material.sky_horizon_color
	environment.environment.ambient_light_energy = 0.6 if state.location == "villa" and not on_balcony() else 0.25 + daylight * 0.2
	camp_light.light_energy = (1 - daylight) * 2 if state.buildings.has("篝火") and state.location == "island" else 0
	rain.emitting = state.weather() in ["春雨", "雷雨", "冷雨"] and state.location != "villa"
	if current_season != state.season():
		current_season = state.season()
		forest.season_changed(current_season)
		grass.albedo_color = [Color("809c58"), Color("5d925b"), Color("b39759"), Color("a8b9ad")][current_season].srgb_to_linear()
		sea.albedo_color = [Color("388f9e"), Color("338ea1"), Color("567e88"), Color("59727f")][current_season].srgb_to_linear()
		sea.albedo_color.a = 0.65
		water_shader.set_shader_parameter("water_color", sea.albedo_color.linear_to_srgb())
	seascape.sync(state)
	if is_instance_valid(shore_lights):shore_lights.sync(state)
	if is_instance_valid(fish_keeper):fish_keeper.sync(state)

func pulse() -> void:
	# Brief harvest/build feedback, inspired by PixelFX's anticipation/contact/recovery.
	var spark := box(props, Vector3(0, 1.5, 2), Vector3(0.2, 0.2, 0.2), material(Color("f7d58b")))
	var tween := create_tween()
	tween.tween_property(spark, "position:y", 3.0, 0.45)
	tween.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.45)
	tween.tween_callback(spark.queue_free)

func _farmer_palette(visual: Node) -> void:
	# Polyfork 那几个基础小孩是彩色发辫 + 惨白脸 + 爪手，和「晴屿农人」完全不是一个人。
	# 不动模型拓扑，只把顶点色归到两种：饱和色（发辫、饰带）压成深棕，近白色（脸、手）换成暖肤色。
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		var source = mesh.mesh
		if not (source is ArrayMesh): continue
		var rebuilt := ArrayMesh.new()
		var touched := false
		for index in range(source.get_surface_count()):
			var arrays: Array = source.surface_get_arrays(index)
			var colors: Variant = arrays[Mesh.ARRAY_COLOR]
			if colors is PackedColorArray and colors.size() > 0:
				var out: PackedColorArray = colors
				for vertex in range(out.size()):
					var color: Color = out[vertex]
					var high := maxf(color.r, maxf(color.g, color.b))
					var low := minf(color.r, minf(color.g, color.b))
					# 用饱和度判定：有彩度（发辫、饰带、耳饰）统一压成头发棕；
					# 低彩度里偏亮的（脸、手、脚）换成暖肤色；衣服的暗绿暗褐不动。
					if color.v < 0.3:
						continue
					if color.s > 0.35:
						out[vertex] = Color(0.33, 0.23, 0.16); touched = true
					elif color.v > 0.58:
						out[vertex] = Color(0.79, 0.6, 0.45); touched = true
				arrays[Mesh.ARRAY_COLOR] = out
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if touched: mesh.mesh = rebuilt

func _apply_vertex_colors(root_node: Node) -> void:
	# Polyfork low-poly GLBs carry their palette in COLOR_0 vertex attributes.
	if root_node is MeshInstance3D and root_node.mesh != null:
		for index in range(root_node.mesh.get_surface_count()):
			var arrays: Array = root_node.mesh.surface_get_arrays(index)
			if arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > 0:
				var original: Material = root_node.get_active_material(index)
				if original is StandardMaterial3D:
					var colored := original.duplicate() as StandardMaterial3D
					colored.vertex_color_use_as_albedo = true
					root_node.set_surface_override_material(index, colored)
	for child in root_node.get_children(): _apply_vertex_colors(child)

func _build_house(state: RefCounted) -> void:
	var timber := material(Color("946641"))
	var light_wood := material(Color("bd9968"))
	var stone := material(Color("8c928c"))
	var roof := material(Color("667e79"))
	var center := Vector3(-2.5, 0.7, -1.7)
	if not state.buildings.has("地基"):
		for x: float in [-2.2, 2.2]:
			for z: float in [-1.8, 1.8]:
				box(props, center + Vector3(x, 0.15, z), Vector3(0.12, 0.3, 0.12), light_wood)
		signpost("未来的家\n先打地基", center + Vector3(0, 0.5, 0))
		return
	box(props, center + Vector3(0, 0.15, 0), Vector3(4.4, 0.3, 3.6), stone)
	box(props, center + Vector3(0, 0.35, 0), Vector3(4.2, 0.15, 3.4), light_wood)
	if not state.buildings.has("墙体"):
		signpost("地基已完成 · 下一步立墙", center + Vector3(0, 0.9, 0))
		return
	for x: float in [-2.0, 2.0]:
		for z: float in [-1.6, 1.6]:
			box(props, center + Vector3(x, 1.6, z), Vector3(0.2, 2.6, 0.2), timber)
	box(props, center + Vector3(0, 1.5, -1.6), Vector3(4.2, 2.3, 0.16), light_wood)
	box(props, center + Vector3(-2, 1.5, 0), Vector3(0.16, 2.3, 3.2), light_wood)
	box(props, center + Vector3(2, 0.9, 0), Vector3(0.16, 1.2, 3.2), light_wood)
	# The front has a door gap; a window opening keeps the silhouette readable.
	for x: float in [-1.45, 1.45]:
		box(props, center + Vector3(x, 1.5, 1.6), Vector3(1.2, 2.3, 0.16), light_wood)
	box(props, center + Vector3(0, 2.7, 1.6), Vector3(1.7, 0.2, 0.16), timber)
	if state.buildings.has("屋顶"):
		for side: float in [-1.0, 1.0]:
			var slope := box(props, center + Vector3(side * 1.1, 3.2, 0), Vector3(2.7, 0.2, 4.2), roof)
			slope.rotation.z = -side * 0.45
	if state.buildings.has("木门与床"):
		box(props, center + Vector3(0.65, 1.4, 1.8), Vector3(1.3, 2.05, 0.13), timber).rotation.y = 0.55
		box(props, center + Vector3(0.8, 0.7, -0.7), Vector3(1.15, 0.55, 1.9), timber)
		box(props, center + Vector3(0.8, 1.0, -0.7), Vector3(1.1, 0.12, 1.8), material(Color("bec7a2")))
		signpost("我的第一间木屋", center + Vector3(0, 4.5, 0))

func _solid(pos: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	props.add_child(body)

func _ensure_player(state: RefCounted) -> void:
	if player == null:
		player = preload("res://scripts/life/player_controller.gd").new()
		player.name = "Player"
		var fill := OmniLight3D.new()
		fill.position = Vector3(0, 1.4, 0.5)
		fill.light_color = Color("fff1d3")
		fill.light_energy = 0.2
		fill.omni_range = 3.0
		player.add_child(fill)
		player.camera = camera
		player.terrain_height = terrain_height
		player.tree_motion = safe_tree_motion
		player.sea_walkable = navigable_water
		player.boat_heading_clear = boat_heading_is_clear
		player.terrain_walkable = terrain_walkable
		add_child(player)
	if last_location != state.location:
		var saved: Array = state.player_position
		player.position = Vector3(float(saved[0]), float(saved[1]), float(saved[2]))
		player.velocity = Vector3.ZERO
		if not terrain_walkable(player.position): player.position = Vector3(0, 0.7, 3.2)
		player.position.y = terrain_height(player.position.x, player.position.z) + 0.03
	# Keep older saves out of the new bookcase footprint.
	if state.location=="villa" and state.home_floor==0 and absf(player.position.x-5.3)<1.7 and absf(player.position.z+4.8)<.7:
		player.position.z=-3.9
		player.position.y=.705
	if state.location=="villa" and state.home_floor==0 and last_location!=state.location:
		for footprint:Rect2 in [Rect2(-10.5,8.7,2.7,2.8),Rect2(-7.4,9.3,1.4,2),Rect2(-10.5,13.3,3,1.4),Rect2(-7.1,1.5,2.2,2),Rect2(-3.9,.8,1.6,3.4)]:
			if footprint.has_point(Vector2(player.position.x,player.position.z)):
				player.position=Vector3(0,.705,8);break
	if state.location=="villa" and state.home_floor==1:
		# Furniture moved into formerly empty floor. Restore older saves to the open hall.
		for footprint: Rect2 in [Rect2(-6.3,-6.1,3.0,4.1),Rect2(-2.8,-5.6,2.1,1.6),Rect2(-.9,-5.1,4.0,1.9),Rect2(.25,-3.55,1.7,1.7),Rect2(3.55,-5.6,1.0,1.7)]:
			if footprint.has_point(Vector2(player.position.x,player.position.z)):
				player.position=Vector3(clampf(player.position.x,-6.5,6.5),Villa.Dimensions.UPPER_FLOOR+.03,.8)
				break
	if state.location == "island" and absf(player.position.x - 11) < 6.4 and absf(player.position.z + 6) < 5.4:
		player.position = Villa.OUTSIDE_SPAWN
	if state.location == "island" and state.buildings.has("地基"):
		if absf(player.position.x + 2.5) < 2.65 and absf(player.position.z + 1.7) < 2.4:
			player.position = Vector3(-2.5, 0.7, 1.1)

	if state.location=="island" and last_location!=state.location: _recover_tree_spawn(state)

func _build_interactions(state: RefCounted) -> void:
	if state.location == "island":
		for tree_index in range(forest.tree_positions.size()):
			var p: Vector3=forest.tree_positions[tree_index]
			interaction_points.append({"kind": "伐木", "title": "伐木", "owner":forest.trees[tree_index], "pos": p, "range": float(forest.trees[forest.tree_positions.find(p)].get_meta("solid_radius")) + 1.8, "min_range": float(forest.trees[forest.tree_positions.find(p)].get_meta("solid_radius")) + player.TREE_RADIUS + 0.3})
		for p: Vector3 in [Vector3(-5, 0.7, -2), Vector3(3, 0.7, -4), Vector3(-5, 0.7, 4.8)]:
			p.y = forest.height_at(p.x,p.z)
			for body: StaticBody3D in props.find_children("TreeObstacle","StaticBody3D",true,false):
				if body.get_parent().position.distance_to(p)<.1:
					var radius: float=body.get_parent().get_meta("solid_radius")
					interaction_points.append({"kind":"伐木","title":"伐木","owner":body.get_parent(),"pos":p,"range":radius+1.8,"min_range":radius+player.TREE_RADIUS+.3})
					break
		for point: Dictionary in [
			{"kind": "拾石", "title": "拾石", "pos": Vector3(0.5, 0.7, -4.5), "range": 1.8},
			{"kind": "采纤维", "title": "采纤维", "pos": Vector3(-4.8, 0.7, 2.8), "range": 1.8},
			{"kind": "采果", "title": "采果", "pos": Vector3(3.6, 0.7, 3.0), "range": 1.8},
			{"kind": "捕鱼", "title": "捕鱼", "pos": Vector3(0, 0.7, 6), "range": 1.6}]:
			var grounded: Vector3 = point.pos
			grounded.y = terrain_height(grounded.x,grounded.z) + 0.025
			point.pos = grounded
			interaction_points.append(point)
			var tint := Color("84918c") if point.kind == "拾石" else (Color("a7684f") if point.kind == "采果" else Color("659b5e"))
			if point.kind != "捕鱼":
				box(props, point.pos + Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 0.7), material(tint))
				_solid(point.pos + Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 0.7))
				point["min_range"] = 1.05
			signpost(point.title, point.pos + Vector3(0, 1.1, 0))
		interaction_points.append({"kind": "house", "title": "我的家", "pos": Vector3(-2.5, 0.7, -1.7), "range": 3.5})
		if state.buildings.has("地基"): _solid(Vector3(-2.5, 1.7, -1.7), Vector3(4.5, 2.2, 3.7))
		if state.buildings.has("篝火"):
			interaction_points.append({"kind": "cook", "title": "烹饪", "pos": Vector3(-1, 0.7, 2), "range": 1.5})
		interaction_points.append({"kind":"villa_entry","title":"进入别墅","pos":Villa.ENTRY,"range":1.8})
		interaction_points.append({"kind":"shore_fish","title":"钓台垂钓","pos":FishingPlatform.POINT,"range":3.5})
		interaction_points.append({"kind": "boat", "title": "上船", "pos": DOCK, "range": BOARD_RADIUS})
	elif state.location == "villa":
		interaction_points.append_array(villa_room.points)
	else:
		for x: float in [-4.0, 0.0, 4.0]:
			_solid(Vector3(x, 1.7, -1), Vector3(3, 2, 2.4))
			interaction_points.append({"kind": "market", "title": "交易", "pos": Vector3(x, 0.7, 2), "range": 2.0})

	_register_interaction_anchors()

func find_interaction(kind: String) -> Dictionary:
	for point: Dictionary in interaction_points:
		if point.kind==kind:return point
	return {}
func _register_interaction_anchors() -> void:
	for index in range(interaction_points.size()):
		var point: Dictionary=interaction_points[index]
		var pos: Vector3=point.pos
		var stand := pos
		var facing := pos+Vector3.FORWARD
		var yaw := .45
		var pitch := deg_to_rad(42)
		var distance := 10.0
		var radial: bool=point.kind in ["伐木","拾石","采纤维","采果","捕鱼"]
		var owner_node: Node3D=point.get("owner",props)
		if radial:
			stand=pos+Vector3(0,0,maxf(1.1,float(point.get("min_range",.8))+.23));facing=pos;distance=9;yaw=.65
		match str(point.kind):
			"shore_fish":
				owner_node=props.find_child("ShoreFishingPlatform",true,false)
				stand=Vector3(-1,.68,15.55);facing=FishingPlatform.FLOAT;yaw=PI-.45;pitch=deg_to_rad(35);distance=28
			"boat":stand=DOCK;facing=MOORING;owner_node=own_boat if is_instance_valid(own_boat) else props;yaw=PI-.4;pitch=deg_to_rad(35);distance=18
			"villa_entry":stand=Villa.OUTSIDE_SPAWN;facing=Villa.ENTRY;yaw=0;distance=15
			"house":stand=Vector3(-2.5,.7,1.1);facing=pos;distance=12
			"cook":stand=pos+Vector3(0,0,1.1);facing=pos;distance=9
			"villa_tv":stand=Vector3(-8.8,.705,2.5);facing=Vector3(-10.2,2.49,2.5)
			"villa_rest":stand=Villa.SOFA_STAND;facing=Villa.SOFA_SEAT;yaw=PI/2;pitch=deg_to_rad(50);distance=12
			"villa_balcony":facing=pos+Vector3.BACK*2
			"villa_balcony_return":facing=pos+Vector3.FORWARD*2
			"villa_balcony_rest":facing=Vector3(-3,pos.y,22.2)
			"villa_exit":stand=Vector3(0,.7,16.5);facing=Vector3(0,.7,17.8);yaw=0;pitch=deg_to_rad(55);distance=14
			"villa_stairs":facing=pos+Vector3(0,0,-1);yaw=.4;pitch=deg_to_rad(55);distance=14
			"villa_water":stand=Vector3(-5.9,.705,-3.65);facing=Vector3(-5.9,1.7,-4.8)
			"villa_cook":stand=Vector3(-3.4,.705,-3.6);facing=Vector3(-3.4,1.7,-4.8)
			"villa_bath","villa_storage":facing=pos+Vector3(0,0,-1);yaw=0;pitch=deg_to_rad(55);distance=12
			"villa_fridge":facing=Vector3(-1.5,.7,-4.9);yaw=0;distance=6
			"villa_bin":facing=Vector3(-7,.7,-3.2);yaw=0;distance=6
			"villa_eat":facing=Villa.DINING_CENTER;yaw=.3;pitch=deg_to_rad(55);distance=12
			"villa_sleep":facing=Vector3(Villa.BED_CENTER.x,pos.y,Villa.BED_CENTER.z);yaw=.3;pitch=deg_to_rad(55);distance=12
			"market":facing=pos+Vector3(0,0,-1);yaw=.4;distance=12
		if not is_instance_valid(owner_node):owner_node=props
		var anchor_name := "InteractionAnchor_%s_%d"%[point.kind,index if owner_node==props or point.kind=="villa_eat" else 0]
		var marker: Marker3D=owner_node.get_node_or_null(NodePath(anchor_name))
		if marker==null:
			marker=preload("res://scripts/life/interaction_anchor.gd").new();marker.name=anchor_name;owner_node.add_child(marker)
		if navigation_state!=null and navigation_state.location=="villa":distance=indoor_camera.FOLLOW_DISTANCE
		var offset := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
		marker.configure(point.get("stand",stand),point.get("facing",facing),point.get("camera_offset",offset));marker.radial=point.get("radial",radial)
		if point.kind=="shore_fish":marker.exact_stand=true;marker.arrival_radius=.12
		point["anchor"]=marker
		if navigation_state!=null and navigation_state.location=="villa":
			var names:Dictionary={"villa_rest":"LivingSofaMain","villa_fridge":"HomeFridge","villa_sleep":"MasterBed","villa_eat":"DiningTable","villa_bath":"BathroomTub","villa_storage":"BedroomWardrobe","villa_exit":"CutawayEntryDoor","villa_tv":"TelevisionScreen"}
			var object:Node3D=villa_room.get_node_or_null(str(names.get(point.kind,"__none__")))
			if object==null and point.kind=="villa_exit":object=props.find_child("CutawayEntryDoor",true,false)
			if object!=null:point["object"]=object
		elif point.kind=="shore_fish":point["object"]=props.find_child("ShoreFishingPlatform",true,false)
		elif point.kind=="boat":point["object"]=own_boat

func nearby_action() -> Dictionary:
	if player == null: return {}
	if player.boating:
		if Vector2(player.position.x - MOORING.x, player.position.z - MOORING.z).length() <= 1.8:
			return {"kind": "disembark", "title": "靠岸", "pos": MOORING}
		var landing:Dictionary=exploration.landing_candidate()
		if not landing.is_empty():return {"kind":"remote_land","title":"登岛","pos":landing.land,"site":landing}
		if player.position.distance_to(Vector3(5, 0.05, 34)) < 4:
			return {"kind": "town_route", "title": "去小镇", "pos": Vector3(5, 0.05, 34)}
		return {"kind": "sea_fish", "title": "捕鱼", "pos": player.position}
	if navigation_state.location=="island" and not navigation_state.island_visit.is_empty() and player.position.distance_to(exploration.vector(navigation_state.island_visit.landing))<3:return {"kind":"remote_return","title":"返回船上","pos":player.position}
	if not orbit.first_person and last_location=="island" and FishingPlatform.within_reach(player.position):return find_interaction("shore_fish")
	if not orbit.first_person and last_location == "island" and Vector2(player.position.x - DOCK.x, player.position.z - DOCK.z).length() <= BOARD_RADIUS:
		return find_interaction("boat")
	if orbit.first_person:
		var candidates:Array[Dictionary]=interaction_points.duplicate()
		if companion!=null:candidates.append({"kind":"pet","title":"抚摸","pos":companion.position,"range":2.0,"object":companion})
		return orbit.pick_interaction(candidates)
	var nearest: Dictionary = {}
	var best_score := INF
	for point: Dictionary in interaction_points:
		if point.kind=="shore_fish" and not FishingPlatform.within_reach(player.position):continue
		# 统一判定：靠近 + 面向就算预选中；分数按「距离 + 朝向偏差」，正对着的那个优先。
		if not interactable(point):continue
		var d: float = Vector2(player.position.x - point.pos.x, player.position.z - point.pos.z).length()
		# 朝向是主要权重：正对着的那个优先，距离只在朝向相近时决定胜负。
		var score: float = d * .3 + 3.0 * (1.0 - facing_amount(point))
		if score < best_score:
			nearest = point
			best_score = score
	if nearest.is_empty() and companion != null and companion.position.distance_to(player.position) <= 2.5:
		return {"kind": "pet", "title": "抚摸", "pos": companion.position}
	return nearest

func facing_point(point: Dictionary, threshold: float = .5) -> bool:
	if player == null: return true
	var target: Vector3 = point.get("pos", point.get("anchor", Vector3.ZERO))
	var flat: Vector3 = target - player.position; flat.y = 0
	if flat.length() < .12: return true
	var forward: Vector3 = player.visual.global_basis.z.normalized() if player.visual != null else Vector3.FORWARD
	return forward.dot(flat.normalized()) >= threshold
## 统一的可交互判定：离得够近 + 正面朝它 + 中间没挡着 + 同一楼层。
## 站位点只作为姿态目标，不再当门槛。
func interactable(point: Dictionary, threshold: float = .5) -> bool:
	if player == null or point.is_empty(): return false
	var target: Vector3 = point.get("pos", point.get("anchor", Vector3.ZERO))
	var flat: Vector3 = target - player.position; flat.y = 0
	if flat.length() > float(point.get("range", 1.4)): return false
	if absf(target.y - player.position.y) > 1.2: return false
	if not facing_point(point, threshold): return false
	return not blocked_to(target)

func blocked_to(target: Vector3) -> bool:
	if player == null or not player.is_inside_tree(): return false
	var from: Vector3 = player.position + Vector3.UP * 1.15
	var to: Vector3 = target + Vector3.UP * .55
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return false
	# 贴着目标本体的碰撞（椅背、柜门棱）不算遮挡，只有明显挡在中间的墙才算。
	return Vector3(hit.position).distance_to(to) > 1.0

func facing_amount(point: Dictionary) -> float:
	if player == null: return 1.0
	var target: Vector3 = point.get("pos", point.get("anchor", Vector3.ZERO))
	var flat: Vector3 = target - player.position; flat.y = 0
	if flat.length() < .12: return 1.0
	var forward: Vector3 = player.visual.global_basis.z.normalized() if player.visual != null else Vector3.FORWARD
	return forward.dot(flat.normalized())

func can_labor(kind: String) -> bool:
	if player == null: return false
	if player.boating: return kind == "捕鱼"
	for point: Dictionary in interaction_points:
		if point.kind == kind and Vector2(player.position.x - point.pos.x, player.position.z - point.pos.z).length() <= float(point.range): return true
	return false

func show_interaction(point: Dictionary) -> void:
	if focus_ring == null: return
	focus_ring.visible = not orbit.first_person and not orbit.stable_third_person and not point.is_empty()
	if not point.is_empty(): focus_ring.position = (point.get("stand",point.anchor.global_position) if is_instance_valid(point.get("anchor")) else point.pos) + Vector3(0, 0.04, 0)

func terrain_height(x: float, z: float) -> float:
	if navigation_state != null and navigation_state.location == "villa":
		if x>7.8 and player!=null and player.stair_active:return player.position.y
		return 0.675+navigation_state.home_floor*Villa.Dimensions.RISE
	if forest.visible and x >= -3 and x <= 3 and z >= 13 and z <= 18: return 0.65
	if forest.visible and x >= 9 and x <= 13 and z >= -1 and z <= 2: return 1.34
	if forest.visible and x >= -.6 and x <= 4.0 and z >= 5 and z <= 19: return 0.65
	return island_ground_height(Vector3(x,0,z)) if forest.visible else 0.675

func terrain_walkable(p: Vector3) -> bool:
	if navigation_state != null and navigation_state.location == "villa":
		if navigation_state.home_floor==1 and (Villa.Dimensions.BALCONY_RECT.has_point(Vector2(p.x,p.z)) or Rect2(Villa.Dimensions.BALCONY_DOOR_X-Villa.Dimensions.BALCONY_DOOR_WIDTH*.5,17.4,Villa.Dimensions.BALCONY_DOOR_WIDTH,1.1).has_point(Vector2(p.x,p.z))):return true
		if p.x> -10.33 and p.x<=7.45 and p.z> -5.45 and p.z<17.65:return true
		if player.stair_active:return p.x>=6 and p.x<=13.3 and p.z>=Villa.Dimensions.STAIR_OPENING_NORTH+.1 and p.z<=3.7
		if p.x>7.45 and p.x<14 and p.z> -5.45 and p.z<17.65:
			return p.z>=2.1 or p.z<=Villa.Dimensions.STAIR_OPENING_NORTH or p.x>=13.85
		return false
	if forest.visible and p.x >= 1.5 and p.x <= 3.7 and p.z >= 14.6 and p.z <= 15.8: return true
	if forest.visible and p.x >= -2.55 and p.x <= 2.55 and p.z >= 13.45 and p.z <= 17.55: return true
	if forest.visible and p.x >= -.25 and p.x <= 3.65 and p.z >= 5 and p.z <= 18.7: return true
	if forest.visible and exploration!=null and exploration.standable(p):return true
	# 木桥面本身是可行走的，桥外仍按地形判定。
	if bridges!=null and is_finite(bridges.height_at(p)):return true
	return forest.walkable(p) if forest.visible else Vector2(p.x, p.z).length() <= 6.35

func _sync_indoor_visibility() -> void:
	var indoor:bool=navigation_state!=null and navigation_state.location=="villa"
	var balcony_now:bool=on_balcony()
	for surface:Node3D in outside_surfaces:surface.visible=true
	if balcony_now!=balcony_view_active:
		balcony_view_active=balcony_now
		if orbit.stable_third_person:
			if balcony_now:orbit.begin_activity_view("balcony",player.position+Vector3.UP*1.2,.65,7.0,deg_to_rad(16))
			else:orbit.end_activity_view("balcony")
			orbit.room_key="";orbit.pivot=Vector3.INF
	elif balcony_now and orbit.stable_third_person and orbit.activity_key=="balcony":orbit.activity_point=player.position+Vector3.UP*1.2
	# Exterior geometry remains hidden; the existing indoor solid background
	# fills cutaway edges instead of showing the outdoor sky or island.
	var render_mask:int=(1048575&~256) if orbit.first_person else 1048575
	if camera.cull_mask!=render_mask:camera.cull_mask=render_mask
	if indoor:
		var envelope:Node3D=props.get_node_or_null("VillaInteriorEnvelope")
		if envelope!=null:envelope.set_upper_visible(true)
		for i in range(villa_rooms.size()):
			villa_rooms[i].visible=true

func _present_indoor_view() -> void:
	if navigation_state==null or navigation_state.location!="villa":return
	if orbit.comfort_mode:indoor_camera.last=camera.position-orbit.pan_offset
	# Enclosed rooms retain all architectural surfaces in every camera pose.
	for room:Node3D in villa_rooms:
		room.visible=true
		var floor_mesh:Node3D=room.get_node_or_null("InteriorFloor")
		if floor_mesh!=null:floor_mesh.visible=true
	var shell:Node3D=props.get_node_or_null("VillaInteriorEnvelope")
	if shell!=null:shell.set_upper_visible(true)
	var stairs:Node3D=props.get_node_or_null("ContinuousVillaStairwell")
	if stairs!=null:
		for mesh:MeshInstance3D in stairs.sight_surfaces:mesh.visible=true

func _blocks_actor(mesh:MeshInstance3D,margin:float=.06) -> bool:
	var inverse:Transform3D=mesh.global_transform.affine_inverse()
	var bounds:AABB=mesh.get_aabb().grow(margin)
	return bounds.intersects_segment(inverse*camera.global_position,inverse*(player.position+Vector3.UP*1.1)) or bounds.intersects_segment(inverse*camera.global_position,inverse*(player.position+Vector3.UP*1.9))

func _process(delta: float) -> void:
	if player == null: return
	_sync_indoor_visibility()
	if orbit.first_person or orbit.stable_third_person:
		if is_instance_valid(fishing_sign):fishing_sign.visible=false
		if is_instance_valid(boat_status_label):boat_status_label.visible=false
		rain.position=player.position+Vector3(0,8,0);forest.active=player.allowed
		return
	orbit.minimum_elevation=deg_to_rad(5 if navigation_state!=null and navigation_state.location=="villa" else 15)
	walk_camera.tick(self,delta)
	if navigation_state != null and navigation_state.location == "villa": orbit.target_pitch = clampf(orbit.target_pitch,deg_to_rad(5 if orbit.comfort_mode else 30),deg_to_rad(20 if orbit.comfort_mode else 55))
	if navigation_state!=null and navigation_state.location=="villa":
		orbit.distance=clampf(orbit.distance,4.8,indoor_camera.FOLLOW_DISTANCE)
		if orbit.target_distance>0:orbit.target_distance=clampf(orbit.target_distance,4.8,indoor_camera.FOLLOW_DISTANCE)
		if player.allowed:home_camera.tick(delta)
		camera.fov=indoor_camera.lens(self) if orbit.comfort_mode else lerpf(home_camera.fov,70,indoor_camera.stair_weight)
	orbit.pan_limit=1.2 if navigation_state!=null and navigation_state.location=="villa" else (6 if player.boating else 4)
	orbit.pan_bounds=Rect2(-10,-5.1,23.5,22.4) if navigation_state!=null and navigation_state.location=="villa" else (Rect2(-7,-7,14,14) if navigation_state!=null and navigation_state.location in ["town","city"] else Rect2(-80,-80,160,160))
	var ahead := 0.0
	if not player.fishing_stage.is_empty():
		ahead=1.5 if player.fishing_stage in ["net_ready","landing","storing","result"] else (3.5 if player.fishing_stage in ["standing","hooking","reeling"] else 6.0)
	if orbit.comfort_mode and not player.fishing_stage.is_empty():ahead=10.5
	var focus_height:float=1.45 if player.fishing_stage in ["net_ready","landing","storing","result"] else 1.0
	if orbit.comfort_mode:focus_height=1.45
	var subject:Vector3=player.position+Vector3(0,focus_height,ahead)
	if not orbit.comfort_mode and navigation_state!=null and navigation_state.location=="villa" and player.pose_skeleton!=null and player.bed_stage!="":
		var skeleton:Skeleton3D=player.pose_skeleton
		subject=skeleton.global_transform*((skeleton.get_bone_global_pose(player._bone("Head")).origin+skeleton.get_bone_global_pose(player._bone("Hips")).origin)*.5)+Vector3.UP*.15
	if player.stair_active:subject=player.position+Vector3.UP*(1.45 if orbit.comfort_mode else 1.25)
	elif navigation_state!=null and navigation_state.location=="villa":
		if home_camera.owner_key!="" and not orbit.comfort_mode:subject=home_camera.subject
		else:
			var lead:Vector3=player.velocity;lead.y=0
			if not orbit.comfort_mode:subject+=lead.limit_length()*.6
	if orbit.comfort_mode and orbit.motion_enabled:
		if player.stair_active:orbit.focus.y=subject.y
		var offset:Vector3=subject-orbit.focus
		var deadzone:float=.25
		if offset.length()>deadzone:orbit.focus+=offset.normalized()*(offset.length()-deadzone)*(1-exp(-4*minf(delta,.05)))
	elif not orbit.comfort_mode:orbit.focus = orbit.focus.lerp(subject, 1 - exp(-(8 if player.stair_active else 4) * delta))
	rain.position = player.position + Vector3(0, 8, 0)
	forest.active = player.allowed
	if is_instance_valid(fishing_sign): fishing_sign.visible = forest.visible and not player.boating and player.position.distance_to(fishing_sign.position)<4
	if is_instance_valid(boat_status_label): boat_status_label.visible = forest.visible and not player.boating and player.position.distance_to(MOORING) < 10
	if forest.visible: forest.reveal_player(camera.global_position, orbit.view_focus if orbit.pan_offset.length()>.15 else player.position + Vector3.UP)

func island_ground_height(p:Vector3) -> float:
	var height:float=forest.height_at(p.x,p.z)
	if exploration!=null:height=maxf(height,exploration.land_height(p))
	# 岛上木桥：只在玩家步行时算进地面，划船时不算，免得桥面挡住船只通行。
	if bridges!=null and player!=null and not player.boating:height=maxf(height,bridges.height_at(p))
	return height

func navigation_view_landmark() -> Vector3:
	return exploration.view_landmark(player.position) if exploration!=null else Villa.ENTRY

func navigable_water(p: Vector3) -> bool:
	if Vector2(p.x,p.z).length()>600:return false
	for offset:Vector2 in [Vector2.ZERO,Vector2(.7,0),Vector2(-.7,0),Vector2(0,1),Vector2(0,-1)]:
		if island_ground_height(p+Vector3(offset.x,0,offset.y))>-.6:return false
	return true

# 停船位只要船体不吃进海底即可；比航行水域的 0.6m 吃水线更浅，
# 否则每座岛的泊位都被推到离岸好几米的深水处，玩家够不到也靠不了岸。
func berth_water(p: Vector3) -> bool:
	if Vector2(p.x,p.z).length()>600:return false
	for offset:Vector2 in [Vector2.ZERO,Vector2(.5,0),Vector2(-.5,0),Vector2(0,.5),Vector2(0,-.5)]:
		if island_ground_height(p+Vector3(offset.x,0,offset.y))>-.55:return false
	return true

func board_boat(state: RefCounted) -> bool:
	if state.location != "island" or player.boating: return false
	if not state.island_visit.is_empty():return exploration.return_to_boat()
	if Vector2(player.position.x - DOCK.x, player.position.z - DOCK.z).length() > BOARD_RADIUS: return state.say("先走到营地南侧木码头。")
	var reason := boarding_block_reason(state)
	if not reason.is_empty(): return state.say(reason)
	_set_boating(true)
	player.position = MOORING
	state.log_event("已上船：摇杆划船，按住奔跑加速；驶回码头靠岸。向南航行到浮标，可前往青湾镇。")
	return true

func disembark_boat() -> bool:
	if not player.boating or Vector2(player.position.x - MOORING.x, player.position.z - MOORING.z).length() > 1.85 or player.velocity.length()>.55: return false
	navigation_state.island_visit={}
	_set_boating(false)
	player.position = DOCK
	exploration.activate(null);exploration.position_parked_boat(navigation_state)
	return true

func _set_boating(value: bool) -> void:
	if not value and player.rowing_pose!=null:player.rowing_pose.finish();player.rowing_pose=null
	if not value: return_pilot.cancel()
	if value: player.end_fishing()
	player.boating = value
	orbit.clear_observation(true)
	orbit.keep_subject = value
	orbit.observing_sun = false
	player.velocity = Vector3.ZERO
	player.collision_mask = 5 if value else 1
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if value else CharacterBody3D.MOTION_MODE_GROUNDED
	for collider: CollisionShape3D in player.walking_shapes: collider.disabled=value
	player.hull_collider.disabled=not value
	if value:
		player.boat_heading=0
		player.hull_collider.rotation.y=0
	if value and player.boat_visual == null:
		var packed := load("res://assets/polyfork/rowboat-c42d85.glb") as PackedScene
		player.boat_visual = packed.instantiate()
		player.boat_visual.scale = Vector3.ONE * 1.1
		player.boat_visual.position.y = -0.3
		player.add_child(player.boat_visual)
		_apply_vertex_colors(player.boat_visual)
	if value and player.rowing_pose==null:
		player.rowing_pose=preload("res://scripts/life/rowing_pose.gd").new();player.rowing_pose.begin(player)
	if player.boat_visual != null: player.boat_visual.visible = value
	if is_instance_valid(own_boat): own_boat.visible = not value

func save_position() -> Vector3:
	# Save a safe berth while at sea, so reopening never spawns a walking actor underwater.
	if player.exercise_return.is_finite():return player.exercise_return
	if player.stair_active:return stair_origin
	if player.bed_stage!="":return player.bed_return
	if player.boating:return exploration.vector(navigation_state.island_visit.landing) if not navigation_state.island_visit.is_empty() else DOCK
	return player.sofa_return if player.sofa_seated else (player.fishing_return if not player.fishing_stage.is_empty() else player.position)

static func solar_direction(hour: float, season_index: int) -> Vector3:
	var rise: float = [6.0, 5.0, 6.0, 7.0][season_index]
	var setting: float = [18.0, 20.0, 18.0, 17.0][season_index]
	var angle: float
	if hour >= rise and hour <= setting: angle = (hour - rise) / (setting - rise) * PI
	else:
		var night_hour := hour + 24 if hour < rise else hour
		angle = PI + (night_hour - setting) / (24 - setting + rise) * PI
	var altitude: float = [0.9, 1.15, 0.9, 0.6][season_index]
	return Vector3(cos(angle), sin(angle) * altitude, -sin(angle) * 0.35).normalized()

func _sync_profile(state: RefCounted) -> void:
	player.cancel_stairs()
	if player.home_cancel.is_valid():player.home_cancel.call()
	player.cancel_bed()
	player.end_fishing()
	player.leave_sofa()
	if player.visual != null:
		player.cancel_work()
		if not player.pet_stage.is_empty(): player.cancel_pet()
		if player.animator != null:
			player.animator.stop()
			player.animator.clear_caches()
		clear_visual_materials(player.visual)
		player.remove_child(player.visual)
		player.visual.queue_free()
	var visual := character_model(preload("res://scripts/life/character_catalog.gd").from_profile(state.profile))
	visual.scale*=PLAYABLE_CHARACTER_SCALE
	visual.name = "SurvivorVisual"
	player.add_child(visual)
	player.bind_visual(visual)
	if companion != null:
		if companion.animation != null:
			companion.animation.stop()
			companion.animation.clear_caches()
		clear_visual_materials(companion)
		remove_child(companion)
		companion.queue_free()
		companion = null
	if state.profile.pet != "none":
		if state.profile.pet in preload("res://scripts/life/companion_catalog.gd").FLOATING:
			companion = preload("res://scripts/life/floating_companion.gd").new()
		else:
			companion = preload("res://scripts/life/companion.gd").new()
		add_child(companion)
		companion.setup(self, state.profile.pet)
		companion.recover()
	last_profile = str(state.profile)

## 所有人物共用标准化骨架，使用原包四套皮肤，预览和游戏采用同一目录。
func character_model(character_id: String) -> Node3D:
	return preload("res://scripts/life/character_catalog.gd").make(character_id)

func pet_companion(state: RefCounted) -> bool:
	if companion == null or player.boating or companion.position.distance_to(player.position) > 2.5: return false
	var facing := player.position - companion.position
	companion.face(atan2(facing.x, facing.z))
	if not player.begin_pet(companion): return false
	companion.petting = 6.0
	state.log_event("你轻轻摸了摸%s，它开心地陪在你身边。" % state.profile.pet_name)
	return true

func clear_visual_materials(visual: Node) -> void:
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = null
		if mesh.mesh != null:
			for surface in range(mesh.mesh.get_surface_count()): mesh.set_surface_override_material(surface, null)

func boarding_block_reason(state: RefCounted) -> String:
	if state.weather() in ["雷雨", "大风"]: return "风浪大，暂时无法上船出海，请等天气转好。"
	if state.hunger < 20 or state.thirst < 20: return "先吃饭喝水，再上船出海。"
	return ""

func transition_in_range(kind:String) -> bool:
	if navigation_state==null or navigation_state.location!="island" or player.boating or not terrain_walkable(player.position):return false
	if kind=="boat":return Vector2(player.position.x-DOCK.x,player.position.z-DOCK.z).length()<=BOARD_RADIUS
	if kind=="villa_entry":
		var gap:=Vector2(player.position.x-Villa.ENTRY.x,player.position.z-Villa.ENTRY.z)
		return gap.length()<=1.8 and absf(gap.x)<=1.3 and gap.y>=-.15
	return false

func enter_villa(state: RefCounted) -> bool:
	if state.location != "island" or player.boating: return state.say("先靠岸回到岛上，再回家。")
	if Vector2(player.position.x - Villa.ENTRY.x,player.position.z - Villa.ENTRY.z).length() > 2: return state.say("先走到别墅门廊，或在任务中选择回家。")
	player.move_input=Vector2.ZERO;player.manual_world_direction=Vector3.INF;player.velocity=Vector3.ZERO
	player.visual.rotation.y=PI
	state.location = "villa"
	state.home_floor = 0
	state.player_position = [Villa.INSIDE_SPAWN.x,Villa.INSIDE_SPAWN.y,Villa.INSIDE_SPAWN.z]
	sync(state)
	state.log_event("欢迎回家。一楼有客厅、厨房餐厅和书房，沿楼梯可去二楼卧室与浴室。")
	return true

func leave_villa(state: RefCounted) -> bool:
	if state.location != "villa" or player.stair_active: return false
	player.cancel_bed()
	state.location = "island"
	state.home_floor = 0
	state.player_position = [Villa.OUTSIDE_SPAWN.x,Villa.OUTSIDE_SPAWN.y,Villa.OUTSIDE_SPAWN.z]
	sync(state)
	if orbit.stable_third_person and not orbit.first_person:orbit.prepare_house_exit()
	state.log_event("走出别墅，回到自己的小岛。")
	return true

func on_balcony() -> bool:
	return navigation_state!=null and navigation_state.location=="villa" and navigation_state.home_floor==1 and player!=null and Villa.Dimensions.BALCONY_RECT.has_point(Vector2(player.position.x,player.position.z))
func visit_balcony(state:RefCounted) -> bool:
	if state.location!="villa" or state.home_floor!=1:return state.say("请先到二楼的阳台门旁。")
	player.position=Vector3(3.2,Villa.Dimensions.UPPER_FLOOR+.03,20.2);player.velocity=Vector3.ZERO
	state.player_position=[player.position.x,player.position.y,player.position.z];sync(state)
	state.log_event("来到阳台，可以走动看海；门旁可返回二楼。")
	return true
func return_from_balcony(state:RefCounted) -> bool:
	if not on_balcony():return false
	player.position=Vector3(3.2,Villa.Dimensions.UPPER_FLOOR+.03,16.9);player.velocity=Vector3.ZERO
	state.player_position=[player.position.x,player.position.y,player.position.z];sync(state)
	state.log_event("回到二楼。")
	return true

func try_walk_exit(state:RefCounted,direction:Vector3) -> bool:
	if state.location!="villa":return false
	if state.home_floor==1:
		if player.home_busy or player.sofa_seated or player.bed_stage!="" or player.stair_active:return false
		var right:Vector3=walk_camera.input_right;var forward:Vector3=walk_camera.input_forward;var active:bool=walk_camera.input_active
		var crossed:=false
		if not on_balcony() and absf(player.position.x-3.2)<Villa.Dimensions.BALCONY_DOOR_WIDTH*.5-.3 and player.position.z>17 and direction.z>.35:crossed=visit_balcony(state)
		elif on_balcony() and absf(player.position.x-3.2)<Villa.Dimensions.BALCONY_DOOR_WIDTH*.5-.3 and player.position.z<19.2 and direction.z<-.35:crossed=return_from_balcony(state)
		if crossed and active:walk_camera.input_active=true;walk_camera.input_revision=orbit.manual_revision;walk_camera.input_right=right;walk_camera.input_forward=forward
		return crossed
	if direction.z<.35:return false
	if player.home_busy or player.sofa_seated or player.bed_stage!="" or player.stair_active:return false
	if absf(player.position.x)>.85 or player.position.z<16.7:return false
	var was_active:bool=walk_camera.input_active
	var right:Vector3=walk_camera.input_right;var forward:Vector3=walk_camera.input_forward
	var exited:bool=leave_villa(state)
	if exited and was_active:
		# Keep the world direction of the held gesture across the room/camera change.
		walk_camera.input_active=true;walk_camera.input_revision=orbit.manual_revision
		walk_camera.input_right=right;walk_camera.input_forward=forward
	return exited

func try_manual_stairs(direction:Vector3) -> bool:
	if navigation_state==null or navigation_state.location!="villa":return false
	return false

func change_home_floor(state: RefCounted,manual:bool=false) -> bool:
	if manual or state.location!="villa" or player.stair_active or player.bed_stage!="" or player.sofa_seated:return false
	var entry: Vector3 = Villa.STAIR_ENTRY+Vector3.UP*(state.home_floor*Villa.Dimensions.RISE)
	if not preload("res://scripts/life/villa_stairwell.gd").can_enter(player.position,state.home_floor):return state.say("先走到楼梯口，再上下楼。")
	var route:Array[Vector3]=preload("res://scripts/life/villa_stairwell.gd").route(state.home_floor==0)
	# Connect directly to the flight mouth; never return to the interaction ring.
	var join:Vector3=route[2]
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=CylinderShape3D.new();shape.radius=player.BODY_RADIUS+.02;shape.height=1.6;query.shape=shape;query.collision_mask=1
	var excludes:Array[RID]=[player.get_rid()]
	if companion!=null:excludes.append(companion.get_rid())
	query.exclude=excludes
	query.transform.origin=player.position+Vector3.UP*.85;query.motion=Vector3(join.x-player.position.x,0,join.z-player.position.z)
	var hit:PackedFloat32Array=get_world_3d().direct_space_state.cast_motion(query)
	var direct:bool=hit.size()==0 or hit[0]>.99
	var approach:Array[Vector3]=[player.position]
	if not direct and absf(player.position.z-3)>.1:approach.append(Vector3(player.position.x,entry.y,3))
	var on_flight:bool=absf(player.position.x-join.x)<.8 and player.position.z<2.9
	approach.append_array(route.slice(3 if on_flight else 2));route=approach
	stair_origin=player.position;stair_target_floor=1-state.home_floor
	state.say("正在上楼，前往二楼卧室。" if stair_target_floor==1 else "正在下楼，前往一楼客厅。")
	orbit.clear_observation();orbit.view_transition=.6
	if companion!=null:
		companion.hide();companion.collision_layer=0;companion.set_physics_process(false)
	player.start_stairs(route,func(completed: bool):
		if completed:
			state.home_floor=stair_target_floor
			sync(state)
		_sync_indoor_visibility()
		if companion!=null:companion.set_physics_process(true);companion.recover()
		state.log_event(("沿楼梯来到%s。"%("二楼卧室" if state.home_floor==1 else "一楼客厅")) if completed else ("回到原楼层。" if player.stair_manual else "楼梯被挡住了，已回到安全平台，请稍后重试。")),manual)
	_sync_indoor_visibility()
	return true

func set_home_tv(value: bool) -> void:
	home_tv_on = value
	for point:Dictionary in interaction_points:
		if point.kind=="villa_tv":point.title="关闭电视" if value else "打开电视"
	if is_instance_valid(villa_room): villa_room.set_tv(value)

var tree_clearance_shape: CylinderShape3D
func safe_tree_motion(pos: Vector3, motion: Vector3) -> Vector3:
	if navigation_state!=null and navigation_state.location=="villa" and not player.stair_active:
		var gate_query:=PhysicsShapeQueryParameters3D.new();var gate_shape:=CylinderShape3D.new();gate_shape.radius=player.BODY_RADIUS;gate_shape.height=1.6
		gate_query.shape=gate_shape;gate_query.collision_mask=32;gate_query.transform.origin=pos+Vector3.UP*.85;gate_query.motion=Vector3(motion.x,0,motion.z)
		var gate_hit:PackedFloat32Array=get_world_3d().direct_space_state.cast_motion(gate_query)
		if gate_hit.size()>0 and gate_hit[0]<1:
			var fraction:float=maxf(0,gate_hit[0]-.01);return Vector3(motion.x*fraction,motion.y,motion.z*fraction)
		return motion
	if navigation_state==null or navigation_state.location!="island" or motion.length_squared()<.000001: return motion
	var query := PhysicsShapeQueryParameters3D.new()
	if tree_clearance_shape==null:
		tree_clearance_shape=CylinderShape3D.new()
		tree_clearance_shape.radius=player.TREE_RADIUS;tree_clearance_shape.height=player.TREE_HEIGHT
	query.shape=tree_clearance_shape;query.collision_mask=8;query.margin=.025
	query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*(player.TREE_HEIGHT*.5+.02))
	var space := get_world_3d().direct_space_state
	query.motion=motion
	var fractions := space.cast_motion(query)
	if fractions[0]>=1: return motion
	var safe := motion*maxf(0,fractions[0]-.015/maxf(motion.length(),.001))
	query.transform.origin+=motion*minf(1,fractions[1]+.01)
	query.motion=Vector3.ZERO
	var hit := space.get_rest_info(query)
	if hit.is_empty(): return safe
	var normal: Vector3=hit.normal;normal.y=0
	if normal.length_squared()<.01: return safe
	var slide := (motion-safe).slide(normal.normalized())
	query.transform.origin=pos+safe+Vector3.UP*(player.TREE_HEIGHT*.5+.02)
	query.motion=slide
	var lateral := space.cast_motion(query)
	return safe+slide*maxf(0,lateral[0]-.015/maxf(slide.length(),.001))

func boat_heading_is_clear(pos: Vector3, heading: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=player.hull_collider.shape
	query.transform=Transform3D(Basis(Vector3.UP,heading),pos)
	query.collision_mask=5
	query.exclude=[player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func safe_observation_position(origin:Vector3,desired:Vector3,delta:float) -> Vector3:
	orbit.observation_blocked=false
	var query:=PhysicsShapeQueryParameters3D.new()
	var sphere:=SphereShape3D.new();sphere.radius=indoor_camera.clearance_radius(self) if navigation_state!=null and navigation_state.location=="villa" else .3;query.shape=sphere
	query.collision_mask=81
	if player!=null:query.exclude=[player.get_rid()]
	var space:PhysicsDirectSpaceState3D=get_world_3d().direct_space_state
	query.transform=Transform3D(Basis.IDENTITY,origin)
	if not space.intersect_shape(query,1).is_empty():return Vector3.INF
	var motion:Vector3=(desired-origin).limit_length(orbit.PAN_SPEED*delta)
	query.motion=motion
	var hit:PackedFloat32Array=space.cast_motion(query)
	var fraction:float=hit[0] if hit.size()>0 else 1.0
	if fraction<.1 and motion.length_squared()>.000001:
		# A sweep starting at a contact can report zero even when moving away.
		# Require both an empty endpoint and an outward contact normal.
		query.motion=Vector3.ZERO;query.transform.origin=origin+motion
		var endpoint_clear:bool=space.intersect_shape(query,1).is_empty()
		query.transform.origin=origin;sphere.radius+=.04
		var contact:Dictionary=space.get_rest_info(query)
		if endpoint_clear and not contact.is_empty() and motion.dot(contact.normal)>.0001:fraction=1.0
	orbit.observation_blocked=fraction<.9999
	if orbit.observation_blocked:fraction=maxf(0,fraction-.02/maxf(motion.length(),.02))
	return origin+motion*fraction

func safe_camera_position(focus: Vector3, desired: Vector3) -> Vector3:
	if navigation_state!=null and navigation_state.location=="villa": return indoor_camera.resolve(self,focus,desired)
	var floor_y: float = terrain_height(desired.x,desired.z)
	desired.y=maxf(desired.y,maxf(.8,floor_y+.6 if is_finite(floor_y) else .8))
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new();shape.radius=.3
	query.shape=shape;query.collision_mask=65
	if player!=null:query.exclude=[player.get_rid()]
	# A single focus-based origin avoids switching cast origins at pan thresholds.
	var start := focus
	var ground: float=terrain_height(focus.x,focus.z)
	start.y=maxf(focus.y,maxf(.9,ground+1.05 if is_finite(ground) else .9))
	var space := get_world_3d().direct_space_state
	query.transform=Transform3D(Basis.IDENTITY,start)
	# An observation focus can enter a tree/roof. Find clear air instead of
	# treating an initially overlapping cast as an unobstructed full-length view.
	for i in range(16):
		if space.intersect_shape(query,1).is_empty():break
		start.y+=.5;query.transform.origin=start
	query.motion=desired-start
	var fraction := 1.0
	if space.intersect_shape(query,1).is_empty():
		var fractions := space.cast_motion(query)
		if fractions.size()>0:fraction=maxf(.005,fractions[0]-.015) if fractions[0]<1 else 1.0
	else:fraction=minf(camera_clearance,.15)
	var dt := clampf(orbit.frame_delta if orbit.comfort_mode else get_process_delta_time(),1.0/120,.05)
	if not camera_last_focus.is_finite() or camera_last_focus.distance_to(focus)>5:
		camera_clearance=fraction;camera_clear_hold=.25
	elif fraction<camera_clearance:
		camera_clearance=fraction;camera_clear_hold=.25
	else:
		camera_clear_hold=maxf(0,camera_clear_hold-dt)
		if camera_clear_hold<=0:camera_clearance=lerpf(camera_clearance,fraction,1-exp(-3.5*dt))
	camera_last_focus=focus
	desired=start.lerp(desired,camera_clearance)
	if orbit.comfort_mode and not orbit.motion_reset:
		# Sweep from the actual camera so obstacle retraction cannot teleport it.
		var previous:Vector3=camera.position
		query.transform=Transform3D(Basis.IDENTITY,previous);query.motion=Vector3.ZERO
		if space.intersect_shape(query,1).is_empty():
			var motion:Vector3=(desired-previous).limit_length(8.0*dt)
			query.motion=motion
			var hit:PackedFloat32Array=space.cast_motion(query)
			desired=previous+motion*(maxf(0,hit[0]-.002) if hit.size()>0 else 1.0)
	floor_y=terrain_height(desired.x,desired.z)
	desired.y=maxf(desired.y,maxf(.8,floor_y+.5 if is_finite(floor_y) else .8))
	return desired
func look_at_sun(state: RefCounted) -> bool:
	if state.location=="villa":return state.say("走到室外再看天空。")
	var direction:=solar_direction(state.hour(),state.season())
	if direction.y<0:return state.say("太阳已经落山，明早会从东方升起。")
	orbit.begin_sun_view()
	orbit.view_transition=.75
	orbit.target_yaw=atan2(-direction.x,-direction.z)
	orbit.observing_sun=true
	orbit.target_pitch=clampf(-asin(direction.y),orbit.MIN_PITCH,orbit.MAX_PITCH)
	return true

func _recover_tree_spawn(state: RefCounted) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new();shape.radius=player.TREE_RADIUS;shape.height=player.TREE_HEIGHT
	query.shape=shape;query.collision_mask=8
	query.transform=Transform3D(Basis.IDENTITY,player.position+Vector3.UP*(player.TREE_HEIGHT*.5+.02))
	var space := get_world_3d().direct_space_state
	var trees: Array=forest.trees.duplicate()
	for body: StaticBody3D in props.find_children("TreeObstacle","StaticBody3D",true,false):trees.append(body.get_parent())
	var embedded := not space.intersect_shape(query,1).is_empty()
	for tree: Node3D in trees:
		if Vector2(player.position.x-tree.position.x,player.position.z-tree.position.z).length()<float(tree.get_meta("root_radius",0))+player.TREE_RADIUS:embedded=true
	if not embedded:return
	var saved := player.position
	for ring in range(1,9):
		for step in range(24):
			var angle := step*TAU/24
			var candidate := saved+Vector3(sin(angle),0,cos(angle))*(ring*.45)
			if not terrain_walkable(candidate):continue
			var roots_clear := true
			for tree: Node3D in trees:
				if Vector2(candidate.x-tree.position.x,candidate.z-tree.position.z).length()<float(tree.get_meta("root_radius",0))+player.TREE_RADIUS+.04:roots_clear=false;break
			if not roots_clear:continue
			candidate.y=terrain_height(candidate.x,candidate.z)+.03
			query.transform.origin=candidate+Vector3.UP*(player.TREE_HEIGHT*.5+.02)
			if not space.intersect_shape(query,1).is_empty():continue
			player.position=candidate
			player.velocity=Vector3.ZERO
			state.log_event("已将人物移到树根外的安全位置，原有物资保留。")
			return
	player.position=Vector3(0,.705,3.2)
	player.velocity=Vector3.ZERO
	state.log_event("已从拥挤树林回到营地安全位置，原有物资保留。")
