extends SceneTree
const Landing=preload("res://scripts/life/fishing_landing.gd")
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
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);await frames(4)
 for gender:String in ["male","female"]:
  app.state.profile.gender=gender;app.world.sync(app.state);await frames(3)
  var actor:CharacterBody3D=app.world.player;actor.position=Vector3(-1,.68,16.1)
  var session:Node=app.fishing_session;check(session.begin(),"landing fixture "+gender);session.set_physics_process(false);session.big_fish=true;session.seat_blend=0;session._set_stage("landing")
  var heads:Array[Vector3]=[];var hands:Array[Vector3]=[];var attached:=true;var upright:=true;var contained:=true;var planted:=true;var feet:Array[Vector3]=[]
  for i in range(34):
   session.elapsed=i*.1;session._update_visual(.1)
   var hand:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("LeftHand")).origin
   var head:Node3D=session.net_tool.get_node("NetHead")
   heads.append(head.global_position);hands.append(hand)
   for side:int in range(2):
    var foot:int=actor._bone(("Left" if side==0 else "Right")+"Foot")
    var point:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(foot).origin
    if i==0:feet.append(point)
    else:planted=planted and point.distance_to(feet[side])<.03
   attached=attached and hand.distance_to(session.net_tool.global_position)<.001
   upright=upright and head.global_basis.y.dot(Vector3.UP)>.99
   if session.elapsed>=Landing.CATCH_TIME:contained=contained and session.fish.to_global(session.fish_center).distance_to(head.global_position-Vector3.UP*.27)<.001
  check(attached,"handle follows actual left hand "+gender)
  check(upright,"hoop opens upwards throughout scoop "+gender)
  check(heads[14].y<0 and heads[32].y>.9,"hoop enters water then lifts fish above deck "+gender)
  check(hands[5].distance_to(hands[14])>.2 and hands[14].distance_to(hands[32])>.3,"arm visibly lowers and lifts "+gender)
  check(planted,"crouch keeps both feet planted "+gender)
  check(contained,"captured fish remains inside net bag "+gender)
  check(app.world.orbit.target_distance<9,"scoop has readable action framing "+gender)
  var previous:int=app.state.count("鲜鱼");session.elapsed=Landing.DURATION-.1;session._physics_process(.01)
  check(app.state.count("鲜鱼")==previous,"no reward before lift completes "+gender)
  session.elapsed=Landing.DURATION;session._physics_process(.01)
  check(session.landed and session.stage=="storing" and app.state.pending_fish.portions==2 and app.state.count("鲜鱼")==previous,"lift completion secures fish before storage "+gender)
  session._update_visual(.1)
  var hoop:Vector3=session.net_tool.get_node("NetHead").global_position
  check(session.fish.to_global(session.fish_center).distance_to(hoop-Vector3.UP*.27)<.001,"result keeps fish displayed in net "+gender)
  session._physics_process(.2)
  check(app.state.count("鲜鱼")==previous and app.state.pending_fish.portions==2,"storage frames cannot duplicate pending fish "+gender)
  session.elapsed=session.Storage.DURATION;session._physics_process(.01)
  check(app.state.kept_portions()==2 and app.state.count("鲜鱼")==previous,"completed storage places fish in keep net "+gender)
  session.cancel()
  check(app.state.count("鲜鱼")==previous+2 and app.state.kept_portions()==0,"leaving packs stored fish exactly once "+gender)
 print("NET LANDING: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
