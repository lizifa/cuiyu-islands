extends RefCounted
const LIFE_ACTIONS=preload("res://assets/mixamo-life/life_actions.tres")
var actor:Node3D
var rig:Skeleton3D
var hand:int=-1
var held_side:="Right"
var rim_height:float=.125
var positions:Array[Vector3]=[]
var rotations:Array[Quaternion]=[]
var prop:MeshInstance3D
var posing:=false
func setup(owner_actor:Node3D) -> bool:
 actor=owner_actor
 if actor.home_busy or actor.sofa_seated or actor.bed_stage!="" or actor.stair_active or actor.working or actor.pet_stage!="":return false
 rig=actor.visual.find_children("*","Skeleton3D",true,false)[0]
 actor.pose_skeleton=rig
 if actor.animator!=null:actor.animator.play(actor.idle_clip);actor.animator.advance(0);actor.animator.stop(true)
 for i in range(rig.get_bone_count()):positions.append(rig.get_bone_pose_position(i));rotations.append(rig.get_bone_pose_rotation(i))
 hand=actor._bone("RightHand");actor.home_busy=true;posing=true;return true
func set_held_side(value:String) -> void:
 held_side=value;hand=actor._bone(held_side+"Hand")
func make_bottle(world:Node3D) -> void:
 if is_instance_valid(prop):return
 prop=MeshInstance3D.new();prop.name="HeldDrinkBottle";var cylinder:=CylinderMesh.new();cylinder.top_radius=.04;cylinder.bottom_radius=.06;cylinder.height=.25;cylinder.radial_segments=12;prop.mesh=cylinder;prop.material_override=world.material(Color("d5a553"));world.add_child(prop);carry()
func tick(target:Vector3,amount:float,tilt:float=0,active_hand:String="") -> void:
 if not is_instance_valid(rig) or not is_instance_valid(actor):return
 rig.clear_bones_global_pose_override()
 for i in range(positions.size()):rig.set_bone_pose_position(i,positions[i]);rig.set_bone_pose_rotation(i,rotations[i])
 var reaching_side:String=held_side if active_hand=="" else active_hand
 var hips:Vector3=rig.get_bone_global_pose(actor._bone("Hips")).origin
 for side:String in ["Left","Right"]:
  var arm:int=actor._bone(side+"Arm")
  var sign_x:float=signf(rig.get_bone_global_pose(arm).origin.x-hips.x)
  var rest:Vector3=rig.global_transform*(hips+Vector3(sign_x*.27,.02,.06))
  actor._reach_arm(side,rest.lerp(target,amount) if side==reaching_side else rest,1)
 carry(tilt)
func carry(tilt:float=0) -> void:
 if is_instance_valid(prop) and is_instance_valid(rig):
  prop.global_position=rig.global_transform*rig.get_bone_global_pose(hand).origin+Vector3.UP*.06
  prop.global_basis=Basis(Vector3.UP,actor.visual.global_rotation.y)*Basis(Vector3.RIGHT,tilt)
func release_pose() -> void:
 if not posing:return
 if is_instance_valid(actor):actor.home_busy=false;actor.home_move_direction=Vector3.ZERO
 if is_instance_valid(actor) and is_instance_valid(rig) and actor.is_inside_tree():
  rig.clear_bones_global_pose_override()
  for i in range(positions.size()):rig.set_bone_pose_position(i,positions[i]);rig.set_bone_pose_rotation(i,rotations[i])
  if actor.pose_skeleton==rig:actor.pose_skeleton=null
  actor.home_busy=false
  if actor.animator!=null:actor.animator.play(actor.idle_clip,.15)
 posing=false
func clear() -> void:
 release_pose()
 if is_instance_valid(prop):prop.queue_free();prop=null

func sip(mouth:Vector3,amount:float) -> void:
 var tilt:float=-.95*amount
 var bottle_basis:=Basis(Vector3.UP,actor.visual.global_rotation.y)*Basis(Vector3.RIGHT,tilt)
 var grip:Vector3=mouth-bottle_basis*Vector3.UP*rim_height-Vector3.UP*.06
 tick(grip,amount,tilt)
 var head:int=actor._bone("Head")
 if head>=0:rig.set_bone_pose_rotation(head,rotations[head]*Quaternion(Vector3.RIGHT,-.1*amount))
func make_spoon(world:Node3D) -> void:
 if is_instance_valid(prop):return
 prop=MeshInstance3D.new();prop.name="HeldCookingSpoon";var shaft:=CylinderMesh.new();shaft.top_radius=.012;shaft.bottom_radius=.012;shaft.height=.38;shaft.radial_segments=8;prop.mesh=shaft;prop.material_override=world.material(Color("a77d51"));world.add_child(prop)
 var bowl:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.038;sphere.height=.09;sphere.radial_segments=8;sphere.rings=4;bowl.mesh=sphere;bowl.material_override=prop.material_override;prop.add_child(bowl);bowl.position.y=-.2;carry()

# Manual sampling follows the session clock: pause/cancel never leaves an AnimationPlayer running.
func sample_mixamo(name:String,time:float,weight:float=1.0) -> void:
 if not posing or not is_instance_valid(rig):return
 rig.clear_bones_global_pose_override()
 for i in positions.size():
  rig.set_bone_pose_position(i,positions[i]);rig.set_bone_pose_rotation(i,rotations[i])
 var clip:Animation=LIFE_ACTIONS.get_animation(name)
 for track in clip.get_track_count():
  var bone_name:String=str(clip.track_get_path(track).get_subname(0))
  # Keep the current grounded stance; life gestures only own the upper body.
  if not (bone_name in ["Spine","Chest","UpperChest","Neck","Head"] or "Arm" in bone_name or "Hand" in bone_name or "Shoulder" in bone_name):continue
  var bone:int=rig.find_bone(bone_name)
  if bone>=0:rig.set_bone_pose_rotation(bone,rotations[bone].slerp(clip.rotation_track_interpolate(track,clampf(time,0,clip.length)),clampf(weight,0,1)))
 rig.force_update_all_bone_transforms()

func mocap_drink(time:float) -> void:
 var duration:float=LIFE_ACTIONS.get_animation("Drinking").length
 var weight:float=smoothstep(0,.35,time)*(1-smoothstep(duration-.35,duration,time))
 sample_mixamo("Drinking",time,weight)
 var amount:float=smoothstep(2.6,3.7,time)*(1-smoothstep(4.6,5.8,time))
 var head:int=actor._bone("Head")
 var mouth:Vector3=rig.global_transform*rig.get_bone_global_pose(head).origin-Vector3.UP*.09+actor.visual.global_basis.z.normalized()*.12
 var bottle_basis:=Basis(Vector3.UP,actor.visual.global_rotation.y)*Basis(Vector3.RIGHT,-.95*amount)
 var grip:Vector3=mouth-bottle_basis*Vector3.UP*rim_height-Vector3.UP*.06
 if amount>0:actor._reach_arm(held_side,grip,amount)
 carry(-.95*amount)
