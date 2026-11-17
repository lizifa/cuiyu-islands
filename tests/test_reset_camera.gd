extends SceneTree
var passed:=0
var failed:=0
var app:Node
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func frames(count:int)->void:
 for frame in range(count):app.inactive=false;await physics_frame;await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(2436,1126);viewport.own_world_3d=true;root.add_child(viewport)
 app=load("res://scenes/life_main.tscn").instantiate();viewport.add_child(app);app.set_process(false);app.set_physics_process(false);app._close_drawers();app.inactive=false;app.paused=false
 var world:Node3D=app.world;var actor:CharacterBody3D=world.player;var rig:Node=world.orbit
 actor.set_physics_process(false);world.set_process(false);rig.set_process(false)
 for scenario:String in ["fishing","balcony_rest","boat","manual","remote_island","first_person"]:
  app._close_drawers();app.paused=false;app.inactive=false
  if scenario=="balcony_rest":
   app.state.location="villa";app.state.home_floor=1;app.state.player_position=[-1.55,world.Villa.Dimensions.UPPER_FLOOR+.03,22.2];world.sync(app.state)
   check(app.sofa_session.begin_balcony(),"fixture starts balcony rest")
  else:
   app.state.location="island";app.state.home_floor=0;app.state.player_position=[0,.705,3.2];world.sync(app.state)
   if scenario=="fishing":
    actor.position=world.FishingPlatform.POINT
    check(app.fishing_session.begin(),"fixture starts fishing")
   elif scenario=="boat":
    actor.position=world.DOCK;check(world.board_boat(app.state),"fixture boards boat");actor.position=Vector3(0,.05,28)
   elif scenario=="remote_island":
    actor.position=world.DOCK;world.board_boat(app.state)
    var site:Dictionary=world.exploration._sites(world.seascape.islands[0])[0];actor.position=site.berth
    check(world.exploration.land(site),"fixture lands on remote island")
   elif scenario=="manual":
    actor.position=Vector3(1,.705,7);rig.manual_view_locked=true;rig.pivot=Vector3(14,3,8);rig.camera.position=Vector3(70,-8,80);rig.sun_target=Vector3(80,100,20)
   elif scenario=="first_person":
    check(rig.set_first_person(true),"fixture selects first person");rig.context="villa";rig.auto_point=Vector3(80,50,20)
  if scenario in ["fishing","balcony_rest"]:
   rig.motion_enabled=true
   for frame in range(120):rig._process(1./60)
  app.joystick.direction=Vector2.ONE;app.sprinting=true
  check(app._reset_game(),"reset succeeds from "+scenario)
  check(not app.fishing_session.active and not app.sofa_session.active and not app.exercise_session.active,"reset closes all action sessions "+scenario)
  check(not actor.boating and actor.rowing_pose==null and not actor.sofa_seated and actor.fishing_stage.is_empty(),"reset releases actor pose "+scenario)
  check(rig.activity_key.is_empty() and rig.room_key.is_empty() and not rig.pivot.is_finite(),"reset discards old camera subject "+scenario)
  check(app.state.island_visit.is_empty(),"reset clears remote parked boat "+scenario)
  check(rig.spawn_reset_pending,"spawn view waits for character selection "+scenario)
  check(app.joystick.direction==Vector2.ZERO and not app.sprinting and not actor.manual_world_direction.is_finite(),"reset releases held input "+scenario)
  await frames(3)
  check(app.arrival.confirm(),"new character selection completes "+scenario)
  check(not rig.spawn_reset_pending,"camera is primed before gameplay is revealed "+scenario)
  if scenario=="first_person":
   check(rig.first_person and rig.camera.position.distance_to(actor.position+Vector3.UP*1.85)<.4,"first-person preference has fresh eye position")
   check(not rig.auto_point.is_finite(),"first-person old look target cleared")
   rig.set_first_person(false)
  else:
   check(rig.pivot.distance_to(actor.position+Vector3.UP*1.05)<.1,"spawn camera focuses new character immediately "+scenario)
   check(rig._body_framed(actor),"full new character visible on first gameplay frame "+scenario)
   check(not rig.manual_view_locked and not rig.sun_target.is_finite(),"old manual observation cleared "+scenario)
  await frames(2)
 print("RESET CAMERA: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
