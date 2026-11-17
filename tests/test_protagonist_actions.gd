extends SceneTree
const Catalog=preload("res://scripts/life/character_catalog.gd")
var failed:=0
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var state=load("res://scripts/life/life_state.gd").new()
 state.location="villa";state.home_floor=1
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 for id in Catalog.CHARACTERS:
  state.profile.character_id=id;world.sync(state)
  var actor=world.player;actor.set_physics_process(false);actor.allowed=true
  check(actor.visual.get_meta("character_id")==id,id+" world uses selected appearance")
  check(actor.start_work("gather",actor.position+Vector3.FORWARD),id+" work starts")
  actor._update_work(.2);actor.cancel_work()
  check(actor.sit_on_sofa(actor.position),id+" seated pose starts")
  actor._update_sofa(.3);actor.leave_sofa()
  var anchor=world.Villa.BED_ANCHOR;anchor.y=world.villa_room.bed_surface()
  check(actor.lie_on_bed(anchor),id+" bed rig starts")
  actor.position=actor.bed_motion.standing_root
  for step in range(150):
   actor.bed_motion.tick(.1)
   if actor.bed_stage=="resting":break
  check(actor.bed_stage=="resting",id+" reaches lying rest without phantom clothing actions")
  actor.cancel_bed()
  check(actor.pose_skeleton==null and actor.bed_motion==null,id+" cancel clears pose ownership")
  for value in [actor.position,actor.visual.scale]:check(value.is_finite(),id+" finite transform")
 world.queue_free()
 await process_frame
 print("PROTAGONIST ACTIONS: ",checks," checks, ",failed," failed")
 quit(1 if failed else 0)
