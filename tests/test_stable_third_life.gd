extends SceneTree
var app:Node
var passed:=0
var failed:=0
var dt:float=1./60
var max_motion:=0.0
var collisions:=0
var max_turn:=0.0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func frame() -> void:
 app.inactive=false;await physics_frame;await process_frame
 dt=minf(app.get_process_delta_time(),.05)
 var before:Vector3=app.world.camera.position
 var before_basis:Basis=app.world.camera.basis
 app.world._process(dt);app.world.orbit._process(dt)
 max_motion=maxf(max_motion,app.world.camera.position.distance_to(before))
 max_turn=maxf(max_turn,rad_to_deg(before_basis.get_rotation_quaternion().angle_to(app.world.camera.basis.get_rotation_quaternion()))/maxf(dt,.001))
func clear_motion() -> void:max_motion=0;collisions=0;max_turn=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 Engine.physics_ticks_per_second=120
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false);app._close_drawers();app.paused=false
 var world:Node=app.world;var actor:Node=world.player;var rig:Node=world.orbit;var camera:Camera3D=world.camera
 world.set_process(false);rig.set_process(false)
 var down_first:bool=OS.get_cmdline_user_args().has("--stairs-down-first")
 app.state.location="villa";app.state.home_floor=1 if down_first else 0;app.state.player_position=[6,.705+(5.25 if down_first else 0),2];world.sync(app.state)
 for i in range(90):await frame()
 for floor_index:int in ([0,1] if down_first else [1,0]):
  check(world.change_home_floor(app.state),"third-person stairs start "+str(floor_index));clear_motion()
  var bad_roll:=0;var lens:=0;var hidden_actor:=0;var outside_frame:=0;var blockers:Dictionary={}
  var skeleton:Skeleton3D=actor.visual.find_children("*","Skeleton3D",true,false)[0]
  var head_index:int=-1;var hip_index:int=-1;var feet:Array[int]=[]
  var clipped_full_body:=0;var maximum_height:=0.0;var maximum_width:=0.0
  for bone in range(skeleton.get_bone_count()):
   if str(skeleton.get_bone_name(bone)).ends_with("Head"):head_index=bone
   if str(skeleton.get_bone_name(bone)).ends_with("Hips"):hip_index=bone
   if str(skeleton.get_bone_name(bone)).ends_with("Foot"):feet.append(bone)
  for i in range(2400):
   await frame()
   if absf(camera.basis.x.y)>.001:bad_roll+=1
   if absf(camera.fov-72)>.001:lens+=1
   var seen:=false;var framed:=false
   for bone:int in [head_index,hip_index]:
    var point:Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
    var ray:=PhysicsRayQueryParameters3D.create(camera.position,point,17,[actor.get_rid()])
    var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty():seen=true
    else:
     var blocker:String=str(hit.collider.get_path());blockers[blocker]=int(blockers.get(blocker,0))+1
    if not camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(view.size)).has_point(camera.unproject_position(point)):framed=true
   if not seen:hidden_actor+=1
   if not framed:outside_frame+=1
   var body_points:Array[Vector2]=[]
   var full_body:=true
   for bone:int in [head_index]+feet:
    var point:Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
    if bone==head_index:point.y+=.22
    else:point.y-=.08
    var screen:Vector2=camera.unproject_position(point)
    if camera.is_position_behind(point) or not Rect2(Vector2(view.size)*.02,Vector2(view.size)*.96).has_point(screen):full_body=false
    body_points.append(screen)
   if not full_body:
    if clipped_full_body<3:print("CLIP ",floor_index," actor ",actor.position," camera ",camera.position," remaining ",actor.stair_path.size()," points ",body_points)
    clipped_full_body+=1
   if body_points.size()==3:
    var bottom:float=maxf(body_points[1].y,body_points[2].y)
    maximum_height=maxf(maximum_height,absf(bottom-body_points[0].y)/view.size.y)
    var distance:float=camera.position.distance_to(actor.position+Vector3.UP*1.2)
    maximum_width=maxf(maximum_width,1.2/(2*tan(deg_to_rad(camera.fov)*.5)*maxf(distance,.01)))
   var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.18;query.shape=sphere;query.transform.origin=camera.position;query.collision_mask=17;query.exclude=[actor.get_rid()]
   if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():collisions+=1
   if not actor.stair_active:break
  print("STAIR END actor ",actor.position," camera ",camera.position," path ",actor.stair_path," yawpitch ",rig.render_yaw," ",rig.render_pitch)
  print("FULL BODY ",floor_index," clipped ",clipped_full_body," max height ",maximum_height," estimated cloak width ",maximum_width)
  check(clipped_full_body==0 and maximum_height<.6 and maximum_width<.4,"stairs retain head, both feet and bounded character size")
  print("STAIR BLOCKERS ",floor_index," ",blockers)
  print("STAIR CAMERA ",floor_index," max displacement ",max_motion," collisions ",collisions," hidden ",hidden_actor," outside ",outside_frame," turn deg/s ",max_turn)
  check(not actor.stair_active and app.state.home_floor==floor_index,"third-person stair path finishes "+str(floor_index))
  check(bad_roll==0 and lens==0,"stairs do not roll or change field of view")
  check(max_turn<46,"final rendered stair view never whips faster than its turn budget: "+str(max_turn))
  check(collisions==0,"stairs camera never enters solid floors, walls or rails")
  check(hidden_actor==0 and outside_frame==0,"stairs retain a visible framed character: %d hidden, %d outside"%[hidden_actor,outside_frame])
  check(max_motion<.3,"stairs do not cut metres between frames: "+str(max_motion))
 if app.state.home_floor!=0:app.state.home_floor=0;world.sync(app.state)
 actor.position=world.Villa.SOFA_STAND;actor.velocity=Vector3.ZERO
 for i in range(60):await frame()
 check(app.sofa_session.begin(),"full-body sofa rest starts")
 for i in range(120):await frame()
 check(actor.sofa_seated and camera.fov==72,"sitting retains the stable third-person lens")
 app.joystick.direction=Vector2.RIGHT;await frame()
 check(actor.sofa_seated,"rest cannot be accidentally cancelled by the stick")
 app.joystick.reset();app.sofa_session.finish()
 actor.position=Vector3(-1.15,.705,-3.82);actor.velocity=Vector3.ZERO
 for i in range(60):await frame()
 check(app.home_routine.open_fridge(),"third-person fridge routine starts")
 for i in range(1000):
  await frame()
  if app.home_routine.phase=="fridge":break
 app.home_routine.take()
 for i in range(1000):
  await frame()
  if app.home_routine.phase=="fridge" and app.state.count("饮料")>0:break
 check(app.state.count("饮料")==1 and app.home_routine.gesture.prop.layers==1,"real character holds the original world-space drink")
 app.home_routine.drink()
 for i in range(1800):
  await frame()
  if app.home_routine.phase=="" and not app.home_routine.fridge.opened:break
 check(app.home_routine.phase=="" and app.state.count("空饮料瓶")==0,"drink, shut-door and bottle disposal finish: phase=%s pos=%s"%[app.home_routine.phase,actor.position])
 app.state.home_floor=1;world.sync(app.state);actor.position=Vector3(-3,world.Villa.Dimensions.UPPER_FLOOR+.03,-1.45);actor.velocity=Vector3.ZERO
 for i in range(90):await frame()
 check(app.bed_session.begin(),"full-body bedtime routine starts")
 var kept_visible:=true
 for i in range(1800):
  await frame()
  for mesh:MeshInstance3D in actor.visual.find_children("*","MeshInstance3D",true,false):
   if mesh.layers!=1:kept_visible=false
  if actor.bed_stage=="resting":break
 check(actor.bed_stage=="resting" and kept_visible,"undressing, shoes and lying remain rendered on the actual character")
 app.bed_session.finish()
 for i in range(1800):
  await frame()
  if actor.bed_stage=="":break
 check(actor.bed_stage=="","waking, shoes and dressing return control: "+actor.bed_stage)
 check(camera.fov==72 and absf(camera.basis.x.y)<.001,"all household actions keep a fixed upright view")
 print("STABLE THIRD LIFE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
