extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.time_scale=5;Engine.physics_ticks_per_second=120
 var state=load("res://scripts/life/life_state.gd").new();var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var actor:CharacterBody3D=world.player;actor.set_physics_process(false)
 for island:Node3D in world.seascape.islands:
  var site:Dictionary=world.exploration._sites(island)[0]
  world._set_boating(true);actor.position=site.berth;actor.boat_heading=site.heading;actor.hull_collider.rotation.y=site.heading
  await physics_frame;await physics_frame
  var began:bool=world.return_pilot.start()
  print("OCEAN ROUTE ",island.spec.id," ",began," nodes ",world.return_pilot.path.size()," ",world.return_pilot.status)
  check(began,"remote island has a planned route home "+str(island.spec.id))
  var valid:=true;var previous:Vector3=actor.position
  for point:Vector3 in world.return_pilot.path:
   for step in range(1,maxi(2,ceili(point.distance_to(previous)/2))):
    if not world.navigable_water(previous.lerp(point,step/float(maxi(2,ceili(point.distance_to(previous)/2))))):valid=false
   previous=point
  check(valid,"return route avoids all islands "+str(island.spec.id))
  world.return_pilot.cancel();world._set_boating(false)
 # Drive the real collision-aware controller home from each of the four islands.
 for island:Node3D in world.seascape.islands:
  var site:Dictionary=world.exploration._sites(island)[0]
  actor.position=world.DOCK;world.board_boat(state);actor.position=site.berth;actor.boat_heading=site.heading;actor.hull_collider.rotation.y=site.heading
  actor.set_physics_process(true);actor.allowed=true
  check(world.return_pilot.start(),"long return begins "+str(island.spec.id))
  for frame in range(7000):
   if not actor.boating:break
   actor.move_input=world.return_pilot.tick(5./120,Vector2.ZERO)
   await physics_frame
   if not world.return_pilot.active and actor.boating:break
  check(not actor.boating,"real distant return reaches dock "+str(island.spec.id)+" "+world.return_pilot.status+" at "+str(actor.position))
  check(actor.position.distance_to(world.DOCK)<1,"return lands on home dock "+str(island.spec.id))
  actor.set_physics_process(false)
 print("ARCHIPELAGO RETURN: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
