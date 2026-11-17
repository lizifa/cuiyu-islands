extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new();var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var islands:Array=world.seascape.islands
 check(islands.size()==4,"all four cone placeholders replaced")
 var kinds:Dictionary={};var areas:Array[float]=[];var pools:Dictionary={}
 var expected:Array[String]=["forest-rabbit-ea2da0","forest-deer-fe648d","red-fox-5c3bc0","herring-gull-base","reef-fish-base","flame-angelfish-ce502b","reef-shark-base"]
 for id:String in load("res://scripts/life/fish_catalog.gd").DATA:expected.append(id)
 for island:Node3D in islands:
  kinds[island.spec.kind]=true;areas.append(island.spec.radii.x*island.spec.radii.y)
  check(island.terrain.mesh is ArrayMesh,"natural terrain mesh "+island.name)
  var vertices:PackedVector3Array=island.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  check(vertices.size()>1000 and vertices.size()<12000,"bounded detailed terrain "+island.name)
  check(Array(vertices).all(func(p):return p.is_finite()),"terrain has no holes or invalid heights "+island.name)
  var normals:PackedVector3Array=island.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
  check(Array(normals).all(func(n):return n.y>0),"land normals face sky "+island.name)
  check(island.tree_positions.all(func(p):return absf(p.y-island.surface_height_at(Vector2(p.x,p.z)))<.001),"trees sit on rendered terrain "+island.name)
  check(island.tree_count==island.spec.trees and island.tree_count>=14,"island populated with trees "+island.name)
  var species:Array=[]
  for animal:Dictionary in island.wildlife:species.append(animal.id)
  var pool:Dictionary=island.creature_pool()
  var want:Array=[]
  for group:String in ["land","air","sea"]:want.append_array(pool[group])
  check(want.all(func(id):return id in species),"island runs its own creature pool "+island.name)
  check(species.size()==want.size(),"pool size matches configuration "+island.name)
  var other_species:Array=Array(expected).filter(func(id):return id not in want)
  check(other_species.all(func(id):return id not in species),"no foreign species leaks in "+island.name)
  pools[String(island.spec.id)]=want
  check(island.terrain.find_children("*","StaticBody3D",true,false).size()==1,"islands have terrain collision for landing "+island.name)
  check(island.find_children("*","AnimationPlayer",true,false).all(func(a):return a.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL),"distant wildlife does not constantly animate offscreen "+island.name)
  var first:float=island.height_at(Vector2(3,2));check(first==island.height_at(Vector2(3,2)),"terrain is reproducible "+island.name)
  check(absf(island.shoreline(0)-island.shoreline(TAU))<.001,"coastline closes without a seam "+island.name)
  for animal:Dictionary in island.wildlife:
   island._move_animal(animal,12)
   check(animal.node.position.is_finite(),"wildlife stays in valid space "+str(animal.id))
 var unique_pools:=true
 var keys:Array=pools.keys()
 for i in range(keys.size()):
  for j in range(i+1,keys.size()):
   if pools[keys[i]]==pools[keys[j]]:unique_pools=false
 check(unique_pools,"each island has a different creature pool")
 check(kinds.size()==4,"four distinct island shapes")
 areas.sort();check(areas[-1]/areas[0]>5,"large and small islands have visibly different footprints")
 var cylinders:=0
 for mesh:MeshInstance3D in world.seascape.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh is CylinderMesh and mesh.mesh.top_radius==0:cylinders+=1
 check(cylinders==0,"no cone island silhouettes remain")
 print("DISTANT ISLANDS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
