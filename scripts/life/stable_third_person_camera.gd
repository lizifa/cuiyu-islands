extends "res://scripts/life/first_person_camera.gd"
## One owner for framing, orbit and collision. Legacy shot requests never drive this rig.
const THIRD_FOV:=72.0
# 人物在屋外、屋内、船上都保持同一个屏幕高度：三种场景共用同一段镜头臂。
const SUBJECT_DISTANCE:=15.9
const OUTDOOR_DISTANCE:=SUBJECT_DISTANCE
const INDOOR_DISTANCE:=SUBJECT_DISTANCE
const BOAT_DISTANCE:=SUBJECT_DISTANCE
const MODE_STORE:="user://view_mode.cfg"
const MANUAL_SPEED:=deg_to_rad(75)
const FOLLOW_TURN_SPEED:=deg_to_rad(18)
const ROOM:=Rect2(-10.38,-5.5,24.28,23.2)
var stable_yaw:=0.0
var stable_pitch:=deg_to_rad(18)
var requested_yaw:=0.0
var requested_pitch:=deg_to_rad(18)
var pivot:=Vector3.INF
var current_arm:=OUTDOOR_DISTANCE
var recovered_arm:=OUTDOOR_DISTANCE
var room_key:=""
var manual_view_locked:=false
# 双指手势转向：给镜头一个不跟随角色朝向的水平偏移，手指停下几秒后自动交还跟随。
var gesture_lock:=false
var gesture_lock_time:=0.0
const GESTURE_HOLD:=3.0
var explicit_recenter:=false
var moving_for:=0.0
var travel_direction:=Vector3.ZERO
var render_yaw:=0.0
var render_pitch:=0.0
var sun_target:=Vector3.INF
var probe:CharacterBody3D
var restored_visual:Node3D
var framing_skeleton:Skeleton3D
var framing_bones:Dictionary={}
var indoor_search_time:=0.0
var activity_key:=""
var activity_settled:=true
var activity_point:=Vector3.ZERO
var activity_radius:=10.0
var activity_pitch:=deg_to_rad(18)
var activity_yaw:=0.0
var free_view:=Vector2.ZERO
var spawn_reset_pending:=false
var spawn_heading:float=NAN
var house_exit_pending:=false
var last_actor_position:=Vector3.INF
func begin_activity_view(key:String,at:Vector3,angle:float,radius:float,elevation:float) -> void:
 if first_person:return
 if activity_key=="":free_view=Vector2(requested_yaw,requested_pitch)
 activity_key=key;activity_point=at;activity_radius=radius;activity_pitch=elevation;activity_yaw=angle
 cancel_drag();manual_view_locked=false;sun_target=Vector3.INF
 requested_yaw=angle;requested_pitch=elevation;explicit_recenter=true
func end_activity_view(key:String) -> void:
 if activity_key!=key:return
 activity_key="";activity_settled=true
 if manual_view_locked:return
 requested_yaw=free_view.x;requested_pitch=free_view.y;explicit_recenter=true
func focus_activity(key:String,at:Vector3,angle:float,radius:float,elevation:float,snap:bool=true) -> void:
 # Deliberate cut for an activity beat: the new framing is in place before the
 # next frame is drawn, so the action never waits for a slow orbit sweep.
 if first_person:return
 if activity_key=="" or activity_key!=key:free_view=Vector2(requested_yaw,requested_pitch)
 activity_key=key;activity_point=at;activity_radius=radius;activity_pitch=elevation;activity_yaw=angle
 cancel_drag();manual_view_locked=false;sun_target=Vector3.INF
 requested_yaw=angle;requested_pitch=elevation;explicit_recenter=true
 if not snap:return
 activity_settled=true
 pivot=at;current_arm=radius;stable_yaw=angle;stable_pitch=elevation
 render_yaw=angle;render_pitch=-elevation
 recovered_arm=radius
 if camera!=null:
  var boom:=Vector3(sin(angle)*cos(elevation),sin(elevation),cos(angle)*cos(elevation))*radius
  camera.global_position=at+boom
  camera.rotation=Vector3(render_pitch,render_yaw,0)
  if probe!=null:probe.position=camera.global_position
func activity_view_ready(key:String) -> bool:
 if first_person or manual_view_locked:return true
 if not activity_settled:return false
 if activity_key!=key or not pivot.is_finite():return false
 if absf(angle_difference(stable_yaw,activity_yaw))>.2 or pivot.distance_to(activity_point)>.3:return false
 var view:Vector2=camera.get_viewport().get_visible_rect().size
 var actor:Node3D=get_parent().player
 var points:Array[Vector3]=[actor.position+Vector3.UP*1.35,actor.position]
 if key=="fishing" and activity_radius>=10.0:points.append(get_parent().FishingPlatform.FLOAT)
 for point:Vector3 in points:
  if camera.is_position_behind(point) or not Rect2(view*.06,view*.88).has_point(camera.unproject_position(point)):return false
 return true
func prepare_house_exit() -> void:
 house_exit_pending=true;room_key="";pivot=Vector3.INF;activity_key="";manual_view_locked=false
func setup(view_camera:Camera3D) -> void:
 super.setup(view_camera)
 stable_third_person=true;first_person=false;comfort_mode=true
 if OS.get_cmdline_user_args().has("--first-person-camera"):first_person=true
 elif not OS.get_cmdline_user_args().has("--test-mode"):
  var config:=ConfigFile.new()
  if config.load(MODE_STORE)==OK:first_person=bool(config.get_value("view","first_person",false))
 camera.fov=VIEW_FOV if first_person else THIRD_FOV
 camera.keep_aspect=Camera3D.KEEP_WIDTH
func can_change_view() -> bool:
 var actor:Node3D=get_parent().player
 return actor!=null and actor.bed_stage=="" and not actor.sofa_seated and not actor.stair_active and actor.fishing_stage=="" and not actor.home_busy and not actor.working and actor.pet_stage==""
func set_first_person(value:bool) -> bool:
 if value==first_person:return true
 if not can_change_view():return false
 cancel_drag();first_person=value;room_key="";context="";pivot=Vector3.INF
 manual_view_locked=false;sun_target=Vector3.INF;auto_point=Vector3.INF;restored_visual=null
 if is_instance_valid(hands):hands.visible=false
 if not value:_restore_body()
 if not OS.get_cmdline_user_args().has("--test-mode"):
  var config:=ConfigFile.new();config.set_value("view","first_person",value);config.save(MODE_STORE)
 return true
func set_comfort(_value:bool) -> void:comfort_mode=true
func fade_cut() -> void:pass
func establish_view(_at:Vector3,_radius:float,_elevation:float) -> void:pass
func set_rotation_mode(_value:bool) -> void:rotation_mode=false
func is_away() -> bool:return super.is_away() if first_person else manual_view_locked or sun_target.is_finite()
func reset_view() -> void:
 if first_person:super.reset_view();return
 cancel_drag();manual_view_locked=false;sun_target=Vector3.INF;moving_for=0;explicit_recenter=true
 requested_yaw=get_parent().player.visual.global_rotation.y+PI;requested_pitch=deg_to_rad(18)
func reset_for_new_game(heading:float=NAN) -> void:
 spawn_heading=heading
 # A world reset is a cut to a new subject, not an ordinary eased recenter.
 cancel_drag();clear_observation(true)
 activity_key="";activity_point=Vector3.ZERO;free_view=Vector2.ZERO
 manual_view_locked=false;sun_target=Vector3.INF;auto_point=Vector3.INF
 house_exit_pending=false;moving_for=0;travel_direction=Vector3.ZERO;explicit_recenter=false
 room_key="";pivot=Vector3.INF;last_actor_position=Vector3.INF;indoor_search_time=0
 context="";activity="";bed_phase="";fishing_phase="";selected_kind="";bounds_cache.clear()
 previous_actor=Vector3.INF;manual_hold=0;stair_manual_look=false;eye_height=1.85
 restored_visual=null;cached_visual=null;framing_skeleton=null;framing_bones.clear()
 current_arm=OUTDOOR_DISTANCE;recovered_arm=OUTDOOR_DISTANCE
 stable_yaw=0;requested_yaw=0;stable_pitch=deg_to_rad(18);requested_pitch=stable_pitch
 yaw_speed=0;pitch_speed=0;target_distance=-1;pan_offset=Vector3.ZERO;target_pan=Vector3.ZERO
 cut_focus=Vector3.INF;base_camera_position=Vector3.INF;motion_reset=true
 if is_instance_valid(hands):hands.visible=false
 spawn_reset_pending=true
func commit_spawn_view() -> void:
 if not spawn_reset_pending:return
 var was_enabled:bool=motion_enabled
 motion_enabled=true
 _process(0)
 motion_enabled=was_enabled
 spawn_reset_pending=false;spawn_heading=NAN
func begin_sun_view() -> void:
 if first_person:super.begin_sun_view();return
 sun_target=get_parent().sun.position;manual_view_locked=true
func focus_action(_key:String,_point:Vector3) -> void:
 if first_person:super.focus_action(_key,_point)
func gesture_drag(relative:Vector2) -> void:
 if first_person:super.gesture_drag(relative);return
 if not motion_enabled:return
 accumulated+=relative
 if not past_threshold:
  if accumulated.length()<5:return
  relative=accumulated;past_threshold=true
 var previous_request:=Vector2(requested_yaw,requested_pitch)
 var height:float=maxf(camera.get_viewport().get_visible_rect().size.y,1)
 requested_yaw-=relative.x/height*PI*sensitivity
 requested_yaw=stable_yaw+clampf(angle_difference(stable_yaw,requested_yaw),-PI*.5,PI*.5)
 requested_pitch=clampf(requested_pitch+relative.y/height*PI*sensitivity,deg_to_rad(8),deg_to_rad(35))
 var world:Node3D=get_parent()
 if world.navigation_state!=null and world.navigation_state.location=="villa" and can_change_view() and pivot.is_finite():
  var candidate:Vector3=_safe_boom(pivot,_indoor_goal(pivot,requested_yaw,requested_pitch,current_arm,world.player),world.player)
  if not _candidate_framed(candidate,world.player):
   requested_yaw=previous_request.x;requested_pitch=previous_request.y
 manual_view_locked=true;sun_target=Vector3.INF;moving_for=0;manual_hold=2;explicit_recenter=false
 # 拖完手指松开后镜头要停在玩家转到的角度上；不然下一帧就被 _follow_heading 拉回角色朝向，
 # 真机上表现就是「长按拖拽一松手视角立刻弹回去」。和双指转向共用同一段手动保持时间。
 gesture_lock=true;gesture_lock_time=GESTURE_HOLD
 manual_revision+=1;manual_look.emit()
func cancel_drag() -> void:
 var was_dragging:bool=mouse_dragging or touch_id>=0
 super.cancel_drag()
 if first_person:
  requested_yaw=stable_yaw;requested_pitch=stable_pitch
  return
 if was_dragging:
  # 拖到一半松手：镜头臂还停在旧角度，但玩家想要的角度在 requested 里。
  # 这里若把 requested 抹平，手指一抬视角就弹回去（真机上就是「拖了没反应」）。
  # 保留 requested，让 stable 继续用 MANUAL_SPEED 追过去，手感是顺滑收尾。
  stable_pitch=clampf(stable_pitch,deg_to_rad(8),deg_to_rad(35))
  return
 if not manual_view_locked:
  requested_yaw=stable_yaw;requested_pitch=stable_pitch
func _restore_body() -> void:
 var world:Node3D=get_parent();var actor:Node3D=world.player
 if actor==null:return
 if actor.visual!=restored_visual:
  for mesh:MeshInstance3D in actor.visual.find_children("*","MeshInstance3D",true,false):mesh.layers=1
  restored_visual=actor.visual
  framing_bones.clear()
  var rigs:Array[Node]=actor.visual.find_children("*","Skeleton3D",true,false)
  framing_skeleton=rigs[0] if not rigs.is_empty() else null
  if framing_skeleton!=null:
   for bone in range(framing_skeleton.get_bone_count()):
    for key:String in ["Head","LeftFoot","RightFoot"]:
     if str(framing_skeleton.get_bone_name(bone)).ends_with(key):framing_bones[key]=bone
 var app:Node=world.get_parent();var routine:Node=app.get("home_routine");var sofa:Node=app.get("sofa_session")
 if routine!=null and routine.gesture!=null and is_instance_valid(routine.gesture.prop):
  routine.gesture.prop.layers=1
  for mesh:MeshInstance3D in routine.gesture.prop.find_children("*","MeshInstance3D",true,false):mesh.layers=1
 if sofa!=null and is_instance_valid(sofa.food_prop):sofa.food_prop.layers=1
 if actor.bed_motion!=null and is_instance_valid(actor.bed_motion.outfit):
  for mesh:MeshInstance3D in actor.bed_motion.outfit.find_children("*","MeshInstance3D",true,false):mesh.layers=1
 if is_instance_valid(actor.work_tool):
  for mesh:MeshInstance3D in actor.work_tool.find_children("*","MeshInstance3D",true,false):mesh.layers=1
 if is_instance_valid(hands):hands.visible=false
func _subject(actor:Node3D) -> Vector3:
 if actor.bed_stage!="":return actor.bed_anchor+Vector3.UP*.45
 return actor.position+Vector3.UP*(.95 if actor.sofa_seated else (1.25 if actor.stair_active else 1.05))
func turn_by_gesture(radians: float) -> void:
 if first_person:return
 if absf(radians) < .00001: return
 cancel_drag();manual_view_locked=true;gesture_lock=true;gesture_lock_time=GESTURE_HOLD
 sun_target=Vector3.INF;explicit_recenter=true
 requested_yaw=wrapf(requested_yaw-radians,-PI,PI)
 # 同步基类字段：外部读数与非稳定模式仍用 target_yaw 判断镜头转了多少。
 target_yaw=wrapf(target_yaw-radians,-PI,PI)
 if activity_key=="":free_view=Vector2(requested_yaw,requested_pitch)

func _process(delta:float) -> void:
 if first_person:super._process(delta);return
 if gesture_lock:
  gesture_lock_time-=delta
  if gesture_lock_time<=0:gesture_lock=false;manual_view_locked=false
 var world:Node3D=get_parent()
 if camera==null or world.player==null or world.navigation_state==null:return
 var actor:Node3D=world.player
 _restore_body();camera.cull_mask=1048575;camera.fov=THIRD_FOV;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.near=.08
 if not motion_enabled:return
 var dt:float=minf(delta,.05);frame_delta=dt
 var indoor:bool=world.navigation_state.location=="villa" and not world.on_balcony()
 var key:String=world.navigation_state.location
 var subject:Vector3=activity_point if activity_key!="" and not manual_view_locked else _subject(actor)
 var teleported:bool=last_actor_position.is_finite() and actor.position.distance_to(last_actor_position)>8
 last_actor_position=actor.position
 var initialize:bool=room_key!=key or not pivot.is_finite() or teleported
 if not initialize and manual_view_locked and not sun_target.is_finite() and not mouse_dragging and touch_id<0 and subject.distance_to(pivot)<=.061 and not actor.home_busy and actor.bed_stage=="" and not actor.stair_active and actor.fishing_stage=="" and actor.pet_stage=="" and not actor.working and (not indoor or _body_framed(actor)):return
 if not initialize and manual_view_locked and not sun_target.is_finite() and not mouse_dragging and touch_id<0 and absf(angle_difference(stable_yaw,requested_yaw))<.02 and absf(requested_pitch-stable_pitch)<.02 and subject.distance_to(pivot)<=.061 and not actor.home_busy and actor.bed_stage=="" and not actor.stair_active and actor.fishing_stage=="" and actor.pet_stage=="" and not actor.working and (not indoor or _body_framed(actor)):return
 if initialize:
  room_key=key;pivot=subject;current_arm=INDOOR_DISTANCE if indoor else (BOAT_DISTANCE if actor.boating else OUTDOOR_DISTANCE)
  if activity_key!="":current_arm=activity_radius
  stable_pitch=activity_pitch if activity_key!="" else deg_to_rad(18);requested_pitch=stable_pitch
  stable_yaw=activity_yaw if activity_key!="" else actor.visual.global_rotation.y+PI
  if key=="island" and not actor.boating:
   var home:Vector3=world.navigation_view_landmark()-actor.position
   if Vector2(home.x,home.z).length()>2:stable_yaw=atan2(-home.x,-home.z)
  if house_exit_pending and key=="island":stable_yaw=0;house_exit_pending=false
  if spawn_reset_pending and is_finite(spawn_heading):stable_yaw=spawn_heading
  stable_yaw=_clear_initial_heading(subject,stable_yaw,stable_pitch,current_arm,actor,indoor)
  requested_yaw=stable_yaw;manual_view_locked=false;sun_target=Vector3.INF
 else:
  var offset:Vector3=subject-pivot
  if offset.length()>.06:pivot+=offset.normalized()*(offset.length()-.06)*(1-exp(-(2.0 if activity_key!="" else 10.0)*dt))
 if activity_key!="" and not manual_view_locked:requested_yaw=activity_yaw;requested_pitch=activity_pitch
 _follow_heading(actor,dt)
 var angle_step:=Vector2(angle_difference(stable_yaw,requested_yaw),requested_pitch-stable_pitch).limit_length((MANUAL_SPEED if mouse_dragging or touch_id>=0 else (deg_to_rad(45) if explicit_recenter else FOLLOW_TURN_SPEED))*dt)
 stable_yaw+=angle_step.x;stable_pitch+=angle_step.y
 if absf(angle_difference(stable_yaw,requested_yaw))<.005:explicit_recenter=false
 var desired_arm:float=activity_radius if activity_key!="" and not manual_view_locked else (INDOOR_DISTANCE if indoor else (BOAT_DISTANCE if actor.boating else OUTDOOR_DISTANCE))
 current_arm=move_toward(current_arm,desired_arm,dt*(4.0 if activity_key!="" else .75))
 var framing_arm:float=minf(current_arm,7.95) if actor.stair_active else current_arm
 var boom:=Vector3(sin(stable_yaw)*cos(stable_pitch),sin(stable_pitch),cos(stable_yaw)*cos(stable_pitch))*framing_arm
 var desired:Vector3=pivot+boom
 if indoor:desired=_indoor_goal(pivot,stable_yaw,stable_pitch,framing_arm,actor)
 if actor.stair_active:desired=_stair_portal_goal(actor,desired)
 # 楼梯上同样要做遮挡回缩：只按楼梯廊道目标硬放，镜头会整块插进墙体/楼板里。
 var safe:Vector3=_safe_boom(pivot,desired,actor)
 if indoor and not actor.stair_active:
  # 回缩后再夹回房间内部。楼梯在 ROOM 之外，上下楼时不能夹，否则镜头会被按进隔墙。
  safe.x=clampf(safe.x,ROOM.position.x+.3,ROOM.end.x-.3)
  safe.z=clampf(safe.z,ROOM.position.y+.3,ROOM.end.y-.3)
 if indoor and can_change_view() and not mouse_dragging and touch_id<0:
  indoor_search_time-=dt
  if (pivot.distance_to(safe)<5.0 or not _candidate_framed(safe,actor)) and indoor_search_time<=0:
   var alternative:float=_clear_initial_heading(pivot,stable_yaw,stable_pitch,current_arm,actor,true)
   var alternate_goal:Vector3=_safe_boom(pivot,_indoor_goal(pivot,alternative,stable_pitch,current_arm,actor),actor)
   if pivot.distance_to(alternate_goal)>pivot.distance_to(safe)+1.0 or (_candidate_framed(alternate_goal,actor) and not _candidate_framed(safe,actor)):requested_yaw=alternative
   indoor_search_time=1.0
 var free_arm:float=pivot.distance_to(safe)
 if initialize or actor.stair_active:recovered_arm=free_arm
 elif free_arm<recovered_arm:recovered_arm=free_arm
 else:recovered_arm=move_toward(recovered_arm,free_arm,dt*.8)
 if free_arm>.001:safe=pivot+(safe-pivot)*(recovered_arm/free_arm)
 if probe==null:
  probe=CharacterBody3D.new();probe.name="StableCameraCollisionProbe";probe.collision_layer=0;probe.collision_mask=17
  var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.22;shape.shape=sphere;probe.add_child(shape);world.add_child(probe)
 (probe.get_child(0).shape as SphereShape3D).radius=.18 if actor.stair_active else .22
 if not initialize:
  var travel:Vector3=safe-camera.position
  var maximum:float=(actor.RUN_SPEED+1.0+minf(framing_arm,7.95)*(MANUAL_SPEED if mouse_dragging or touch_id>=0 else FOLLOW_TURN_SPEED))*dt
  probe.position=camera.position
  var motion:Vector3=_bounded_view_motion(camera.position,travel.limit_length(maximum),sun_target if sun_target.is_finite() else pivot)
  for i in range(3):
   if motion.length_squared()<.000001:break
   var collision:KinematicCollision3D=probe.move_and_collide(motion,false,.001)
   if collision==null:break
   motion=collision.get_remainder().slide(collision.get_normal())
  safe=probe.position
 else:probe.position=safe
 camera.position=safe
 var aim:Vector3=sun_target if sun_target.is_finite() else pivot
 if camera.position.distance_squared_to(aim)>.001:
  var wanted_angles:Vector2=_aim_angles(camera.position,aim)
  if initialize:render_yaw=wanted_angles.x;render_pitch=wanted_angles.y
  else:
   var change:Vector2=Vector2(angle_difference(render_yaw,wanted_angles.x),wanted_angles.y-render_pitch).limit_length((MANUAL_SPEED if mouse_dragging or touch_id>=0 else deg_to_rad(45))*dt)
   render_yaw+=change.x;render_pitch+=change.y
  camera.rotation=Vector3(render_pitch,render_yaw,0)
 focus=pivot;view_focus=pivot;base_camera_position=camera.position
 yaw=stable_yaw;target_yaw=requested_yaw;pitch=stable_pitch;target_pitch=requested_pitch;distance=current_arm;target_distance=-1
 pan_offset=Vector3.ZERO;target_pan=Vector3.ZERO;cut_focus=Vector3.INF;motion_reset=false
 if world.forest.visible:world.forest.reveal_player(camera.global_position,actor.position+Vector3.UP)
func _indoor_goal(at:Vector3,angle:float,elevation:float,radius:float,actor:Node3D) -> Vector3:
 var goal:Vector3=at+Vector3(sin(angle)*cos(elevation),sin(elevation),cos(angle)*cos(elevation))*radius
 goal.x=clampf(goal.x,ROOM.position.x+.3,7.45 if actor.position.x<7.8 else ROOM.end.x-.3)
 goal.z=clampf(goal.z,ROOM.position.y+.3,ROOM.end.y-.3)
 var floor_y:float=get_parent().Villa.Dimensions.BASE+get_parent().navigation_state.home_floor*get_parent().Villa.Dimensions.RISE
 goal.y=minf(goal.y,floor_y+get_parent().Villa.Dimensions.CLEAR_HEIGHT-.45)
 return goal
func _clear_initial_heading(at:Vector3,preferred:float,elevation:float,radius:float,actor:Node3D,indoor:bool) -> float:
 # Rank collision-safe views; callers ease any recovery through the existing turn budget.
 var best:float=preferred;var best_score:float=-INF
 for degrees:float in [0,15,-15,30,-30,45,-45,60,-60,90,-90,180]:
  var angle:float=preferred+deg_to_rad(degrees)
  var direction:=Vector3(sin(angle)*cos(elevation),sin(elevation),cos(angle)*cos(elevation))
  var wanted:Vector3=at+direction*radius
  if indoor:wanted=_indoor_goal(at,angle,elevation,radius,actor)
  var safe:Vector3=_safe_boom(at,wanted,actor)
  var clearance:float=minf(radius,at.distance_to(safe))
  if indoor and not ROOM.has_point(Vector2(safe.x,safe.z)):clearance=0
  var score:float=clearance-absf(degrees)*.003
  if indoor and not _candidate_framed(safe,actor):score-=20
  if score>best_score:best_score=score;best=angle
  if clearance>=radius*.95 and (not indoor or _candidate_framed(safe,actor)):return angle
 return best
func _aim_angles(at:Vector3,aim:Vector3) -> Vector2:
 var direction:=aim-at
 var horizontal:float=Vector2(direction.x,direction.z).length()
 return Vector2(atan2(-direction.x,-direction.z) if horizontal>.05 else render_yaw,clampf(atan2(direction.y,horizontal),deg_to_rad(-75),deg_to_rad(75)))
func _view_error(at:Vector3,aim:Vector3) -> float:
 var angles:=_aim_angles(at,aim)
 return Vector2(angle_difference(render_yaw,angles.x),angles.y-render_pitch).length()
func _bounded_view_motion(at:Vector3,motion:Vector3,aim:Vector3) -> Vector3:
 var allowance:float=maxf(deg_to_rad(6),_view_error(at,aim))
 if _view_error(at+motion,aim)<=allowance:return motion
 var low:=0.0;var high:=1.0
 for i in range(8):
  var amount:float=(low+high)*.5
  if _view_error(at+motion*amount,aim)<=allowance:low=amount
  else:high=amount
 return motion*low
func _stair_portal_goal(actor:Node3D,_normal_goal:Vector3) -> Vector3:
 # Rise inside the actual central stair opening, never through a landing slab.
 var shaft_z:float=get_parent().Villa.Dimensions.STAIR_FRONT-.6
 var leaving:bool=actor.stair_path.size()<=3
 var eye_y:float=minf(actor.position.y+2.6,get_parent().Villa.Dimensions.TOP-.3)
 if not leaving:
  if camera.position.x<8.25:
   if camera.position.z<.65 or camera.position.z>1.15 or absf(camera.position.y-eye_y)>.1:return Vector3(minf(camera.position.x,7.3),eye_y,.85)
   return Vector3(8.5,eye_y,.85)
  if actor.position.x<8.2:return Vector3(10.625,eye_y,.85)
  # Clear the upper landing before raising the camera through the stair shaft.
  if camera.position.z>shaft_z+.25 and camera.position.y<get_parent().Villa.Dimensions.UPPER_FLOOR+.4:
   return Vector3(10.625,camera.position.y,shaft_z)
  return Vector3(10.625,minf(actor.position.y+4.5,get_parent().Villa.Dimensions.TOP-.3),shaft_z)
 if camera.position.x>7.35:
  if camera.position.z<3.15 or camera.position.z>3.65 or absf(camera.position.y-eye_y)>.1:return Vector3(maxf(camera.position.x,8.4),eye_y,3.4)
  return Vector3(7.1,eye_y,3.4)
 if actor.position.x>7.35:return Vector3(7.1,eye_y,3.4)
 return Vector3(4.5,eye_y,6.0)
func stair_ready(target:Vector3) -> bool:
 if first_person:return true
 var actor:Node3D=get_parent().player
 var next:Vector3=actor.position+(target-actor.position).limit_length(.12)+Vector3.UP*1.2
 var view_size:Vector2=camera.get_viewport().get_visible_rect().size
 if camera.is_position_behind(next) or not Rect2(view_size*.12,view_size*.76).has_point(camera.unproject_position(next)):return false
 if not _body_framed(actor,(target-actor.position).limit_length(.12),.58):return false
 if actor.position.x<7.8 and target.x>8 and actor.position.x>7.15 and camera.position.x<8.15:return false
 if actor.position.x>7.8 and target.x<7 and actor.position.x<8.6 and camera.position.x>7.45:return false
 return true
func _candidate_framed(at:Vector3,actor:Node3D) -> bool:
 if not is_instance_valid(framing_skeleton) or framing_bones.size()!=3:return false
 var aim:Vector3=_subject(actor)
 if at.distance_to(aim)<3.0:return false
 var view:Vector2=camera.get_viewport().get_visible_rect().size
 var vertical_tan:float=tan(deg_to_rad(THIRD_FOV)*.5)*view.y/view.x
 var inverse:Transform3D=Transform3D(Basis.looking_at(aim-at,Vector3.UP),at).affine_inverse()
 var top:=INF;var bottom:float=-INF
 for key:String in ["Head","LeftFoot","RightFoot"]:
  var point:Vector3=framing_skeleton.global_transform*framing_skeleton.get_bone_global_pose(framing_bones[key]).origin
  point.y+=.22 if key=="Head" else -.08
  point=inverse*point
  if point.z>=-.1:return false
  var y:float=point.y/(-point.z*vertical_tan)
  if absf(y)>.86 or absf(point.x/(-point.z*tan(deg_to_rad(THIRD_FOV)*.5)))>.86:return false
  top=minf(top,y);bottom=maxf(bottom,y)
 return (bottom-top)*.5<.55
func _body_framed(actor:Node3D,offset:Vector3=Vector3.ZERO,maximum_height:float=.55) -> bool:
 var view:Vector2=camera.get_viewport().get_visible_rect().size
 var top:=INF;var bottom:float=-INF
 if not is_instance_valid(framing_skeleton) or framing_bones.size()!=3:return false
 for key:String in ["Head","LeftFoot","RightFoot"]:
  var point:Vector3=framing_skeleton.global_transform*framing_skeleton.get_bone_global_pose(framing_bones[key]).origin+offset
  point.y+=.22 if key=="Head" else -.08
  if camera.is_position_behind(point):return false
  var screen:Vector2=camera.unproject_position(point)
  if not Rect2(view*.07,view*.86).has_point(screen):return false
  top=minf(top,screen.y);bottom=maxf(bottom,screen.y)
 return (bottom-top)/view.y<maximum_height and camera.position.distance_to(actor.position+Vector3.UP*1.2)>2.8
func _follow_heading(actor:Node3D,dt:float) -> void:
 if activity_key!="" or manual_view_locked or sun_target.is_finite():return
 if actor.stair_active or actor.home_busy or actor.bed_stage!="" or actor.sofa_seated or actor.fishing_stage!="" or actor.pet_stage!="" or actor.working:
  moving_for=0;return
 var travel:=Vector3(actor.velocity.x,0,actor.velocity.z)
 if travel.length()<.25:moving_for=0;return
 travel=travel.normalized()
 if travel_direction.dot(travel)<.85:moving_for=0
 travel_direction=travel;moving_for+=dt
 if moving_for<1.0:return
 var heading:float=atan2(travel.x,travel.z)+PI
 var difference:float=absf(angle_difference(requested_yaw,heading))
 # Backward walking must not trigger a long automatic orbit around the player.
 if difference>deg_to_rad(25) and difference<deg_to_rad(120):requested_yaw=heading
func _safe_boom(origin:Vector3,wanted:Vector3,actor:Node3D) -> Vector3:
 var space:PhysicsDirectSpaceState3D=get_parent().get_world_3d().direct_space_state
 var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.22
 query.shape=sphere;query.collision_mask=17;query.exclude=[actor.get_rid()];query.transform.origin=origin;query.motion=wanted-origin
 var hit:PackedFloat32Array=space.cast_motion(query)
 var fraction:float=hit[0] if hit.size()>0 else 1.0
 var point:Vector3=origin+(wanted-origin)*(maxf(0,fraction-.015) if fraction<.999 else 1.0)
 query.transform.origin=point;query.motion=Vector3.ZERO
 if space.intersect_shape(query,1).is_empty():return point
 # 被栏杆、门框挤住时先小幅抬高绕过去（只抬高 ≤0.9 米，且必须比原机位更远），
 # 抬不动才走下面的收臂逻辑；不能大幅上抬，否则会飞到灯罩高度上。
 for rise: float in [0.45, 0.9]:
  var lifted: Vector3 = origin + Vector3(0, rise, 0)
  var goal: Vector3 = lifted + (wanted - origin)
  query.transform.origin = lifted; query.motion = goal - lifted
  var probe: PackedFloat32Array = space.cast_motion(query)
  var raised_fraction: float = probe[0] if probe.size() > 0 else 1.0
  var raised_point: Vector3 = lifted + (goal - lifted) * (maxf(0, raised_fraction - .02) if raised_fraction < .999 else 1.0)
  if raised_point.distance_to(origin) < point.distance_to(origin) + .35: continue
  query.transform.origin = raised_point; query.motion = Vector3.ZERO
  if space.intersect_shape(query, 1).is_empty(): return raised_point
 # An action pivot can touch furniture. Search this same arm; never swap room sides.
 for i in range(24,0,-1):
  point=origin+(wanted-origin)*(i/24.0)
  query.transform.origin=point
  if space.intersect_shape(query,1).is_empty():return point
 return camera.position
