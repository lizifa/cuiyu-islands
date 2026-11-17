extends RefCounted
## Authored procedural bed choreography. Only standing approaches use physical walking.
const LENGTHS := {"sitting_down":.85,"removing_shoes":1.6,"putting_shoes":1.6,"undressing":1.1,"hanging_cloak":.9,"taking_cloak":.9,"boarding":1.2,"lying_down":1.2,"eyes_opening":.35,"sitting_up":1.1,"moving_feet":1.25,"getting_off":1.15,"dressing":1.2}
const LABELS := {"sitting_down":"坐到床沿","removing_shoes":"脱下鞋子，放在床边","putting_shoes":"坐稳，穿好鞋子","approaching_rack":"走到衣帽架旁","undressing":"解开领口，脱下斗篷","hanging_cloak":"把斗篷和帽子挂好","taking_cloak":"从架上取回衣物","approaching_bed":"走到床边","boarding":"坐到床沿，上床","lying_down":"慢慢躺下，准备休息","resting":"精力恢复中 · 点击起床离开","eyes_opening":"睁眼，准备起床","sitting_up":"撑起身体，坐到床沿","moving_feet":"挪脚落地","getting_off":"撑起站稳，下床","stepping_clear":"走到衣帽架旁","dressing":"披上斗篷，整理领口"}
var footwear=preload("res://scripts/life/bed_footwear.gd").new()
var actor: Node3D
var elapsed := 0.0
var clock := 0.0
var stalled := 0.0
var height_scale := 1.0
var hip_rest := Vector3.ZERO
var feet_rest: Array[Vector3] = []
var lying_hip := Vector3.ZERO
var seat_hip := Vector3.ZERO
var crouch_hip := Vector3.ZERO
var standing_root := Vector3.ZERO
var outfit: Node3D
var covers: Array[MeshInstance3D] = []
var eye_lines: Array[MeshInstance3D] = []
var eye_mount: BoneAttachment3D
var wake_requested := false
var sit_progress_from := 0.0
var has_cape := false
var rack_stand:=Vector3.ZERO
var rack_hook:=Vector3.ZERO
var hung:=false
var garment_body:StaticBody3D
var phase_yaw:=0.0
var phase_world:Array[Transform3D]=[]
var phase_hip:=Vector3.ZERO
var phase_feet:Array[Vector3]=[]
var clothing_on := true
var eyes_closed := 0.0
func setup(owner_actor: Node3D) -> void:
 actor=owner_actor;height_scale=actor.pose_skeleton.global_basis.get_scale().y
 hip_rest=actor.pose_skeleton.get_bone_global_pose(actor._bone("Hips")).origin
 for side:String in ["Left","Right"]:feet_rest.append(actor.pose_skeleton.get_bone_global_pose(actor._bone(side+"Foot")).origin)
 lying_hip=actor.bed_anchor+Vector3(0,.10,-hip_rest.y*height_scale)
 seat_hip=Vector3(-3.95,actor.bed_anchor.y+.12,-3.05)
 crouch_hip=Vector3(-3.75,seat_hip.y,-3.05)
 standing_root=Vector3(-3.05,actor.bed_return.y,-3.05)
 var rack:Node3D=actor.get_parent().villa_room.get_node("BedroomCoatRack")
 rack_stand=rack.get_node("Approach").global_position;rack_hook=rack.get_node("Hook").global_position
 footwear.setup(actor);_make_eyes();_make_outfit();_phase("approaching_rack")
 actor.collision_mask=1;actor.collision_layer=2
func _phase(value:String) -> void:
 if actor.visual.has_meta("character_id"):
  value=str({"approaching_rack":"approaching_bed","undressing":"approaching_bed","hanging_cloak":"approaching_bed","removing_shoes":"boarding","putting_shoes":"getting_off","taking_cloak":"dressing"}.get(value,value))
 phase_world.clear();phase_feet.clear()
 var rig:Skeleton3D=actor.pose_skeleton
 for bone in range(rig.get_bone_count()):phase_world.append(rig.global_transform*rig.get_bone_global_pose(bone))
 phase_hip=rig.global_transform*rig.get_bone_global_pose(actor._bone("Hips")).origin
 for side:String in ["Left","Right"]:phase_feet.append(rig.global_transform*rig.get_bone_global_pose(actor._bone(side+"Foot")).origin)
 actor.bed_stage=value;elapsed=0;stalled=0;phase_yaw=actor.visual.rotation.y
func wake() -> void:
 if actor.bed_stage in ["eyes_opening","sitting_up","moving_feet","putting_shoes","getting_off","stepping_clear","taking_cloak","dressing"]:return
 if actor.bed_stage=="resting":sit_progress_from=0;_phase("eyes_opening")
 elif actor.bed_stage in ["approaching_rack","undressing","hanging_cloak","approaching_bed"]:
  if clothing_on:actor.bed_return=actor.position;actor.cancel_bed()
  elif hung:_phase("stepping_clear")
  else:_phase("dressing")
 elif actor.bed_stage in ["sitting_down","removing_shoes","boarding"]:wake_requested=true
 else:
  sit_progress_from=1-smoothstep(0,1,clampf(elapsed/float(LENGTHS["lying_down"]),0,1))
  _phase("sitting_up")
func tick(delta:float) -> void:
 elapsed+=delta;clock+=delta
 var phase:String=actor.bed_stage
 if phase in ["approaching_rack","approaching_bed","stepping_clear"]:
  _walking(delta,standing_root if phase=="approaching_bed" else rack_stand)
  _blend_entry();return
 var t:float=clampf(elapsed/float(LENGTHS.get(phase,1)),0,1)
 var blend:=smoothstep(0,1,t)
 _neutral()
 match phase:
  "undressing":
   actor.visual.rotation=Vector3(0,lerp_angle(phase_yaw,PI/2,blend),0)
   _relax_arms()
   var collar:Vector3=actor.position+Vector3.UP*(1.38*height_scale)+actor.visual.global_basis.z.normalized()*.13
   _collar_hands(collar,smoothstep(0,.25,t))
   if t>=.4:
    _clothes(false)
    var fold:=smoothstep(.4,1,t)
    _garment(collar.lerp(_held_position(),fold)+Vector3.UP*sin(fold*PI)*.15,fold)
   _eyes(0)
   if t>=1:_phase("hanging_cloak")
  "hanging_cloak":
   actor.visual.rotation=Vector3(0,PI/2,0)
   var spine:int=actor._bone("Spine")
   if spine>=0:actor.pose_skeleton.set_bone_pose_rotation(spine,Quaternion(Vector3.RIGHT,.18*sin(t*PI)))
   _collar_hands(rack_hook,smoothstep(0,.6,t))
   _garment(_held_position().lerp(rack_hook,blend),1-blend)
   _eyes(0)
   if t>=1:_hang_garment();_phase("approaching_bed")
  "taking_cloak":
   actor.visual.rotation=Vector3(0,lerp_angle(phase_yaw,PI/2,blend),0)
   var spine:int=actor._bone("Spine")
   if spine>=0:actor.pose_skeleton.set_bone_pose_rotation(spine,Quaternion(Vector3.RIGHT,.18*sin(t*PI)))
   _collar_hands(rack_hook,smoothstep(0,.5,t));_eyes(0)
   if t<.4:_hang_garment()
   else:_garment(rack_hook.lerp(_held_position(),smoothstep(.4,1,t)),smoothstep(.4,1,t))
   if t>=1:_phase("dressing")
  "sitting_down":
   actor.collision_mask=0;actor.collision_layer=0
   _hip_pose(phase_hip.lerp(seat_hip,blend),lerp_angle(phase_yaw,PI/2,blend),0)
   for i in range(2):_leg(i,phase_feet[i].lerp(_ground_foot(i),blend),1)
   _brace(blend);_hang_garment();_eyes(0)
   if t>=1:_phase("removing_shoes")
  "removing_shoes","putting_shoes":
   var taking_off:bool=phase=="removing_shoes"
   _hip_pose(seat_hip if taking_off else crouch_hip,PI/2,0)
   var active_side:int=0 if t<.5 else 1
   var shoe_reach:float=sin(fposmod(t*2,1)*PI)
   for i in range(2):_leg(i,_ground_foot(i)+(Vector3.UP*.26*shoe_reach if i==active_side else Vector3.ZERO),1)
   var spine:int=actor._bone("Spine")
   if spine>=0:actor.pose_skeleton.set_bone_pose_rotation(spine,Quaternion(Vector3.RIGHT,.65*sin(t*TAU)*sin(t*TAU)))
   _relax_arms()
   var side:int=0 if t<.5 else 1
   var reach:float=sin(fposmod(t*2,1)*PI)
   _collar_hands(footwear.foot_position(side)+Vector3.UP*.12,reach)
   footwear.animate(t,taking_off);_hang_garment();_eyes(0)
   if t>=1:_phase("boarding" if taking_off else "getting_off")
  "boarding":
   actor.collision_mask=0;actor.collision_layer=0
   var hip:=seat_hip+Vector3.UP*sin(PI*t)*.12
   _hip_pose(hip,PI/2,0)
   for i in range(2):
    var f:float=smoothstep(0 if i==0 else .2,.8 if i==0 else 1,t)
    _leg(i,_ground_foot(i).lerp(_raised_foot(i),f)+Vector3.UP*sin(f*PI)*.12,1)
   _brace(1)
   _hang_garment()
   _eyes(0)
   if t>=1:_phase("moving_feet" if wake_requested else "lying_down")
  "lying_down":
   _sit_pose(1-blend)
   _hang_garment();_eyes(smoothstep(.25,1,t))
   if t>=1:actor.bed_blend=1;_phase("resting")
  "resting":
   _lie();_hang_garment();_eyes(1)
  "eyes_opening":
   _lie();_hang_garment();_eyes(1-blend)
   if t>=1:_phase("sitting_up")
  "sitting_up":
   _sit_pose(lerpf(sit_progress_from,1,blend));_hang_garment();_eyes(0)
   if t>=1:_phase("moving_feet")
  "moving_feet":
   var hip:=seat_hip
   hip=seat_hip.lerp(crouch_hip,blend)
   _hip_pose(hip,PI/2,0)
   for i in range(2):_leg(i,_raised_foot(i).lerp(_ground_foot(i),blend),1)
   _brace(1);_hang_garment();_eyes(0)
   if t>=1:_phase("putting_shoes")
  "getting_off":
   _hip_pose(crouch_hip.lerp(_standing_hip(),blend),PI/2,0)
   for i in range(2):
    var step:float=smoothstep(.08 if i==0 else .3,.7 if i==0 else .98,t)
    _leg(i,_ground_foot(i).lerp(_standing_foot(i),step)+Vector3.UP*sin(step*PI)*.05,1)
   _brace(sin(t*PI))
   _hang_garment()
   _eyes(0)
   if t>=1:
    actor.collision_mask=1;actor.collision_layer=2;_phase("stepping_clear")
  "dressing":
   if actor.visual.has_meta("character_id"):
    actor.bed_return=actor.position;actor.bed_visual_transform=actor.visual.transform;actor.cancel_bed();return
   _relax_arms()
   var collar:Vector3=actor.position+Vector3.UP*(1.4*height_scale)
   var unfolded:=smoothstep(0,.7,t)
   _garment(_held_position().lerp(collar,unfolded)+Vector3.UP*sin(unfolded*PI)*.18,1-unfolded)
   _collar_hands(collar,1-smoothstep(.8,1,t))
   if t>=.75:
    _clothes(true)
    if outfit!=null:outfit.hide()
   _eyes(0)
   if t>=1:
    actor.bed_return=actor.position
    actor.bed_visual_transform=actor.visual.transform
    actor.cancel_bed()
 _blend_entry()
func _blend_entry() -> void:
 if phase_world.is_empty() or elapsed>=.22:return
 var rig:Skeleton3D=actor.pose_skeleton;var inverse:Transform3D=rig.global_transform.affine_inverse()
 var targets:Array[Transform3D]=[]
 for bone in range(rig.get_bone_count()):targets.append(rig.global_transform*rig.get_bone_global_pose(bone))
 for bone in range(targets.size()):rig.set_bone_global_pose_override(bone,inverse*phase_world[bone].interpolate_with(targets[bone],smoothstep(0,.22,elapsed)),1,true)
func _neutral() -> void:
 actor.pose_skeleton.clear_bones_global_pose_override();actor.pose_skeleton.reset_bone_poses()
func _standing_hip() -> Vector3:
 return standing_root+Vector3.UP*(hip_rest.y*height_scale)
func _hip_pose(target:Vector3,yaw:float,tilt:float) -> void:
 actor.visual.rotation=Vector3(tilt,yaw,0)
 var current:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("Hips")).origin
 actor.global_position+=target-current
func _lie() -> void:
 _hip_pose(lying_hip,0,-PI/2);_relax_arms()
 var spine:int=actor._bone("Spine")
 if spine>=0:actor.pose_skeleton.set_bone_pose_rotation(spine,Quaternion(Vector3.RIGHT,sin(clock*1.8)*.012))
func _sit_pose(progress:float) -> void:
 var hip:=lying_hip.lerp(seat_hip,progress);hip.y+=sin(PI*progress)*.12
 _hip_pose(hip,PI/2*progress,-PI/2*(1-progress))
 for i in range(2):
  var lying:Vector3=actor.bed_anchor+Vector3(feet_rest[i].x*height_scale,.10,-feet_rest[i].y*height_scale)
  _leg(i,lying.lerp(_raised_foot(i),progress)+Vector3.UP*sin(progress*PI)*.1,progress)
 _brace(progress)
func _raised_foot(index:int) -> Vector3:
 return Vector3(-3.35,actor.bed_anchor.y+.10,seat_hip.z-feet_rest[index].x*height_scale)
func _ground_foot(index:int) -> Vector3:
 return Vector3(-3.35,standing_root.y,standing_root.z)+Vector3(0,feet_rest[index].y*height_scale,-feet_rest[index].x*height_scale)
func _standing_foot(index:int) -> Vector3:
 return standing_root+Vector3(0,feet_rest[index].y*height_scale,-feet_rest[index].x*height_scale)
func _leg(index:int,target_world:Vector3,flat:float) -> void:
 var side:String="Left" if index==0 else "Right"
 var upper:int=actor._bone(side+"UpLeg");var lower:int=actor._bone(side+"Leg");var foot:int=actor._bone(side+"Foot")
 var skeleton:Skeleton3D=actor.pose_skeleton
 var a:Transform3D=skeleton.get_bone_global_pose(upper);var b:Transform3D=skeleton.get_bone_global_pose(lower);var c:Transform3D=skeleton.get_bone_global_pose(foot)
 var target:Vector3=skeleton.to_local(target_world)
 var l1:float=a.origin.distance_to(b.origin);var l2:float=b.origin.distance_to(c.origin)
 var direction:Vector3=(target-a.origin).normalized();var distance:float=clampf(target.distance_to(a.origin),.02,l1+l2-.003)
 var along:float=(l1*l1-l2*l2+distance*distance)/(2*distance)
 var pole:=Vector3.BACK-direction*Vector3.BACK.dot(direction)
 if pole.length()<.05:pole=Vector3.UP-direction*Vector3.UP.dot(direction)
 var knee:Vector3=a.origin+direction*along+pole.normalized()*sqrt(maxf(0,l1*l1-along*along))
 a.basis=Basis(Quaternion((b.origin-a.origin).normalized(),(knee-a.origin).normalized()))*a.basis
 b.basis=Basis(Quaternion((c.origin-b.origin).normalized(),(a.origin+direction*distance-knee).normalized()))*b.basis;b.origin=knee
 c.origin=a.origin+direction*distance
 var world_flat:=skeleton.global_basis.orthonormalized().inverse()*Basis(Vector3.UP,PI/2)
 c.basis=c.basis.slerp(world_flat,flat)
 skeleton.set_bone_global_pose_override(upper,a,1,true);skeleton.set_bone_global_pose_override(lower,b,1,true);skeleton.set_bone_global_pose_override(foot,c,1,true)
func _relax_arms() -> void:
 var center:Vector3=actor.pose_skeleton.get_bone_global_pose(actor._bone("Hips")).origin
 for side:String in ["Left","Right"]:
  var arm:int=actor._bone(side+"Arm")
  var sign_x:float=signf(actor.pose_skeleton.get_bone_global_pose(arm).origin.x-center.x)
  actor._reach_arm(side,actor.pose_skeleton.global_transform*(center+Vector3(sign_x*.27,.02,.06)),1)
func _collar_hands(collar:Vector3,amount:float) -> void:
 var center:Vector3=actor.pose_skeleton.get_bone_global_pose(actor._bone("Hips")).origin
 for side:String in ["Left","Right"]:
  var arm:int=actor._bone(side+"Arm");var sign_x:float=signf(actor.pose_skeleton.get_bone_global_pose(arm).origin.x-center.x)
  var rest:Vector3=actor.pose_skeleton.global_transform*(center+Vector3(sign_x*.27,.02,.06))
  var grip:Vector3=collar+actor.visual.global_basis.x.normalized()*sign_x*.14
  actor._reach_arm(side,rest.lerp(grip,amount),1)
func _brace(weight:float) -> void:
 var center:Vector3=actor.pose_skeleton.get_bone_global_pose(actor._bone("Hips")).origin
 for side:String in ["Left","Right"]:
  var arm:int=actor._bone(side+"Arm");var sign_x:float=signf(actor.pose_skeleton.get_bone_global_pose(arm).origin.x-center.x)
  var rest:Vector3=actor.pose_skeleton.global_transform*(center+Vector3(sign_x*.27,.02,.06))
  var support:=Vector3(-4.12,actor.bed_anchor.y-.05,-3.05+(.3 if side=="Right" else -.3))
  actor._reach_arm(side,rest.lerp(support,weight),1)
func _walking(delta:float,goal:Vector3) -> void:
 actor.collision_mask=1;actor.collision_layer=2
 var offset:Vector3=goal-actor.position;offset.y=0
 if offset.length()<.055:
  actor.velocity=Vector3.ZERO
  _phase("sitting_down" if actor.bed_stage=="approaching_bed" else ("undressing" if actor.bed_stage=="approaching_rack" else "taking_cloak"))
  return
 var before:Vector3=actor.position;var direction:=offset.normalized()
 actor.velocity=direction*minf(2,offset.length()/maxf(delta,.001));actor.velocity.y=-.2 if actor.is_on_floor() else -2
 actor.move_and_slide();actor.visual.rotation=Vector3(0,lerp_angle(actor.visual.rotation.y,atan2(direction.x,direction.z),1-exp(-10*delta)),0)
 _neutral()
 if actor.animator!=null and actor.walk_clip!=&"":
  actor.animator.play(actor.walk_clip);actor.animator.seek(fposmod(clock,actor.animator.get_animation(actor.walk_clip).length),true);actor.animator.stop(true)
 if clothing_on:outfit.hide()
 elif hung:_hang_garment()
 else:_garment(_held_position(),1)
 _relax_arms();_eyes(0)
 if actor.position.distance_to(before)<delta*.1:stalled+=delta
 else:stalled=0
 if stalled>3:
  actor.bed_return=actor.position
  if actor.bed_stage in ["approaching_rack","approaching_bed"]:actor.cancel_bed()
  else:_phase("dressing")
func _held_position() -> Vector3:
 return actor.position+Vector3.UP*(1.05*height_scale)+actor.visual.global_basis.z.normalized()*.25
func _hang_garment() -> void:
 if outfit==null:return
 outfit.show();outfit.global_position=rack_hook
 outfit.global_basis=Basis(Vector3.UP,-PI/2)*Basis.from_scale(Vector3(.65,1,.65)*height_scale)
 if not hung:
  if garment_body==null:
   garment_body=StaticBody3D.new();garment_body.name="HangingBedClothes";actor.get_parent().add_child(garment_body)
   for mesh:MeshInstance3D in outfit.get_children():
    var points:=PackedVector3Array()
    for surface in range(mesh.mesh.get_surface_count()):
     var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
     for vertex:Vector3 in vertices:points.append(mesh.global_transform*vertex)
    if points.size()<4:continue
    var collision:=CollisionShape3D.new();var shape:=ConvexPolygonShape3D.new();shape.points=points;collision.shape=shape;garment_body.add_child(collision)
  garment_body.collision_layer=1;hung=true
func _clothes(value:bool) -> void:
 clothing_on=value
 if value:
  hung=false
  if garment_body!=null:garment_body.collision_layer=0
 for mesh:MeshInstance3D in actor.bed_hidden:
  if is_instance_valid(mesh):mesh.visible=actor.bed_hidden[mesh] and value
func _make_outfit() -> void:
 for source:MeshInstance3D in actor.bed_hidden:
  if str(source.name)=="attach-neck-mesh" and actor.bed_hidden[source]:has_cape=true
 outfit=Node3D.new();outfit.name="BedOutfit";actor.get_parent().add_child(outfit);outfit.hide()
 for source:MeshInstance3D in actor.bed_hidden:
  if not actor.bed_hidden[source]:continue
  var geometry:=ArrayMesh.new()
  for surface in range(source.mesh.get_surface_count()):
   var arrays:Array=source.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for i in range(vertices.size()):vertices[i]-=Vector3(0,1.4,0)
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null
   geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);geometry.surface_set_material(surface,source.get_active_material(surface))
  var mesh:=MeshInstance3D.new();mesh.mesh=geometry;outfit.add_child(mesh)
func _garment(position_world:Vector3,folded:float) -> void:
 if outfit==null:return
 hung=false
 if garment_body!=null:garment_body.collision_layer=0
 outfit.show();outfit.global_position=position_world
 var scale:=Vector3.ONE.lerp(Vector3(.4,.15,.3),folded)*height_scale
 outfit.global_basis=Basis(Vector3.UP,actor.visual.global_rotation.y if folded<.99 else 0)*Basis.from_scale(scale)
func _make_eyes() -> void:
 # 新人物的五官画在整张皮肤上，不叠加旧 Polyfork 专属位置的眼皮几何。
 if actor.visual.has_meta("character_id"):return
 var skeleton:Skeleton3D=actor.pose_skeleton;var head:int=actor._bone("Head")
 eye_mount=BoneAttachment3D.new();eye_mount.name="BedEyelids";eye_mount.bone_name=skeleton.get_bone_name(head);skeleton.add_child(eye_mount)
 var female:bool=actor.visual.find_child("attach-face-mesh",true,false)!=null
 var skin:=StandardMaterial3D.new();skin.albedo_color=Color(.445,.27,.156) if female else Color(.624,.376,.202)
 var line:=StandardMaterial3D.new();line.albedo_color=Color(.08,.035,.02)
 var inverse:Transform3D=skeleton.get_bone_global_rest(head).affine_inverse()
 for x:float in [-.0507,.0507]:
  var lid:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.05,.03,.004);lid.mesh=box;lid.material_override=skin;eye_mount.add_child(lid);lid.position=inverse*Vector3(x,1.604,.112);covers.append(lid)
  var closed:=MeshInstance3D.new();var stroke:=BoxMesh.new();stroke.size=Vector3(.034,.003,.001);closed.mesh=stroke;closed.material_override=line;eye_mount.add_child(closed);closed.position=inverse*Vector3(x,1.604,.115);eye_lines.append(closed)
 _eyes(0)
func _eyes(amount:float) -> void:
 eyes_closed=clampf(amount,0,1)
 for lid:MeshInstance3D in covers:lid.visible=eyes_closed>.02;lid.scale.y=maxf(.01,eyes_closed)
 for line:MeshInstance3D in eye_lines:line.visible=eyes_closed>.7
func label() -> String:
 if not has_cape and actor.bed_stage in ["undressing","dressing"]:return "取下帽子，整理衣物" if actor.bed_stage=="undressing" else "戴上帽子，整理衣物"
 return str(LABELS.get(actor.bed_stage,"准备休息"))
func dispose(detach:bool=true) -> void:
 footwear.dispose(detach)
 if is_instance_valid(garment_body):
  garment_body.collision_layer=0
  if detach and garment_body.get_parent()!=null:garment_body.get_parent().remove_child(garment_body)
  garment_body.queue_free();garment_body=null
 if is_instance_valid(outfit):
  outfit.hide()
  if detach and outfit.get_parent()!=null:outfit.get_parent().remove_child(outfit)
  outfit.queue_free()
 if is_instance_valid(eye_mount):
  eye_mount.hide()
  if detach and eye_mount.get_parent()!=null:eye_mount.get_parent().remove_child(eye_mount)
  eye_mount.queue_free()
 outfit=null;eye_mount=null
