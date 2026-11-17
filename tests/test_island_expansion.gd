extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func area(mesh:Mesh,transform:Transform3D)->float:
 var total:=0.0
 for surface in range(mesh.get_surface_count()):
  var arrays: Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for i in range(0,indices.size(),3):
   var a:Vector3=transform*vertices[indices[i]];var b:Vector3=transform*vertices[indices[i+1]];var c:Vector3=transform*vertices[indices[i+2]]
   total+=absf((b-a).cross(c-a).y)*.5
 return total
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new()
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var forest:Node3D=world.forest;forest.set_process(false)
 var original:MeshInstance3D
 for node:Node in forest.get_child(0).find_children("*","MeshInstance3D",true,false):
  if node.name=="woodland":original=node
 var baked:MeshInstance3D
 for node:Node in forest.get_children():
  if node is MeshInstance3D and node.mesh is ArrayMesh:baked=node;break
 check(original!=null and baked!=null,"original and expanded terrain exist")
 var ratio:float=area(baked.mesh,baked.global_transform)/area(original.mesh,original.global_transform)
 check(absf(ratio-2)<.001,"horizontal land footprint doubled")
 var outer:=0
 for x in range(-40,41,2):
  for z in range(-45,-24,2):
   if forest.walkable(Vector3(x,0,z)):outer+=1
 check(outer>10,"expanded northern land is walkable")
 check(forest.tree_positions.size()>=55,"new land has additional trees")
 check(world.terrain_walkable(Vector3(3,0,15.3)),"pier approach remains walkable")
 check(absf(forest.road_height(11)-1.3)<.001,"villa road retains height")
 print("ISLAND EXPANSION: %d passed, %d failed; footprint %.4f, outer samples %d, trees %d"%[passed,failed,ratio,outer,forest.tree_positions.size()]);quit(1 if failed else 0)
