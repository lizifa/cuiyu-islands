extends Marker3D
## Owned by a prop/scene root. Child markers remain editable with that prefab.
@export var radial := false
@export var arrival_radius := .2
@export var exact_stand := false
var facing: Marker3D
var camera_hint: Marker3D
func configure(stand: Vector3, target: Vector3, camera_offset: Vector3) -> void:
 global_transform=Transform3D(Basis.IDENTITY,stand)
 if facing==null:
  facing=Marker3D.new();facing.name="FacingTarget";add_child(facing)
  camera_hint=Marker3D.new();camera_hint.name="RecommendedCamera";add_child(camera_hint)
 facing.global_position=target
 camera_hint.global_position=stand+camera_offset
func view_spec() -> Dictionary:
 var offset := camera_hint.global_position-global_position
 return {"yaw":atan2(offset.x,offset.z),"pitch":asin(offset.y/maxf(offset.length(),.001)),"distance":offset.length()}
