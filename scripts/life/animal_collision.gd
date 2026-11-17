extends RefCounted
## Conservative, model-sized body footprint. Render animation never sets body position.
static func attach(body: CharacterBody3D, visual: Node3D) -> CollisionShape3D:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		var box: AABB=(body.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var shape := BoxShape3D.new()
	shape.size=Vector3(maxf(.25,bounds.size.x),maxf(.25,bounds.size.y-.06),maxf(.35,bounds.size.z))
	var collider := CollisionShape3D.new();collider.shape=shape;collider.name="AnimalBodyCollider"
	collider.position=bounds.get_center()+Vector3.UP*.03
	body.add_child(collider)
	body.collision_layer=1;body.collision_mask=3
	body.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	body.set_meta("animal_obstacle",true)
	return collider
static func clear_at(body: CharacterBody3D, collider: CollisionShape3D, pos: Vector3, heading: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=collider.shape;query.collision_mask=3;query.exclude=[body.get_rid()]
	query.transform=Transform3D(Basis(Vector3.UP,heading),pos)*collider.transform
	return body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
