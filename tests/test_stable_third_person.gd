extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func step(dt:float=1./60) -> void:
 app.inactive=false;app.world.player.allowed=true;app.world._process(dt);app.world.orbit._process(dt)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(2436,1126);viewport.own_world_3d=true;root.add_child(viewport)
 app=load("res://scenes/life_main.tscn").instantiate();viewport.add_child(app);app._close_drawers();app.paused=false;app.inactive=false
 app.set_process(false);app.set_physics_process(false);app.world.set_process(false);app.world.orbit.set_process(false);app.world.player.set_physics_process(false)
 var actor:Node3D=app.world.player;var rig:Node=app.world.orbit;var camera:Camera3D=app.world.camera
 await physics_frame;await physics_frame
 for i in range(120):step()
 check(rig.stable_third_person and not rig.first_person,"production default is the new stable third person")
 check(camera.keep_aspect==Camera3D.KEEP_WIDTH and is_equal_approx(camera.fov,72),"third-person horizontal lens is fixed")
 var meshes:Array[Node]=actor.visual.find_children("*","MeshInstance3D",true,false)
 check(meshes.all(func(mesh):return mesh.layers==1),"entire original character is rendered")
 var skeleton:Skeleton3D=actor.visual.find_children("*","Skeleton3D",true,false)[0]
 var framed:=true
 for i in range(skeleton.get_bone_count()):
  if str(skeleton.get_bone_name(i)).ends_with("Head") or str(skeleton.get_bone_name(i)).ends_with("Foot"):
   var joint:Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(i).origin
   if camera.is_position_behind(joint) or not Rect2(Vector2.ZERO,Vector2(viewport.size)).has_point(camera.unproject_position(joint)):framed=false
 check(framed,"standing head and both feet fit on the phone screen")
 check(not app.first_person_reticle.visible,"first-person gaze reticle is absent in third person")
 var before:Transform3D=camera.transform
 for i in range(120):
  actor.visual.position.y=sin(i*.7)*.07;actor.visual.rotation.y+=.1;step()
 actor.visual.position.y=0
 check(camera.transform.is_equal_approx(before),"idle bones and body turns cannot shake or rotate the camera")
 rig.establish_view(Vector3(100,100,100),30,1);rig.target_distance=35;rig.target_yaw=3;rig.view_transition=.1
 app.world.home_camera.begin(app.world,"test",Vector3(50,50,50),2,2,5,40)
 for i in range(30):step()
 check(camera.transform.is_equal_approx(before) and is_equal_approx(camera.fov,72),"legacy action shots cannot cut, zoom or rotate the new camera")
 app.world.home_camera.release(app.world)
 for hz:int in [30,60]:
  rig.mouse_dragging=true
  var upright:=true;var bounded:=true
  for i in range(hz*4):
   var yaw_before:float=rig.stable_yaw;var pitch_before:float=rig.stable_pitch;var before_view:Basis=camera.basis
   rig.gesture_drag(Vector2(170 if i%2==0 else -160,200 if i%3==0 else -90));step(1./hz)
   if absf(camera.basis.x.y)>.001 or not camera.position.is_finite():upright=false
   if Vector2(angle_difference(yaw_before,rig.stable_yaw),rig.stable_pitch-pitch_before).length()>rig.MANUAL_SPEED/hz+.001:bounded=false
   if before_view.get_rotation_quaternion().angle_to(camera.basis.get_rotation_quaternion())>deg_to_rad(76)/hz+.001:bounded=false
  check(upright and bounded,"rapid drag has no roll or unbounded turns at %d fps"%hz)
  rig.cancel_drag();var stopped:=Vector2(rig.stable_yaw,rig.stable_pitch);var stopped_view:Transform3D=camera.transform
  for i in range(120):step(1./hz)
  check(Vector2(rig.stable_yaw,rig.stable_pitch).distance_to(stopped)<.001 and camera.transform.is_equal_approx(stopped_view),"release stops the actual view without automatic snapback at %d fps"%hz)
 check(rig.set_first_person(true),"player can explicitly choose first person")
 for i in range(120):step()
 check((camera.cull_mask&256)==0 and camera.fov==88,"optional first person keeps its eye-level rendering")
 check(rig.set_first_person(false),"player can explicitly return to third person")
 for i in range(120):step()
 check(meshes.all(func(mesh):return mesh.layers==1) and (rig.hands==null or not rig.hands.visible),"switching back restores body and removes duplicate hands")
 actor.home_busy=true
 check(not rig.set_first_person(true),"view switching cannot interrupt a scripted household action")
 actor.home_busy=false
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[0,.705,8];app.world.sync(app.state)
 await physics_frame;await physics_frame
 for i in range(180):step()
 check(is_equal_approx(camera.fov,72) and (camera.cull_mask&2)!=0,"indoors retain the same lens and real architecture")
 var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.18;query.shape=sphere;query.collision_mask=17;query.exclude=[actor.get_rid()];query.transform.origin=camera.position
 check(app.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"indoor camera rests outside solid geometry")
 var safe:Transform3D=camera.transform
 rig.motion_enabled=false;actor.position.x+=.5;step()
 check(camera.transform.is_equal_approx(safe),"pause freezes the third-person camera")
 print("STABLE THIRD PERSON: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
