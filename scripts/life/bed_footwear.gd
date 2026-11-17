extends RefCounted
## Two copies of the equipped footwear, separated by side, placed beside the bed.
var actor:Node3D
var source:MeshInstance3D
var original_visible:=false
var root:Node3D
var shoes:Array[MeshInstance3D]=[]
var removed:=[false,false]
func setup(owner_actor:Node3D) -> void:
 actor=owner_actor;source=actor.visual.find_child("attach-feet-mesh",true,false)
 if source==null:return
 original_visible=source.visible
 root=Node3D.new();root.name="BedsideShoes";actor.get_parent().add_child(root)
 for side in range(2):
  var shoe:=MeshInstance3D.new();var geometry:=ArrayMesh.new()
  var foot:int=actor._bone(("Left" if side==0 else "Right")+"Foot")
  var pivot:Vector3=actor.pose_skeleton.get_bone_global_rest(foot).origin
  for surface in range(source.mesh.get_surface_count()):
   var arrays:Array=source.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for i in range(vertices.size()):indices.append(i)
   var selected:=PackedInt32Array()
   for i in range(0,indices.size(),3):
    var x:float=(vertices[indices[i]].x+vertices[indices[i+1]].x+vertices[indices[i+2]].x)/3
    if signf(x)==signf(pivot.x):selected.append_array(indices.slice(i,i+3))
   if selected.is_empty():continue
   for i in range(vertices.size()):vertices[i]-=pivot
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=selected;arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null
   geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   geometry.surface_set_material(geometry.get_surface_count()-1,source.get_active_material(surface))
  shoe.mesh=geometry;root.add_child(shoe);shoe.hide();shoes.append(shoe)
func floor_position(side:int) -> Vector3:
 return Vector3(-3.35,actor.bed_return.y+.09,-3.05+(.28 if side==0 else -.28))
func foot_position(side:int) -> Vector3:
 return actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone(("Left" if side==0 else "Right")+"Foot")).origin
func animate(t:float,taking_off:bool) -> void:
 if source==null:return
 source.hide()
 for side in range(2):
  var progress:float=smoothstep(0,1,clampf(t*2-side,0,1))
  var off:float=progress if taking_off else 1-progress
  removed[side]=off>.99
  var shoe:MeshInstance3D=shoes[side];shoe.visible=original_visible
  shoe.global_basis=Basis(Vector3.UP,PI/2)*Basis.from_scale(Vector3.ONE*actor.pose_skeleton.global_basis.get_scale().y)
  shoe.global_position=foot_position(side).lerp(floor_position(side),off)+Vector3.UP*sin(off*PI)*.15
 if not taking_off and t>=1:source.visible=original_visible;root.hide()
func dispose(detach:bool=true) -> void:
 if is_instance_valid(source):source.visible=original_visible
 if is_instance_valid(root):
  root.hide()
  if detach and root.get_parent()!=null:root.get_parent().remove_child(root)
  root.queue_free()
