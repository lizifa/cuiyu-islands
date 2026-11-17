extends RefCounted
## Owns the seated rowing pose without locking normal boat controls via home_busy.
const Legs=preload("res://scripts/life/grounded_pose.gd")
const READY_TIME:=2.0
var actor:CharacterBody3D
var rig:Skeleton3D
var equipment:Node3D
var oars:Array[Node3D]=[]
var stock:Array[MeshInstance3D]=[]
var positions:Array[Vector3]=[]
var rotations:Array[Quaternion]=[]
var start_yaw:=0.0
var elapsed:=0.0
var phase:=0.0
var strength:=0.0
var hip_height:=0.0
var eye_height:=1.18
var net_phase:=""
var oar_blade:StandardMaterial3D
var net_time:=0.0
var active:=false
func begin(owner_actor:CharacterBody3D) -> bool:
 actor=owner_actor
 start_yaw=actor.visual.rotation.y
 var rigs:Array[Node]=actor.visual.find_children("*","Skeleton3D",true,false)
 if rigs.is_empty():return false
 rig=rigs[0];actor.pose_skeleton=rig
 if actor.animator!=null:
  actor.animator.speed_scale=1;actor.animator.play(actor.idle_clip);actor.animator.advance(0);actor.animator.stop(true)
 rig.clear_bones_global_pose_override()
 for bone in range(rig.get_bone_count()):positions.append(rig.get_bone_pose_position(bone));rotations.append(rig.get_bone_pose_rotation(bone))
 hip_height=(rig.global_transform*rig.get_bone_global_pose(actor._bone("Hips")).origin).y-actor.position.y
 for mesh:MeshInstance3D in actor.boat_visual.find_children("*","MeshInstance3D",true,false):
  if str(mesh.name).contains("oar"):stock.append(mesh);mesh.hide()
 equipment=Node3D.new();equipment.name="RowingEquipment";actor.add_child(equipment)
 var world:Node3D=actor.get_parent();var wood:Material=world.material(Color("a57e4d"))
 oar_blade=world.material(Color("c8a06a"))
 world.box(equipment,Vector3(0,.18,0),Vector3(1.12,.10,.34),wood).name="RowingBench"
 for side in range(2):
  var oar:=Node3D.new();oar.name="LeftOar" if side==0 else "RightOar";equipment.add_child(oar);oars.append(oar)
  var shaft:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.024;cylinder.bottom_radius=.03;cylinder.height=1.78;cylinder.radial_segments=10;shaft.mesh=cylinder;shaft.material_override=wood;shaft.position.y=.36;oar.add_child(shaft)
  world.box(oar,Vector3(0,1.36,0),Vector3(.19,.46,.045),oar_blade).name="Blade"
  var grip:=Marker3D.new();grip.name="Grip";grip.position.y=-.55;oar.add_child(grip)
 active=true;elapsed=0;phase=0;strength=0
 tick(0,0)
 return true
func ready() -> bool:return active and elapsed>=READY_TIME-.0001
func tick(delta:float,speed:float) -> void:
 if not active or not is_instance_valid(rig) or not actor.allowed:return
 elapsed+=delta
 actor.visual.rotation.y=lerp_angle(start_yaw,actor.boat_heading+PI,smoothstep(0,.75,elapsed))
 var sitting:float=smoothstep(0,.9,elapsed)
 var taking:float=smoothstep(1.15,READY_TIME,elapsed)
 strength=move_toward(strength,clampf(speed/3.0,0,1) if ready() else 0,delta*3)
 if strength>.001:phase=fposmod(phase+delta*1.05*clampf(speed/4,.65,1.45),1)
 else:phase=0
 rig.clear_bones_global_pose_override()
 for bone in range(positions.size()):rig.set_bone_pose_position(bone,positions[bone]);rig.set_bone_pose_rotation(bone,rotations[bone])
 var hips:int=actor._bone("Hips")
 var hip:Vector3=positions[hips];hip.y+=(.48-hip_height)*sitting/maxf(.01,rig.global_basis.get_scale().y);rig.set_bone_pose_position(hips,hip)
 var drive:bool=phase<.58
 var sweep:float=lerpf(.65,-.65,smoothstep(0,.58,phase)) if drive else lerpf(-.65,.65,smoothstep(.58,1,phase))
 var lift:float=0 if drive else sin((phase-.58)/.42*PI)
 # 桨叶只在水面附近擦过，不再深插到水下把整根桨当成黑色尖刺。
 var dip:float=lerpf(-.03,-.19+lift*.22,strength)
 var lean:float=sin(phase*TAU)*.10*strength+sin(smoothstep(.35,1.65,elapsed)*PI)*.35
 for key:String in ["Spine","Spine1"]:
  var spine:int=actor._bone(key)
  if spine>=0:rig.set_bone_pose_rotation(spine,rotations[spine]*Quaternion(Vector3.RIGHT,lean))
 equipment.rotation.y=actor.boat_heading
 for side in range(2):
  var sign_x:float=-1 if side==0 else 1
  var oar:Node3D=oars[side]
  var outward:=Vector3(sign_x*cos(sweep*strength),dip,sin(sweep*strength)).normalized()
  var working:Basis=Basis(Quaternion(Vector3.UP,outward))
  var stowed:Basis=Basis(Quaternion(Vector3.UP,Vector3.BACK))
  oar.position=Vector3(sign_x*.22,.27,-.25).lerp(Vector3(sign_x*.70,.50,0),taking)
  oar.basis=stowed.slerp(working,taking)
  oar.get_node("Grip").position.y=lerpf(.15,-.55,taking)
  if actor.visual.has_meta("character_id"):
   # 短身卡通人物使用靠近身体的握点；桨叶与船桨保持原尺寸。
   var grip_target:Vector3=actor.position+actor.visual.global_basis.x.normalized()*(.20 if side==0 else -.20)+actor.visual.global_basis.z.normalized()*(.12+.14*sin(phase*TAU)*strength)+Vector3.UP*(.82+.025*lift)
   oar.global_position+=grip_target-oar.get_node("Grip").global_position
  var foot:Vector3=actor.position+actor.visual.global_basis.z.normalized()*.48+actor.visual.global_basis.x.normalized()*(.16 if side==0 else -.16)
  foot.y=actor.position.y-.07
  if actor.visual.has_meta("character_id"):
   foot=actor.position+actor.visual.global_basis.z.normalized()*.12+actor.visual.global_basis.x.normalized()*(.16 if side==0 else -.16)
   foot.y=actor.position.y+.07
  Legs.leg(actor,side,foot,sitting)
  actor._reach_arm("Left" if side==0 else "Right",oar.get_node("Grip").global_position,smoothstep(.25,1.1,elapsed))
 if net_phase!="":
  var stow:float=(1-smoothstep(0,1,net_time)) if net_phase=="recover" else (smoothstep(0,.5,net_time) if net_phase=="cast" else 1.0)
  for index in range(oars.size()):
   var oar:Node3D=oars[index]
   oar.position=oar.position.lerp(Vector3(-.22 if index==0 else .22,.27,-.25),stow)
   oar.basis=oar.basis.slerp(Basis(Quaternion(Vector3.UP,Vector3.BACK)),stow)
  var chest:int=actor._bone("Spine1")
  if chest>=0:rig.set_bone_pose_rotation(chest,rotations[chest]*Quaternion(Vector3.UP,-.7*stow))
  var forward:Vector3=-actor.visual.global_basis.x.normalized()
  var right:Vector3=actor.visual.global_basis.x.normalized()
  var reach:float=smoothstep(.3,1.3,net_time) if net_phase=="cast" else (.5+.3*sin(net_time*TAU*1.2) if net_phase=="haul" else .2)
  for side in range(2):
   var hand:Vector3=actor.position+Vector3.UP*(.85+reach*.3)+forward*(.35+reach*.65)+right*(.3 if side==0 else -.3)
   actor._reach_arm("Left" if side==0 else "Right",hand,stow)
 else:
  for oar:Node3D in oars:oar.show()
 rig.force_update_all_bone_transforms()
 eye_height=(rig.global_transform*rig.get_bone_global_pose(actor._bone("Head")).origin).y-actor.position.y
func finish() -> void:
 if not active:return
 active=false
 if is_instance_valid(rig):
  rig.clear_bones_global_pose_override()
  for bone in range(positions.size()):rig.set_bone_pose_position(bone,positions[bone]);rig.set_bone_pose_rotation(bone,rotations[bone])
 if is_instance_valid(actor):
  if actor.pose_skeleton==rig:actor.pose_skeleton=null
  if actor.animator!=null:actor.animator.speed_scale=1;actor.animator.play(actor.idle_clip,.2)
 for mesh:MeshInstance3D in stock:
  if is_instance_valid(mesh):mesh.show()
 if is_instance_valid(equipment):equipment.queue_free()
