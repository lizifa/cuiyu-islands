extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(value:bool,message:String) -> void:
 if value:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func wait_for(value:String) -> void:
 for i in range(500):
  await frames(1)
  if app.home_routine.phase==value:return
 check(false,"sequence reaches "+value+" actual "+app.home_routine.phase)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=5;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.world.orbit.comfort_mode=false
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[-1,.705,7.5];app.world.sync(app.state)
 await frames(80)
 var world:Node3D=app.world;var actor:CharacterBody3D=world.player
 var wide_distance:float=world.camera.position.distance_to(actor.position+Vector3.UP)
 check(world.home_camera.owner_key=="" and wide_distance>7,"ordinary indoor view shows the room from afar")
 check(is_equal_approx(world.camera.fov,80),"wide walking field of view")
 var saved_yaw:float=world.orbit.target_yaw
 actor.position=Vector3(-1.5,.705,-2.6);await frames(4)
 var routine:Node=app.home_routine;check(routine.open_fridge(),"start fridge sequence")
 await wait_for("fridge")
 check(world.home_camera.owner_key=="household" and world.home_camera.radius<4,"opening fridge uses close interaction framing")
 check(actor.position.distance_to(routine.FRIDGE_STAND)<.2,"walk to reachable handle before opening")
 var fridge:Node3D=world.villa_room.get_node("HomeFridge")
 check(fridge.opened and fridge.angle< -1.5,"door visibly opens before selection")
 var inventory:int=app.state.count("饮料");var stock:int=app.state.home_drinks
 routine.take();await wait_for("retreating")
 check(app.state.count("饮料")==inventory+1 and app.state.home_drinks==stock-1,"take commits once before retreat")
 var origin:Vector3=actor.position
 await wait_for("closing")
 check(actor.position.distance_to(origin)>.8 and actor.position.distance_to(routine.FRIDGE_CLEAR)<.12,"retreat clears the door sweep")
 check(is_instance_valid(routine.gesture.prop),"bottle remains in hand while closing")
 await wait_for("fridge");await frames(55)
 check(not fridge.opened and absf(fridge.angle)<.03,"door physically closed after taking")
 check(world.home_camera.owner_key=="" and world.home_camera.radius>7,"taking ends in wide view")
 check(absf(angle_difference(saved_yaw,world.orbit.target_yaw))<.01,"restore previous heading")
 routine.drink();await wait_for("drinking")
 check(not fridge.opened,"drink begins with door closed")
 var to_camera:Vector3=world.camera.position-actor.position;to_camera.y=0
 check(actor.visual.global_basis.z.normalized().dot(to_camera.normalized())>.2,"drink shows front or three-quarter face")
 routine.cancel();check(not actor.home_busy and world.home_camera.owner_key=="","cancel releases pose and camera")
 actor.position=Vector3(-5.9,.705,-3.65);await frames(3);app.state.thirst=20
 check(routine.begin_sink("water"),"visible sink action starts")
 
 for i in range(350):
  await frames(1)
  if routine.phase=="":break
 check(app.state.thirst>40 and routine.phase=="","sink gesture commits water once and finishes")
 actor.position=Vector3(-3.4,.705,-3.6);await frames(3);app.state.inventory["鲜鱼"]=2
 var dried:int=app.state.count("鱼干")
 check(routine.begin_sink("cooking"),"cooking gesture starts")
 
 for i in range(250):
  await frames(1)
  if routine.phase=="":break
 check(app.state.count("鱼干")==dried+1 and app.state.count("鲜鱼")==0,"cooking commits recipe after gesture")
 check(world.home_camera.owner_key=="","cooking releases close camera")
 print("HOME CAMERA: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
