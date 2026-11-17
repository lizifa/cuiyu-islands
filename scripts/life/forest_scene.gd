extends Node3D
## Persistent island scenery. Surface grid is shared by placement and movement.
const CELL := 2.0
# Double horizontal land area around the working pier; props stay human-sized.
const LAND_SCALE := 1.41421356237
const COAST_ANCHOR := Vector2(0,16.1)
# A four-metre front promenade, with a gentle western approach to camp.
const ROAD := Rect2(3.0, 1.8, 13.0, 4.0)
func road_height(x: float) -> float:
	return lerpf(0.675, 1.3, smoothstep(3.0, 7.0, x))
func reserved_garden(p: Vector3, margin: float = 0.0) -> bool:
	return ROAD.grow(margin).has_point(Vector2(p.x, p.z))

var cells: Dictionary = {}
var tree_positions: Array[Vector3] = []
var trees: Array[Node3D] = []
var extra_trees: Array[Node3D] = []
var faded: Dictionary = {}
var actors: Array[Node3D] = []
var ground_material: StandardMaterial3D
var world: Node3D
var elapsed := 0.0
var active := true
var batching := false
var tree_batches: Dictionary = {}
var batch_links: Dictionary = {}
var animators: Array[AnimationPlayer] = []

func setup(owner_world: Node3D) -> void:
	world = owner_world
	name = "ForestIsland"
	var source := load("res://assets/polyfork/nature-forest-terrain-0e61f0.glb").instantiate() as Node3D
	add_child(source)
	source.scale = Vector3.ONE * 0.5
	source.position.y = 0.9
	world._apply_vertex_colors(source)
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		if node.name == "water":
			# The source asset's water volume rises above the player's eye.
			# The world already supplies the continuous ocean and shoreline shader.
			node.hide()
			continue
		if node.name != "woodland": continue
		var mesh_node := node as MeshInstance3D
		var land := ArrayMesh.new()
		for surface in range(mesh_node.mesh.get_surface_count()):
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				var p := mesh_node.global_transform * vertices[i]
				var expanded:Vector2=COAST_ANCHOR+(Vector2(p.x,p.z)-COAST_ANCHOR)*LAND_SCALE
				p.x=expanded.x;p.z=expanded.y
				# A gentle cleared homestead keeps existing house stages/saves usable.
				var blend := smoothstep(7.0, 10.0, Vector2(p.x, p.z).length())
				p.y = lerpf(0.675, p.y, blend)
				var plot_edge := maxf(absf(p.x - 11) - 5.5, absf(p.z + 5) - 7)
				p.y = lerpf(p.y, 1.3, 1 - smoothstep(0,2,maxf(0,plot_edge)))
				# Grade the shoulder too, so the road meets grass without a vertical lip.
				var nearest := Vector2(clampf(p.x, ROAD.position.x, ROAD.end.x), clampf(p.z, ROAD.position.y, ROAD.end.y))
				var shoulder := Vector2(p.x, p.z).distance_to(nearest)
				p.y = lerpf(p.y, road_height(p.x), 1.0 - smoothstep(0.0, 1.3, shoulder))
				vertices[i] = p
			arrays[Mesh.ARRAY_VERTEX] = vertices
			# Recompute normals after grading the small building clearing.
			var temporary := ArrayMesh.new()
			temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var tool := SurfaceTool.new()
			tool.create_from(temporary, 0)
			tool.generate_normals()
			tool.commit(land)
			ground_material = mesh_node.get_active_material(surface).duplicate() as StandardMaterial3D
			land.surface_set_material(surface, ground_material)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				_index_triangle(vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]])
		var baked := MeshInstance3D.new()
		baked.mesh = land
		add_child(baked)
		baked.create_trimesh_collision()
		# 地面不投放阴影：平地自己给自己投影，只会在这种大三角面上抖出一块块明暗斑，
		# 也就是实录里那片「阶梯状的亮绿/暗绿补丁」。道具照样把影子投到地面上。
		baked.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.visible = false
	_build_promenade()
	_scatter()
	_populate()

func _index_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if absf(normal.y) < 0.001: return
	for x in range(floori(minf(a.x, minf(b.x, c.x)) / CELL), floori(maxf(a.x, maxf(b.x, c.x)) / CELL) + 1):
		for z in range(floori(minf(a.z, minf(b.z, c.z)) / CELL), floori(maxf(a.z, maxf(b.z, c.z)) / CELL) + 1):
			var key := Vector2i(x, z)
			if not cells.has(key): cells[key] = []
			cells[key].append([a, b, c])

func height_at(x: float, z: float) -> float:
	var highest := -INF
	for triangle: Array in cells.get(Vector2i(floori(x / CELL), floori(z / CELL)), []):
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(denominator) < 0.00001: continue
		var u := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / denominator
		var v := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / denominator
		if minf(u, minf(v, 1 - u - v)) >= -0.0001:
			highest = maxf(highest, u * a.y + v * b.y + (1 - u - v) * c.y)
	return highest

func walkable(p: Vector3) -> bool:
	var h := height_at(p.x, p.z)
	if not is_finite(h) or h < 0.12: return false
	for offset: Vector2 in [Vector2(0.4, 0), Vector2(-0.4, 0), Vector2(0, 0.4), Vector2(0, -0.4)]:
		var neighbor := height_at(p.x + offset.x, p.z + offset.y)
		if not is_finite(neighbor) or absf(neighbor - h) > 0.45: return false
	return true

func asset(id: String, p: Vector3, size: float = 1.0) -> Node3D:
	var node := (load("res://assets/polyfork/%s.glb" % id) as PackedScene).instantiate() as Node3D
	add_child(node)
	node.position = p
	node.scale = Vector3.ONE * size
	world._apply_vertex_colors(node)
	return node

func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	var species := ["broad-canopy-shade-tree-e7c4a2", "young-pine-0d7695", "birch-tree-181b33", "broad-canopy-shade-tree-e7c4a2"]
	for attempt in range(6000):
		if tree_positions.size() >= 64: break
		var p := Vector3(rng.randf_range(-32, 31), 0, rng.randf_range(-40, 26))
		if (p.x > 3.5 and p.x < 19.5 and p.z > -14 and p.z < 3.5) or reserved_garden(p, 2.8) or Vector2(p.x, p.z).length() < 8.5 or not walkable(p): continue
		# Keep the camp-to-pier passage clear of actual branches and shoulder clearance.
		if p.x> -4 and p.x<6.5 and p.z>5 and p.z<19:continue
		var crowded := false
		for other: Vector3 in tree_positions:
			if p.distance_to(Vector3(other.x, 0, other.z)) < 2.7: crowded = true; break
		if crowded: continue
		p.y = height_at(p.x, p.z)
		tree_positions.append(p)
		var tree := asset(species[tree_positions.size() % species.size()], p, rng.randf_range(0.62, 0.85))
		tree.rotation.y = rng.randf_range(0, TAU)
		trees.append(tree)
		preload("res://scripts/life/prop_collision.gd").tree(tree, species[tree_positions.size() % species.size()])
	for i in range(18):
		var p := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
		if (p.x > 3.5 and p.x < 19.5 and p.z > -14 and p.z < 3.5) or reserved_garden(p, 1.0) or Vector2(p.x, p.z).length() < 8 or not walkable(p): continue
		p.y = height_at(p.x, p.z)
		var rock := asset("medium-rock-e08405", p, rng.randf_range(0.6, 1.4))
		rock.rotation.y = rng.randf_range(0, TAU)
		preload("res://scripts/life/prop_collision.gd").convex(rock)

func _clip_axis(points: Array[Vector3], axis: int, edge: float, above: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if points.is_empty(): return result
	var previous := points[-1]
	var previous_inside: bool = previous[axis]>=edge if above else previous[axis]<=edge
	for point: Vector3 in points:
		var inside: bool = point[axis]>=edge if above else point[axis]<=edge
		if inside!=previous_inside: result.append(previous.lerp(point,(edge-previous[axis])/(point[axis]-previous[axis])))
		if inside: result.append(point)
		previous=point;previous_inside=inside
	return result

func _build_promenade() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("b9bcb5").srgb_to_linear()
	concrete.roughness = 0.95
	var joint := StandardMaterial3D.new()
	joint.albedo_color = Color("90978d").srgb_to_linear()
	joint.roughness = 1.0
	# Clip the actual graded terrain triangles. One authoritative terrain collider
	# avoids separate paving edges catching the player's flat foot collider.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seen: Dictionary = {}
	for triangles: Array in cells.values():
		for triangle: Array in triangles:
			if seen.has(triangle): continue
			seen[triangle] = true
			# Terrain includes the island underside; paving only uses upward faces.
			if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y >= -0.00001: continue
			var polygon: Array[Vector3] = []
			polygon.assign(triangle)
			for boundary: Array in [[0,ROAD.position.x,true],[0,ROAD.end.x,false],[2,ROAD.position.y,true],[2,ROAD.end.y,false]]:
				polygon = _clip_axis(polygon,boundary[0],boundary[1],boundary[2])
			for i in range(1,polygon.size()-1):
				# 前庭是平的：法线一律朝上。以前用 generate_normals() 出来的是逐三角面法线，
				# 每块被剪出来的三角形亮度都不一样，地面看起来像打了一身补丁（也就是实录里那片花斑）。
				for vertex: Vector3 in [polygon[0],polygon[i],polygon[i+1]]:
					tool.set_normal(Vector3.UP)
					tool.add_vertex(vertex+Vector3.UP*.02)
	tool.generate_normals()
	var surface := MeshInstance3D.new()
	surface.name = "VillaConcretePromenade"
	surface.mesh = tool.commit()
	surface.material_override = concrete
	add_child(surface)
	# All flush expansion joints share one draw call on mobile.
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [7.0,10.0,13.0]:
		for iz in range(16):
			var z := ROAD.position.y + iz*.25
			var corners: Array[Vector3] = []
			for flat: Vector2 in [Vector2(x-.009,z),Vector2(x+.009,z),Vector2(x+.009,z+.25),Vector2(x-.009,z+.25)]:
				corners.append(Vector3(flat.x,height_at(flat.x,flat.y)+.014,flat.y))
			for index: int in [0,1,2,0,2,3]: seams.add_vertex(corners[index])
	seams.generate_normals()
	var seam_mesh := MeshInstance3D.new()
	seam_mesh.name="ConcreteExpansionJoints"
	seam_mesh.mesh=seams.commit();seam_mesh.material_override=joint
	seam_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seam_mesh)
	# Landscape trees frame the north-west side, keeping the front sea view open.
	for p: Vector3 in [Vector3(-1.0,0,-9.5),Vector3(1.0,0,-14.0),Vector3(3.0,0,-18.5)]:
		p.y = height_at(p.x,p.z)
		if not walkable(p): continue
		var tree := asset("ornamental-front-yard-tree-c6781a",p,0.85)
		preload("res://scripts/life/prop_collision.gd").tree(tree,"ornamental-front-yard-tree-c6781a")
		tree_positions.append(p)
		trees.append(tree)

func _actor(id: String, center: Vector3, radius: Vector2, speed: float, size: float, mode: String) -> void:
	var actor: Node3D = AnimatableBody3D.new() if mode=="boat" else (CharacterBody3D.new() if mode=="land" else Node3D.new())
	add_child(actor)
	var visual:Node3D
	if preload("res://scripts/life/fish_catalog.gd").DATA.has(id):
		visual=preload("res://scripts/life/fish_catalog.gd").create(id,world);add_child(visual);visual.scale=Vector3.ONE*size
	else:visual=asset(id,Vector3.ZERO,size)
	visual.reparent(actor, false)
	actor.set_meta("species", id)
	actor.set_meta("center", center)
	actor.set_meta("radius", radius)
	actor.set_meta("speed", speed)
	actor.set_meta("phase", actors.size() * 1.71)
	actor.set_meta("mode", mode)
	actor.set_meta("visual", visual)
	for animation: AnimationPlayer in visual.find_children("*", "AnimationPlayer", true, false):
		animators.append(animation)
		for clip: StringName in animation.get_animation_list():
			var desired := "swim" if mode == "sea" else ("fly" if mode == "air" else "walk")
			if str(clip).to_lower().ends_with(desired):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animation.play(clip)
				break
	actor.position = center
	if mode=="air":
		var flight=preload("res://scripts/life/bird_flight.gd").new();flight.setup(actor);actor.set_meta("flight",flight)
	if mode=="boat":
		actor.collision_layer=4
		actor.collision_mask=5
		actor.sync_to_physics=false
		actor.set_meta("sea_obstacle",true)
		var collider := CollisionShape3D.new()
		collider.shape=preload("res://scripts/life/boat_hull.gd").shape(size,0)
		actor.add_child(collider)
	if mode=="land":
		var land_shape := preload("res://scripts/life/animal_collision.gd").attach(actor,visual)
		actor.set_meta("animal_shape",land_shape)
	actors.append(actor)

func _populate() -> void:
	# Land routes are accepted only if the entire circuit is safe and dry.
	var count := 0
	for center: Vector3 in tree_positions:
		if count >= 8: break
		var safe := true
		for step in range(32):
			var angle := step * TAU / 32
			if not walkable(center + Vector3(cos(angle) * 1.1, 0, sin(angle) * 0.7)): safe = false; break
		if not safe: continue
		var kind := "forest-rabbit-ea2da0" if count < 4 else ("forest-deer-fe648d" if count < 6 else "red-fox-5c3bc0")
		_actor(kind, center, Vector2(1.1, 0.7), 0.35 if count < 4 else 0.18, 0.8, "land")
		count += 1
	for i in range(12):
		_actor("reef-fish-base" if i % 2 == 0 else "flame-angelfish-ce502b", Vector3(0, -0.65 - (i % 3) * 0.15, 22 + i * 0.35), Vector2(5 + i * 0.3, 0.8), 0.18 + i * 0.01, 0.45, "sea")
	for i in range(16):
		var fish_id:String=preload("res://scripts/life/fish_catalog.gd").DATA.keys()[i%8]
		_actor(fish_id,Vector3(-5+(i%5)*2,-.5-(i%4)*.3,21+(i/5)*4),Vector2(4+i%3,1.2+i%2),.12+i*.008,.5 if i<10 else .8,"sea")
	for i in range(2):
		_actor("reef-shark-base", Vector3(0, -0.8, 29 + i * 4), Vector2(17, 2), 0.12 + i * 0.02, 0.9, "sea")
	for i in range(3):
		_actor("herring-gull-base", Vector3(-2, 6 + i, 4), Vector2(13 + i, 8), 0.14, 1.0, "air")
	_actor("rowboat-c42d85", Vector3(14, -0.62, 27), Vector2(0.12, 0.15), 0.25, 1.0, "boat")
	_actor("rowboat-c42d85", Vector3(-13, -0.62, 29), Vector2(0.1, 0.18), 0.2, 1.0, "boat")

func _process(delta: float) -> void:
	for animation: AnimationPlayer in animators:
		animation.speed_scale = 1.0 if active and visible else 0.0
	if not visible or not active: return
	elapsed += delta
	for actor: Node3D in actors:
		var mode: String = actor.get_meta("mode")
		if mode in ["boat","land"]: continue
		if mode=="air":actor.get_meta("flight").tick(actor,delta);continue
		var center: Vector3 = actor.get_meta("center")
		var radius: Vector2 = actor.get_meta("radius")
		var angle: float = elapsed * float(actor.get_meta("speed")) + float(actor.get_meta("phase"))
		var next := center + Vector3(cos(angle) * radius.x, 0, sin(angle) * radius.y)
		if mode == "land": next.y = height_at(next.x, next.z)
		elif mode == "sea" and world.player != null and world.player.boating and "shark" not in str(actor.get_meta("species")):
			var away: Vector3 = next - world.player.position
			away.y = 0
			if away.length() < 3:
				next += away.normalized() * (3 - away.length())
				next.y = center.y
			# A brief staggered surface leap makes small fish visible from the boat.
			if cos(angle * 2) > 0.985: next.y += pow((cos(angle * 2) - 0.985) / 0.015, 2) * 1.0
		elif mode == "boat": next.y += sin(angle * 2) * 0.06
		elif mode == "air": next.y += sin(angle * 2) * 0.4
		actor.position = next
		if mode=="sea":preload("res://scripts/life/fish_catalog.gd").animate(actor.get_meta("visual"),elapsed+float(actor.get_meta("phase")))
		if mode != "boat": actor.rotation.y = atan2(-sin(angle) * radius.x, cos(angle) * radius.y)

func season_changed(index: int) -> void:
	if ground_material != null:
		ground_material.albedo_color = [Color.WHITE, Color("e5f2cf"), Color("e4c58f"), Color("c2d5dd")][index]

func reveal_player(camera_pos: Vector3, target: Vector3) -> void:
	var ray := target - camera_pos
	if ray.length_squared() < 0.1: return
	for tree: Node3D in trees+extra_trees:
		if not is_instance_valid(tree):continue
		var center := tree.position + Vector3(0, 2.7, 0)
		var t := clampf((center - camera_pos).dot(ray) / ray.length_squared(), 0, 1)
		var nearby := Vector2(target.x-tree.position.x,target.z-tree.position.z).length()<float(tree.get_meta("foliage_radius",1.0))+.7
		var obstructing := nearby or (center.distance_to(camera_pos + ray * t) < 2.0 and t < 0.98)
		if batching and batch_links.has(tree.get_instance_id()):
			for link: Dictionary in batch_links[tree.get_instance_id()]:
				if bool(link.obstructing) != obstructing:
					link.batch.multimesh.set_instance_transform(link.index,Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO) if obstructing else link.transform)
					link.mesh.visible = obstructing
					link.obstructing = obstructing
		if obstructing == bool(faded.get(tree.get_instance_id(), false)): continue
		faded[tree.get_instance_id()] = obstructing
		for mesh: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
			for surface: int in mesh.get_meta("foliage_surfaces",[]):
				var mat := mesh.get_active_material(surface) as StandardMaterial3D
				if mat == null: continue
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if obstructing else BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = 0.22 if obstructing else 1.0

func set_tree_batching(enabled: bool) -> void:
	if batching == enabled: return
	batching = enabled
	if enabled and tree_batches.is_empty():
		var groups: Dictionary = {}
		for tree: Node3D in trees:
			for mesh: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
				var key := "%s:%d:%d" % [mesh.mesh.get_rid().get_id(),floori(tree.position.x/16),floori(tree.position.z/16)]
				if not groups.has(key): groups[key] = []
				groups[key].append({"tree":tree,"mesh":mesh,"transform":global_transform.affine_inverse()*mesh.global_transform})
		for key: String in groups:
			var entries: Array = groups[key]
			var batch := MultiMeshInstance3D.new()
			batch.name = "ForestTreeBatch"
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			var first: MeshInstance3D = entries[0].mesh
			var geometry := first.mesh.duplicate() as ArrayMesh
			for surface in range(geometry.get_surface_count()):
				var mat := first.get_active_material(surface).duplicate() as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = 1
				geometry.surface_set_material(surface,mat)
			multi.mesh = geometry
			multi.instance_count = entries.size()
			batch.multimesh = multi
			add_child(batch)
			tree_batches[key] = batch
			for i in range(entries.size()):
				var entry: Dictionary = entries[i]
				multi.set_instance_transform(i,entry.transform)
				var id: int = entry.tree.get_instance_id()
				if not batch_links.has(id): batch_links[id] = []
				batch_links[id].append({"batch":batch,"index":i,"transform":entry.transform,"mesh":entry.mesh,"obstructing":false})
	for batch: MultiMeshInstance3D in tree_batches.values(): batch.visible = enabled
	for tree: Node3D in trees:
		for mesh: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false): mesh.visible = not enabled
	if enabled:
		for links: Array in batch_links.values():
			for link: Dictionary in links:
				link.batch.multimesh.set_instance_transform(link.index,link.transform)
				link.obstructing = false
	faded.clear()

func _physics_process(_delta: float) -> void:
	if not visible or not active: return
	for actor: Node3D in actors:
		if actor.get_meta("mode")=="land":
			if preload("res://scripts/life/pet_social.gd").tick_animal(world,actor,_delta):continue
			var center: Vector3=actor.get_meta("center")
			var radius: Vector2=actor.get_meta("radius")
			var angle: float=elapsed*float(actor.get_meta("speed"))+float(actor.get_meta("phase"))
			var target := center+Vector3(cos(angle)*radius.x,0,sin(angle)*radius.y)
			if not walkable(target):continue
			var body := actor as CharacterBody3D
			var heading := atan2(-sin(angle)*radius.x,cos(angle)*radius.y)
			if preload("res://scripts/life/animal_collision.gd").clear_at(body,body.get_meta("animal_shape"),body.position,heading):body.rotation.y=heading
			var old := body.position
			var offset := target-old;offset.y=0
			body.velocity=offset.limit_length(.8*_delta)/maxf(_delta,.001)
			body.move_and_slide()
			if not walkable(body.position):body.position=old
			body.position.y=height_at(body.position.x,body.position.z)+.02
			continue
		if actor.get_meta("mode")!="boat": continue
		var center: Vector3=actor.get_meta("center")
		var radius: Vector2=actor.get_meta("radius")
		var angle: float=elapsed*float(actor.get_meta("speed"))+float(actor.get_meta("phase"))
		var candidate := center+Vector3(cos(angle)*radius.x,0,sin(angle)*radius.y)
		if world.player==null or not world.player.boating or Vector2(candidate.x-world.player.position.x,candidate.z-world.player.position.z).length()>4.5:
			actor.position=candidate
		var visual: Node3D=actor.get_meta("visual")
		visual.position.y=sin(angle*2)*.06
