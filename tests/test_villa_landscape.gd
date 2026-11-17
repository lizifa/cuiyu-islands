extends SceneTree
var failures := 0
var passed := 0
func check(ok: bool, message: String) -> void:
 if ok: passed += 1
 else: failures += 1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var state=load("res://scripts/life/life_state.gd").new()
 var world=load("res://scripts/life/life_world.gd").new()
 root.add_child(world);world.sync(state)
 await physics_frame
 await physics_frame
 if world.companion != null:
  world.companion.collision_layer=0
  world.companion.set_physics_process(false)
 var forest=world.forest
 var paving: MeshInstance3D=forest.get_node("VillaConcretePromenade")
 var paving_normals: PackedVector3Array=paving.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 check(paving_normals.size()>0,"paving mesh is present")
 check(Array(paving_normals).all(func(n):return n.y>0.0),"paving has only upward-facing road surfaces")
 check(forest.ROAD.size==Vector2(13,4),"four-metre concrete promenade")
 for x: float in [3.1,4.,5.,6.,7.,9.,11.,13.,15.9]:
  for z: float in [1.9,3.8,5.7]:
   var y: float=forest.height_at(x,z)
   var hit=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,8,z),Vector3(x,-2,z),1))
   check(not hit.is_empty() and absf(hit.position.y-y)<.025,"road physics matches walking height %s %s"%[x,z])
   check(world.terrain_walkable(Vector3(x,y,z)),"continuous dry road")
 for tree: Node3D in forest.trees+forest.extra_trees:
  check(not forest.reserved_garden(tree.position,1.),"road and shoulders are free of trees")
 for i in range(forest.tree_positions.size()):
  for j in range(i):
   check(forest.tree_positions[i].distance_to(forest.tree_positions[j])>=2.7,"spaced tree crowns")
 for x: float in [3.2,5.,7.,9.,11.,14.,15.5]:
  world.player.position=Vector3(x,world.terrain_height(x,3.8)+.08,3.8)
  world.player.set_physics_process(false)
  for step in range(3):await physics_frame
  check(not world.player.test_move(world.player.global_transform,Vector3(0,0,.8)),"clear broad front path")
 print("VILLA LANDSCAPE: %d passed, %d failed"%[passed,failures])
 quit(1 if failures else 0)
