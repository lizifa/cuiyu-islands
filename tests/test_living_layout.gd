extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var state=load("res://scripts/life/life_state.gd").new();state.location="villa";state.home_floor=0
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var room=world.villa_room
 var cabinet:MeshInstance3D=room.get_node("TelevisionCabinet")
 var frame:MeshInstance3D=room.get_node("LargeTelevisionFrame")
 var coffee:MeshInstance3D=room.get_node("CoffeeTableTop")
 check(cabinet.position==Vector3(-10.2,1,2.5),"TV cabinet occupies separate west living wall")
 check(frame.mesh.size.z>4.0 and is_equal_approx(frame.position.z,cabinet.position.z),"large television is centred on cabinet")
 var cabinet_front:float=cabinet.position.x+cabinet.mesh.size.x*.5
 var coffee_front:float=coffee.position.x-coffee.mesh.size.x*.5
 check(coffee_front-cabinet_front>=2.9,"three metres clear viewing area")
 var main:Node3D=room.get_node("LivingSofaMain")
 var bounds=AABB();var first=true
 for mesh:MeshInstance3D in main.find_children("*","MeshInstance3D",true,false):
  var a: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  bounds=a if first else bounds.merge(a);first=false
 var coffee_back:float=coffee.position.x+coffee.mesh.size.x*.5
 check(bounds.position.x-coffee_back>=1.0,"one metre passage before actual sofa geometry")
 check(bounds.end.x< -2,"sofa stays inside front wall")
 check(room.get_node("WovenFloorLamp").position.z>cabinet.position.z+cabinet.mesh.size.z*.5,"lamp placed at right of cabinet")
 check(room.get_node("DiningTable").position==Vector3(1.6,.7,11),"table shifted right half metre")
 var query=PhysicsShapeQueryParameters3D.new();var shape=CylinderShape3D.new();shape.radius=.4;shape.height=1.68;query.shape=shape;query.collision_mask=1;query.exclude=[world.player.get_rid()]
 if world.companion!=null:query.exclude.append(world.companion.get_rid())
 for x:float in [(bounds.position.x+coffee_back)*.5]:
  query.transform=Transform3D(Basis.IDENTITY,Vector3(x,1.57,2.5))
  check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"body can pass inside sofa row %s"%x)
 for p:Vector3 in [Vector3(0,1.57,3.85),Vector3(0,1.57,2.5),Vector3(0,1.57,-1.5),Vector3(4.1,1.57,-1.5),Vector3(6,1.57,-1.5)]:
  query.transform=Transform3D(Basis.IDENTITY,p)
  check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"kitchen/living/stair hall stays clear %s"%p)
 check(world.find_interaction("villa_rest").anchor.global_position.distance_to(world.Villa.SOFA_STAND)<.001,"seat approach follows sofa layout")
 print("LIVING LAYOUT: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
