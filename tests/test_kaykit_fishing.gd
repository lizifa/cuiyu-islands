extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var actor=load("res://scripts/life/player_controller.gd").new();root.add_child(actor)
 var model=load("res://assets/kenney-protagonists/protagonist.scn").instantiate();actor.add_child(model);actor.bind_visual(model)
 check(actor.begin_fishing(Vector3.ZERO),"begin fishing")
 var rig:Skeleton3D=actor.pose_skeleton
 var foot:int=actor._bone("RightFoot")
 var original:Quaternion=rig.get_bone_pose_rotation(foot)
 var used:Dictionary={}
 for spec:Array in [["casting",.35,true],["waiting",.35,true],["bite",.35,true],["hooking",.35,true],["reeling",.35,true],["reeling",.9,true],["net_ready",.35,true]]:
  var stage:String=spec[0]
  var name:String=actor.fishing_animation.clip_for(stage,spec[1],spec[2]);used[name]=true
  check(actor.fishing_animation.LIBRARY.has_animation(name),"actual clip exists for "+stage)
  for sample in range(31):
   var time:float=sample/30.0
   var grip:Vector3=actor.pose_fishing(stage,time,Vector3(0,.5,.86).normalized(),time*6,0,Vector3.INF,spec[1],spec[2])
   check(grip.is_finite(),"finite hand grip")
   for bone in rig.get_bone_count():check(rig.get_bone_pose_rotation(bone).is_finite(),"finite retargeted bone")
  check(rig.get_bone_pose_rotation(foot).is_equal_approx(original),"standing foot rotation preserved")
 check(used.size()==7,"all seven clips used by fishing stages")
 var arm:int=actor._bone("RightArm")
 actor.fishing_animation.clear()
 actor.pose_fishing("casting",0,Vector3.UP)
 actor.pose_fishing("casting",.5,Vector3.UP)
 var cast:Quaternion=rig.get_bone_pose_rotation(arm)
 actor.pose_fishing("casting",.85,Vector3.UP)
 check(not cast.is_equal_approx(rig.get_bone_pose_rotation(arm)),"cast animation produces actual motion")
 actor.pose_fishing("landing",.5,Vector3.UP,0,0,Vector3(.3,1,.5))
 check(actor.fishing_animation.current_clip.is_empty(),"net sequence releases animation ownership")
 actor.end_fishing()
 check(actor.fishing_stage.is_empty() and actor.pose_skeleton==null and actor.fishing_animation.last.is_empty(),"cancel restores actor and clears animation")
 check(actor.collision_mask==1,"cancel restores collision")
 check(actor.begin_fishing(),"can restart after cancel")
 actor.end_fishing();actor.free()
 print("KAYKIT FISHING: ",passed," checks, ",failed," failed");quit(1 if failed else 0)
