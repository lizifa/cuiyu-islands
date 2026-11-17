extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():
 if "--test-mode" not in OS.get_cmdline_user_args():quit(1);return
 call_deferred("run")
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);await frames(4)
 var actor:CharacterBody3D=app.world.player;actor.set_physics_process(false);actor.move_input=Vector2.ZERO;actor.allowed=true
 for kind:String in ["dog","cat","rabbit"]:
  app.state.profile.pet=kind;app.world.sync(app.state);await frames(3)
  actor=app.world.player;actor.set_physics_process(false);actor.allowed=true;actor.position=Vector3(0,.7,3.2)
  var pet:CharacterBody3D=app.world.companion;pet.position=Vector3(0,.7,5);pet.last_place=app.world.last_location;pet.trail.clear();pet.last_player=actor.position;pet.activity.reset(pet);pet.activity.rng.seed=42
  var modes:Dictionary={};var safe:=true;var moved:float=0;var jumping:=false;var original:Vector3=pet.position;var active_frames:int=0;var previous_position:Vector3=pet.position
  for i in range(1000):
   await frames(1);modes[pet.activity.mode]=true
   if pet.position.distance_to(previous_position)>.003:active_frames+=1
   previous_position=pet.position
   moved=maxf(moved,pet.position.distance_to(original));jumping=jumping or pet.visual.position.y>.1
   if Vector2(pet.position.x-actor.position.x,pet.position.z-actor.position.z).length()>pet.activity.roam_radius(pet)+.3:safe=false
   if not app.world.terrain_walkable(pet.position):safe=false
  print("PET_MODES ",kind," ",modes," displacement ",moved," hop ",jumping)
  check(modes.has("wait") and modes.has("walk") and modes.has("run"),"random activity mixes rest, walk and run "+kind)
  if kind=="dog":check(active_frames>550,"dog spends most idle time actively moving "+str(active_frames))
  if not jumping:
   # Random choices need not select every action inside a short sample window.
   pet.position=Vector3(0,.7,5);pet.activity.still_time=3;pet.activity.last_owner=actor.position;pet.activity.choose(pet,"hop")
   for i in range(24):
    await frames(1);jumping=jumping or pet.visual.position.y>.1
  check(moved>.7 and jumping,"idle pet travels and really hops "+kind)
  check(safe,"idle activity remains in safe nearby range "+kind)
  app._open_settings();await frames(1)
  var before:Vector3=pet.position;var phase:float=pet.activity.elapsed
  await frames(12)
  check(pet.position==before and pet.activity.elapsed==phase,"settings pause roaming and hop "+kind)
  app._close_drawers();actor.allowed=true
  actor.position=Vector3(0,.7,8)
  var initial:float=pet.position.distance_to(actor.position)
  await frames(2)
  check(pet.activity.mode=="follow","owner walking away interrupts activity immediately "+kind)
  for i in range(220):
   await frames(1)
   if pet.position.distance_to(actor.position)<2:break
  check(pet.position.distance_to(actor.position)<2 and pet.position.distance_to(actor.position)<initial,"pet catches owner automatically "+kind)
  pet.activity.choose(pet,"hop");pet.petting=6;await frames(2)
  check(pet.activity.mode=="follow" and absf(pet.visual.position.y)<.02,"petting suppresses free play "+kind)
  pet.petting=0;actor.boating=true;await frames(2)
  check(pet.activity.mode=="follow" and pet.visual.position.y==0,"boat ride suppresses free play "+kind)
  actor.boating=false
 print("PET ACTIVITY: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
