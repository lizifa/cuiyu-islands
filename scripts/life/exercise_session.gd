extends Node
## One interruptible session per piece of equipment; no reward on repeated clicks.
const Gesture=preload("res://scripts/life/home_gesture.gd")
const Legs=preload("res://scripts/life/grounded_pose.gd")
var app:Node
var active:=false
var kind:=""
var equipment:Node3D
var gesture:RefCounted
var elapsed:=0.0
var intensity:=1
var paused:=false
var reps:=0
var return_position:=Vector3.ZERO
## 开始锻炼那一刻朝着器材的方向；整套动作都沿这个方向做，不再扭回世界坐标的固定朝向。
var work_yaw:=0.0
var mount:=Vector3.ZERO
var weights:Array[MeshInstance3D]=[]
## 哑铃的「拿起 / 放下」用独立阶段演：pickup → stand → train → putdown。
var stage:="train"
var stage_time:=0.0
var train_time:=0.0
var stopping:=false
var rack_targets:Array[Vector3]=[]
var idle_hands:Array[Vector3]=[]
var grab_position:=Vector3.ZERO
var panel:PanelContainer
var label:Label
func setup(owner_app:Node) -> void:
 app=owner_app
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",app.panel());app.safe_root.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 panel.offset_left=-160;panel.offset_right=160;panel.offset_top=-118;panel.offset_bottom=-76
 var rows:=VBoxContainer.new();panel.add_child(rows)
 # 只留一行进度：退出统一走右下那一个「结束锻炼」槽位，不再多一个同义大按钮。
 label=app.label("锻炼中",18);rows.add_child(label);panel.hide()
func begin(point:Dictionary) -> bool:
 if active or app.state.location!="villa" or app.state.home_floor!=0:return false
 equipment=point.get("equipment")
 var reach:float=2.6 if str(point.get("kind",""))=="gym_weights" else 1.0
 # 靠近器材 + 面对它就能开始，不再要求先挪到某个固定站位。
 if not is_instance_valid(equipment) or not app.world.interactable(point):return app.state.say("靠近器材，正面面对它再开始。")
 if app.state.energy<5 or app.state.thirst<5:return app.state.say("先休息、补充饮水后再锻炼。" if app.state.energy<5 and app.state.thirst<5 else ("先休息一会儿再锻炼。" if app.state.energy<5 else "先喝点水再锻炼。"))
 gesture=Gesture.new()
 if not gesture.setup(app.world.player):return false
 var actor:Node3D=app.world.player
 return_position=actor.position;actor.exercise_return=return_position
 var rig:Skeleton3D=gesture.rig
 kind=str(point.kind).trim_prefix("gym_")
 # 「面对器材」的方向就是动作方向：以器材中心为准，玩家已经朝着它，这里只是把角度对齐到器材。
 var eu:Vector3=equipment.global_position
 var to_equipment:Vector3=eu-actor.position;to_equipment.y=0
 work_yaw=atan2(to_equipment.x,to_equipment.z) if to_equipment.length()>.05 else actor.visual.rotation.y
 mount=equipment.global_position
 if kind=="treadmill":mount+=Vector3(0,.24,.25)
 elif kind=="bike":mount+=Vector3(0,.02,.24)
 elif kind=="weights":
  # 弯举是站桩动作：机位中心在伸手位（拿完就站在原地练，不挪窝）。
  mount=actor.position
 else:mount.y+=.03
 if kind=="weights":
  # 拿起哑铃：先记下架子上的抓取点，和双手待机位置，后面从待机位插值过去。
  stage="pickup";stage_time=0;train_time=0;stopping=false
  rack_targets.clear();idle_hands.clear()
  var to_player:Vector3=actor.position-equipment.global_position;to_player.y=0
  to_player=to_player.normalized() if to_player.length()>.05 else actor.visual.global_basis.z.normalized()
  var rack_side:Vector3=equipment.global_basis.x.normalized()
  # 伸手站位：站得离架多远才够得着。架面哑铃在离地 0.645 米，人站 0.5 米外弯下腰刚好能握住。
  grab_position=equipment.global_position+to_player*.52
  # 站位横向往架子中间收一收：内圈两把哑铃在 ±0.27 米，人站太偏的话外侧那只手会伸不到位。
  var side_offset:float=(grab_position-equipment.global_position).dot(rack_side)
  grab_position-=rack_side*(side_offset-clampf(side_offset,-.28,.28))
  grab_position.y=actor.position.y
  # 机位中心也要跟着落到伸手位：否则镜头还围着 2 米外那个起点，人一贴近架子就整个出框。
  mount=grab_position
  # 抓取点就取内圈那两把哑铃的杆位（架宽 2.3 米，内圈在 ±0.27 米），高度按架面本身算，
  # 不要再拍脑袋写 0.58 —— 那会让手停在半空、碰不到哑铃。
  for side_index in range(2):
   var lat:float=-.27 if side_index==0 else .27
   rack_targets.append(equipment.global_position+Vector3.UP*.645+rack_side*lat+to_player*.06)
   var hand_bone:int=actor._bone("LeftHand" if side_index==0 else "RightHand")
   var rest:Vector3=actor.position+Vector3.UP*1.05
   if hand_bone>=0 and rig!=null:rest=rig.global_transform*rig.get_bone_global_pose(hand_bone).origin
   idle_hands.append(rest)
 else:
  stage="train";train_time=0;stopping=false
 active=true;elapsed=0;intensity=1;paused=false;reps=0;app.sprinting=false;app.sprint_action.reset()
 panel.show();app.state.say(str(point.title)+" · 右下角可结束")
 if kind=="weights":
  for side in range(2):
   # 杆要短、配重要小：原来杆长 0.24 米、配重半径 0.085 米，两只哑铃在胸前连成一根杠铃，
   # 内端直接插进前臂和胸口（两手实距只有 0.41 米，杆总宽 0.65 米）。
   var prop:=MeshInstance3D.new();prop.name="HeldGymDumbbell";var shaft:=CylinderMesh.new();shaft.top_radius=.017;shaft.bottom_radius=.017;shaft.height=.15;prop.mesh=shaft;prop.material_override=app.world.material(Color("8d9aa0"));app.world.add_child(prop)
   for end:float in [-.075,.075]:
    var plate:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.055;mesh.bottom_radius=.055;mesh.height=.04;plate.mesh=mesh;plate.position.y=end;plate.material_override=app.world.material(Color("3d4d55"));prop.add_child(plate)
   prop.visible=false
   weights.append(prop)
 if app.world.orbit.stable_third_person:
  var view:Dictionary={"treadmill":{"yaw":2.35,"distance":6.8,"pitch":20,"height":1.2},"bike":{"yaw":2.6,"distance":6.5,"pitch":20,"height":1.35},"weights":{"yaw":3.05,"distance":3.2,"pitch":20,"height":1.15},"yoga":{"yaw":1.15,"distance":6.8,"pitch":22,"height":1.1}}[kind]
  # 机位跟着「面对器材的方向」转：原来按固定世界朝向调的机位，转到侧面对着器材时会拍到后脑。
  app.world.orbit.begin_activity_view("gym",mount+Vector3.UP*float(view.height),work_yaw+float(view.yaw),float(view.distance),deg_to_rad(float(view.pitch)))
 return true

func finish() -> void:
 if not active:return
 # 按下结束时先演「把哑铃放回架上」，演完再真正退出；取消/离开别墅则直接退出。
 if kind=="weights" and not stopping and app.state.location=="villa" and app.state.home_floor==0 and is_instance_valid(equipment):
  stopping=true;stage="putdown";stage_time=0;paused=false
  app.state.say("把哑铃放回架上…");app._update_context();return
 _release()

func _release() -> void:
 if not active:return
 active=false;stopping=false
 var actor:Node3D=app.world.player
 if gesture!=null:gesture.clear();gesture=null
 if kind=="weights":
  pass # 站桩动作原地结束：位置不动，避免"退回去再上来"
 elif app.state.location=="villa" and app.state.home_floor==0 and is_instance_valid(equipment):actor.position=return_position
 actor.exercise_return=Vector3.INF;actor.velocity=Vector3.ZERO
 for prop:MeshInstance3D in weights:
  if is_instance_valid(prop):prop.queue_free()
 weights.clear()
 if is_instance_valid(equipment) and kind=="bike":
  for side in range(2):equipment.get_node("Pedal%d"%side).position=Vector3(-.22 if side==0 else .22,.4,0)
 if app.world.orbit.stable_third_person:app.world.orbit.end_activity_view("gym")
 panel.hide();app._sync_overlay_state();app._update_context();app._save(false)

func _weights_tick(actor:Node3D,rig:Skeleton3D,delta:float) -> void:
 var pace:float=1.0+float(intensity-1)*.55
 stage_time+=delta
 # 拿起前先把人送到伸手能够到的位置（站位可以随便站，够不着就自己贴过去），
 # 不然人站在 2 米外挥手臂，哑铃会「隔空飞到手上」。
 if stage=="pickup" and grab_position.is_finite():
  actor.position=actor.position.lerp(grab_position,1.0-exp(-12.0*delta))
 var bend:=0.0
 var held:=false
 if stage=="pickup":
  bend=smoothstep(0,1,minf(stage_time/.75,1))
  if stage_time>=.75:held=true
  if stage_time>1.05:stage="stand";stage_time=0
 elif stage=="stand":
  bend=1.0-smoothstep(0,1,minf(stage_time/.6,1));held=true
  if stage_time>.6:stage="train";stage_time=0;train_time=0
 elif stage=="train":
  train_time+=delta;held=true
  _curl_arms(actor,rig,train_time,delta,pace)
  app.state.energy=maxf(0,app.state.energy-delta*.08*pace)
  app.state.thirst=maxf(0,app.state.thirst-delta*.05*pace)
  if app.state.energy<3 or app.state.thirst<3:_release();app.state.say("锻炼结束，休息补充些水。");return
 elif stage=="putdown":
  bend=smoothstep(0,1,minf(stage_time/.8,1));held=true
  if stage_time>.8:
   for prop:MeshInstance3D in weights:
    if is_instance_valid(prop):prop.visible=false
   _release();return
 if stage in ["pickup","stand","putdown"]:
  _bend_to_rack(actor,rig,bend,held)
 _weights_label()

func _bend_to_rack(actor:Node3D,rig:Skeleton3D,t:float,held:bool) -> void:
 # 弯腰伸手到架面：脊柱前屈 + 髋略下沉，双手从待机位插值到抓取点。
 var spine:int=actor._bone("Spine")
 if spine>=0 and gesture!=null and spine<gesture.rotations.size():
  rig.set_bone_pose_rotation(spine,gesture.rotations[spine]*Quaternion(Vector3.RIGHT,1.2*t))
 var hip:int=actor._bone("Hips")
 if hip>=0 and gesture!=null and hip<gesture.positions.size():
  var scale_y:float=maxf(rig.global_basis.get_scale().y,.001)
  rig.set_bone_pose_position(hip,gesture.positions[hip]+Vector3.DOWN*(.22*t/scale_y))
 for side_index in range(2):
  var side:String="Left" if side_index==0 else "Right"
  if side_index>=idle_hands.size() or side_index>=rack_targets.size():continue
  actor._reach_arm(side,idle_hands[side_index].lerp(rack_targets[side_index],t),1)
 rig.force_update_all_bone_transforms()
 for side_index in range(2):
  var prop:MeshInstance3D=weights[side_index] if side_index<weights.size() else null
  if prop==null or not is_instance_valid(prop):continue
  prop.visible=held
  if not held:continue
  var hand_bone:int=actor._bone("LeftHand" if side_index==0 else "RightHand")
  if hand_bone<0:continue
  var hand:Vector3=rig.global_transform*rig.get_bone_global_pose(hand_bone).origin
  var side_axis:Vector3=actor.visual.global_basis.x.normalized()
  var front_axis:Vector3=actor.visual.global_basis.z.normalized()
  prop.global_transform=Transform3D(Basis(side_axis.cross(front_axis).normalized(),side_axis,front_axis),hand+front_axis*.04)

func _weights_label() -> void:
 var prefix:="拿起哑铃…" if stage in ["pickup","stand"] else ("把哑铃放回架上…" if stage=="putdown" else "哑铃 · 交替屈臂训练")
 label.text=prefix+(" · 第 %d 次"%[reps+1] if stage=="train" else "")+(" · 暂停中" if paused else "")+" · 强度%d"%intensity

func set_intensity(level:int) -> void:
 if not active:return
 intensity=clampi(level,1,3)
 app.state.say("训练强度调到 %d 档。"%intensity)
 app._update_context()
func toggle_pause() -> void:
 if not active:return
 paused=not paused
 app.state.say("先歇一下，动作停在半空。" if paused else "继续练。")
 app._update_context()
func _curl_arms(actor:Node3D,rig:Skeleton3D,since_start:float,delta:float,pace:float) -> void:
 # 弯举：肘钉在体侧不动，前臂在矢状面（前-上）里屈伸；手骨旋后，哑铃落在掌心。
 var phase:float=since_start*2.2*pace
 reps=int(maxf(0.0,phase)/TAU)
 var to_local:Basis=rig.global_transform.basis.inverse()
 var forward:Vector3=(to_local*actor.visual.global_basis.z.normalized()).normalized()
 var up_local:Vector3=(to_local*Vector3.UP).normalized()
 var lateral:Vector3=actor.visual.global_basis.x.normalized()
 for side_index in range(2):
  var side:String="Left" if side_index==0 else "Right"
  var flex:float=(sin(phase+PI*side_index)+1)*.5
  var fore:int=actor._bone(side+"ForeArm")
  var hand_bone:int=actor._bone(side+"Hand")
  if fore<0 or hand_bone<0:continue
  var elbow_t:Transform3D=rig.get_bone_global_pose(fore)
  var base_hand:Vector3=rig.get_bone_global_pose(hand_bone).origin
  var fore_len:float=elbow_t.origin.distance_to(base_hand)
  if fore_len<.01:continue
  var angle:float=deg_to_rad(8.0+142.0*flex)
  var dir:Vector3=(forward*sin(angle)-up_local*cos(angle)).normalized()
  var rest_dir:Vector3=(base_hand-elbow_t.origin).normalized()
  var wrist:Vector3=elbow_t.origin+dir*fore_len
  var fore_t:Transform3D=elbow_t
  fore_t.basis=Basis(Quaternion(rest_dir,dir))*fore_t.basis
  fore_t.origin=elbow_t.origin
  var hand_t:Transform3D=rig.get_bone_global_pose(hand_bone)
  hand_t.origin=wrist
  # 旋后：底端锤式，越屈掌心越朝上（顶端约 75°）。
  hand_t.basis=Basis(Quaternion(dir,-deg_to_rad(75.0)*flex))*hand_t.basis
  rig.set_bone_global_pose_override(fore,fore_t,1,true)
  rig.set_bone_global_pose_override(hand_bone,hand_t,1,true)
  if side_index<weights.size():
   # 握点在掌心：腕骨沿前臂方向再推 4.5 厘米；杆轴保持横向并跟着前臂走。
   var world_dir:Vector3=(rig.global_transform.basis*dir).normalized()
   var palm:Vector3=rig.global_transform*(wrist+dir*.045)
   var y_axis:Vector3=lateral
   var x_axis:Vector3=world_dir.cross(y_axis).normalized()
   var z_axis:Vector3=x_axis.cross(y_axis).normalized()
   weights[side_index].global_transform=Transform3D(Basis(x_axis,y_axis,z_axis),palm)
func _physics_process(delta:float) -> void:
 if not active:return
 if app.state.location!="villa" or app.state.home_floor!=0 or not is_instance_valid(equipment) or not is_instance_valid(gesture.rig):finish();return
 if not app.movement_enabled():return
 if paused:return
 elapsed+=delta
 var actor:Node3D=app.world.player
 var rig:Skeleton3D=gesture.rig
 # 哑铃是站桩动作：位置由拿起阶段自己贴到架前，这里不能再把人按回原位，否则每帧都被拉回去、
 # 手永远停在离架子一米多的地方。
 if kind!="weights":actor.position=return_position.lerp(mount,smoothstep(0,1,minf(elapsed/1.1,1)))
 # 保持开始时的方向（就是面对器材的那一面），不再固定转到 0 / PI 让玩家原地转身。
 actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,work_yaw,1-exp(-7*delta))
 rig.clear_bones_global_pose_override()
 if kind=="weights":
  _weights_tick(actor,rig,delta)
  return
 var pace:float=1.0+float(intensity-1)*.55
 if elapsed<1.1 or kind=="treadmill":
  if actor.animator!=null:
   var clip:StringName=actor.run_clip if kind=="treadmill" and elapsed>=1.1 and not actor.run_clip.is_empty() else actor.walk_clip
   actor.animator.play(clip);actor.animator.seek(fmod(elapsed*(1.25 if elapsed>=1.1 else .8)*pace,actor.animator.current_animation_length),true);actor.animator.pause()
 else:
  for bone in range(gesture.positions.size()):rig.set_bone_pose_position(bone,gesture.positions[bone]);rig.set_bone_pose_rotation(bone,gesture.rotations[bone])
  if kind=="bike":
   var hip:int=actor._bone("Hips")
   var hips:Vector3=rig.global_transform*rig.get_bone_global_pose(hip).origin
   rig.set_bone_pose_position(hip,gesture.positions[hip]+Vector3.UP*((equipment.global_position.y+.99-hips.y)/rig.global_basis.get_scale().y))
   for side in range(2):
    var angle:float=(elapsed-1.1)*3.8*pace+side*PI
    var pedal:=Vector3(-.22 if side==0 else .22,.4+cos(angle)*.18,-sin(angle)*.18)
    equipment.get_node("Pedal%d"%side).position=pedal
    Legs.leg(actor,side,equipment.to_global(pedal)+Vector3.UP*.09,1)
    actor._reach_arm("Left" if side==0 else "Right",equipment.to_global(Vector3(-.29 if side==0 else .29,1.27,-.56)),1)
  else:
   var wave:float=(sin((elapsed-1.1)*(.8 if kind=="yoga" else 2.2)*pace)+1)*.5
   if kind=="weights":
    _curl_arms(actor,rig,elapsed,delta,pace)
   else:
    for side:String in ["Left","Right"]:
     var lateral:float=1.0 if side=="Left" else -1.0
     var hand_target:Vector3=actor.position+actor.visual.global_basis.x*lateral*(.35+.12*wave)
     hand_target+=Vector3.UP*(1.1+.95*wave)*app.world.PLAYABLE_CHARACTER_SCALE
     hand_target+=actor.visual.global_basis.z*.12
     actor._reach_arm(side,hand_target,1)
   if kind=="yoga":
    var spine:int=actor._bone("Spine");rig.set_bone_pose_rotation(spine,gesture.rotations[spine]*Quaternion(Vector3.RIGHT,.18*wave))
   rig.force_update_all_bone_transforms()
   if kind!="weights":
    for side in range(weights.size()):
     var hand:=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftHand" if side==0 else "RightHand")).origin
     var side_axis:Vector3=actor.visual.global_basis.x.normalized()
     var front_axis:Vector3=actor.visual.global_basis.z.normalized()
     var cross_axis:Vector3=side_axis.cross(front_axis).normalized()
     weights[side].global_transform=Transform3D(Basis(cross_axis,side_axis,front_axis),hand+front_axis*.02)
 if elapsed>1.1:
  app.state.energy=maxf(0,app.state.energy-delta*.08*pace);app.state.thirst=maxf(0,app.state.thirst-delta*.05*pace)
  if app.state.energy<3 or app.state.thirst<3:finish();app.state.say("锻炼结束，休息补充些水。")
 label.text={"treadmill":"跑步机 · 跑步","bike":"健身车 · 踩踏","weights":"哑铃 · 交替屈臂训练","yoga":"瑜伽垫 · 舒展身体"}.get(kind,"锻炼中")+(" · 第 %d 次"%[reps+1] if kind=="weights" else "")+(" · 暂停中" if paused else "")+" · 强度%d · %d秒"%[intensity,elapsed]
