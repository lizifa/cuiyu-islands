extends RefCounted
## Distance-driven feet: alternate lift and plant onto the visible stair treads.
const Stairs=preload("res://scripts/life/villa_stairwell.gd")
const IK=preload("res://scripts/life/grounded_pose.gd")
var actor:CharacterBody3D
var phase:float=0
var lift:float=0
var targets:Array[Vector3]=[]
var planted:Array[Vector3]=[]
var swing_start:Array[Vector3]=[]
var swing_end:Array[Vector3]=[]
var swinging:Array[bool]=[]
var hip_base:=Vector3.ZERO
var hip_drop:float=.04
var last_targets:Array[Vector3]=[]
var last_heading:float=0
func setup(owner_actor:CharacterBody3D) -> void:
 actor=owner_actor;last_heading=actor.visual.rotation.y;phase=0;lift=0;hip_drop=.04;targets.clear();planted.clear();swing_start.clear();swing_end.clear();swinging.clear();last_targets.clear()
 for skeleton:Skeleton3D in actor.visual.find_children("*","Skeleton3D",true,false):actor.pose_skeleton=skeleton;break
 if actor.pose_skeleton!=null and actor._bone("Hips")>=0:hip_base=actor.pose_skeleton.get_bone_pose_position(actor._bone("Hips"))
func tick(delta:float,before:Vector3) -> void:
 if not is_instance_valid(actor.pose_skeleton):return
 var moved:float=Vector2(actor.position.x-before.x,actor.position.z-before.z).length()
 var turning:float=absf(angle_difference(last_heading,actor.visual.rotation.y))
 last_heading=actor.visual.rotation.y
 moved=maxf(moved,turning*.18)
 if moved<=.0001 and last_targets.size()==2:
  # Camera waits must not slide both planted feet back to a neutral stance.
  if actor.animator!=null:actor.animator.pause()
  return
 phase+=moved/.5
 var moving:bool=moved>.0001
 lift=move_toward(lift,1.0 if moving else 0.0,delta*7)
 var rig:Skeleton3D=actor.pose_skeleton
 rig.clear_bones_global_pose_override()
 if actor.animator!=null:
  actor.animator.play(actor.walk_clip if moving else actor.idle_clip)
  if moving:actor.animator.seek(fmod(phase,1.0)*actor.animator.current_animation_length,true)
  actor.animator.pause()
 targets.clear()
 for i in range(2):
  var foot:int=actor._bone(("Left" if i==0 else "Right")+"Foot")
  if foot<0:continue
  var cycle:float=fposmod(phase+i*.5,1)
  var swing:float=clampf((cycle-.5)*2,0,1)
  var forward:Vector3=actor.visual.global_basis.z.normalized()
  var side:Vector3=actor.visual.global_basis.x.normalized()*(.16 if i==0 else -.16)
  var desired:Vector3=actor.position+side+forward*.14
  desired.y=Stairs.surface_at(desired,actor.position.y)+.11
  if planted.size()<=i:
   planted.append(desired);swing_start.append(desired);swing_end.append(desired);swinging.append(false);last_targets.append(desired)
  var target:Vector3=planted[i]
  if not moving:
   target=last_targets[i].lerp(desired,minf(1,delta*8));planted[i]=target;swinging[i]=false
  elif cycle>=.5:
   if not swinging[i]:
    swinging[i]=true;swing_start[i]=planted[i];swing_end[i]=desired+forward*.12
    swing_end[i].y=Stairs.surface_at(swing_end[i],actor.position.y)+.11
   target=swing_start[i].lerp(swing_end[i],smoothstep(0,1,swing))
   var clearance:float=.14 if swing_end[i].y<swing_start[i].y-.04 else .24
   target.y+=sin(swing*PI)*clearance*lift
  elif swinging[i]:
   planted[i]=swing_end[i];swinging[i]=false;target=planted[i]
  # Keep each foot on its anatomical side even while turning on a landing.
  var right:Vector3=actor.visual.global_basis.x.normalized()
  var lateral:float=(target-actor.position).dot(right)
  var safe_lateral:float=maxf(.09,lateral) if i==0 else minf(-.09,lateral)
  target+=right*(safe_lateral-lateral)
  if not swinging[i]:planted[i]=target
  last_targets[i]=target
  targets.append(target)
 var hip:int=actor._bone("Hips")
 if hip>=0 and not targets.is_empty():
  # Only planted feet support the pelvis; the descending swing foot must not
  # drag both knees into a squat before it has touched its next tread.
  var support:float=-INF
  for i in range(targets.size()):
   if not swinging[i]:support=maxf(support,targets[i].y)
  if not is_finite(support):support=maxf(targets[0].y,targets[-1].y)
  var needed:float=clampf(.04+actor.position.y+.11-support,.04,.24)
  # Keep each planted/swing target within the actual leg length without
  # imposing a constant deep crouch for the entire descent.
  rig.set_bone_pose_position(hip,hip_base)
  for i in range(targets.size()):
   var side:String="Left" if i==0 else "Right"
   var upper:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone(side+"UpLeg")).origin
   var knee:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone(side+"Leg")).origin
   var ankle:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone(side+"Foot")).origin
   var reach:float=upper.distance_to(knee)+knee.distance_to(ankle)-.025
   var horizontal:float=Vector2(upper.x-targets[i].x,upper.z-targets[i].z).length()
   var vertical:float=sqrt(maxf(.01,reach*reach-horizontal*horizontal))
   needed=maxf(needed,upper.y-targets[i].y-vertical)
  needed=clampf(needed,.04,.38)
  hip_drop=move_toward(hip_drop,needed,delta*1.2)
  var hip_pose:Vector3=hip_base;hip_pose.y-=hip_drop/maxf(rig.global_basis.get_scale().y,.01)
  rig.set_bone_pose_position(hip,hip_pose)
 for i in range(targets.size()):IK.leg(actor,i,targets[i],1)
func finish() -> void:
 if actor==null:return
 if is_instance_valid(actor.pose_skeleton):
  actor.pose_skeleton.clear_bones_global_pose_override()
  if actor._bone("Hips")>=0:actor.pose_skeleton.set_bone_pose_position(actor._bone("Hips"),hip_base)
 actor.pose_skeleton=null
 if actor.animator!=null:actor.animator.play(actor.idle_clip,.15)
