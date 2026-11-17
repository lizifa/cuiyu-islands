extends SceneTree
const Hop=preload("res://scripts/life/pet_hop.gd")
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func _initialize():
 if "--test-mode" not in OS.get_cmdline_user_args():quit(1);return
 call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);await frames(4)
 var actor:CharacterBody3D=app.world.player;actor.set_physics_process(false);actor.position=Vector3(0,.7,3.2);actor.allowed=true
 var pet:CharacterBody3D=app.world.companion;pet.set_physics_process(false);pet.position=Vector3(-.7,.7,4);pet.last_place=app.world.last_location;pet.trail.clear();pet.last_player=actor.position;pet.activity.reset(pet)
 var previous:float=0;var peak:float=0;var largest:float=0
 pet.activity.choose(pet,"hop")
 for i in range(90):
  pet.activity.elapsed=minf(pet.activity.duration,float(i)/60);pet._advance_gait(1.0/60,pet.position);pet.activity.pose(pet,1.0/60)
  var height:float=pet.visual.position.y;peak=maxf(peak,height);largest=maxf(largest,absf(height-previous));previous=height
 check(peak>.15 and largest<.04 and previous<.005,"jump has gradual takeoff and soft landing without height snaps")
 check(absf(Hop.sample(.3).front-Hop.sample(.3).hind)>.15,"front and hind legs fold at different times")
 pet.activity.hop_pose.height=.2;pet.activity._follow(pet);pet.activity.pose(pet,1.0/60)
 check(pet.visual.position.y>.1 and pet.visual.position.y<.2,"following interrupts jump with a short settling motion")
 pet.activity.reset(pet)
 var animal:CharacterBody3D=app.world.forest.actors.filter(func(item):return item.get_meta("mode")=="land")[0]
 animal.position=Vector3(1.5,.7,4);animal.set_meta("center",animal.position);animal.set_meta("radius",Vector2.ZERO);animal.set_meta("speed",0)
 await frames(2)
 pet.activity.still_time=3;pet.activity.last_owner=actor.position;pet.activity.choose(pet,"social")
 check(pet.activity.mode=="social" and pet.activity.social.partner==animal,"pet selects nearby friendly land animal")
 var original:Vector3=animal.position;var played:=false;var overlapping:=false;var animal_motion:float=0
 pet.set_physics_process(true)
 for i in range(90):
  await frames(1);played=played or pet.activity.social.playing;animal_motion=maxf(animal_motion,animal.position.distance_to(original))
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=pet.collider.shape;query.collision_mask=1;query.exclude=[pet.get_rid()];query.transform=pet.global_transform*pet.collider.transform
  for hit:Dictionary in app.world.get_world_3d().direct_space_state.intersect_shape(query,16):
   if hit.collider==animal:overlapping=true
 check(played and animal_motion>.03,"both participants respond and move during play")
 check(not overlapping,"social play preserves solid animal bodies")
 app._open_settings();await frames(1)
 var saved:Vector3=animal.position;var time:float=pet.activity.elapsed;await frames(10)
 check(animal.position==saved and pet.activity.elapsed==time,"settings freeze both participants")
 app._close_drawers();actor.working=true;await frames(2)
 check(pet.activity.mode=="follow" and not animal.has_meta("pet_play"),"labor interrupts play instead of blocking work space")
 actor.working=false;actor.position=Vector3(0,.7,9);await frames(2)
 check(pet.activity.mode=="follow" and not animal.has_meta("pet_play"),"owner leaving immediately releases play partner and restores following")
 print("PET SOCIAL HOP: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
