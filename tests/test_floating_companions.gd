extends SceneTree
const Catalog=preload("res://scripts/life/companion_catalog.gd")
const State=preload("res://scripts/life/life_state.gd")
var checks:=0
var failed:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.set_physics_process(false)
 await physics_frame;await physics_frame
 app._open_arrival()
 check(app.arrival.pet_wheel.values.size()==6,"five companions plus solo available")
 var inventory=app.state.inventory.duplicate(true)
 for kind in Catalog.FLOATING:
  app.arrival._select_pet(kind)
  check(app.arrival.preview.get_child_count()==2,kind+" selection has real 3D preview")
  check(app.arrival.confirm(),kind+" confirms")
  check(app.state.inventory==inventory,kind+" keeps inventory")
  var restored=State.new();check(restored.restore(app.state.snapshot()) and restored.profile.pet==kind,kind+" saved and restored")
  var pet=app.world.companion;var actor=app.world.player
  actor.set_physics_process(false);pet.set_physics_process(false);actor.allowed=true
  check(pet.get_script().resource_path.ends_with("floating_companion.gd"),kind+" uses aerial movement")
  check(pet.collision_layer==0 and pet.collision_mask==0,kind+" does not block player")
  actor.position=Vector3(0,.7,3.2);pet.recover()
  for i in 90:pet._physics_process(1./60)
  check(pet.position.y>actor.position.y+.6,kind+" hovers above ground")
  actor.position+=Vector3(3,0,0)
  for i in 90:pet._physics_process(1./60)
  check(pet.position.distance_to(actor.position)<2.0,kind+" follows moving player")
  actor.allowed=false;var before=pet.position;var clock=pet.clock
  pet._physics_process(1)
  check(pet.position==before and pet.clock==clock,kind+" freezes while paused")
  actor.allowed=true;actor.boating=true
  for i in 90:pet._physics_process(1./60)
  check(pet.position.y>actor.position.y+.8 and pet.position.distance_to(actor.position)<2.0,kind+" accompanies boat")
  actor.boating=false;pet.position=Vector3(100,100,100);pet._physics_process(.1)
  check(pet.position.distance_to(actor.position)<2,kind+" recovers if left behind")
  pet.reserve_interaction(actor.position);check(pet.held_for_interaction,kind+" yields to interaction")
  pet.release_interaction();check(not pet.held_for_interaction,kind+" releases interaction")
  pet.petting=6
  for i in 120:pet._physics_process(1./60)
  check(pet.position.y<actor.position.y+.4,kind+" descends for petting")
  check(app.world.pet_companion(app.state),kind+" pet interaction starts")
  for i in 120:actor._update_pet(1./60)
  check(actor.pose_skeleton!=null,kind+" player uses petting rig")
  if actor.pose_skeleton!=null:
   var hand:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("RightHand")).origin
   check(hand.distance_to(actor.last_hand_target)<.12,kind+" hand reaches actual companion")
  actor.cancel_pet()
  app._open_arrival()
 app._close_drawers();app.queue_free();await process_frame
 var invalid=State.new().snapshot();invalid.profile.pet="unlicensed_bird"
 check(not State.new().restore(invalid),"unlisted companion rejected")
 print("FLOATING COMPANIONS: ",checks," checks, ",failed," failed")
 quit(1 if failed else 0)
