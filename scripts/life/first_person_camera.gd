extends "res://scripts/life/orbit_camera.gd"
## A stable eye-level camera. No head bob, roll, zoom, or bone-driven walking sway.
const PLAYER_LAYER:=256
const VIEW_FOV:=88.0
const LOOK_SPEED:=deg_to_rad(100)
const AUTO_SPEED:=deg_to_rad(38)
const STORE_FP:="user://first_person.cfg"
var sensitivity:float=1.0
var hands:Node3D
var clock:float=0
var eye_height:float=1.85
var context:=""
var activity:=""
var bed_phase:=""
var fishing_phase:=""
var stair_manual_look:=false
var manual_hold:float=0
var auto_point:=Vector3.INF
var previous_actor:=Vector3.INF
var cached_visual:Node3D
var selected_kind:=""
var bounds_cache:Dictionary={}
func setup(view_camera:Camera3D) -> void:
 first_person=true;comfort_mode=true;process_priority=100;camera=view_camera
 yaw=0;target_yaw=0;pitch=0;target_pitch=0;initial_yaw=0;initial_pitch=0
 camera.fov=VIEW_FOV;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.near=.04
 var config:=ConfigFile.new()
 if not OS.get_cmdline_user_args().has("--test-mode") and config.load(STORE_FP)==OK:sensitivity=clampf(float(config.get_value("look","sensitivity",1.0)),.4,1.6)
func set_sensitivity(value:float) -> void:
 sensitivity=clampf(value,.4,1.6)
 if OS.get_cmdline_user_args().has("--test-mode"):return
 var config:=ConfigFile.new();config.set_value("look","sensitivity",sensitivity);config.save(STORE_FP)
func set_comfort(_value:bool) -> void:comfort_mode=true
func set_rotation_mode(_value:bool) -> void:rotation_mode=false
func is_away() -> bool:return false
func observation_limit() -> float:return 0
func gesture_drag(relative:Vector2) -> void:
 if camera==null:return
 if not past_threshold:
  accumulated+=relative
  if accumulated.length()<3:return
  relative=accumulated;past_threshold=true
 var height:float=maxf(camera.get_viewport().get_visible_rect().size.y,1)
 target_yaw-=relative.x/height*PI*sensitivity
 target_pitch=clampf(target_pitch+relative.y/height*PI*sensitivity,deg_to_rad(-75),deg_to_rad(65))
 target_yaw=yaw+clampf(angle_difference(yaw,target_yaw),-PI*.5,PI*.5)
 if get_parent().player!=null and get_parent().player.stair_active:stair_manual_look=true
 manual_hold=2;auto_point=Vector3.INF;manual_revision+=1;manual_look.emit()
func cancel_drag() -> void:
 super.cancel_drag();target_yaw=yaw;target_pitch=pitch
func rotate_drag(relative:Vector2) -> void:gesture_drag(relative)
func pan_drag(relative:Vector2) -> void:gesture_drag(relative)
func return_to_player() -> void:reset_view()
func reset_view() -> void:
 cancel_drag();target_pitch=0;auto_point=Vector3.INF;manual_hold=1
func establish_view(_at:Vector3,_radius:float,_elevation:float) -> void:pass
func begin_sun_view() -> void:
 auto_point=get_parent().sun.position;manual_hold=0
func focus_action(_key:String,point:Vector3) -> void:
 if point.distance_to(camera.position)>1:auto_point=point
func _actor_visual(actor:Node3D) -> void:
 cached_visual=actor.visual
 if cached_visual==null:return
 for mesh:MeshInstance3D in cached_visual.find_children("*","MeshInstance3D",true,false):mesh.layers=PLAYER_LAYER
func _process(delta:float) -> void:
 var world:Node3D=get_parent()
 if camera==null or world.player==null or world.navigation_state==null:return
 var actor:Node3D=world.player
 _actor_visual(actor)
 camera.cull_mask=1048575&~PLAYER_LAYER;camera.fov=VIEW_FOV;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.near=.04
 if not motion_enabled:return
 var dt:float=minf(delta,.05);clock+=dt;frame_delta=dt;manual_hold=maxf(0,manual_hold-dt)
 var app:Node=world.get_parent()
 if hands==null:
  hands=preload("res://scripts/life/first_person_hands.gd").new();camera.add_child(hands);hands.setup(world);hands.position.y=.12
 var key:String=world.navigation_state.location
 var teleported:bool=context!=key or not previous_actor.is_finite() or actor.position.distance_to(previous_actor)>8
 var initial_view:bool=context.is_empty()
 if context!=key:
  context=key;yaw=0 if key=="villa" else actor.visual.rotation.y+PI;target_yaw=yaw;pitch=0;target_pitch=0;auto_point=Vector3.INF;activity=""
  if initial_view and key=="island" and not actor.boating:
   var toward_home:Vector3=world.navigation_view_landmark()-actor.position
   if Vector2(toward_home.x,toward_home.z).length()>2:yaw=atan2(-toward_home.x,-toward_home.z);target_yaw=yaw
 var height:float=1.85
 if actor.boating:height=actor.rowing_pose.eye_height if actor.rowing_pose!=null else 1.18
 elif actor.sofa_seated:height=1.18
 elif actor.fishing_stage!="":
  var session:Node=app.get("fishing_session")
  height=1.85-.65*float(session.seat_blend) if session!=null else 1.2
 elif actor.pet_stage=="crouch":height=1.05
 var eye:Vector3=actor.position+Vector3.UP*height
 if actor.bed_stage!="" and actor.pose_skeleton!=null:
  var head:int=actor._bone("Head")
  if head>=0:eye=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(head).origin
  eye.y=maxf(world.Villa.Dimensions.UPPER_FLOOR+.6,eye.y)
 eye_height=move_toward(eye_height,height,dt*.75)
 if actor.bed_stage=="":eye=actor.position+Vector3.UP*eye_height
 if teleported:camera.position=eye
 else:
  # Horizontal travel follows the physical body directly. Smooth only height.
  camera.position.x=eye.x;camera.position.z=eye.z
  camera.position.y=move_toward(camera.position.y,eye.y,dt*(1.5 if actor.stair_active else .85))
 previous_actor=actor.position
 var session:Node=app.get("fishing_session")
 var routine:Node=app.get("home_routine")
 var next_activity:String="fishing" if session!=null and session.active else (("dining" if app.sofa_session.mode=="dining" else "sofa") if actor.sofa_seated else ("bed" if actor.bed_stage!="" else ("pet" if actor.pet_stage!="" else (str(routine.phase) if routine!=null and actor.home_busy else ""))))
 if next_activity!=activity:
  activity=next_activity
  if touch_id<0 and not mouse_dragging:manual_hold=0
  if activity=="fishing":auto_point=world.FishingPlatform.FLOAT
  elif activity=="pet" and is_instance_valid(actor.pet_target):auto_point=actor.pet_target.global_position+Vector3.UP*.45
  elif activity=="sofa" and world.villa_room!=null:auto_point=world.villa_room.tv_screen.global_position
  elif activity=="dining" and world.villa_room!=null:auto_point=world.villa_room.get_node("DiningTable").global_position+Vector3.UP*.8
  elif activity in ["opening","taking","closing"]:auto_point=Vector3(-1.5,1.65,-4.7)
  elif activity in ["filling","water"]:auto_point=Vector3(-5.9,1.45,-4.3)
  elif activity in ["cooking_setup","cooking"]:auto_point=Vector3(-3.4,1.65,-4.4)
  else:auto_point=Vector3.INF
 if session!=null and session.active and fishing_phase!=session.stage:
  fishing_phase=session.stage
  if manual_hold<=0:
   if fishing_phase in ["net_ready","landing"]:auto_point=session.origin+Vector3(-.6,-.5,2.35)
   elif fishing_phase=="storing":auto_point=world.fish_keeper.REST+Vector3.UP*.35
   elif fishing_phase in ["ready","casting","waiting"]:auto_point=session.cast_target
 if not actor.stair_active:stair_manual_look=false
 if bed_phase!=actor.bed_stage:
  bed_phase=actor.bed_stage
  if bed_phase in ["lying_down","resting","eyes_opening"] and manual_hold<=0:target_pitch=deg_to_rad(-65)
  if bed_phase in ["removing_shoes","putting_shoes"] and manual_hold<=0:target_pitch=deg_to_rad(45)
  if bed_phase in ["sitting_up","moving_feet","getting_off","stepping_clear",""]:target_pitch=deg_to_rad(5)
 var director:Node=app.get("interaction_director")
 if director!=null and director.active and is_instance_valid(director.anchor) and manual_hold<=0 and director.camera_revision==manual_revision:auto_point=director.anchor.facing.global_position
 if actor.stair_active and not stair_manual_look and manual_hold<=0 and actor.stair_path.size()>0:
  var target:Vector3=actor.stair_path[0]
  if Vector2(target.x-actor.position.x,target.z-actor.position.z).length()<.75 and actor.stair_path.size()>1:target=actor.stair_path[1]
  auto_point=Vector3(target.x,camera.position.y,target.z)
 if auto_point.is_finite() and manual_hold<=0:
  var direction:Vector3=auto_point-camera.position
  if Vector2(direction.x,direction.z).length()>.15:
   target_yaw=atan2(-direction.x,-direction.z)
   target_pitch=clampf(-atan2(direction.y,Vector2(direction.x,direction.z).length()),deg_to_rad(-70),deg_to_rad(60))
 target_pitch=clampf(target_pitch,deg_to_rad(-75),deg_to_rad(65))
 var speed:float=LOOK_SPEED if manual_hold>0 else AUTO_SPEED
 var angular:Vector2=Vector2(angle_difference(yaw,target_yaw),target_pitch-pitch).limit_length(speed*dt)
 yaw+=angular.x;pitch+=angular.y
 camera.rotation=Vector3(-pitch,yaw,0)
 focus=camera.position;view_focus=camera.position-camera.basis.z*3;base_camera_position=camera.position
 pan_offset=Vector3.ZERO;target_pan=Vector3.ZERO;cut_focus=Vector3.INF;motion_reset=false
 hands.update_pose(app,actor,clock)
 _hide_held_world_props(app,actor)
 if session!=null and session.active:session.present_first_person(hands)
func _hide_held_world_props(app:Node,actor:Node3D) -> void:
 var routine:Node=app.get("home_routine")
 var sofa:Node=app.get("sofa_session")
 if sofa!=null and is_instance_valid(sofa.food_prop):sofa.food_prop.layers=PLAYER_LAYER
 if routine!=null and routine.gesture!=null and is_instance_valid(routine.gesture.prop):
  var prop:MeshInstance3D=routine.gesture.prop;prop.layers=PLAYER_LAYER
  for mesh:MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):mesh.layers=PLAYER_LAYER
 if actor.bed_motion!=null and is_instance_valid(actor.bed_motion.outfit):
  for mesh:MeshInstance3D in actor.bed_motion.outfit.find_children("*","MeshInstance3D",true,false):mesh.layers=1 if actor.bed_motion.hung else PLAYER_LAYER
 if is_instance_valid(actor.work_tool):
  for mesh:MeshInstance3D in actor.work_tool.find_children("*","MeshInstance3D",true,false):mesh.layers=PLAYER_LAYER
func pick_interaction(points:Array[Dictionary]) -> Dictionary:
 var world:Node3D=get_parent();var actor:Node3D=world.player
 var start:Vector3=camera.position;var direction:Vector3=-camera.basis.z
 var best:Dictionary={};var score:float=INF
 var ray:=PhysicsRayQueryParameters3D.create(start,start+direction*6,17,[actor.get_rid()])
 var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
 for point:Dictionary in points:
  if absf(float(point.pos.y)-actor.position.y)>1.25:continue
  var object:Node3D=point.get("object",point.get("owner"))
  var bounds:=AABB();var has_bounds:=false
  if is_instance_valid(object) and object!=world.props and object not in world.villa_rooms:
   var cached:Dictionary=_object_bounds(object)
   bounds=cached.bounds;has_bounds=cached.valid
  var anchor:Vector3=point.anchor.facing.global_position if is_instance_valid(point.get("anchor")) else point.pos+Vector3.UP*.8
  var distance:float=Vector2(point.pos.x-actor.position.x,point.pos.z-actor.position.z).length()
  var aimed:=false
  if has_bounds:
   var closest:Vector3=Vector3(clampf(actor.position.x,bounds.position.x,bounds.end.x),actor.position.y,clampf(actor.position.z,bounds.position.z,bounds.end.z))
   distance=Vector2(closest.x-actor.position.x,closest.z-actor.position.z).length()
   var contact:Variant=bounds.grow(.16).intersects_segment(start,start+direction*6)
   aimed=contact!=null
   if aimed and bounds.has_point(start):
    var toward:Vector3=anchor-start
    aimed=toward.length()>.1 and direction.dot(toward.normalized())>.4
   if aimed and not hit.is_empty() and not bounds.grow(.3).has_point(hit.position):aimed=false
  else:
   var to:Vector3=anchor-start;aimed=to.length()>.1 and direction.dot(to.normalized())>.84
   if aimed and not hit.is_empty() and start.distance_to(hit.position)+.25<to.length() and hit.position.distance_to(anchor)>1.1:aimed=false
  if not aimed or distance>minf(2.6,float(point.get("range",1.8))+1):continue
  var rank:float=distance-(.12 if str(point.kind)==selected_kind else 0)
  if rank<score:best=point;score=rank
 selected_kind=str(best.get("kind",""));return best

func _object_bounds(object:Node3D) -> Dictionary:
 var id:int=object.get_instance_id()
 if bounds_cache.has(id) and bounds_cache[id].transform==object.global_transform:return bounds_cache[id]
 var bounds:=AABB();var valid:=false
 var meshes:Array[Node]=object.find_children("*","MeshInstance3D",true,false)
 if object is MeshInstance3D:meshes.append(object)
 for mesh:MeshInstance3D in meshes:
  var box:AABB=mesh.global_transform*mesh.get_aabb()
  bounds=bounds.merge(box) if valid else box;valid=true
 var entry:Dictionary={"transform":object.global_transform,"bounds":bounds,"valid":valid}
 if bounds_cache.size()>256:bounds_cache.clear()
 bounds_cache[id]=entry;return entry
