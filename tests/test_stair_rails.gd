extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
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
 var stairs:Node3D=world.props.get_node("ContinuousVillaStairwell")
 var rails:Array[Node]=stairs.find_children("AlignedHandrail*","Node3D",true,false)
 check(rails.size()==7,"four flight handrails and three turning-platform guards")
 for flight in range(2):
  for side_index in range(2):
   var rail:Node3D=rails[flight*2+side_index]
   var mesh:MeshInstance3D=rail.get_child(0)
   var length:float=mesh.mesh.size.z
   var ends:Array[Vector3]=[rail.to_global(Vector3(0,0,-length*.5)),rail.to_global(Vector3(0,0,length*.5))]
   for end:Vector3 in ends:
    var z:float=end.z
    var stairs_type=load("res://scripts/life/villa_stairwell.gd")
    var rise:float=(stairs_type.FRONT-z)/(stairs_type.FRONT-stairs_type.BACK) if flight==0 else (z-stairs_type.BACK)/(stairs_type.FRONT-stairs_type.BACK)
    var floor_y:float=.675+flight*(VillaDimensions.RISE*.5)+rise*(VillaDimensions.RISE*.5)
    check(absf(end.y-floor_y-.95)<.001,"handrail endpoint stays 95cm above matching stair slope")
    check(absf(end.x-((9.25 if flight==0 else 12.0)+(-1.13 if side_index==0 else 1.13)))<.001,"handrail follows outer edge of flight")
   check(rail.find_children("*","StaticBody3D",true,false).size()==1,"handrail collision matches visual beam")
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 for point:Vector3 in [Vector3(9.25,VillaDimensions.BASE+.825,2),Vector3(12,VillaDimensions.UPPER_FLOOR+.825,2),Vector3(10.65,VillaDimensions.BASE+VillaDimensions.RISE*.5+.725,VillaDimensions.STAIR_BACK-.725)]:
  var query:=PhysicsShapeQueryParameters3D.new();var shape:=SphereShape3D.new();shape.radius=.35;query.shape=shape;query.transform.origin=point;query.collision_mask=1;query.exclude=[world.player.get_rid()]
  check(space.intersect_shape(query,1).is_empty(),"flight entrance and platform turning route remain clear")
 # Probe the newly widened edge strips on both floors, with the same body clearance.
 for level:int in [0,1]:
  for z:float in [.75,4.05]:
   var ray:=PhysicsRayQueryParameters3D.create(Vector3(7.3,VillaDimensions.BASE+level*VillaDimensions.RISE+1.2,z),Vector3(8.3,VillaDimensions.BASE+level*VillaDimensions.RISE+1.2,z),1,[world.player.get_rid()])
   check(space.intersect_ray(ray).is_empty(),"widened doorway edge is free of visual-wall collision on floor "+str(level))
 var upper_peek:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(3,4.1,6.5),Vector3(12,6.3,2),17,[world.player.get_rid()]))
 check(not upper_peek.is_empty() and str(upper_peek.collider.name).begins_with("VillaSolid_"),"doorway lintel blocks the stray upper-flight view from the downstairs hall")
 var body_query:=PhysicsShapeQueryParameters3D.new();var body_shape:=CylinderShape3D.new();body_shape.radius=.4;body_shape.height=1.7;body_query.shape=body_shape;body_query.collision_mask=1;body_query.exclude=[world.player.get_rid()]
 for point:Vector3 in [Vector3(5.2,1.6,4.6),Vector3(5.2,1.6,3.5),Vector3(0,1.6,16.8),Vector3(9.25,1.6,1.6)]:
  body_query.transform.origin=point
  check(space.intersect_shape(body_query,1).is_empty(),"doorway and former desk/chair positions are clear "+str(point))
 check(world.villa_room.get_node("StudyDeskTop").position.z>12,"study desk is relocated away from the stair entrance")
 print("STAIR RAILS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
