extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var state=load("res://scripts/life/life_state.gd").new();state.location="villa"
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 for room:Node3D in world.villa_rooms:
  var floor_mesh:MeshInstance3D=room.get_node("InteriorFloor")
  var material:StandardMaterial3D=floor_mesh.material_override
  check(material.albedo_texture!=null and material.albedo_texture.get_image().has_mipmaps(),"floor seams have mip levels")
  check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"floor seams use filtered anisotropic sampling")
  var strips:=0
  for mesh:MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh is BoxMesh and is_equal_approx(mesh.mesh.size.z,11.5) and mesh.mesh.size.x<.03:strips+=1
  check(strips==0,"no thin floating seam geometry remains")
 var stairs:Node3D=world.props.get_node("ContinuousVillaStairwell")
 var duplicates:=0
 for mesh:MeshInstance3D in stairs.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh is BoxMesh and is_equal_approx(mesh.mesh.size.x,1.3) and is_equal_approx(mesh.mesh.size.z,1.5):duplicates+=1
 check(duplicates==0,"ground landing has no duplicate coplanar slab")
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 for p:Vector2 in [Vector2(8.1,2.1),Vector2(8.6,2.7),Vector2(9.2,3.4),Vector2(10.5,4)]:
  var hits:=0;var exclude:Array[RID]=[world.player.get_rid()]
  for i in range(8):
   var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,1,p.y),Vector3(p.x,.64,p.y),1,exclude)
   var hit:Dictionary=space.intersect_ray(query)
   if hit.is_empty():break
   if absf(hit.position.y-.675)<.001:hits+=1
   exclude.append(hit.rid)
  check(hits==1,"one physical floor at ground landing "+str(p))
 check(is_equal_approx(world.camera.near,.12) and is_equal_approx(world.camera.far,45),"indoor depth range excludes distant ocean")
 state.location="island";world.sync(state)
 check(is_equal_approx(world.camera.near,.05) and is_equal_approx(world.camera.far,2400),"outdoor depth range restores on exit")
 print("FLOOR SURFACES: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
