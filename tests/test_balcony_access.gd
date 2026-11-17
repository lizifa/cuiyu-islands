extends SceneTree
const D=preload("res://scripts/life/villa_dimensions.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new();state.location="villa";state.home_floor=1;state.player_position=[3.2,D.UPPER_FLOOR+.03,16.9]
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 for frame in range(75):await physics_frame
 world.player.set_physics_process(false)
 check(not world.find_interaction("villa_balcony").is_empty(),"balcony entry prompt exists")
 check(not world.find_interaction("villa_balcony_return").is_empty(),"balcony return prompt exists")
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.3;shape.height=1.6;query.shape=shape;query.collision_mask=1;query.exclude=[world.player.get_rid()]
 for z:float in [17.5,18.0,18.4,18.8,19.4]:
  query.transform.origin=Vector3(3.2,D.UPPER_FLOOR+.85,z)
  check(space.intersect_shape(query,1).is_empty(),"balcony doorway body clearance "+str(z))
 check(world.visit_balcony(state),"balcony entrance succeeds")
 check(world.on_balcony(),"balcony position recognized")
 check(world.terrain_walkable(world.player.position),"balcony deck walkable")
 check(not world.terrain_walkable(Vector3(4,D.UPPER_FLOOR,27)),"sea beyond balcony is not walkable")
 var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(3.2,7,21),Vector3(3.2,5,21),1,[world.player.get_rid()]))
 check(not floor_hit.is_empty() and absf(floor_hit.position.y-D.UPPER_FLOOR)<.02,"balcony deck matches upstairs height")
 var guard:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(3.2,6.5,21),Vector3(3.2,6.5,27),1,[world.player.get_rid()]))
 check(not guard.is_empty(),"balcony sea edge physically guarded")
 check(world.orbit.activity_key=="balcony","balcony uses outdoor camera")
 world.orbit.set_process(false)
 for frame in range(300):world.orbit.motion_enabled=true;world.orbit._process(1./60)
 check(world.orbit._body_framed(world.player),"balcony camera includes complete character")
 check(world.environment.environment.background_mode==Environment.BG_SKY,"balcony opens sky background")
 check(world.return_from_balcony(state) and not world.on_balcony(),"return doorway leads upstairs")
 check(world.orbit.activity_key!="balcony","return releases balcony camera")
 state.home_floor=0;world.sync(state)
 check(not world.visit_balcony(state),"ground floor cannot enter upstairs balcony")
 print("BALCONY: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
