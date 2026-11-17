extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new();var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame;await physics_frame
 var actor:CharacterBody3D=world.player;actor.set_physics_process(false)
 check(world.navigable_water(Vector3(90,.05,60)),"old sea boundary is open")
 check(not world.navigable_water(Vector3(610,.05,0)),"finite outer sea boundary remains")
 for island:Node3D in world.seascape.islands:
  var candidates:Array=world.exploration._sites(island)
  print("LANDING SITES ",island.spec.id," ",candidates.size())
  check(candidates.size()==1,"single fixed dock "+str(island.spec.id))
  if candidates.is_empty():continue
  var site:Dictionary=candidates[0]
  check(world.navigable_water(site.berth) and world.terrain_walkable(site.land),"water and land endpoints valid "+str(island.spec.id))
  check(not world.navigable_water(island.to_global(Vector3(0,1,0))),"boat cannot drive through island "+str(island.spec.id))
  if not actor.boating:world._set_boating(true)
  actor.position=site.berth
  var cue:Dictionary=world.nearby_action()
  check(cue.kind=="remote_land","near coast offers landing "+str(island.spec.id))
  check(world.exploration.land(site),"landing succeeds "+str(island.spec.id))
  check(not actor.boating and actor.rowing_pose==null and world.exploration.active_island==island,"walking restored on new island")
  check(world.terrain_height(actor.position.x,actor.position.z)>.12 and actor.position.y>0,"character placed above actual island terrain")
  check(not island.near_props.is_empty() and world.forest.extra_trees.size()>=island.tree_count,"trees and rocks gain real collision/visibility")
  check(world.nearby_action().kind=="remote_return","shore offers return to boat")
  check(world.own_boat.position.distance_to(site.berth-Vector3.UP*.62)<.01,"own boat stays at visited coast")
  var snapshot:Dictionary=state.snapshot();snapshot.player_position=[actor.position.x,actor.position.y,actor.position.z]
  var restored=load("res://scripts/life/life_state.gd").new()
  check(restored.restore(snapshot) and restored.island_visit.id==site.id,"remote island and parked boat survive save roundtrip")
  var bad:Dictionary=snapshot.duplicate(true);bad.island_visit.berth=[NAN,0,0]
  check(not restored.restore(bad),"invalid parked boat coordinates rejected")
  world.last_location="";world.sync(restored);state=restored
  await physics_frame;await physics_frame
  check(world.exploration.active_island==island and actor.position.distance_to(site.land)<.05,"reload restores visited shore")
  check(world.own_boat.position.distance_to(site.berth-Vector3.UP*.62)<.01,"reload restores boat berth")
  state.hunger=0;state.thirst=0
  check(world.exploration.return_to_boat(),"quick return does not strand an exhausted explorer")
  check(actor.boating and actor.position.distance_to(site.berth)<.01 and actor.rowing_pose!=null,"quick return boards the parked boat")
  check(world.save_position().distance_to(site.land)<.01,"sea save returns to last safe shore")
  await physics_frame;await physics_frame
  state.hunger=100;state.thirst=100
  actor.position=world.MOORING
  check(world.disembark_boat() and state.island_visit.is_empty(),"returning home clears remote berth")
  await physics_frame;await physics_frame
 print("ISLAND EXPLORATION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
