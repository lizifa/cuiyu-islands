extends SceneTree
const Dimensions=preload("res://scripts/life/villa_dimensions.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.world.orbit.comfort_mode=false;app.set_physics_process(false) # Exercise optional close-up cameras.
 app.state.location="villa";app.state.home_floor=0;app.world.sync(app.state)
 var world=app.world;var actor=world.player
 actor.set_physics_process(false);world.set_process(false);world.orbit.set_process(false)
 app.inactive=false;actor.allowed=true
 await physics_frame;await physics_frame
 check(is_equal_approx(Dimensions.CEILING-Dimensions.BASE,4.8),"first-floor clear height is 4.8m")
 check(is_equal_approx(Dimensions.TOP-Dimensions.UPPER_FLOOR,4.8),"second-floor clear height is 4.8m")
 for axis:Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
  app.joystick.direction=axis;app.joystick.knob=Vector2.ZERO
  var vertices:PackedVector2Array=app.joystick.direction_marker()
  var base:Vector2=(vertices[1]+vertices[2])*.5
  var radius:float=minf(app.joystick.size.x,app.joystick.size.y)*.46
  check(vertices[1].distance_to(vertices[2])>vertices[0].distance_to(base)*2,"direction triangle is flat")
  check(base.distance_to(app.joystick.size*.5)>=radius*.35-.01,"direction triangle touches outer rim of inner circle")
 app.joystick.reset()
 for up:bool in [true,false]:
  app.state.home_floor=0 if up else 1;world.sync(app.state);await physics_frame
  var route:Array[Vector3]=load("res://scripts/life/villa_stairwell.gd").route(up)
  actor.stair_active=true;world.indoor_camera.reset()
  var hidden:=0;var front:=0;var measured:=0;var visibility_samples:=0
  for segment in range(route.size()-1):
   var direction:Vector3=route[segment+1]-route[segment];direction.y=0;direction=direction.normalized()
   var count:int=ceili(route[segment].distance_to(route[segment+1])/.04)
   for i in range(count):
    actor.position=route[segment].lerp(route[segment+1],float(i)/count);actor.visual.rotation.y=atan2(direction.x,direction.z)
    var focus:Vector3=actor.position+Vector3.UP*1.25
    var camera_pos:Vector3=world.indoor_camera.resolve(world,focus,focus+Vector3(0,4,4),1./30)
    world.camera.position=camera_pos;world.camera.look_at(focus);world.camera.fov=world.indoor_camera.VIEW_FOV
    if segment in [3,7] and i>=25:
     measured+=1
     var behind:Vector3=camera_pos-actor.position;behind.y=0
     if behind.dot(direction)>0:front+=1
    visibility_samples+=1
    var visible:=false
    for height:float in [.75,1.2,1.75]:
     var target:Vector3=actor.position+Vector3.UP*height
     var query:=PhysicsRayQueryParameters3D.create(camera_pos,target,17,[actor.get_rid()])
     if world.camera.is_position_in_frustum(target) and world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():visible=true
    if not visible:
     hidden+=1
     if hidden<=3:print("HIDDEN up ",up," segment ",segment," actor ",actor.position," camera ",camera_pos)
  print("STAIR VISIBILITY ",up," samples ",visibility_samples," hidden ",hidden," front ",front)
  check(measured>50 and hidden==0,"character stays visible on both flights")
  check(front==0,"camera follows behind walking direction")
  actor.stair_active=false
 app.state.home_floor=0;world.sync(app.state);actor.position=Vector3(6.7,.705,2.6)
 if world.companion!=null:world.companion.set_physics_process(false);world.companion.position=Vector3(0,-10,0)
 await physics_frame
 var start:Vector3=actor.position
 app._nearby_interact()
 check(actor.stair_active and not app.interaction_director.active,"one tap starts stairs without generic anchor approach")
 check(actor.stair_route[0].distance_to(start)<.01 and actor.stair_route[1].x>start.x,"stairs connect forward from current position instead of returning to ring")
 actor.cancel_stairs()
 print("HOME MOTION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
