extends RefCounted
## Cached source triangles are clipped at world-height bands after model scaling.
static var tree_triangles: Dictionary = {}
static var tree_meshes: Dictionary = {}
static var camera_shapes: Dictionary = {}
static func clip_height(points: Array[Vector3], height: float, above: bool) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if points.is_empty(): return result
	var previous: Vector3=points[-1]
	var previous_inside: bool=previous.y>=height if above else previous.y<=height
	for point: Vector3 in points:
		var inside: bool=point.y>=height if above else point.y<=height
		if inside!=previous_inside:
			result.append(previous.lerp(point,(height-previous.y)/(point.y-previous.y)))
		if inside: result.append(point)
		previous=point;previous_inside=inside
	return result
static func tree(node: Node3D, id: String) -> float:
	if not tree_triangles.has(id):
		var triangles: Array=[]
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			var relative := node.global_transform.affine_inverse()*mesh.global_transform
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				for i in range(0,indices.size(),3):
					var color: Color=colors[indices[i]] if not colors.is_empty() else Color.WHITE
					# The supplied assets mark foliage green and bark brown/cream.
					# Leaves are soft occlusion, never a solid wall around the crown.
					if color.g>color.r*1.12 and color.g>color.b*1.12: continue
					var triangle: Array[Vector3]=[relative*vertices[indices[i]],relative*vertices[indices[i+1]],relative*vertices[indices[i+2]]]
					triangles.append(triangle)
		tree_triangles[id]=triangles
	var foliage_radius := 0.0
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		foliage_radius=maxf(foliage_radius,Vector2(mesh.get_aabb().size.x,mesh.get_aabb().size.z).length()*.5*node.scale.x)
		split_foliage(mesh,id+":"+str(mesh.name))
		# Full visual geometry for cameras only. Player/animal movement keeps
		# its existing height bands and can still pass beneath soft foliage.
		var camera_key:String=id+":"+str(mesh.name)
		if not camera_shapes.has(camera_key):
			var full_shape:ConcavePolygonShape3D=mesh.mesh.create_trimesh_shape()
			full_shape.backface_collision=true
			camera_shapes[camera_key]=full_shape
		var camera_body:=StaticBody3D.new();camera_body.name="CameraTreeSurface";camera_body.collision_layer=64;camera_body.collision_mask=0
		mesh.add_child(camera_body)
		var camera_collider:=CollisionShape3D.new();camera_collider.shape=camera_shapes[camera_key];camera_body.add_child(camera_collider)
	node.set_meta("foliage_radius",foliage_radius)
	var body := StaticBody3D.new()
	body.name="TreeObstacle"
	body.collision_layer=9 # Ordinary solids plus tree-only head/shoulder clearance.
	node.add_child(body)
	var scale_value := node.global_basis.get_scale().x
	var radius := 0.0
	var bands := [-.12,.4,.9,1.4,1.9,2.5,3.0]
	for band in range(bands.size()-1):
		var low: float=bands[band]/scale_value
		var high: float=bands[band+1]/scale_value
		var footprint := PackedVector2Array()
		var band_radius := 0.0
		for triangle: Array in tree_triangles[id]:
			var polygon: Array[Vector3]=[]
			polygon.assign(triangle)
			polygon=clip_height(clip_height(polygon,low,true),high,false)
			for point: Vector3 in polygon:
				var flat := Vector2(point.x,point.z)
				# A small, world-sized skin prevents surface flicker at contact.
				if flat.length()>.001: flat+=flat.normalized()*(.025/scale_value)
				footprint.append(flat)
				band_radius=maxf(band_radius,flat.length()*scale_value)
		if footprint.size()<3: continue
		var outline := Geometry2D.convex_hull(footprint)
		var points := PackedVector3Array()
		for point: Vector2 in outline:
			for height: float in [low,high]: points.append(Vector3(point.x,height,point.y))
		var shape := ConvexPolygonShape3D.new();shape.points=points
		var collider := CollisionShape3D.new();collider.shape=shape
		collider.name="TreeBand%d"%band
		body.add_child(collider)
		if band==0: node.set_meta("root_radius",band_radius)
		radius=maxf(radius,band_radius)
	node.set_meta("solid_radius",radius)
	return radius
static func split_foliage(mesh: MeshInstance3D, key: String) -> void:
	var materials: Array[Material]=[]
	for surface in range(mesh.mesh.get_surface_count()):materials.append(mesh.get_active_material(surface))
	if not tree_meshes.has(key):
		var geometry := ArrayMesh.new()
		var origins: Array[int]=[]
		var foliage: Array[int]=[]
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var wood := PackedInt32Array();var leaves := PackedInt32Array()
			for index in range(0,indices.size(),3):
				var color: Color=colors[indices[index]] if not colors.is_empty() else Color.WHITE
				var green := color.g>color.r*1.12 and color.g>color.b*1.12
				for offset in range(3):
					if green:leaves.append(indices[index+offset])
					else:wood.append(indices[index+offset])
			for group: PackedInt32Array in [wood,leaves]:
				if group.is_empty():continue
				var copy := arrays.duplicate();copy[Mesh.ARRAY_INDEX]=group
				if group==leaves:foliage.append(geometry.get_surface_count())
				geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy)
				geometry.surface_set_material(geometry.get_surface_count()-1,materials[surface])
				origins.append(surface)
		tree_meshes[key]={"mesh":geometry,"origins":origins,"foliage":foliage}
	var entry: Dictionary=tree_meshes[key]
	mesh.mesh=entry.mesh
	mesh.set_meta("foliage_surfaces",entry.foliage)
	for surface in range(entry.origins.size()):mesh.set_surface_override_material(surface,materials[entry.origins[surface]].duplicate())

static func convex(node: Node3D) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var body := StaticBody3D.new()
		body.name = "PropObstacle"
		var collider := CollisionShape3D.new()
		collider.shape = mesh.mesh.create_convex_shape(true, false)
		body.add_child(collider)
		mesh.add_child(body)
