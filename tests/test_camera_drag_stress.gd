extends SceneTree
var world:Node3D
var rig:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func tick(dt:float) -> void:
 world._process(dt);rig._process(dt)
func reset() -> void:
 rig.clear_observation(true,false);rig.motion_reset=true
 rig.focus=world.player.position+Vector3.UP;rig.distance=18;rig.target_distance=18
 rig.yaw=rig.initial_yaw;rig.target_yaw=rig.yaw;rig.pitch=rig.initial_pitch;rig.target_pitch=rig.pitch
 rig.pan_limit=4;rig.motion_enabled=true
 for i in range(60):tick(1.0/60)
func _initialize():call_deferred("run")
func run():
 var state=load("res://scripts/life/life_state.gd").new()
 world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 world.set_process(false);world.player.set_physics_process(false);rig=world.orbit;rig.set_process(false)
 world.player.allowed=true
 await physics_frame;await physics_frame
 reset()
 var inventory:Dictionary=state.inventory.duplicate(true)
 var press:=InputEventScreenTouch.new();press.index=5;press.position=Vector2(650,600);press.pressed=true;root.push_input(press,true)
 check(rig.touch_id==5,"native touch owns its camera gesture")
 var drag:=InputEventScreenDrag.new();drag.index=5;drag.position=Vector2(650,660);drag.relative=Vector2(0,60);root.push_input(drag,true)
 check(rig.target_pan.length()>.1,"native screen drag reaches observation mapping")
 press.pressed=false;press.position=Vector2(-50,-50);root.push_input(press,true)
 check(rig.touch_id==-1 and rig.target_pan==rig.pan_offset,"release outside the viewport stops the owning finger")
 reset()
 rig.base_camera_position=rig.focus+Vector3(0,1.2,1.6)
 check(rig.observation_limit()<.7,"a close camera automatically tightens the observation range")
 reset()
 # Gesture mapping must not feed the camera's own changing basis back into input.
 rig.pan_drag(Vector2(0,180));world.camera.rotation.y+=.8;rig.pan_drag(Vector2(0,-180))
 check(rig.target_pan.length()<.0001,"opposite events cancel even if the rendered basis changes")
 reset();rig.pan_drag(Vector2(0,100000));rig.pan_drag(Vector2(0,-100000))
 check(rig.target_pan.length()<.0001,"overdragging the boundary cannot accumulate observation drift")
 for hz:int in [30,60,120]:
  reset();rig.touch_id=1
  var radius:float=world.camera.position.distance_to(rig.view_focus)
  var basis:Quaternion=world.camera.basis.get_rotation_quaternion()
  var y:float=0;var bounded:=true;var framed:=true;var level:=true
  for i in range(hz*15):
   var next:float=180*sin((i+1)*TAU*3/hz)
   # Touch event batches represent an input rate higher than the render rate.
   for j in range(4):rig.pan_drag(Vector2(0,(next-y)/4))
   y=next
   var old_pos:Vector3=world.camera.position;var old_focus:Vector3=rig.view_focus
   tick(1.0/hz)
   if world.camera.position.distance_to(old_pos)>4.0/hz+.0001 or rig.view_focus.distance_to(old_focus)>4.0/hz+.0001:bounded=false
   if absf(world.camera.position.distance_to(rig.view_focus)-radius)>.001:framed=false
   if world.camera.basis.get_rotation_quaternion().angle_to(basis)>.001:level=false
  check(bounded,"camera and focus share one speed budget at %d fps"%hz)
  check(framed,"rapid reversals never pump the lens distance at %d fps"%hz)
  check(level,"rapid reversals never change orientation at %d fps"%hz)
  check(rig.target_pan.length()<.001,"fifteen seconds of symmetric drags have no accumulated drift at %d fps"%hz)
  rig.cancel_drag();var stopped:Vector3=world.camera.position
  for i in range(10):tick(1.0/hz)
  check(world.camera.position.distance_to(stopped)<.001,"release stops observation without a delayed chase at %d fps"%hz)
 reset()
 var wall:=StaticBody3D.new();wall.position=world.camera.position+Vector3(1.2,0,0);world.add_child(wall)
 var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,6,6);collider.shape=box;wall.add_child(collider)
 await physics_frame;await physics_frame
 var baseline:Vector3=world.camera.position;var arm:float=baseline.distance_to(rig.view_focus)
 rig.target_pan=Vector3(4,0,0)
 for i in range(120):tick(1.0/60)
 check(world.camera.position.x<=wall.position.x-.399,"pan sweeps stop before the obstruction")
 check(absf(world.camera.position.distance_to(rig.view_focus)-arm)<.001,"an obstacle does not retract the observation arm")
 check(rig.pan_offset.length()<=4.001,"blocked observation remains within the local range")
 var blocked:Vector3=world.camera.position;rig.target_pan=Vector3(-2,0,0);tick(1.0/60)
 check(world.camera.position.x<blocked.x-.01,"reversing away from a wall responds immediately")
 world.camera.position=wall.position;tick(1.0/60)
 check(rig.target_pan==Vector3.ZERO and rig.pan_offset==Vector3.ZERO,"an invalid external pose recovers to the unpanned rig")
 check(is_instance_valid(rig.cut_overlay) and rig.cut_overlay.modulate.a>.9,"invalid-pose recovery is covered by a fade")
 wall.queue_free();await physics_frame
 # Use the actual shipped tree asset: camera coverage must extend above
 # the original three-metre player bands without changing player collision.
 var tree:Node3D=world.model("broad-canopy-shade-tree-e7c4a2",Vector3(50,0,50))
 load("res://scripts/life/prop_collision.gd").tree(tree,"broad-canopy-shade-tree-e7c4a2")
 await physics_frame;await physics_frame
 var detected:=false;var player_clear:=false
 var canopy_start:=Vector3.ZERO;var canopy_end:=Vector3.ZERO;var canopy_surface:=Vector3.ZERO
 for height:float in [3.2,3.5,4.0,4.5,5.0,5.5,6.0,7.0,8.0]:
  for angle:float in [0.0,PI/4,PI/2,PI*3/4]:
   var center:=Vector3(50,height,50);var ray_arm:=Vector3(cos(angle),0,sin(angle))*12
   var query:=PhysicsRayQueryParameters3D.create(center-ray_arm,center+ray_arm,64)
   var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
   if hit.is_empty():continue
   if not detected:canopy_start=center-ray_arm;canopy_end=center+ray_arm;canopy_surface=hit.position
   detected=true;query.collision_mask=1
   if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():player_clear=true
 check(detected,"camera detects shipped tree geometry above three metres")
 check(player_clear,"camera-only tree geometry does not block player movement")
 var at:Vector3=canopy_start;var safe:=true
 for i in range(480):
  var next:Vector3=world.safe_observation_position(at,canopy_end,1.0/60)
  if not next.is_finite() or next.distance_to(at)>4.0/60+.0001:safe=false;break
  at=next
 check(safe,"continuous high-canopy sweep obeys its movement budget")
 check(at.distance_to(canopy_start)<canopy_surface.distance_to(canopy_start)-.25,"holding toward a real canopy stops before its visual surface")
 check(state.inventory==inventory,"camera stress never consumes resources")
 print("CAMERA DRAG STRESS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
