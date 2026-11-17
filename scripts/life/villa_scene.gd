extends Node3D
## Original modular architecture, furnished with credited Polyfork models.
const Dimensions=preload("res://scripts/life/villa_dimensions.gd")
const STAIR_ENTRY := Vector3(6,0.705,2.0)
const BED_CENTER := Vector3(-4.8,0.7,-4.05)
const BED_STAND := Vector3(-3,0.705,-1.45)
const BED_ANCHOR := Vector3(-4.8,1.389+Dimensions.RISE,-2.9)
const SOFA_STAND := Vector3(-4.2,0.705,3.6)
const SOFA_SEAT := Vector3(-3.225,0.705,2.5)
const SOFA_FACING := -PI/2
const COFFEE_CENTER := Vector3(-6,1.0,2.5)
const DINING_CENTER := Vector3(1.6,0.7,11.0)
const ENTRY := Vector3(11, 1.34, 0.7)
const OUTSIDE_SPAWN := Vector3(11, 1.4, 2.2)
const INSIDE_SPAWN := Vector3(0, 0.705, 16.5)
var world: Node3D
var points: Array[Dictionary] = []
var palette: Dictionary = {}
var high_wall: MeshInstance3D
var wall_faded := false
var tv_screen: MeshInstance3D
func setup(owner_world: Node3D) -> void:
	world = owner_world
	for spec: Array in [["plaster","e9e4ce"],["teak","946e4c"],["dark","36515a"],["roof","426b6c"],["glass","82bdc8"],["floor","c4a77c"],["cream","f4e9cb"],["rug","578b87"],["metal","4f5b5d"],["green","5d8055"]]:
		palette[spec[0]] = world.material(Color(spec[1]))
func block(pos: Vector3, dimensions: Vector3, key: String, solid: bool = false) -> MeshInstance3D:
	var mesh: MeshInstance3D = world.box(self,pos,dimensions,palette[key])
	if solid:
		var body := StaticBody3D.new()
		body.name="VillaSolid_%s"%str(pos)
		body.position = pos
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return mesh
func furniture(id: String, pos: Vector3, angle: float, factor: float, footprint: Vector2) -> Node3D:
	var node := (load("res://assets/polyfork/%s.glb" % id) as PackedScene).instantiate() as Node3D
	node.position = pos
	node.rotation.y = angle
	node.scale = Vector3.ONE * factor
	add_child(node)
	world._apply_vertex_colors(node)
	if footprint != Vector2.ZERO:
		preload("res://scripts/life/prop_collision.gd").convex(node)
	return node
func point(kind: String, title: String, pos: Vector3, radius: float = 1.5) -> void:
	points.append({"kind":kind,"title":title,"pos":to_global(pos),"range":radius,"owner":self})
func plant(pos: Vector3, factor: float = 1.0) -> void:
	block(pos+Vector3(0,0.2,0),Vector3(0.42,0.4,0.42)*factor,"cream")
	for side in [-1,0,1]:
		var leaf := block(pos+Vector3(side*0.13,0.55+abs(side)*0.08,0),Vector3(0.18,0.6,0.16)*factor,"green")
		leaf.rotation.z = -side*0.4
func lamp(pos: Vector3) -> void:
	block(pos+Vector3(0,0.7,0),Vector3(0.07,1.4,0.07),"metal")
	block(pos+Vector3(0,1.5,0),Vector3(0.55,0.35,0.55),"cream")
	var light := OmniLight3D.new()
	light.position = pos+Vector3(0,1.3,0)
	light.light_color = Color("ffdfaa")
	light.light_energy = 0.75
	light.omni_range = 5
	add_child(light)
func chair(pos: Vector3, angle: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = angle
	add_child(root)
	for x in [-0.22,0.22]:
		for z in [-0.22,0.22]: world.box(root,Vector3(x,0.25,z),Vector3(0.06,0.5,0.06),palette.teak)
	world.box(root,Vector3(0,0.54,0),Vector3(0.6,0.12,0.6),palette.cream)
	world.box(root,Vector3(0,0.9,-0.24),Vector3(0.6,0.65,0.08),palette.teak)
	preload("res://scripts/life/prop_collision.gd").convex(root)
	return root
func woven_floor_lamp(pos: Vector3) -> void:
	var root := Node3D.new();root.name="WovenFloorLamp";add_child(root);root.position=pos
	world.box(root,Vector3(0,.78,0),Vector3(.045,1.56,.045),palette.metal)
	var base := MeshInstance3D.new();var disc := CylinderMesh.new()
	disc.top_radius=.22;disc.bottom_radius=.22;disc.height=.04;disc.radial_segments=16
	base.mesh=disc;base.material_override=palette.metal;base.position.y=.02;root.add_child(base)
	var straw: StandardMaterial3D = world.material(Color("c9ac70"))
	var shade := MeshInstance3D.new();var cone := CylinderMesh.new()
	cone.top_radius=.2;cone.bottom_radius=.34;cone.height=.4;cone.radial_segments=24
	shade.mesh=cone;shade.material_override=straw;shade.position.y=1.56;root.add_child(shade)
	var ribs := MultiMeshInstance3D.new();var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	var slat := BoxMesh.new();slat.size=Vector3(.012,.425,.014);slat.material=palette.teak
	multi.mesh=slat;multi.instance_count=24
	for i in range(24):
		var angle := i*TAU/24
		var basis := Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,-atan2(.14,.4))
		multi.set_instance_transform(i,Transform3D(basis,Vector3(sin(angle)*.273,1.56,cos(angle)*.273)))
	ribs.multimesh=multi;root.add_child(ribs)
	var light := OmniLight3D.new();light.position.y=1.5;light.light_color=Color("ffdfaa")
	light.light_energy=.75;light.omni_range=5;root.add_child(light)
	preload("res://scripts/life/prop_collision.gd").convex(root)

func window_panel(pos: Vector3, dimensions: Vector3, angle: float = 0.0) -> void:
	var frame := Node3D.new()
	frame.position = pos
	frame.rotation.y = angle
	add_child(frame)
	world.box(frame,Vector3.ZERO,dimensions+Vector3(0.12,0.12,0.02),palette.dark)
	world.box(frame,Vector3(0,0,0.025),dimensions,palette.glass)
	world.box(frame,Vector3(0,0,0.05),Vector3(0.055,dimensions.y,0.03),palette.cream)
func exterior() -> void:
	name = "SeaviewVillaExterior"
	position = Vector3(11,1.34,-6)
	block(Vector3(0,-0.22,0.5),Vector3(14,0.45,13),"cream",true)
	block(Vector3(0,3.1,-.6),Vector3(12,6.2,8.8),"plaster",true)
	for x:float in [-3.8,3.8]:block(Vector3(x,3.1,4.4),Vector3(4.4,6.2,1.2),"plaster",true)
	block(Vector3(0,4.6,4.4),Vector3(3.2,3.2,1.2),"plaster",true)
	block(Vector3(0,3.15,0),Vector3(12.4,0.2,10.4),"cream")
	for x in [-4.2,0,4.2]:
		window_panel(Vector3(x,4.8,5.06),Vector3(2.8,2,0.08))
		if x != 0: window_panel(Vector3(x,1.65,5.06),Vector3(2.8,1.85,0.08))
	for side in [-1,1]:
		for height in [1.65,4.8]:
			for z in [-2.5,1.5]: window_panel(Vector3(side*6.07,height,z),Vector3(2.4,1.8,0.08),side*PI/2)
	for x in [-4.2,0.0,4.2]:
		for height in [1.65,4.8]: window_panel(Vector3(x,height,-5.07),Vector3(2.6,1.8,0.08),PI)
	window_panel(Vector3(0,6.65,5.08),Vector3(0.9,0.6,0.08))
	for x in [-1.4,1.4]:
		var porch_light := OmniLight3D.new()
		porch_light.position = Vector3(x,2.3,5.7)
		porch_light.light_color = Color("ffdfa0")
		porch_light.light_energy = 0.6
		porch_light.omni_range = 5
		add_child(porch_light)
	# A recessed entrance, balcony and asymmetrical timber bay give the facade depth.
	var entrance=preload("res://scripts/life/home_glass_door.gd").new();add_child(entrance);entrance.setup(self,Vector3(0,1.5,5.18),3.2)
	block(Vector3(0,2.9,5.8),Vector3(3.2,0.18,2),"dark")
	block(Vector3(0,3.2,5.75),Vector3(9,0.22,2),"teak")
	for x in [-4.3,4.3]: block(Vector3(x,1.5,6.1),Vector3(0.23,3,0.23),"cream")
	for x in range(-4,5): block(Vector3(x,3.85,6.6),Vector3(0.055,1.1,0.055),"dark")
	block(Vector3(0,4.4,6.6),Vector3(9,0.08,0.08),"teak")
	for side in [-1,1]:
		var roof := block(Vector3(side*3.2,6.7,0),Vector3(6.8,0.25,11.4),"roof")
		roof.rotation.z = -side * 0.22
	block(Vector3(0,7.45,0),Vector3(0.22,0.2,11.5),"dark")
	for side in [-1,1]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.add_vertex(Vector3(-6,6.2,side*5.02))
		tool.add_vertex(Vector3(0,7.45,side*5.02))
		tool.add_vertex(Vector3(6,6.2,side*5.02))
		tool.generate_normals()
		var gable := MeshInstance3D.new()
		gable.mesh = tool.commit()
		gable.material_override = palette.plaster
		gable.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		add_child(gable)
	chair(Vector3(-2.3,3.34,5.7),0)
	chair(Vector3(2.3,3.34,5.7),0)
	for x in [-5.3,5.3]:
		for z in [6.0,-4.8]: plant(Vector3(x,0,z),1.3)
	for x in [-4.3,4.3]:
		block(Vector3(x,0.25,6.7),Vector3(2.2,0.5,0.6),"teak")
		for leaf in [-0.6,0.0,0.6]: plant(Vector3(x+leaf,0.45,6.7),0.55)
	# Door mat and porch are visible destinations; entry occurs through its interaction.
	block(Vector3(0,0.02,6.3),Vector3(2.3,0.04,1.3),"rug")
	var sign := Label3D.new()
	sign.text = "晴屿别墅 · 我的家"
	sign.font = load("res://assets/fonts/NotoSansSC.ttf")
	sign.font_size = 28
	sign.pixel_size = 0.009
	sign.position = Vector3(0,2.7,5.3)
	add_child(sign)
func interior(floor_index: int) -> void:
	name = "VillaFloor%d" % (floor_index+1)
	# Full-height room walls meet the enclosed ceiling.
	var floor_mesh:=block(Vector3(Dimensions.MAIN_CENTER_X,0.5,6.1),Vector3(Dimensions.MAIN_WIDTH,0.35,24.2),"floor",true)
	floor_mesh.name="InteriorFloor"
	floor_mesh.material_override=preload("res://scripts/life/interior_floor_material.gd").make(palette.floor)
	block(Vector3(-10.68,Dimensions.WALL_CENTER,6.1),Vector3(0.22,Dimensions.CLEAR_HEIGHT,24.2),"plaster",true)
	# Wide shared stair doorway on both levels; visual wall and collision match.
	for spec: Vector2 in [Vector2((-5.8+Dimensions.STAIR_DOOR_NORTH)*.5,Dimensions.STAIR_DOOR_NORTH+5.8),Vector2((Dimensions.STAIR_DOOR_SOUTH+18)*.5,18-Dimensions.STAIR_DOOR_SOUTH)]:
		block(Vector3(7.8,Dimensions.WALL_CENTER,spec.x),Vector3(.22,Dimensions.CLEAR_HEIGHT,spec.y),"plaster",true)
	# Close the floor edge above the arch; upper treads must not peek through
	# an unfinished gap over the downstairs doorway.
	var lintel_bottom:float=Dimensions.BASE+Dimensions.STAIR_DOOR_HEIGHT
	var lintel_top:float=minf(Dimensions.BASE+Dimensions.RISE,Dimensions.TOP-floor_index*Dimensions.RISE)
	block(Vector3(7.8,(lintel_bottom+lintel_top)*.5,(Dimensions.STAIR_DOOR_NORTH+Dimensions.STAIR_DOOR_SOUTH)*.5),Vector3(.22,lintel_top-lintel_bottom,Dimensions.STAIR_DOOR_SOUTH-Dimensions.STAIR_DOOR_NORTH),"plaster",true).name="StairDoorLintel"
	high_wall = block(Vector3(Dimensions.MAIN_CENTER_X,Dimensions.WALL_CENTER,-5.8),Vector3(Dimensions.MAIN_WIDTH,Dimensions.CLEAR_HEIGHT,0.22),"plaster",true)
	high_wall.material_override = palette.plaster.duplicate()
	block(Vector3(-6.115,Dimensions.WALL_CENTER,18),Vector3(9.03,Dimensions.CLEAR_HEIGHT,0.22),"plaster",true)
	if floor_index==0:
		block(Vector3(4.675,Dimensions.WALL_CENTER,18),Vector3(6.15,Dimensions.CLEAR_HEIGHT,.22),"plaster",true)
		var entrance=preload("res://scripts/life/home_glass_door.gd").new();add_child(entrance);entrance.setup(self,Vector3(0,Dimensions.BASE+1.5,18.08),3.2)
	else:
		for span:Vector2 in [Vector2(1.25,Dimensions.BALCONY_DOOR_X-Dimensions.BALCONY_DOOR_WIDTH*.5),Vector2(Dimensions.BALCONY_DOOR_X+Dimensions.BALCONY_DOOR_WIDTH*.5,7.75)]:
			var pane:MeshInstance3D=block(Vector3((span.x+span.y)*.5,Dimensions.WALL_CENTER,18),Vector3(span.y-span.x,Dimensions.CLEAR_HEIGHT,.22),"glass",true)
			var glass:=ShaderMaterial.new();glass.shader=preload("res://shaders/privacy_glass.gdshader");pane.material_override=glass
		block(Vector3(Dimensions.BALCONY_DOOR_X,Dimensions.BASE+Dimensions.DOOR_HEIGHT+(Dimensions.CLEAR_HEIGHT-Dimensions.DOOR_HEIGHT)*.5,18),Vector3(Dimensions.BALCONY_DOOR_WIDTH,Dimensions.CLEAR_HEIGHT-Dimensions.DOOR_HEIGHT,.22),"plaster",true)
		var entrance=preload("res://scripts/life/home_glass_door.gd").new();add_child(entrance);entrance.setup(self,Vector3(Dimensions.BALCONY_DOOR_X,Dimensions.BASE+1.5,18.08),Dimensions.BALCONY_DOOR_WIDTH)
		for x:float in [Dimensions.BALCONY_DOOR_X-Dimensions.BALCONY_DOOR_WIDTH*.5-.04,Dimensions.BALCONY_DOOR_X+Dimensions.BALCONY_DOOR_WIDTH*.5+.04]:block(Vector3(x,Dimensions.BASE+Dimensions.DOOR_HEIGHT*.5,18.18),Vector3(.08,Dimensions.DOOR_HEIGHT,.12),"teak")
		point("villa_balcony","去阳台看海",Vector3(3.2,.705,17.0),1.8)
		point("villa_balcony_return","返回二楼",Vector3(3.2,.705,20.1),2.0)
		point("villa_balcony_rest","躺下休息",Vector3(-1.55,.705,22.2),1.8)

	# Wood floor boards and room rugs make the spaces legible without HUD labels.
	# Board seams are filtered into the floor material, not separate thin strips.
	for x in [0.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(x,3.3,0)
		light.light_color = Color("fff0d3")
		light.light_energy = 0.65
		light.omni_range = 13
		add_child(light)
	for x in [0.0]:
		var light:=OmniLight3D.new();light.position=Vector3(x,3.3,12);light.light_color=Color("fff0d3");light.light_energy=.6;light.omni_range=13;add_child(light)
	if floor_index == 0: _ground_floor()
	else: _upper_floor()
	point("villa_stairs","上二楼" if floor_index == 0 else "下一楼",Vector3(8.2 if floor_index==0 else 9.5,.705,2.6),3.2 if floor_index==0 else 4.2)
	if floor_index==0:
		plant(Vector3(-7,0.7,4.7))
		plant(Vector3(7,0.7,4.7))
func _ground_floor() -> void:
	# Living room: two sofas, rug, coffee table and television.
	block(Vector3(-6.2,0.69,3.15),Vector3(8.3,0.025,7.3),"rug")
	furniture("sofa-9c0e7e",Vector3(-2.9,0.7,2.5),-PI/2,1.25,Vector2(2.6,1.1)).name="LivingSofaMain"
	furniture("sofa-9c0e7e",Vector3(-6.6,0.7,6.1),PI,1.1,Vector2(2.2,1.1)).name="LivingSofaSide"
	block(COFFEE_CENTER,Vector3(1.7,0.6,.94),"teak",true).name="CoffeeTableBase"
	block(COFFEE_CENTER+Vector3(0,.32,0),Vector3(1.85,0.06,1.0),"cream").name="CoffeeTableTop"
	block(Vector3(-10.2,1.0,2.5),Vector3(.65,0.6,4.4),"teak",true).name="TelevisionCabinet"
	block(Vector3(-10.25,2.49,2.5),Vector3(.08,2.33345,4.10122),"dark").name="LargeTelevisionFrame"
	tv_screen=MeshInstance3D.new();tv_screen.name="TelevisionScreen";var screen_quad:=QuadMesh.new();screen_quad.size=Vector2(4.06122,2.29345);tv_screen.mesh=screen_quad
	add_child(tv_screen);tv_screen.position=Vector3(-10.198,2.49,2.5);tv_screen.rotation.y=PI/2
	set_tv(world.home_tv_on)
	if world.orbit.first_person or world.orbit.stable_third_person:point("villa_tv","关闭电视" if world.home_tv_on else "打开电视",Vector3(-8.8,.705,2.5),1.8)
	_tea_set()
	woven_floor_lamp(Vector3(-10.0,0.7,5.25))
	point("villa_rest","沙发小憩",SOFA_STAND,1.4)
	# Kitchen and pantry at the back, dining in the central open space.
	for x in [-6,-4.7,-3.4]:
		block(Vector3(x,1.15,-4.8),Vector3(1.25,0.9,1.3),"cream",true)
		block(Vector3(x,1.63,-4.8),Vector3(1.3,0.08,1.4),"dark")
		block(Vector3(x,2.65,-5.2),Vector3(1.2,0.7,0.6),"teak")
	for x in [-3.65,-3.15]:
		for z in [-4.5,-5]: block(Vector3(x,1.69,z),Vector3(0.23,0.025,0.23),"metal")
	var cooking_pot:=Node3D.new();cooking_pot.name="CookingPot";cooking_pot.position=Vector3(-3.4,1.75,-4.35);add_child(cooking_pot)
	_cylinder(cooking_pot,Vector3(0,.07,0),.24,.14,world.material(Color("a3afb0")))
	_cylinder(cooking_pot,Vector3(0,.145,0),.21,.012,palette.dark)
	for x:float in [-.29,.29]:world.box(cooking_pot,Vector3(x,.09,0),Vector3(.17,.035,.06),palette.metal)
	for x:float in [-.09,.09]:world.box(cooking_pot,Vector3(x,.16,0),Vector3(.12,.025,.18),world.material(Color("bd8c59")))
	block(Vector3(-5.9,1.69,-4.8),Vector3(0.7,0.025,0.7),"glass")
	block(Vector3(-5.9,1.9,-5),Vector3(0.06,0.4,0.06),"metal")
	var fridge=preload("res://scripts/life/home_fridge.gd").new();add_child(fridge);fridge.position=Vector3(-1.5,.7,-4.9);fridge.setup(world)
	point("villa_fridge","打开冰箱",Vector3(-1.5,.7,-2.6),1.2)
	var bin:=Node3D.new();bin.name="KitchenBin";bin.position=Vector3(-7,.7,-3.2);add_child(bin)
	_cylinder(bin,Vector3(0,.36,0),.27,.72,palette.metal,.3)
	_cylinder(bin,Vector3(0,.73,0),.3,.04,palette.dark)
	preload("res://scripts/life/prop_collision.gd").convex(bin)
	point("villa_bin","丢空饮料瓶",Vector3(-6.4,.7,-2.5),1.2)
	point("villa_cook","烹饪鱼干",Vector3(-3.4,0.7,-3.2),1.2)
	point("villa_water","接水饮用",Vector3(-6,0.7,-3),1.3)
	furniture("dining-table-7af83a",DINING_CENTER,PI/2,1.3,Vector2(2.3,1.2)).name="DiningTable"
	for i in range(2):
		var z:float=10.3+i*1.4
		var id:int=-2 if i==0 else 12
		chair(Vector3(0.4,0.7,z),PI/2).name="DiningChairLeft_%d"%id
		chair(Vector3(2.8,0.7,z),-PI/2).name="DiningChairRight_%d"%id
	for seat:Node3D in find_children("DiningChair*","Node3D",false,false):
		var facing:Vector3=seat.global_basis.z.normalized()
		points.append({"kind":"villa_eat","title":"坐下用餐","pos":seat.global_position,"range":1.8,"owner":self,"object":seat,"seat":seat,"stand":seat.global_position-facing*.9,"facing":to_global(DINING_CENTER)})
	_fruit_bowl()
	_meal_plate()
	var gym=preload("res://scripts/life/home_gym.gd").new();add_child(gym);gym.setup(self)
	# Study with books, desk and a pet bed, away from the main walking corridor.
	block(Vector3(6.1,1.1,14.5),Vector3(2.4,0.8,1.0),"teak",true).name="StudyDeskBase"
	block(Vector3(6.1,1.54,14.5),Vector3(2.5,0.08,1.1),"cream").name="StudyDeskTop"
	chair(Vector3(6.1,0.7,13.4),0).name="StudyChair"
	_bookcase()
	block(Vector3(6.1,0.74,13.4),Vector3(1,.12,.8),"rug").name="StudyFootMat"
	point("villa_exit","走出别墅",Vector3(0,0.7,17.4),1.4)
func _cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,mat: Material,top: float=-1) -> MeshInstance3D:
	var node := MeshInstance3D.new();var mesh := CylinderMesh.new()
	mesh.bottom_radius=radius;mesh.top_radius=radius if top<0 else top;mesh.height=height;mesh.radial_segments=16
	node.mesh=mesh;node.material_override=mat;parent.add_child(node);node.position=pos
	return node
func _tea_set() -> void:
	var tray := Node3D.new();tray.name="CoffeeTeaSet";add_child(tray);tray.position=COFFEE_CENTER+Vector3(0,.35,0)
	world.box(tray,Vector3(0,.012,0),Vector3(.65,.024,.38),palette.teak)
	var tea: Material=world.material(Color("734825"))
	for x: float in [-.18,.18]:
		_cylinder(tray,Vector3(x,.035,0),.12,.012,palette.cream)
		_cylinder(tray,Vector3(x,.105,0),.065,.13,palette.cream,.08)
		_cylinder(tray,Vector3(x,.172,0),.064,.004,tea)
		var handle := MeshInstance3D.new();var ring := TorusMesh.new()
		ring.inner_radius=.022;ring.outer_radius=.036;ring.rings=8;ring.ring_segments=12
		handle.mesh=ring;handle.material_override=palette.cream;tray.add_child(handle)
		handle.position=Vector3(x+.088,.11,0);handle.rotation.x=PI/2
func _meal_plate() -> void:
	# 餐盘道具：默认收在桌上方的隐藏位，技能「摆放餐食」时出现、「收拾餐具」时收起。
	var plate:=Node3D.new();plate.name="DiningMealPlate";add_child(plate)
	plate.position=DINING_CENTER+Vector3(.42,1.02,-.12);plate.visible=false
	_cylinder(plate,Vector3.ZERO,.19,.022,palette.cream,.2)
	_cylinder(plate,Vector3(0,.035,0),.1,.05,palette.metal,.13)
	var bread:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.14,.05,.09);bread.mesh=box;bread.material_override=world.material(Color("d6a15c"));plate.add_child(bread)
	bread.position=Vector3(-.02,.062,.01);bread.rotation.y=.4
	set_meta("meal_placed",false)
func _fruit_bowl() -> void:
	var root := Node3D.new();root.name="DiningFruitBowl";add_child(root);root.position=DINING_CENTER+Vector3(0,.98,0)
	_cylinder(root,Vector3(0,.06,0),.17,.12,palette.cream,.32)
	var colors := [Color("bd493a"),Color("8caa46"),Color("e6a346"),Color("bc4b32"),Color("9bb64d")]
	for i in range(5):
		var fruit := MeshInstance3D.new();var sphere := SphereMesh.new()
		sphere.radius=.11;sphere.height=.22;sphere.radial_segments=8;sphere.rings=4
		fruit.mesh=sphere;fruit.material_override=world.material(colors[i]);root.add_child(fruit)
		var angle := i*TAU/5
		fruit.position=Vector3(cos(angle)*.16,.17,sin(angle)*.16)
		world.box(root,fruit.position+Vector3(0,.12,0),Vector3(.018,.05,.018),palette.teak)
func _bookcase() -> void:
	var root := Node3D.new();root.name="StudyBookcase";add_child(root);root.position=Vector3(5.3,.7,-4.8);root.rotation.y=PI/2
	world.box(root,Vector3(.27,1.15,0),Vector3(.08,2.3,2.6),palette.teak)
	for z:float in [-1.25,1.25]:world.box(root,Vector3(0,1.15,z),Vector3(.6,2.3,.08),palette.teak)
	world.box(root,Vector3(0,2.3,0),Vector3(.6,.08,2.6),palette.teak)
	world.box(root,Vector3(0,.15,0),Vector3(.6,.3,2.6),palette.teak)
	for shelf in range(4):
		world.box(root,Vector3(0,.3+shelf*.45,0),Vector3(.55,.08,2.4),palette.teak)
		for book in range(6):
			world.box(root,Vector3(0,.5+shelf*.45,-.9+book*.32),Vector3(.35,.28,.13),[palette.rug,palette.cream,palette.green][book%3])
	var body := StaticBody3D.new();body.name="BookcaseObstacle";root.add_child(body);body.position.y=1.15
	var collider := CollisionShape3D.new();var shape := BoxShape3D.new();shape.size=Vector3(.6,2.3,2.6);collider.shape=shape;body.add_child(collider)

func _upper_floor() -> void:
	var furnishings := preload("res://scripts/life/upstairs_rooms.gd").new()
	add_child(furnishings);furnishings.setup(self)

func _process(_delta: float) -> void:
	pass

func set_tv(enabled: bool) -> void:
	if tv_screen == null:return
	var television:Node=get_node_or_null("HomeTelevision")
	if television==null:
		television=preload("res://scripts/life/home_television.gd").new();television.name="HomeTelevision";add_child(television);television.setup(self)
	television.set_enabled(enabled)

func sofa_surface() -> float:
	var height:=SOFA_SEAT.y
	var sofa:Node3D=get_node("LivingSofaMain")
	var point:Vector3=to_global(SOFA_SEAT)
	for mesh:MeshInstance3D in sofa.find_children("*","MeshInstance3D",true,false):
		var faces:PackedVector3Array=mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var hit:Variant=Geometry3D.segment_intersects_triangle(point+Vector3.UP*3,point-Vector3.UP,mesh.global_transform*faces[i],mesh.global_transform*faces[i+1],mesh.global_transform*faces[i+2])
			if hit!=null:height=maxf(height,hit.y)
	return height

func bed_surface() -> float:
	var height:float=BED_ANCHOR.y
	var bed:Node3D=get_node("MasterBed")
	var point:=Vector3(BED_CENTER.x,0,-3.05)
	var found:=false
	for mesh:MeshInstance3D in bed.find_children("*","MeshInstance3D",true,false):
		var faces:PackedVector3Array=mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var hit:Variant=Geometry3D.segment_intersects_triangle(point+Vector3.UP*10,point-Vector3.UP,mesh.global_transform*faces[i],mesh.global_transform*faces[i+1],mesh.global_transform*faces[i+2])
			if hit!=null:
				height=maxf(height,hit.y) if found else hit.y;found=true
	return height
