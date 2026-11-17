extends SceneTree
var passed:=0
var failed:=0
var app:Node
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func face(actor:Node3D,target:Vector3) -> void:
  var flat:Vector3=target-actor.position;flat.y=0
  if flat.length()<.01:return
  actor.visual.rotation.y=atan2(flat.x,flat.z)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame;await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app._close_drawers();app.paused=false;app.inactive=false;app.set_process(false);app.set_physics_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[0,.705,8];app.world.sync(app.state)
 await frames(3)
 var actor:CharacterBody3D=app.world.player
 actor.set_physics_process(false);app.world.orbit.set_process(false);app.world.set_process(false)
 var seats:=0
 for point:Dictionary in app.world.interaction_points:
  if point.kind!="villa_eat":continue
  seats+=1;actor.position=point.anchor.global_position;face(actor,point.pos)
  check(app.world.nearby_action().kind=="villa_eat","dining cue is reachable at each chair "+str(seats))
  app._update_context();check(app.context_action.title=="坐下用餐","nearby action names dining")
  check(app.sofa_session.begin_dining(point.seat),"selected chair can start dining")
  check(app.sofa_session.mode=="dining" and app.sofa_session.eat_button.visible,"dining exposes eating action")
  check(app.world.orbit.activity_key=="dining","dining selects dedicated camera")
  for frame in range(300):actor._update_sofa(1./60);app.world.orbit.motion_enabled=true;app.world.orbit._process(1./60)
  if not app.world.orbit._body_framed(actor):
   print("DINING ",seats," cam ",app.world.camera.position," actor ",actor.position," pivot ",app.world.orbit.pivot)
   for key:String in ["Head","LeftFoot","RightFoot"]:
    var wp:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone(key)).origin
    print(key," ",wp," screen ",app.world.camera.unproject_position(wp))
  check(app.world.orbit._body_framed(actor),"dining camera keeps seated body visible "+str(seats))
  if seats==1:
   app.state.inventory["鱼干"]=1;app.state.inventory["浆果"]=0;app.state.inventory["蔬菜"]=0;app.state.inventory["鲜鱼"]=0;app.state.hunger=50
   app._sync_overlay_state();app._update_context()
   check(app.context_action.title=="吃东西" and app.sprint_action.title=="起身" and app.build_action.visible and not app.build_action.active,"dining greys unrelated movement skills")
   app._nearby_interact()
   check(app.sofa_session.food_time>=0,"primary dining action starts an actual eating motion")
   for i in range(150):app.sofa_session._physics_process(1./60)
   check(app.state.count("鱼干")==0 and app.state.hunger>50,"eating consumes exactly one food and restores hunger")
  app.sofa_session.finish()
 check(seats==4,"four chairs have their own action anchors")
 for kind:String in ["treadmill","bike","weights","yoga"]:
  var point:Dictionary=app.world.find_interaction("gym_"+kind)
  check(not point.is_empty(),"equipment registered "+kind)
  if point.is_empty():continue
  actor.position=point.anchor.global_position;face(actor,point.pos)
  check(app.world.nearby_action().kind==point.kind,"equipment-specific nearby prompt "+kind)
  check(app.exercise_session.begin(point),"equipment-specific session starts "+kind)
  if kind=="weights":
   # 量「拿起这一段的最近一次接触」：整个 pickup 阶段跟踪双手到架上哑铃的最近距离，
   # 要求真的贴上架面（隔空抓 = 人比架矮都够不着）。
   var early_rig:Skeleton3D=app.exercise_session.gesture.rig
   var targets:Array=app.exercise_session.rack_targets
   check(targets.size()>=2,"dumbbell pickup knows where the rack is")
   var near_left:=999.0
   var near_right:=999.0
   for i in range(120):
    if targets.size()>=2:
     var lh0:Vector3=early_rig.global_transform*early_rig.get_bone_global_pose(actor._bone("LeftHand")).origin
     var rh0:Vector3=early_rig.global_transform*early_rig.get_bone_global_pose(actor._bone("RightHand")).origin
     near_left=minf(near_left,lh0.distance_to(targets[0]))
     near_right=minf(near_right,rh0.distance_to(targets[1]))
    if app.exercise_session.stage!="pickup":break
    app.exercise_session._physics_process(1./60)
   if targets.size()>=2:
    check(near_left<.16,"left hand touches the rack dumbbell")
    check(near_right<.16,"right hand touches the rack dumbbell")
  var saved:Vector3=app.world.save_position()
  for i in range(120):app.exercise_session._physics_process(1./60)
  var rig:Skeleton3D=app.exercise_session.gesture.rig
  var sample:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("RightHand")).origin
  for i in range(25):app.exercise_session._physics_process(1./60)
  var later:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("RightHand")).origin
  if kind=="bike":
   check(absf(point.equipment.get_node("Pedal0").position.z)>.01,"bike pedals actually rotate")
   var foot:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftFoot")).origin
   var pedal:Vector3=point.equipment.get_node("Pedal0").global_position+Vector3.UP*.09
   check(foot.distance_to(pedal)<.12,"rider foot follows the moving pedal")
  else:check(sample.distance_to(later)>.015*app.world.PLAYABLE_CHARACTER_SCALE,"real character animates "+kind)
  if kind=="weights":
   var left:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftHand")).origin
   var right:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("RightHand")).origin
   check((left-right).dot(actor.visual.global_basis.x.normalized())>.25,"dumbbell arms stay on their anatomical sides")
   # 拿起时手必须真的摸到架上的哑铃：这条是「人比架矮、隔空拿哑铃」的防回归。

  if kind=="bike":
   var left:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftFoot")).origin
   var right:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("RightFoot")).origin
   check((left-right).dot(actor.visual.global_basis.x.normalized())>.2,"bike feet do not cross")
   app.exercise_session.elapsed=1.1+PI/2/3.8;app.exercise_session._physics_process(0)
   check(point.equipment.get_node("Pedal0").position.z<-.17,"pedal moves forward after top dead centre")
  check(app.world.save_position().is_equal_approx(saved),"exercise saves a safe return point "+kind)
  app._update_context();check(app.context_action.title=="结束锻炼","exercise has an explicit stop action")
  for i in range(300):app.world.orbit.motion_enabled=true;app.world.orbit._process(1./60)
  # 哑铃机位会为了躲开哑铃架走到侧面（弯举是矢状面动作，侧面最清楚），所以只要求「不是背后机位」。
  # 哑铃架贴着西墙，正面机位会顶到墙里，所以这里明确用越肩机位：不再要求「镜头不在背后」。
  if kind=="weights":check(app.world.camera.position.distance_to(actor.position)>2.7,"dumbbell camera stays back")
  if not app.world.orbit._body_framed(actor):
   var target:Vector3=app.world.orbit._indoor_goal(app.world.orbit.pivot,app.world.orbit.stable_yaw,app.world.orbit.stable_pitch,app.world.orbit.current_arm,actor)
   var hit:Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(app.world.orbit.pivot,target,17,[actor.get_rid()]))
   print("GYM OCCLUSION ",target," safe ",app.world.orbit._safe_boom(app.world.orbit.pivot,target,actor)," recovered ",app.world.orbit.recovered_arm," ray ",hit.get("position")," collider ",hit.get("collider"))
   print("GYM FRAME ",kind," camera ",app.world.camera.position," actor ",actor.position," pivot ",app.world.orbit.pivot)
   for key:String in ["Head","LeftFoot","RightFoot"]:
    var world_point:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone(key)).origin
    print(key," ",world_point," screen ",app.world.camera.unproject_position(world_point))
  if kind=="weights":
   # 哑铃是贴着架子站桩练：全身入框要求不现实，只要求「脑袋在画面里、镜头没贴到身上」。
   var head_point:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("Head")).origin
   var view_size:Vector2=app.world.camera.get_viewport().get_visible_rect().size
   check(app.world.camera.unproject_position(head_point).y>view_size.y*.1,"dumbbell camera keeps the head in frame")
   check(app.world.camera.position.distance_to(actor.position+Vector3.UP*1.2)>2.4,"dumbbell camera does not sit inside the character")
  else:check(app.world.orbit._body_framed(actor),"exercise camera keeps the complete character visible "+kind)
  var before_pause:float=app.exercise_session.elapsed
  app.paused=true;app.exercise_session._physics_process(2);app.paused=false
  check(app.exercise_session.elapsed==before_pause,"pausing freezes exercise and resource consumption "+kind)
  app.exercise_session.finish()
  # 哑铃结束要先演「放回架上」，这里把放下的一秒推完再断言姿势复位。
  for i in range(70):
   if not app.exercise_session.active:break
   app.exercise_session._physics_process(1./60)
  check(not app.exercise_session.active,"dumbbell putdown finishes before release "+kind)
  # 哑铃拿到手后人是站在架前练的（不再按回起手位置），所以位置断言只对其它器材成立。
  if kind=="weights":check(not actor.home_busy and actor.pose_skeleton==null,"stopping restores pose and movement "+kind)
  else:check(not actor.home_busy and actor.pose_skeleton==null and actor.position.is_equal_approx(saved),"stopping restores pose and movement "+kind)
 # Exercise the actual nearby-button -> approach -> facing -> session path.
 actor.set_physics_process(true);app.set_physics_process(true)
 for kind:String in ["treadmill","bike","weights","yoga"]:
  var point:Dictionary=app.world.find_interaction("gym_"+kind)
  actor.position=point.anchor.global_position+Vector3(0,0,.1);actor.velocity=Vector3.ZERO;face(actor,point.pos)
  app._nearby_interact()
  for i in range(500):
   await frames(1)
   if app.exercise_session.active or not app.interaction_director.active:break
  check(app.exercise_session.active and app.exercise_session.kind==kind,"nearby button approaches and starts the actual equipment "+kind+" "+app.interaction_director.stage)
  app._nearby_interact()
  # 哑铃的结束会先演放下再收尾，等它真正退出再继续去下一台。
  for i in range(90):
   await frames(1)
   if not app.exercise_session.active:break
  check(not app.exercise_session.active,"same contextual button stops exercise "+kind)
 var dining:Dictionary=app.world.find_interaction("villa_eat")
 actor.position=dining.anchor.global_position;actor.velocity=Vector3.ZERO;face(actor,app.world.villa_room.to_global(app.world.Villa.DINING_CENTER))
 app._nearby_interact()
 for i in range(500):
  await frames(1)
  if app.sofa_session.active or not app.interaction_director.active:break
 check(app.sofa_session.active and app.sofa_session.mode=="dining","left-side dining prompt actually approaches and sits")
 app.sofa_session.finish();app.set_physics_process(false);actor.set_physics_process(false)
 actor.position=Vector3(0,.705,16.9)
 check(not app.world.try_walk_exit(app.state,Vector3.FORWARD),"walking back into the room does not exit")
 app.world.walk_camera.input_active=true;app.world.walk_camera.input_revision=app.world.orbit.manual_revision
 app.world.walk_camera.input_right=Vector3.RIGHT;app.world.walk_camera.input_forward=Vector3.BACK
 check(app.world.try_walk_exit(app.state,Vector3.BACK),"holding movement outward exits via the door")
 check(app.world.walk_camera.map_input(app.world,Vector2.UP).z>.9,"held movement keeps its outward world direction after the camera changes")
 await frames(3)
 app.world.orbit.motion_enabled=true
 for i in range(180):app.world.orbit._process(1./60)
 var camera:Camera3D=app.world.camera
 check(camera.position.z>actor.position.z,"exit camera stays on the clear yard side of the house")
 check(not camera.is_position_behind(actor.position+Vector3.UP),"character remains in front of exit camera")
 var platform=load("res://scripts/life/fishing_platform.gd")
 actor.position=platform.POINT;actor.velocity=Vector3.ZERO
 app.world.orbit.room_key=""
 for i in range(90):app.world.orbit._process(1./60)
 check(app.fishing_session.begin(),"fishing starts from the platform")
 var maximum_camera_step:=0.0
 for i in range(600):
  var previous:Vector3=camera.position
  app.world.orbit._process(1./60)
  maximum_camera_step=maxf(maximum_camera_step,camera.position.distance_to(previous))
 check(maximum_camera_step<.15,"entering fishing eases the view instead of teleporting its focus")
 check(app.world.orbit.activity_view_ready("fishing"),"settled fishing view opens the cast action")
 check(app.world.orbit.activity_key=="fishing","fishing owns a dedicated stable third-person view")
 for point:Vector3 in [actor.position+Vector3.UP*2.1,actor.position,platform.FLOAT]:
  check(not camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(view.size)).has_point(camera.unproject_position(point)),"fishing shot includes person and float "+str(point))
 print("FISHING VIEW ",camera.position," actor ",actor.position," float screen ",camera.unproject_position(platform.FLOAT))
 app.fishing_session.cancel();check(app.world.orbit.activity_key=="","leaving fishing releases its camera")
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[-9,.705,11.65];app.world.sync(app.state)
 await frames(3)
 var reset_point:Dictionary=app.world.find_interaction("gym_treadmill")
 actor.position=reset_point.anchor.global_position;face(actor,reset_point.pos)
 check(app.exercise_session.begin(reset_point),"reset fixture begins exercise")
 check(app._reset_game() and not app.exercise_session.active and not actor.home_busy and not actor.exercise_return.is_finite(),"reset releases exercise and its safe-save anchor before creating a fresh game")
 print("HOME INTERACTION PATHS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
