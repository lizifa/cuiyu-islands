extends Node3D
## SingleIsland —— 单个初心岛生成器（对照参考图）
## 生成一座完整热带海岛：沙滩+草地、棕榈树+圆顶树、彩色花、木质告示牌、
## 山石瀑布、背景山峦、船桨、小木船，以及猴子/鹦鹉/海鸥/蜥蜴/白兔/狐狸。

const SEA_Y: float = 0.0

# 动物定义（名称, 主色, 体型, 是否飞行）
const ANIMAL_DEFS := [
	{"name": "猴子", "color": Color(0.62, 0.45, 0.28), "scale": 1.0, "fly": false},
	{"name": "鹦鹉", "color": Color(0.85, 0.30, 0.28), "scale": 0.85, "fly": false},
	{"name": "海鸥", "color": Color(0.95, 0.95, 0.92), "scale": 0.9, "fly": true},
	{"name": "蜥蜴", "color": Color(0.40, 0.72, 0.35), "scale": 0.8, "fly": false},
	{"name": "白兔", "color": Color(0.96, 0.94, 0.90), "scale": 0.95, "fly": false},
	{"name": "狐狸", "color": Color(0.92, 0.55, 0.30), "scale": 1.05, "fly": false},
]

var _rng := RandomNumberGenerator.new()

# ---- 材质 ----
var mat_sea: StandardMaterial3D
var mat_sand: StandardMaterial3D
var mat_grass: StandardMaterial3D
var mat_grass2: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_palm: StandardMaterial3D
var mat_rock: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_wood_light: StandardMaterial3D
var mat_waterfall: StandardMaterial3D
var mat_mountain: StandardMaterial3D
var mat_mountain2: StandardMaterial3D
var mat_stem: StandardMaterial3D
var mat_berry: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_dark: StandardMaterial3D

func _ready() -> void:
	_rng.seed = 20261102
	_build_materials()
	_build_sea()
	_build_island()
	_build_mountains()

# ============================================================ 材质
func _build_materials() -> void:
	mat_sea = _make(Color(0.16, 0.60, 0.72), 0.1, 0.0, false)
	mat_sand = _make(Color(0.93, 0.85, 0.64), 0.0, 0.0, false)
	mat_grass = _make(Color(0.44, 0.75, 0.38), 0.0, 0.0, false)
	mat_grass2 = _make(Color(0.52, 0.80, 0.42), 0.0, 0.0, false)
	mat_trunk = _make(Color(0.56, 0.38, 0.22), 0.0, 0.0, false)
	mat_palm = _make(Color(0.28, 0.58, 0.28), 0.0, 0.0, false)
	mat_rock = _make(Color(0.58, 0.56, 0.52), 0.0, 0.2, false)
	mat_wood = _make(Color(0.60, 0.42, 0.24), 0.0, 0.0, false)
	mat_wood_light = _make(Color(0.78, 0.62, 0.38), 0.0, 0.0, false)
	mat_mountain = _make(Color(0.42, 0.62, 0.44), 0.0, 0.0, false)
	mat_mountain2 = _make(Color(0.52, 0.66, 0.52), 0.0, 0.0, false)
	mat_stem = _make(Color(0.34, 0.60, 0.30), 0.0, 0.0, false)
	mat_berry = _make(Color(0.82, 0.20, 0.30), 0.0, 0.0, false)
	mat_white = _make(Color(0.96, 0.95, 0.90), 0.0, 0.0, false)
	mat_dark = _make(Color(0.30, 0.22, 0.16), 0.0, 0.0, false)

	# 半透明水面
	mat_waterfall = StandardMaterial3D.new()
	mat_waterfall.albedo_color = Color(0.55, 0.80, 0.92, 0.7)
	mat_waterfall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_waterfall.roughness = 0.1

func _make(color: Color, rough: float, metal: float, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

# ============================================================ 海面
func _build_sea() -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 90.0
	mesh.bottom_radius = 90.0
	mesh.height = 1.0
	mi.mesh = mesh
	mi.material_override = mat_sea
	mi.position = Vector3(0, SEA_Y, 0)
	add_child(mi)

# ============================================================ 岛屿主体
func _build_island() -> void:
	var island := Node3D.new()
	island.name = "初心岛"

	# 沙滩（大圆盘）
	var sand := _cylinder(radius, 7.0, 1.9, 1.15, mat_sand, Vector3(0, 0.65, 0))
	island.add_child(sand)
	# 草地（内圈）
	var grass := _cylinder(radius, 4.6, 1.5, 1.0, mat_grass, Vector3(0, 1.55, 0))
	island.add_child(grass)

	add_child(island)
	_island_root = island
	_populate(island)

var _island_root: Node3D
const radius: float = 7.0

# 摆放大件
func _populate(island: Node3D) -> void:
	# 棕榈树（岛上分布）
	for i in 7:
		var p := _rand_pos(3.6, 0.3)
		_build_palm(island, p)
	# 圆顶树
	for i in 4:
		var p := _rand_pos(3.4, 0.3)
		_build_round_tree(island, p)
	# 彩色花簇
	for i in 26:
		var p := _rand_pos(4.2, 0.5)
		_build_flower(island, p)
	# 岩石
	for i in 6:
		var p := _rand_pos(4.5, 0.9)
		_build_rock(island, p)
	# 采集物（野花/浆果/青草/原木）
	for i in 22:
		var p := _rand_pos(4.4, 0.4)
		_build_collectable(island, p)
	# 告示牌（岛前侧）
	_build_sign(island, Vector3(0, 1.3, 5.4))
	# 瀑布（岛后侧）+ 山石
	_build_waterfall(island, Vector3(-2.2, 1.2, -4.6))
	# 小木船 + 船桨（岸边）
	var boat := _build_boat(island)
	boat.position = Vector3(3.4, SEA_Y - 0.15, 4.2)
	boat.rotation.y = -1.1
	# 小动物
	for def in ANIMAL_DEFS:
		var a := _rand_pos(3.4, 0.2)
		_build_animal(island, a, def)

func _rand_pos(max_r: float, min_frac: float) -> Vector3:
	var a := _rng.randf_range(0, TAU)
	var r := max_r * _rng.randf_range(min_frac, 1.0)
	return Vector3(cos(a) * r, 0, sin(a) * r)

# 生成一个圆柱 MeshInstance
func _cylinder(top_r: float, bot_r: float, h: float, y: float, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = h
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

# ============================================================ 棕榈树
func _build_palm(parent: Node3D, pos: Vector3) -> void:
	var palm := Node3D.new()
	palm.position = Vector3(pos.x, 1.6, pos.z)
	var tilt := _rng.randf_range(-0.25, 0.25)
	palm.rotation.z = tilt

	# 树干（略微倾斜的圆柱）
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12
	tm.bottom_radius = 0.20
	tm.height = 2.6
	trunk.mesh = tm
	trunk.material_override = mat_trunk
	trunk.position = Vector3(0, 1.2, 0)
	palm.add_child(trunk)

	# 树冠点
	var crown := Vector3(0, 2.5, 0)
	# 扇形羽叶（6 片，围绕冠点向外斜下）
	for i in 6:
		var angle := TAU * i / 6.0 + _rng.randf_range(-0.2, 0.2)
		_palm_leaf(palm, crown, angle)

	# 果实
	var fruit := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.2
	fruit.mesh = fm
	fruit.material_override = mat_berry
	fruit.position = crown + Vector3(0, -0.1, 0)
	palm.add_child(fruit)

	parent.add_child(palm)

func _palm_leaf(parent: Node3D, origin: Vector3, angle: float) -> void:
	var leaf := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.55
	lm.height = 1.1
	leaf.mesh = lm
	leaf.material_override = mat_palm
	# 压扁成羽叶
	leaf.scale = Vector3(0.5, 0.13, 1.0)
	# 放在冠点，指向外斜下
	leaf.position = origin
	leaf.rotation.y = angle
	leaf.rotate(Vector3(1, 0, 0), 0.6)   # 向下倾斜
	leaf.position = origin + Vector3(cos(angle) * 0.5, -0.35, sin(angle) * 0.5)
	parent.add_child(leaf)

# ============================================================ 圆顶树
func _build_round_tree(parent: Node3D, pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = Vector3(pos.x, 1.6, pos.z)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.13
	tm.bottom_radius = 0.19
	tm.height = 1.5
	trunk.mesh = tm
	trunk.material_override = mat_trunk
	trunk.position = Vector3(0, 0.75, 0)
	tree.add_child(trunk)
	for k in 3:
		var ball := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.7 - k * 0.1
		bm.height = 1.2 - k * 0.15
		ball.mesh = bm
		ball.material_override = mat_grass if k % 2 == 0 else mat_grass2
		ball.position = Vector3(0, 1.5 + k * 0.4, 0)
		tree.add_child(ball)
	parent.add_child(tree)

# ============================================================ 花 / 岩石
func _build_flower(parent: Node3D, pos: Vector3) -> void:
	var f := Node3D.new()
	f.position = Vector3(pos.x, 1.3, pos.z)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.05
	sm.height = 0.5
	stem.mesh = sm
	stem.material_override = mat_stem
	stem.position = Vector3(0, 0.25, 0)
	f.add_child(stem)
	var cols := [Color(0.96, 0.55, 0.7), Color(0.98, 0.8, 0.3), Color(0.85, 0.5, 0.92), Color(1, 1, 1)]
	for k in 5:
		var petal := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.08
		pm.height = 0.14
		petal.mesh = pm
		petal.material_override = _make(cols[k % cols.size()], 0.0, 0.0, false)
		petal.position = Vector3(cos(TAU * k / 5.0) * 0.15, 0.5, sin(TAU * k / 5.0) * 0.15)
		f.add_child(petal)
	parent.add_child(f)

func _build_rock(parent: Node3D, pos: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(_rng.randf_range(0.4, 1.0), _rng.randf_range(0.25, 0.6), _rng.randf_range(0.4, 1.0))
	rock.mesh = rm
	rock.material_override = mat_rock
	rock.position = Vector3(pos.x, 1.05, pos.z)
	rock.rotation.y = _rng.randf_range(0, TAU)
	parent.add_child(rock)

# ============================================================ 可采集物
func _build_collectable(parent: Node3D, pos: Vector3) -> void:
	var kind := _rng.randi_range(0, 3)
	var root := Node3D.new()
	root.position = Vector3(pos.x, 1.4, pos.z)
	match kind:
		0:  # 野花
			for k in 5:
				var petal := MeshInstance3D.new()
				var pm := SphereMesh.new()
				pm.radius = 0.08
				pm.height = 0.14
				petal.mesh = pm
				var cols := [Color(0.96, 0.55, 0.7), Color(0.98, 0.8, 0.3), Color(0.85, 0.5, 0.92), Color(1, 1, 1)]
				petal.material_override = _make(cols[k % cols.size()], 0.0, 0.0, false)
				petal.position = Vector3(cos(TAU * k / 5.0) * 0.15, 0.35, sin(TAU * k / 5.0) * 0.15)
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
		3:  # 青草
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

	var coll := _script_node("res://scripts/props/collectable.gd")
	root.add_child(coll)
	coll.set_meta("item_name", root.get_meta("item_name"))
	parent.add_child(root)

# ============================================================ 木质告示牌
func _build_sign(parent: Node3D, pos: Vector3) -> void:
	var sign := Node3D.new()
	sign.position = pos
	# 两根立柱
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07
		pm.bottom_radius = 0.09
		pm.height = 1.5
		post.mesh = pm
		post.material_override = mat_wood
		post.position = Vector3(side * 0.7, 0.75, 0)
		sign.add_child(post)
	# 面板
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.9, 0.08)
	board.mesh = bm
	board.material_override = mat_wood_light
	board.position = Vector3(0, 1.65, 0)
	sign.add_child(board)
	# 告示文字（Label3D 面向镜头/朝向海岸）
	var label := Label3D.new()
	label.text = "初心岛"
	label.font_size = 90
	label.pixel_size = 0.004
	label.outline_size = 10
	label.modulate = Color(0.2, 0.12, 0.05)
	label.position = Vector3(0, 1.62, -0.06)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.add_child(label)
	parent.add_child(sign)

# ============================================================ 瀑布 + 山石
func _build_waterfall(parent: Node3D, pos: Vector3) -> void:
	var wf := Node3D.new()
	wf.position = pos

	# 山石底座（堆叠的岩石块）
	var rock_colors := [mat_rock, mat_mountain, mat_mountain2]
	for i in 5:
		var rock := MeshInstance3D.new()
		var rm := BoxMesh.new()
		var s := _rng.randf_range(0.6, 1.3)
		rm.size = Vector3(s, s * _rng.randf_range(0.8, 1.2), s * _rng.randf_range(0.8, 1.2))
		rock.mesh = rm
		rock.material_override = rock_colors[i % rock_colors.size()]
		var a := _rng.randf_range(0, TAU)
		var r := _rng.randf_range(0, 1.0)
		rock.position = Vector3(cos(a) * r, 0.6 + i * 0.7, sin(a) * r * 0.6)
		rock.rotation.y = _rng.randf_range(0, TAU)
		wf.add_child(rock)

	# 水帘（半透明蓝柱，从高处垂落）
	var fall := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.18
	fm.bottom_radius = 0.22
	fm.height = 2.4
	fall.mesh = fm
	fall.material_override = mat_waterfall
	fall.position = Vector3(0, 1.6, -0.3)
	wf.add_child(fall)

	# 水潭（浅蓝圆盘）
	var pool := _cylinder(radius, 1.2, 1.2, 0.25, _make(Color(0.45, 0.75, 0.85, 0.85), 0.1, 0.0, true), Vector3(0.5, 0.3, 1.4))
	wf.add_child(pool)

	# 水花粒子
	var parts := CPUParticles3D.new()
	parts.direction = Vector3(0, 1, 0)
	parts.spread = 45.0
	parts.initial_velocity_min = 1.2
	parts.initial_velocity_max = 2.4
	parts.gravity = Vector3(0, -3.0, 0)
	parts.scale_amount_min = 0.08
	parts.scale_amount_max = 0.18
	parts.color = Color(0.8, 0.93, 1.0, 0.9)
	parts.amount = 20
	parts.lifetime = 1.2
	parts.emitting = true
	parts.position = Vector3(0.4, 0.5, 0.8)
	wf.add_child(parts)

	parent.add_child(wf)

# ============================================================ 背景山峦
func _build_mountains() -> void:
	var angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]
	var dists := [12.0, 14.0, 13.0, 15.0, 12.5, 14.5]
	for i in angles.size():
		var a := deg_to_rad(angles[i])
		var pos := Vector3(cos(a) * dists[i], SEA_Y + 1.0, sin(a) * dists[i])
		var mountain := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = 0.0
		mm.bottom_radius = _rng.randf_range(3.0, 5.0)
		mm.height = _rng.randf_range(3.5, 6.0)
		mountain.mesh = mm
		mountain.material_override = mat_mountain if i % 2 == 0 else mat_mountain2
		mountain.position = pos
		mountain.rotation.y = _rng.randf_range(0, TAU)
		add_child(mountain)

# ============================================================ 小木船 + 船桨
func _build_boat(parent: Node3D) -> Node3D:
	var boat := Node3D.new()
	boat.name = "小木船"
	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(1.6, 0.35, 3.4)
	hull.mesh = hm
	hull.material_override = mat_wood
	hull.position = Vector3(0, 0.1, 0)
	boat.add_child(hull)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.1, 0.05, 2.2)
	deck.mesh = dm
	deck.material_override = mat_dark
	deck.position = Vector3(0, 0.32, 0)
	boat.add_child(deck)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.05
	mm.bottom_radius = 0.06
	mm.height = 1.8
	mast.mesh = mm
	mast.material_override = mat_trunk
	mast.position = Vector3(0, 1.0, 0)
	boat.add_child(mast)
	var sail := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 1.2, 0.9)
	sail.mesh = sm
	sail.material_override = mat_white
	sail.position = Vector3(0.5, 1.4, 0)
	boat.add_child(sail)
	# 船桨（靠在船侧）
	var oar := Node3D.new()
	oar.position = Vector3(1.0, 0.3, -0.4)
	oar.rotation.z = 0.5
	var shaft := MeshInstance3D.new()
	var sm2 := CylinderMesh.new()
	sm2.top_radius = 0.03
	sm2.bottom_radius = 0.04
	sm2.height = 2.2
	shaft.mesh = sm2
	shaft.material_override = mat_wood_light
	oar.add_child(shaft)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.05, 0.22)
	blade.mesh = bm
	blade.material_override = mat_wood_light
	blade.position = Vector3(0, -1.05, 0)
	oar.add_child(blade)
	boat.add_child(oar)
	# 航行脚本
	boat.add_child(_script_node("res://scripts/props/boat.gd"))
	parent.add_child(boat)
	return boat

# ============================================================ 小动物
func _build_animal(parent: Node3D, pos: Vector3, def: Dictionary) -> void:
	var animal := Node3D.new()
	animal.name = def["name"]
	var s: float = def["scale"]
	animal.scale = Vector3.ONE * s

	if def["fly"]:
		# 海鸥：在岛上空盘旋
		animal.position = Vector3(pos.x, 6.0, pos.z)
		var fly := _script_node("res://scripts/animals/flying.gd")
		animal.add_child(fly)
	else:
		animal.position = Vector3(pos.x, 1.4, pos.z)
		# 身体
		var body := _sphere(0.4, 0.75, _make(def["color"], 0.2, 0.0, false), Vector3(0, 0.35, 0))
		animal.add_child(body)
		# 头
		var head := _sphere(0.27, 0.5, _make(def["color"].lightened(0.1), 0.2, 0.0, false), Vector3(0, 0.72, 0.34))
		animal.add_child(head)
		# 细节
		match def["name"]:
			"白兔", "狐狸":
				for side in [-1, 1]:
					var ear := _cylinder(0.06, 0.09, 0.4, 0.0, _make(def["color"], 0.2, 0.0, false), Vector3(side * 0.18, 1.0, 0.24))
					animal.add_child(ear)
				# 尾巴
				var tail := _sphere(0.1, 0.18, _make(def["color"].lightened(0.2), 0.2, 0.0, false), Vector3(0, 0.3, -0.42))
				animal.add_child(tail)
			"猴子":
				var face := _sphere(0.16, 0.3, mat_wood_light, Vector3(0, 0.74, 0.48))
				animal.add_child(face)
				# 长尾
				var tail := _cylinder(0.04, 0.06, 1.0, 0.0, _make(def["color"], 0.2, 0.0, false), Vector3(0, 0.2, -0.5))
				tail.rotation.x = -1.2
				animal.add_child(tail)
			"鹦鹉":
				# 翅膀
				for side in [-1, 1]:
					var wing := _sphere(0.22, 0.4, _make(Color(0.32, 0.6, 0.32), 0.2, 0.0, false), Vector3(side * 0.34, 0.4, 0))
					animal.add_child(wing)
			"蜥蜴":
				# 尾巴
				var tail := _cylinder(0.03, 0.06, 1.2, 0.0, _make(def["color"], 0.2, 0.0, false), Vector3(0, 0.3, -0.6))
				tail.rotation.x = 0.8
				animal.add_child(tail)

		# 游荡 + 投喂
		var npc := _script_node("res://scripts/animals/animal_npc.gd")
		animal.add_child(npc)
		npc.set_meta("animal_name", def["name"])
		npc.set_meta("home_pos", parent.to_global(pos))

	parent.add_child(animal)

func _sphere(r: float, h: float, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi

func _script_node(script_path: String) -> Node:
	var script := load(script_path) as Script
	return script.new()
