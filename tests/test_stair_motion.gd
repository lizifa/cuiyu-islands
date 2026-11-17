extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frame() -> void:
 app.inactive=false;await physics_frame
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=5;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.set_physics_process(false)
 var actor:CharacterBody3D=app.world.player;actor.stair_view_ready=Callable() # Physics/pose coverage; camera pacing is covered by test_stair_handoff.
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[6,.705,2];app.world.sync(app.state)
 actor.stair_view_ready=Callable()
 actor.allowed=true
 await frame();await frame()
 for up:bool in [true,false]:
  check(app.world.change_home_floor(app.state),"start stair motion "+str(up))
  var minimum_spacing:float=INF
  var maximum_lift:float=0;var samples:int=0;var foot_error:float=0
  var hip_total:=0.0;var hip_samples:=0;var hip_change:=0.0;var previous_hip:=.04
  for i in range(1800):
   if not actor.stair_active:break
   await frame()
   var gait:RefCounted=actor.stair_motion
   hip_total+=gait.hip_drop;hip_samples+=1;hip_change=maxf(hip_change,absf(gait.hip_drop-previous_hip));previous_hip=gait.hip_drop
   for target:Vector3 in gait.targets:
    maximum_lift=maxf(maximum_lift,target.y-load("res://scripts/life/villa_stairwell.gd").surface_at(target,actor.position.y)-.11)
   if gait.targets.size()==2 and actor.pose_skeleton!=null:
    samples+=1
    var feet:Array[Vector3]=[]
    for side:String in ["Left","Right"]:feet.append(actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone(side+"Foot")).origin)
    minimum_spacing=minf(minimum_spacing,(feet[0]-feet[1]).dot(actor.visual.global_basis.x.normalized()))
    if actor.stair_active and actor.pose_skeleton!=null:
     for side_index in range(2):
      var actual:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone(("Left" if side_index==0 else "Right")+"Foot")).origin
      var error:float=actual.distance_to(gait.targets[side_index])
      if error>foot_error and error>.1:print("FOOT_ERROR ",error," actor ",actor.position," actual ",actual," target ",gait.targets[side_index]," phase ",gait.phase)
      foot_error=maxf(foot_error,error)
   if i==80 and gait.last_targets.size()==2:
    var held:Array[Vector3]=gait.last_targets.duplicate()
    var held_phase:float=gait.phase
    actor.stair_view_ready=func(_point:Vector3)->bool:return false
    for j in range(8):await frame()
    check(gait.last_targets==held and is_equal_approx(gait.phase,held_phase),"camera wait keeps both feet planted without re-centering")
    actor.stair_view_ready=Callable()
   if i==100:
    var phase:float=gait.phase
    actor.allowed=false
    for j in range(8):await frame()
    check(is_equal_approx(phase,gait.phase),"paused game freezes gait")
    actor.allowed=true
  check(not actor.stair_active and app.state.home_floor==(1 if up else 0),"walk completes "+str(up))
  check(minimum_spacing>.04,"actual stair feet stay uncrossed "+str(up)+" spacing "+str(minimum_spacing))
  check(samples>40 and maximum_lift>.18,"feet visibly lift on stairs "+str(up))
  check(foot_error<.1,"real foot bones follow stair targets "+str(up)+" error "+str(foot_error))
  check(actor.pose_skeleton==null,"stair IK released on landing")
  print("STAIR PELVIS ",up," average drop ",hip_total/maxi(hip_samples,1)," maximum per-frame change ",hip_change)
  check(hip_total/maxi(hip_samples,1)<.25 and hip_change<.07,"stairs avoid sustained deep squatting or pelvis snaps")
 print("STAIR MOTION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
