extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false)
 for i in range(5):app.inactive=false;await physics_frame
 var world:Node3D=app.world;var rig:Node=world.orbit;var actor:CharacterBody3D=world.player
 actor.allowed=true;actor.set_physics_process(false);world.set_process(false);rig.set_process(false);rig.motion_enabled=true
 check(rig.comfort_mode,"comfort is the default")
 var walk:RefCounted=world.walk_camera;walk.reset()
 var original:Vector3=walk.map_input(world,Vector2.RIGHT);var changed:=Vector3.ZERO
 for i in range(1,181):changed=walk.map_input(world,Vector2.RIGHT.rotated(i*PI/900))
 check(absf(rad_to_deg(original.angle_to(changed))-36)<.05,"slow thumb turns accumulate continuously")
 var held:Vector3=changed;world.camera.rotation.y+=.8
 check(walk.map_input(world,Vector2.RIGHT.rotated(PI/5)).distance_to(held)<.001,"automatic camera motion never steers a held stick")
 walk.follow_requested=true;actor.manual_world_direction=Vector3.RIGHT
 var yaw:float=rig.target_yaw
 for i in range(120):walk.tick(world,1.0/60)
 check(is_equal_approx(yaw,rig.target_yaw),"walking never forces rear alignment")
 var held_offset:Vector3=rig.pan_offset
 rig.target_pan=Vector3(1,0,0);rig.cancel_drag()
 for i in range(180):rig._update_pan(1.0/60)
 check(rig.target_pan==held_offset and rig.return_timer==0,"release freezes the reached offset without chasing queued input")
 rig.return_to_player();check(rig.target_pan==Vector3.ZERO,"explicit return still works")
 # A large requested turn must obey the final output budget at both render rates.
 for dt:float in [1.0/30,1.0/60]:
  rig.motion_reset=true;rig._process(dt);rig.target_yaw+=2.2;rig.target_pitch=deg_to_rad(45)
  var bounded:=true;var level:=true
  for i in range(240):
   var before:Quaternion=world.camera.basis.get_rotation_quaternion();rig._process(dt)
   var after:Quaternion=world.camera.basis.get_rotation_quaternion()
   if rad_to_deg(before.angle_to(after))/dt>30.3:bounded=false
   if absf(world.camera.basis.x.y)>.001:level=false
  check(bounded,"final angular speed bounded at %d fps"%roundi(1/dt))
  check(level,"horizon remains level at %d fps"%roundi(1/dt))
 # Resolved collision positions must use the actual previous camera position.
 world.camera.position=Vector3(50,10,50);rig.motion_reset=false;rig.frame_delta=1.0/60
 var limited:Vector3=world.safe_camera_position(Vector3(50,1,50),Vector3(50,10,60))
 check(limited.distance_to(world.camera.position)<=8.0/60+.001,"outdoor collision movement respects its translation budget")
 rig.motion_enabled=false;var frozen:Transform3D=world.camera.transform;rig.target_yaw+=1;rig._process(.05)
 check(world.camera.transform==frozen,"pause freezes the camera")
 rig.motion_enabled=true
 actor.position=Vector3(-1,.68,16.1)
 check(app.fishing_session.begin(),"fishing begins")
 app.fishing_session.set_physics_process(false)
 for i in range(600):world._process(1.0/60);rig._process(1.0/60)
 check(world.camera.is_position_in_frustum(actor.position+Vector3.UP),"stable fishing shot includes the angler")
 check(world.camera.is_position_in_frustum(load("res://scripts/life/fishing_platform.gd").FLOAT),"stable fishing shot includes the distant float")
 var shot:Vector3=Vector3(rig.target_yaw,rig.target_pitch,rig.target_distance)
 for stage:String in ["waiting","reeling","landing","storing"]:
  app.fishing_session._set_stage(stage)
  check(Vector3(rig.target_yaw,rig.target_pitch,rig.target_distance)==shot,"one fishing view through "+stage)
 app.fishing_session.cancel()
 check(Vector3(rig.target_yaw,rig.target_pitch,rig.target_distance)==shot,"fishing exit never sweeps back")
 app.state.location="villa";app.state.home_floor=0;world.sync(app.state)
 yaw=rig.target_yaw
 world.home_camera.begin(world,"audit",actor.position+Vector3.UP,.95,2.35,2.3,58)
 for i in range(120):world._process(1.0/60);rig._process(1.0/60)
 check(is_equal_approx(world.camera.fov,world.indoor_camera.COMFORT_FOV) and is_equal_approx(world.home_camera.radius,7.8),"interaction keeps wide lens and distance")
 check(is_equal_approx(rig.target_yaw,yaw),"interaction preserves viewing side")
 actor.stair_active=true
 var stair_view:Vector3=world.indoor_camera.resolve(world,actor.position+Vector3.UP,world.camera.position,1.0/60)
 actor.visual.rotation.y+=PI
 var turned_view:Vector3=world.indoor_camera.resolve(world,actor.position+Vector3.UP,world.camera.position,1.0/60)
 check(stair_view==turned_view,"stairs keep one view through character turns")
 actor.stair_active=false
 rig.target_yaw+=.4;yaw=rig.target_yaw
 world.home_camera.release(world)
 check(is_equal_approx(rig.target_yaw,yaw),"ending an action preserves manual camera changes")
 app.state.location="island";world.sync(app.state)
 check(is_equal_approx(world.camera.fov,44),"leaving home restores the outdoor lens")
 check(rig.motion_reset,"location change resets motion without flying across the map")
 print("CAMERA COMFORT: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
