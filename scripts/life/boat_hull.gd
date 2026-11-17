extends RefCounted
## Both boats use the same hull silhouette; oars never enlarge solid contact.
static var outline := PackedVector2Array()
static var bottom := 0.0
static var top := 0.0
static func shape(model_scale: float, visual_y: float) -> ConvexPolygonShape3D:
	if outline.is_empty():
		var model: Node3D=load("res://assets/polyfork/rowboat-c42d85.glb").instantiate()
		var mesh: MeshInstance3D=model.find_child("hull",true,false)
		var relative := mesh.transform
		var parent := mesh.get_parent()
		while parent!=null and parent!=model:
			relative=parent.transform*relative
			parent=parent.get_parent()
		relative=model.transform*relative
		var footprint := PackedVector2Array()
		bottom=INF;top=-INF
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := relative*vertex
				footprint.append(Vector2(point.x,point.z))
				bottom=minf(bottom,point.y);top=maxf(top,point.y)
		outline=Geometry2D.convex_hull(footprint)
		model.free()
	var points := PackedVector3Array()
	for point: Vector2 in outline:
		for height: float in [bottom,top]:
			points.append(Vector3(point.x*model_scale,height*model_scale+visual_y,point.y*model_scale))
	var result := ConvexPolygonShape3D.new()
	result.points=points
	return result
