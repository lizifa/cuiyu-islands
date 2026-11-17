extends Node3D
## 给所有可探索岛屿各生成一条木桥：从岛岸伸到水面，玩家可以直接走过去登岛。
## 桥面高度写进 world.island_ground_height()，所以现有的地面吸附 / 可行走判定直接就能用。

const DECK_WIDTH := 2.4
const DECK_Y := 0.62
const OUTWARD := 7.0   # 桥伸出岸外的长度（米）
const INWARD := 2.4    # 桥压在岛岸上的长度，保证和地形接得上
const PLANK := 0.34

var world: Node3D
var bridges: Dictionary = {}
var wood := StandardMaterial3D.new()

func setup(owner_world: Node3D) -> void:
	world = owner_world
	wood.albedo_color = Color("8a6a45")
	wood.roughness = 0.85
	if world == null or world.seascape == null: return
	for island: Node3D in world.seascape.islands:
		_build(island)

func _build(island: Node3D) -> void:
	var spec: Dictionary = island.spec
	var yaw := _bridge_yaw(island)
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	var shore := _shore_distance(island, dir)
	if shore <= 0.0 or not is_finite(shore): return
	var inner: Vector3 = island.global_position + dir * maxf(0.0, shore - INWARD)
	var deck_y: float = island.global_position.y + DECK_Y
	var length := INWARD + OUTWARD
	var holder := Node3D.new()
	holder.name = "IslandBridge_" + str(spec.id)
	holder.position = Vector3(inner.x, deck_y, inner.z)
	holder.rotation.y = yaw
	add_child(holder)
	_planks(holder, length)
	_railings(holder, length)
	_supports(holder, length, deck_y)
	bridges[String(spec.id)] = {
		"origin": Vector3(inner.x, deck_y, inner.z),
		"dir": dir,
		"yaw": yaw,
		"length": length,
		"surface": deck_y,
	}

func _bridge_yaw(island: Node3D) -> float:
	# 选一段最短就能到开阔水面的岸线：桥不要横穿山脊，也不要伸进礁石。
	var best_yaw := float(island.rotation.y)
	var best_cost := INF
	for step in range(24):
		var yaw := step * TAU / 24.0
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var shore := _shore_distance(island, dir)
		if shore <= 0.0 or not is_finite(shore): continue
		var clear := true
		for offset in range(1, 5):
			var p: Vector3 = island.global_position + dir * (shore + offset * 1.6)
			var local := Vector3(p.x - island.global_position.x, 0, p.z - island.global_position.z)
			if island.surface_height_at(Vector2(local.x, local.z)) > -0.55:
				clear = false
				break
		if not clear: continue
		var cost: float = shore + absf(angle_difference(yaw, float(island.rotation.y))) * 2.0
		if cost < best_cost:
			best_cost = cost
			best_yaw = yaw
	return best_yaw

func _shore_distance(island: Node3D, dir: Vector3) -> float:
	var limit: float = maxf(island.spec.radii.x, island.spec.radii.y) * 1.35
	var shore := -1.0
	var r := 1.0
	while r <= limit:
		var p: Vector3 = island.global_position + dir * r
		var h: float = island.surface_height_at(Vector2(p.x - island.global_position.x, p.z - island.global_position.z))
		if is_finite(h) and h > 0.16: shore = r
		r += 0.35
	return shore

func _planks(holder: Node3D, length: float) -> void:
	var count: int = maxi(6, int(ceil(length / PLANK)))
	var step: float = length / float(count)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(DECK_WIDTH, 0.12, step * 0.86)
	var material := wood
	for i in range(count):
		var plank := MeshInstance3D.new()
		plank.mesh = mesh
		plank.material_override = material
		plank.position = Vector3(0, 0, step * (i + 0.5))
		holder.add_child(plank)

func _railings(holder: Node3D, length: float) -> void:
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, 0.08, length)
		rail.mesh = mesh
		rail.material_override = wood
		rail.position = Vector3(side * (DECK_WIDTH * 0.5 - 0.08), 0.86, length * 0.5)
		holder.add_child(rail)
		for i in range(int(length / 1.6) + 1):
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.09, 1.0, 0.09)
			post.mesh = post_mesh
			post.material_override = wood
			post.position = Vector3(side * (DECK_WIDTH * 0.5 - 0.08), 0.4, minf(length - 0.12, 0.25 + i * 1.6))
			holder.add_child(post)

func _supports(holder: Node3D, length: float, deck_y: float) -> void:
	var legs := int(length / 2.2) + 1
	for i in range(legs):
		var z: float = minf(length - 0.3, 0.3 + i * 2.2)
		for side in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.16, maxf(0.8, deck_y + 1.4), 0.16)
			leg.mesh = mesh
			leg.material_override = wood
			leg.position = Vector3(side * (DECK_WIDTH * 0.5 - 0.25), -(deck_y + 1.4) * 0.5, z)
			holder.add_child(leg)

func has_bridge(island_id: String) -> bool:
	return bridges.has(island_id)

## 站在桥面上的时候返回桥面高度，否则 -INF（交给地形判定）。
func height_at(p: Vector3) -> float:
	if bridges.is_empty(): return -INF
	for key: String in bridges:
		var data: Dictionary = bridges[key]
		var origin: Vector3 = data.origin
		var dir: Vector3 = data.dir
		var along: float = (p.x - origin.x) * dir.x + (p.z - origin.z) * dir.z
		if along < 0.0 or along > float(data.length): continue
		var lateral: float = absf((p.x - origin.x) * -dir.z + (p.z - origin.z) * dir.x)
		if lateral > DECK_WIDTH * 0.5 - 0.12: continue
		return float(data.surface)
	return -INF
