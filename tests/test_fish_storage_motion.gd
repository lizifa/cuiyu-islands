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
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);await frames(4)
 for gender:String in ["male","female"]:
  app.state.profile.gender=gender;app.world.sync(app.state);await frames(3)
  var actor:Node3D=app.world.player;actor.position=Vector3(-1,.68,16.1)
  var session:Node=app.fishing_session;session.begin();session.set_physics_process(false);session.big_fish=true;session.fish_mass=2;session._set_stage("landing");session.elapsed=session.Landing.DURATION;session._physics_process(.01)
  check(session.stage=="storing" and not app.state.pending_fish.is_empty(),"landing begins storage action "+gender)
  var previous:Vector3=actor.position;var step:float=0;var held:=true;var net_clear:=true
  for i in range(111):
   session.elapsed=i*.05;session._update_visual(.05)
   step=maxf(step,actor.position.distance_to(previous));previous=actor.position
   if session.elapsed>4.0 and session.elapsed<4.8:
    net_clear=net_clear and Vector2(app.world.fish_keeper.mouth.x-actor.position.x,app.world.fish_keeper.mouth.z-actor.position.z).length()>.72
   if session.elapsed>1.5 and session.elapsed<4.1:
    var hand:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("RightHand")).origin
    held=held and session.fish.to_global(session.fish_center).distance_to(hand+Vector3(0,.12,.26))<.01
  var bag:MeshInstance3D=session.net_tool.get_node("NetHead/NetBag")
  var bounds:AABB=bag.global_transform*bag.mesh.get_aabb()
  check(bounds.position.y>=.63 and session.net_tool.position.distance_to(actor.position)>.7,"parked net clears the floor and the walking lane "+gender)
  check(step<.1 and actor.position.z>17,"step toward keep net is continuous "+gender)
  check(net_clear,"raised keep-net mouth stays clear of character body "+gender)
  check(held,"fish stays supported by actual hand during unhook and approach "+gender)
  check(not session.fish.visible and app.world.fish_keeper.mouth.distance_to(app.world.fish_keeper.REST)<.01,"fish enters net and mouth settles back "+gender)
  session.elapsed=session.Storage.DURATION;session._physics_process(.01)
  check(app.state.kept_portions()==2,"storage completes into keep net "+gender)
  session.interact();session.set_physics_process(false)
  check(session.active and app.state.kept_portions()==2 and app.state.count("鲜鱼")==0,"next cast preserves fish in keep net "+gender)
  session.cancel();check(app.state.count("鲜鱼")==2 and app.state.kept_portions()==0,"cancel packs fish without duplication "+gender)
  app.state.inventory["鲜鱼"]=0
 print("FISH STORAGE MOTION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
