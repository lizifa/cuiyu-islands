extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(value:bool,message:String) -> void:
 if value:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func phase(value:String,minimum:float=0) -> void:
 for i in range(700):
  await frames(1)
  if app.home_routine.phase==value and app.home_routine.elapsed>=minimum:return
 check(false,"reach "+value+" actual "+app.home_routine.phase)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.world.orbit.comfort_mode=false
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[-1,.705,7.5];app.world.sync(app.state)
 await frames(80)
 var world:Node3D=app.world;var actor:CharacterBody3D=world.player
 for axis:Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
  app.joystick._set_point(app.joystick.get_global_rect().get_center()+axis*100)
  check(app.joystick.knob==Vector2.ZERO,"thumb remains fixed "+str(axis))
  var marker:PackedVector2Array=app.joystick.direction_marker();var middle:Vector2=(marker[1]+marker[2])*.5
  check((marker[0]-middle).normalized().dot(axis)>.99,"only arrow rotates "+str(axis))
 app.joystick.reset()
 var right:Vector3=world.camera.global_basis.x;right.y=0;right=right.normalized()
 var start:Vector3=actor.position
 app.joystick.direction=Vector2.RIGHT;await frames(48)
 var displacement:Vector3=actor.position-start;displacement.y=0
 check(displacement.length()>1 and displacement.normalized().dot(right)>.99,"held input remains a straight world path during camera turn")
 var rear:Vector3=world.camera.position-actor.position;rear.y=0
 check(rear.normalized().dot(displacement.normalized())< -.3,"walking camera reaches the rear side")
 app.joystick.reset();await frames(8)
 var stopped_yaw:float=world.orbit.target_yaw;await frames(20)
 check(absf(angle_difference(stopped_yaw,world.orbit.target_yaw))<.01,"stopping does not keep rotating the camera")
 actor.position=world.Villa.SOFA_STAND;world.orbit.yaw=PI/2;world.orbit.target_yaw=PI/2;world.indoor_camera.reset();await frames(45)
 check(app.sofa_session.begin(),"sofa rest begins")
 await frames(100)
 check(world.home_camera.owner_key=="sofa" and world.camera.fov<51,"sofa has a closer television shot")
 var screen:MeshInstance3D=world.villa_room.tv_screen;var size:Vector2=screen.mesh.size
 var left:Vector2=world.camera.unproject_position(screen.to_global(Vector3(-size.x*.5,0,0)))
 var right_edge:Vector2=world.camera.unproject_position(screen.to_global(Vector3(size.x*.5,0,0)))
 var width:float=left.distance_to(right_edge)/world.camera.get_viewport().get_visible_rect().size.x
 check(width>.20 and world.camera.is_position_in_frustum(screen.global_position),"television is legible and in frame "+str(width))
 app.sofa_session.finish();check(world.home_camera.owner_key=="","standing releases sofa framing")
 actor.position=Vector3(-1.5,.705,-2.6);await frames(4)
 var routine:Node=app.home_routine;routine.open_fridge();await phase("fridge");routine.take();await phase("retreating");await phase("fridge");routine.drink();await phase("drinking",1.3)
 check(world.camera.fov<61 and world.home_camera.radius<2.6,"drinking uses a stable close-up")
 var head:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("Head")).origin
 var mouth:Vector3=head-Vector3.UP*.09+actor.visual.global_basis.z.normalized()*.12
 var rim:Vector3=routine.gesture.prop.to_global(Vector3(0,.125,0))
 check(rim.distance_to(mouth)<.12,"vessel rim reaches mouth "+str(rim.distance_to(mouth)))
 var to_camera:Vector3=world.camera.position-actor.position;to_camera.y=0
 check(actor.visual.global_basis.z.normalized().dot(to_camera.normalized())>.55,"face remains visible during the sip")
 check(world.camera.is_position_in_frustum(mouth) and world.camera.is_position_in_frustum(rim),"face and vessel remain in frame")
 routine.cancel()
 actor.position=Vector3(-3.4,.705,-3.6);actor.visual.rotation.y=PI;await frames(3);app.state.inventory["鲜鱼"]=2
 routine.begin_sink("cooking");await phase("cooking",1)
 check(world.villa_room.has_node("CookingPot") and routine.gesture.prop.name=="HeldCookingSpoon","cooking shot has visible pot and utensil")
 check(world.camera.is_position_in_frustum(Vector3(-3.4,1.9,-4.35)),"cooking shot includes the pot")
 check(world.home_camera.target_fov==60,"cooking uses its own lens")
 routine.cancel()
 print("CINEMATIC CAMERA: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
