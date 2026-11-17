extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new();state.profile.gender="female" if "--female" in OS.get_cmdline_user_args() else "male";var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var actor:CharacterBody3D=world.player;actor.position=world.DOCK
 check(world.board_boat(state),"board ready boat")
 actor.set_physics_process(false);actor.allowed=true
 var rowing:RefCounted=actor.rowing_pose
 check(rowing!=null and not rowing.ready() and not actor.home_busy,"boarding starts seated preparation without home interaction lock")
 var pickup_error:=0.0
 for frame in range(150):
  rowing.tick(1./60,0)
  if rowing.elapsed>=1.1 and rowing.elapsed<=1.15:
   for side in range(2):
    var hand:Vector3=rowing.rig.global_transform*rowing.rig.get_bone_global_pose(actor._bone("LeftHand" if side==0 else "RightHand")).origin
    pickup_error=maxf(pickup_error,hand.distance_to(rowing.oars[side].get_node("Grip").global_position))
 check(pickup_error<.12,"hands reach stowed oars before lifting "+str(pickup_error))
 check(rowing.ready(),"sit and take oars finishes")
 var rig:Skeleton3D=actor.pose_skeleton
 var hip:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("Hips")).origin
 check(absf(hip.y-actor.position.y-.48)<.03,"pelvis sits above the actual bench")
 var maximum_hand_error:=0.0
 var first:Vector3=rowing.oars[0].get_node("Grip").global_position
 for frame in range(120):
  rowing.tick(1./60,4)
  for side in range(2):
   var hand:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftHand" if side==0 else "RightHand")).origin
   maximum_hand_error=maxf(maximum_hand_error,hand.distance_to(rowing.oars[side].get_node("Grip").global_position))
 check(maximum_hand_error<.12,"both hands actually follow oar grips "+str(maximum_hand_error))
 check(first.distance_to(rowing.oars[0].get_node("Grip").global_position)>.05,"rowing moves actual oars")
 var left:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftFoot")).origin
 var right:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("RightFoot")).origin
 check((left-right).dot(actor.visual.global_basis.x.normalized())>.2,"seated feet do not cross")
 check(left.y>actor.position.y-.15 and left.y<actor.position.y+.1,"feet stay inside hull above its floor")
 var phase:float=rowing.phase;actor.allowed=false;rowing.tick(1,7)
 check(rowing.phase==phase,"pause freezes rowing")
 actor.allowed=true
 for frame in range(90):rowing.tick(1./60,0)
 check(rowing.strength<.001 and rowing.ready(),"stopped boat keeps seated ready pose")
 rowing.phase=0;rowing.strength=1;rowing.tick(.1,4);var normal_phase:float=rowing.phase
 rowing.phase=0;rowing.tick(.1,7)
 check(rowing.phase>normal_phase,"acceleration increases rowing cadence")
 actor.boat_heading=PI/2;actor.visual.rotation.y=actor.boat_heading+PI;rowing.tick(.1,4)
 check(absf(angle_difference(rowing.equipment.rotation.y,actor.boat_heading))<.001,"oars follow hull heading")
 world._set_boating(false)
 check(actor.rowing_pose==null and actor.pose_skeleton==null,"disembarking clears rowing ownership")
 check(actor.animator.is_playing(),"normal animation resumes ashore")
 await process_frame
 check(actor.get_node_or_null("RowingEquipment")==null,"rowing equipment removed on disembark")
 print("ROWING POSE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
