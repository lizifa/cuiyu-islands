extends SceneTree
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
 var actor:CharacterBody3D=app.world.player;var session:Node=app.fishing_session
 for start:Vector3 in [Vector3(-2.35,.68,16.2),Vector3(.8,.68,14.5),Vector3(2.2,.68,16.1),Vector3(-1,.68,17.1)]:
  actor.position=start;actor.visual.rotation.y=1.8;actor.velocity=Vector3.ZERO;await frames(2)
  check(app.world.nearby_action().get("kind")=="shore_fish","full platform exposes fishing action "+str(start))
  app._nearby_interact()
  check(app.world.companion.held_for_interaction,"pet temporarily yields for fishing approach "+str(start))
  for i in range(800):
   await frames(1)
   if session.active or not app.interaction_director.active:break
  if not session.active:print("PET_BLOCK ",app.world.companion.position," target ",app.world.companion.interaction_wait_target," actor ",actor.position)
  check(session.active,"one tap walks to safe fishing anchor "+str(start)+" "+app.state.last_message)
  check(not app.world.companion.held_for_interaction,"successful approach releases pet hold "+str(start))
  if session.active:
   for i in range(40):
    await frames(1)
    if session.stage=="waiting":break
   check(actor.position.distance_to(session.Platform.SEAT)<.01 and absf(actor.visual.rotation.y)<.01,"fishing starts seated and facing sea "+str(start))
   session.cancel()
 actor.position=Vector3(.8,.68,14.5);actor.velocity=Vector3.ZERO;await frames(2)
 app._nearby_interact();check(app.interaction_director.active and app.world.companion.held_for_interaction,"approach owns temporary pet hold")
 app.joystick.direction=Vector2.RIGHT;await frames(2);app.joystick.reset()
 check(not app.interaction_director.active and not app.world.companion.held_for_interaction,"manual takeover releases pet without trapping it")
 actor.position=app.world.DOCK;await frames(2)
 check(app.world.nearby_action().get("kind")=="boat","actual boarding stance keeps boat priority")
 actor.position=Vector3(-1,.68,16.1);check(session.begin(),"size test fixture");session.set_physics_process(false)
 check(is_equal_approx(session.big_fish_probability(),.3),"ordinary big-fish chance is thirty percent")
 session.chummed=true;check(is_equal_approx(session.big_fish_probability(),.5),"chumming helps without making big fish common")
 app.state.buildings["好鱼竿"]=true;check(is_equal_approx(session.big_fish_probability(),.55),"upgraded rod has modest bonus")
 session.stage="reeling";session.elapsed=.6;session.progress=.4;session.tension=.65;session.big_fish=false;session.fish_mass=.4
 for i in range(100):session._update_visual(1.0/60)
 var small:float=session.bend_load
 session.big_fish=true;session.fish_mass=3.5
 for i in range(100):session._update_visual(1.0/60)
 check(session.bend_load>small+.5 and session.bend_load<=2.2,"large fish creates visibly stronger bounded flex")
 session.tension=.15
 for i in range(100):session._update_visual(1.0/60)
 check(session.bend_load<1.1,"unloading the rod releases large-fish flex")
 session.cancel()
 print("FISHING ACCESS SIZE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
