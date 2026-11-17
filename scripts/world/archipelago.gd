extends Node3D
## Archipelago —— 群岛世界生成器
## 程序化生成：水面 + 初心岛 + 环绕的远岛 + 植被/岩石/花草/小动物/小船/可采集物。
## 全部使用 PrimitiveMesh + StandardMaterial3D，不依赖外部模型，打开即跑。

const SEA_Y: float = 0.0            # 海平面
const WATER_RADIUS: float = 260.0   # 水面半径

# 动物预制参数（名称, 颜色, 体型缩放）
const ANIMAL_DEFS := [
	{"name": "狐狸", "color": Color(0.95, 0.55, 0.28), "scale": 1.1},
	{"name": "白兔", "color": Color(0.96, 0.94, 0.90), "scale": 0.9},
	{"name": "鹦鹉", "color": Color(0.35, 0.78, 0.45), "scale": 0.8},
	{"name": "陆龟", "color": Color(0.55, 0.72, 0.42), "scale": 0.85},
	{"name": "松鼠", "color": Color(0.78, 0.52, 0.30), "scale": 0.7},
]

var _rng := RandomNumberGenerator.new()

# ---- 材质缓存 ----
var mat_water: StandardMaterial3D
var mat_sand: StandardMaterial3D
var mat_grass: StandardMaterial3D
var mat_rock: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_leaf: StandardMaterial3D
var mat_leaf2: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_flower_stem: StandardMaterial3D
var mat_berry: StandardMaterial3D
var mat_flower_petal: StandardMaterial3D

func _ready() -> void:
	_rng.seed = 20261102
	_build_materials()
	_build_water()
	_build_archipelago()

# ============================================================ 材质
func _build_materials() -> void:
	mat_sand = _make_mat(Color(0.94, 0.86, 0.66), 0.0)
	mat_grass = _make_mat(Color(0.45, 0.78, 0.40), 0.0)
	mat_rock = _make_mat(Color(0.55, 0.55, 0.58), 0.15)
	mat_trunk = _make_mat(Color(0.55, 0.36, 0.20), 0.0)
	mat_leaf = _make_mat(Color(0.30, 0.66, 0.30), 0.0)
	mat_leaf2 = _make_mat(Color(0.36, 0.72, 0.36), 0.0)
	mat_wood = _make_mat(Color(0.62, 0.44, 0.26), 0.0)
	mat_flower_stem = _make_mat(Color(0.35, 0.62, 0.30), 0.0)
	mat_berry = _make_mat(Color(0.82, 0.20, 0.30), 0.0)
	mat_flower_petal = _make_mat(Color(0.95, 0.55, 0.72), 0.0)

	# 半透明水面
	mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.20, 0.62, 0.85, 0.82)
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_water.metallic = 0.1
	mat_water.roughness = 0.15

func _make_mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = rough
	return m

# ============================================================ 水面
func _build_water() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = WATER_RADIUS
	mesh.bottom_radius = WATER_RADIUS
	mesh.height = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat_water
	mi.position = Vector3(0, SEA_Y, 0)
	add_child(mi)

# ============================================================ 群岛
func _build_archipelago() -> void:
	# 中心初心岛（出生点）
	var birth := _build_island(3.2, "初心岛")
	birth.position = Vector3(0, SEA_Y, 0)
	add_child(birth)
	_populate_island(birth, 3.2, true)

	# 环绕远岛
	var angles := [30.0, 95.0, 160.0, 225.0, 295.0]
	var radii := [26.0, 34.0, 30.0, 36.0, 28.0]
	for i in angles.size():
		var r: float = radii[i]
		var a := deg_to_rad(angles[i])
		var pos := Vector3(cos(a) * r, SEA_Y, sin(a) * r)
		var radius := 2.2 + _rng.randf_range(0, 1.2)
		var island := _build_island(radius, "远岛%d" % (i + 1))
		island.position = pos
		island.rotation.y = _rng.randf_range(0, TAU)
		add_child(island)
		_populate_island(island, radius, false)

# 建造一座岛（沙滩底 + 草地顶）
func _build_island(radius: float, _name: String) -> Node3D:
	var island := Node3D.new()
	island.name = _name

	var sand := MeshInstance3D.new()
	var s := CylinderMesh.new()
	s.top_radius = radius
	s.bottom_radius = radius * 1.1
	s.height = 1.6
	sand.mesh = s
	sand.material_override = mat_sand
	sand.position = Vector3(0, 0.6, 0)
	island.add_child(sand)

	var grass := MeshInstance3D.new()
	var g := CylinderMesh.new()
	g.top_radius = radius * 0.62
	g.bottom_radius = radius * 0.70
	g.height = 1.2
	grass.mesh = g
	grass.material_override = mat_grass
	grass.position = Vector3(0, 1.35, 0)
	island.add_child(grass)

	return island

# 在岛上摆放植被、岩石、采集物、小动物、小船
func _populate_island(island: Node3D, radius: float, is_birth: bool) -> void:
	var inner := radius * 0.55   # 可摆放区域半径

	# 树
	for i in int(radius * 3.0):
		var t := _rand_pos_on_island(inner, 0.5)
		_build_tree(island, t, is_birth)

	# 岩石
	for i in int(radius * 1.2):
		var rpos := _rand_pos_on_island(inner, 0.9)
		_build_rock(island, rpos)

	# 花草 / 采集物（野花、浆果、青草、原木）
	for i in int(radius * 4.0):
		var cpos := _rand_pos_on_island(inner, 0.6)
		_build_collectable(island, cpos)

	# 小动物
	if is_birth:
		var used := {}
		for def in ANIMAL_DEFS:
			var apos := _rand_pos_on_island(inner * 0.8, 0.4)
			_build_animal(island, apos, def, used)

	# 出生岛岸边停靠小木船
	if is_birth:
		var boat_node := _build_boat()
		boat_node.position = Vector3(radius * 1.15, SEA_Y - 0.1, radius * 0.3)
		boat_node.rotation.y = -0.6
		island.add_child(boat_node)

# 在岛上随机取点
func _rand_pos_on_island(radius: float, min_frac: float) -> Vector3:
	var a := _rng.randf_range(0, TAU)
	var r := radius * _rng.randf_range(min_frac, 1.0)
	return Vector3(cos(a) * r, 0, sin(a) * r)

# ============================================================ 植被 / 岩石
func _build_tree(parent: Node3D, pos: Vector3, tall: bool) -> void:
	var tree := Node3D.new()
	tree.position = Vector3(pos.x, 1.3, pos.z)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12
	tm.bottom_radius = 0.18
	tm.height = 1.6
	trunk.mesh = tm
	trunk.material_override = mat_trunk
	trunk.position = Vector3(0, 0.8, 0)
	tree.add_child(trunk)

	var h := 1.0
	if tall:
		h = 1.6
	for k in 3:
		var ball := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.8 - k * 0.12
		bm.height = 1.4 - k * 0.2
		ball.mesh = bm
		ball.material_override = mat_leaf if k % 2 == 0 else mat_leaf2
		ball.position = Vector3(_rng.randf_range(-0.15, 0.15), h + k * 0.45, _rng.randf_range(-0.15, 0.15))
		tree.add_child(ball)

	parent.add_child(tree)

func _build_rock(parent: Node3D, pos: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(
		_rng.randf_range(0.4, 1.1),
		_rng.randf_range(0.25, 0.6),
		_rng.randf_range(0.4, 1.0)
	)
	rock.mesh = rm
	rock.material_override = mat_rock
	rock.position = Vector3(pos.x, 1.0, pos.z)
	rock.rotation.y = _rng.randf_range(0, TAU)
	parent.add_child(rock)

# ============================================================ 小动物
func _build_animal(parent: Node3D, pos: Vector3, def: Dictionary, used: Dictionary) -> void:
	var animal := Node3D.new()
	animal.name = def["name"]
	animal.position = Vector3(pos.x, 1.3, pos.z)
	var s: float = def["scale"]
	animal.scale = Vector3.ONE * s

	# 身体
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.4
	bm.height = 0.75
	body.mesh = bm
	body.material_override = _make_mat(def["color"], 0.2)
	body.position = Vector3(0, 0.35, 0)
	animal.add_child(body)

	# 头
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.28
	hm.height = 0.5
	head.mesh = hm
	head.material_override = _make_mat(def["color"].lightened(0.1), 0.2)
	head.position = Vector3(0, 0.75, 0.35)
	animal.add_child(head)

	# 耳朵 / 尾巴（根据名字加一点辨识）
	if def["name"] in ["白兔", "狐狸", "松鼠"]:
		for side in [-1, 1]:
			var ear := MeshInstance3D.new()
			var em := CylinderMesh.new()
			em.top_radius = 0.06
			em.bottom_radius = 0.09
			em.height = 0.4
			ear.mesh = em
			ear.material_override = _make_mat(def["color"], 0.2)
			ear.position = Vector3(side * 0.18, 1.0, 0.25)
			animal.add_child(ear)

	# 脚本组件：游荡 + 投喂
	var npc := _new_script_node("res://scripts/animals/animal_npc.gd")
	animal.add_child(npc)
	npc.set_meta("animal_name", def["name"])
	npc.wander_radius = 2.2
	npc.bob_speed = 1.6 + _rng.randf_range(0, 0.8)
	npc.set_meta("home_pos", parent.to_global(pos))

	parent.add_child(animal)

# ============================================================ 小木船
func _build_boat() -> Node3D:
	var boat := Node3D.new()
	boat.name = "小木船"

	# 船体（两个 Box 拼出船头船尾翘起的效果）
	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(1.6, 0.35, 3.4)
	hull.mesh = hm
	hull.material_override = mat_wood
	hull.position = Vector3(0, 0.1, 0)
	boat.add_child(hull)

	# 船舱凹槽（深色）
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.1, 0.05, 2.2)
	deck.mesh = dm
	deck.material_override = _make_mat(Color(0.4, 0.28, 0.16), 0.3)
	deck.position = Vector3(0, 0.32, 0)
	boat.add_child(deck)

	# 桅杆
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.05
	mm.bottom_radius = 0.06
	mm.height = 1.8
	mast.mesh = mm
	mast.material_override = mat_trunk
	mast.position = Vector3(0, 1.0, 0)
	boat.add_child(mast)

	# 帆
	var sail := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 1.2, 0.9)
	sail.mesh = sm
	sail.material_override = _make_mat(Color(0.95, 0.95, 0.92), 0.4)
	sail.position = Vector3(0.5, 1.4, 0)
	boat.rotate_y(0)  # 帆朝向按船体方向
	boat.add_child(sail)

	# 航行脚本
	boat.add_child(_new_script_node("res://scripts/props/boat.gd"))
	return boat

# ============================================================ 可采集物
func _build_collectable(parent: Node3D, pos: Vector3) -> void:
	var kind := _rng.randi_range(0, 3)
	var root := Node3D.new()
	root.position = Vector3(pos.x, 1.3, pos.z)

	var stem: MeshInstance3D
	match kind:
		0:  # 野花
			stem = MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.03
			c.bottom_radius = 0.05
			c.height = 0.5
			stem.mesh = c
			stem.material_override = mat_flower_stem
			stem.position = Vector3(0, 0.25, 0)
			root.add_child(stem)
			for k in 5:
				var petal := MeshInstance3D.new()
				var pm := SphereMesh.new()
				pm.radius = 0.09
				pm.height = 0.16
				petal.mesh = pm
				var cols := [Color(0.95, 0.55, 0.72), Color(0.98, 0.8, 0.3), Color(0.85, 0.5, 0.9)]
				petal.material_override = _make_mat(cols[k % cols.size()], 0.2)
				petal.position = Vector3(cos(TAU * k / 5.0) * 0.18, 0.5, sin(TAU * k / 5.0) * 0.18)
				root.add_child(petal)
			root.set_meta("item_name", "野花")
		1:  # 原木
			var log := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.22
			lm.bottom_radius = 0.22
			lm.height = 0.9
			log.mesh = lm
			log.material_override = mat_trunk
			log.position = Vector3(0, 0.2, 0)
			log.rotation.z = PI / 2
			root.add_child(log)
			root.set_meta("item_name", "木材")
		2:  # 浆果
			for k in 3:
				var b := MeshInstance3D.new()
				var bm := SphereMesh.new()
				bm.radius = 0.08
				bm.height = 0.14
				b.mesh = bm
				b.material_override = mat_berry
				b.position = Vector3(_rng.randf_range(-0.1, 0.1), 0.25 + k * 0.12, _rng.randf_range(-0.1, 0.1))
				root.add_child(b)
			root.set_meta("item_name", "浆果")
		3:  # 青草丛
			for k in 5:
				var g := MeshInstance3D.new()
				var gm := CylinderMesh.new()
				gm.top_radius = 0.03
				gm.bottom_radius = 0.05
				gm.height = 0.45
				g.mesh = gm
				g.material_override = mat_grass
				g.position = Vector3(_rng.randf_range(-0.2, 0.2), 0.22, _rng.randf_range(-0.2, 0.2))
				root.add_child(g)
			root.set_meta("item_name", "青草")

	var coll := _new_script_node("res://scripts/props/collectable.gd")
	root.add_child(coll)
	coll.set_meta("item_name", root.get_meta("item_name"))
	parent.add_child(root)

# 工具：以脚本作为唯一子节点创建
func _new_script_node(script_path: String) -> Node:
	var script := load(script_path) as Script
	return script.new()
