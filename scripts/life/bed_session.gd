extends Node
## Visible rest accrues while lying down; overnight rewards commit once after the sleep interval.
var app: Node
var active := false
var panel: PanelContainer
var label: Label
var night_button: Button
var sleep_elapsed := -1.0
var sleep_committed := false
var auto_sleep := false
var camera_stage:=""
func setup(owner_app: Node) -> void:
 app=owner_app
 panel=PanelContainer.new();panel.name="BedRestControls"
 panel.add_theme_stylebox_override("panel",app.panel());app.safe_root.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 panel.offset_left=-210;panel.offset_right=210;panel.offset_top=100;panel.offset_bottom=195
 var rows=VBoxContainer.new();panel.add_child(rows)
 label=app.label("躺在床上休息 · 点击起床离开",18);rows.add_child(label)
 var buttons=HBoxContainer.new();rows.add_child(buttons)
 night_button=app.button(buttons,"睡到清晨",sleep_to_morning)
 app.button(buttons,"起床",finish)
 panel.hide()
func begin() -> bool:
 if active or app.state.location!="villa" or app.state.home_floor!=1:return false
 var actor: CharacterBody3D=app.world.player
 var point: Dictionary=app.world.find_interaction("villa_sleep")
 if point.is_empty() or not app.world.interactable(point):return app.state.say("走近主卧的床，正面对着它再躺下。")
 var anchor:Vector3=app.world.Villa.BED_ANCHOR;anchor.y=app.world.villa_room.bed_surface()
 if not actor.lie_on_bed(anchor):return false
 app.world.orbit.clear_observation();app.world.orbit.view_transition=.6
 active=true;camera_stage="";_frame_bed();sleep_elapsed=-1;sleep_committed=false;auto_sleep=false;panel.show()
 label.text="收起外衣，躺下休息…"
 app.state.log_event("在主卧床上躺下，披风和帽子暂时收起，起床后恢复。")
 return true
func sleep_to_morning() -> void:
 if not active or not app.movement_enabled() or app.world.player.bed_stage!="resting" or sleep_elapsed>=0:return
 if app.state.hour()>=6 and app.state.hour()<18:
  app.state.say("白天可以躺着休息，18:00 后可睡到清晨。")
  return
 sleep_elapsed=0;sleep_committed=false
## 白天躺床：短休两小时（+20 精力），不起床，也不推进到清晨。
func nap() -> void:
 if not active or not app.movement_enabled() or app.world.player.bed_stage!="resting":return
 if app.state.rest(false):label.text="短休两小时…"
## 起床时被子会留下褶皱；「整理床铺」把被子和枕头拉回原始摆法（真实位移，不是提示文字）。
func _bed_parts() -> Array:
 var bed:Node3D=app.world.villa_room.get_node_or_null("MasterBed")
 if bed==null:return []
 var list:Array=[]
 for part_name:String in ["duvet","pillows"]:
  var part:Node3D=bed.find_child(part_name,true,false)
  if part!=null and part.has_meta("rest_position"):list.append(part)
 return list
func rumple() -> void:
 for part:Node3D in _bed_parts():
  part.position=Vector3(part.get_meta("rest_position"))+Vector3(0,.025,.04)
  part.rotation=Vector3(part.get_meta("rest_rotation"))+Vector3(.03,0,.05)
 app.world.villa_room.set_meta("bed_tidy",false)
func tidy() -> bool:
 if not app.movement_enabled() or app.world.player.bed_stage!="":return false
 var parts:Array=_bed_parts()
 if parts.is_empty():return false
 if bool(app.world.villa_room.get_meta("bed_tidy",true)):return false
 var tween:Tween=app.create_tween()
 for part:Node3D in parts:
  tween.parallel().tween_property(part,"position",Vector3(part.get_meta("rest_position")),1.0).set_trans(Tween.TRANS_SINE)
  tween.parallel().tween_property(part,"rotation",Vector3(part.get_meta("rest_rotation")),1.0).set_trans(Tween.TRANS_SINE)
 app.world.villa_room.set_meta("bed_tidy",true)
 app.state.say("把被子拉平，枕头也摆正了。")
 return true
func finish() -> void:
 if not active:return
 if not app.movement_enabled():return
 rumple()
 sleep_elapsed=-1
 app.world.player.rise_from_bed()
func cancel() -> void:
 if is_instance_valid(app.world.player):app.world.player.cancel_bed()
 app.world.home_camera.release(app.world,"bed")
 active=false;camera_stage="";sleep_elapsed=-1
 if panel!=null:panel.hide()
func _physics_process(delta: float) -> void:
 if not active:return
 if app.state.location!="villa" or app.state.home_floor!=1:
  cancel();return
 var actor: CharacterBody3D=app.world.player
 if actor.bed_stage=="":
  app.world.home_camera.release(app.world,"bed");camera_stage=""
  active=false;panel.hide();app._save(false);return
 if not app.movement_enabled():return
 _frame_bed()
 night_button.disabled=actor.bed_stage!="resting" or sleep_elapsed>=0
 if actor.bed_stage!="resting":
  label.text=actor.bed_phase_label()
  return
 if auto_sleep:
  auto_sleep=false;sleep_to_morning()
 if app.perf_probe:return
 if sleep_elapsed>=0:
  sleep_elapsed+=delta
  label.text="正在安睡 · %d 秒后醒来"%maxi(0,ceili(8-sleep_elapsed))
  if sleep_elapsed>=8 and not sleep_committed:
   sleep_committed=true
   app.state.rest(true)
   sleep_elapsed=-1
   actor.rise_from_bed()
 else:
  label.text="精力恢复中 · 点击起床离开"
  app.state.energy=minf(100,app.state.energy+delta/3.0)
  app.state.health=minf(100,app.state.health+delta/6.0)

func _frame_bed() -> void:
 var actor:CharacterBody3D=app.world.player
 var phase:String=actor.bed_stage
 var group:String="rest" if phase in ["resting","eyes_opening"] else ("clothes" if phase in ["approaching_rack","undressing","hanging_cloak","stepping_clear","taking_cloak","dressing"] else "bedside")
 if group==camera_stage:return
 camera_stage=group
 var floor_y:float=app.world.Villa.Dimensions.UPPER_FLOOR
 if group=="clothes":app.world.home_camera.begin(app.world,"bed",Vector3(-2.6,floor_y+1.1,-2.75),1.0,3.6,2.35,60)
 elif group=="rest":app.world.home_camera.begin(app.world,"bed",Vector3(-4.8,actor.bed_anchor.y+.35,-3.8),.45,4.8,2.7,66)
 else:app.world.home_camera.begin(app.world,"bed",Vector3(-4.0,floor_y+.95,-3.05),.45,3.8,2.4,64)
