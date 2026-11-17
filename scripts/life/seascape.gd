extends Node3D
var world: Node3D
var far_material: ShaderMaterial
var solar_disc: MeshInstance3D
var solar_material: StandardMaterial3D
var depth_texture: ImageTexture
var islands:Array[Node3D]=[]
func setup(owner_world: Node3D) -> void:
	world=owner_world
	name="OpenSeaAndSky"
	far_material=ShaderMaterial.new()
	far_material.shader=preload("res://shaders/distant_ocean.gdshader")
	for data: Array in [[Vector3(0,-.27,-2084),Vector2(8192,4024)],[Vector3(0,-.27,2084),Vector2(8192,4024)],[Vector3(-2084,-.27,0),Vector2(4024,144)],[Vector3(2084,-.27,0),Vector2(4024,144)]]:
		var surface := PlaneMesh.new()
		surface.size=data[1]
		var ocean := MeshInstance3D.new()
		ocean.name="DistantOcean%d"%get_child_count()
		ocean.mesh=surface;ocean.position=data[0];ocean.material_override=far_material
		ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ocean)
	var depth := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for x in range(128):
		for z in range(128):
			var h: float=world.forest.height_at(x-63.5,z-63.5)
			var value := clampf((-.25-h)/4.0,0,1) if is_finite(h) else 1.0
			depth.set_pixel(x,z,Color(value,value,value,1))
	depth_texture=ImageTexture.create_from_image(depth)
	world.water_shader.set_shader_parameter("shore_depth",depth_texture)
	for spec:Dictionary in [
		{"id":"twin_hills","kind":"hills","at":Vector3(190,0,170),"radii":Vector2(36,28),"height":12.0,"trees":34,"seed":8131,"yaw":.3},
		{"id":"crescent_bay","kind":"bay","at":Vector3(-230,0,160),"radii":Vector2(54,38),"height":11.0,"trees":58,"seed":9274,"yaw":-.5},
		{"id":"rocky_reef","kind":"reef","at":Vector3(270,0,-190),"radii":Vector2(23,17),"height":7.0,"trees":14,"seed":10333,"yaw":.8},
		{"id":"forest_cape","kind":"cape","at":Vector3(-290,0,-210),"radii":Vector2(70,29),"height":18.0,"trees":80,"seed":11591,"yaw":1.1}]:
		var island=preload("res://scripts/life/distant_island.gd").new();add_child(island);island.setup(world,spec);islands.append(island)
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var radius := Vector2((x-31.5)/31.5,(y-31.5)/31.5).length()
			image.set_pixel(x,y,Color(1,1,1,1-smoothstep(.7,1,radius)))
	solar_material=StandardMaterial3D.new()
	solar_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	solar_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	solar_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	solar_material.set_flag(BaseMaterial3D.FLAG_DISABLE_FOG,true)
	solar_material.albedo_texture=ImageTexture.create_from_image(image)
	solar_disc=MeshInstance3D.new()
	solar_disc.name="VisibleSolarDisc"
	var disc := QuadMesh.new();disc.size=Vector2(14,14)
	solar_disc.mesh=disc;solar_disc.material_override=solar_material
	solar_disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(solar_disc)
func sync(state: RefCounted) -> void:
	var solar: Vector3=world.solar_direction(state.hour(),state.season())
	var color: Color=world.sea.albedo_color.linear_to_srgb()
	var level: float=.16+state.daylight()*.84
	world.water_shader.set_shader_parameter("shore_depth_enabled",state.location=="island")
	for mat: ShaderMaterial in [world.water_shader,far_material]:
		mat.set_shader_parameter("water_color",color)
		mat.set_shader_parameter("solar_direction",solar)
		mat.set_shader_parameter("sun_color",world.sun.light_color)
		mat.set_shader_parameter("light_level",level)
	for mat:ShaderMaterial in [world.water_shader,far_material]:mat.set_shader_parameter("horizon_color",world.sky_material.sky_horizon_color)
	solar_material.albedo_color=world.sun.light_color
	solar_disc.visible=solar.y>-.015
func _process(_delta: float) -> void:
	if world==null or world.navigation_state==null:return
	var solar: Vector3=world.solar_direction(world.navigation_state.hour(),world.navigation_state.season())
	solar_disc.position=world.camera.position+solar*450
