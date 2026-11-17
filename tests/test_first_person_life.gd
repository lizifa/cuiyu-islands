extends SceneTree
var passed:=0
var failed:=0
var app:Node
var dt:float=1./60
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frame() -> void:
 app.inactive=false;await physics_frame;await process_frame
 dt=minf(app.get_process_delta_time(),.05)
 app.world._process(dt);app.world.orbit._process(dt)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=1;Engine.physics_ticks_per_second=120
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.world.orbit.set_first_person(true);app.set_process(false)
 app._close_drawers();app.paused=false;app.inactive=false
 var world:Node=app.world;var actor:Node=world.player;var rig:Node=world.orbit;var camera:Camera3D=world.camera
 world.set_process(false);rig.set_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[6,.705,2];world.sync(app.state)
 for i in range(60):await frame()
 var size:Vector2=camera.get_viewport().get_visible_rect().size
 var press:=InputEventScreenTouch.new();press.index=1;press.position=Vector2(size.x*.65,size.y*.4);press.pressed=true
 rig._unhandled_input(press)
 check(rig.touch_id==1,"right look finger owns its gesture")
 var release_other:=InputEventScreenTouch.new();release_other.index=0;release_other.pressed=false;rig._input(release_other)
 check(rig.touch_id==1,"releasing the movement finger does not release look")
 press.pressed=false;rig._input(press)
 check(rig.touch_id==-1,"releasing the look finger stops its gesture")
 for destination:int in [1,0]:
  check(world.change_home_floor(app.state),"one-tap stair traversal starts "+str(destination))
  var clipped:=0;var roll:=0;var jumps:=0;var zooms:=0
  var old:Vector3=camera.position;var old_basis:Basis=camera.basis
  var turns:=0
  for i in range(2400):
   await frame()
   if absf(camera.basis.x.y)>.001:roll+=1
   if absf(camera.fov-88)>.001:zooms+=1
   if camera.position.distance_to(old)>actor.WALK_SPEED*dt+.11:jumps+=1
   if old_basis.get_rotation_quaternion().angle_to(camera.basis.get_rotation_quaternion())>rig.AUTO_SPEED*dt+.002:turns+=1
   var q:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.045;q.shape=sphere;q.transform.origin=camera.position;q.collision_mask=17;q.exclude=[actor.get_rid()]
   if not world.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():clipped+=1
   old=camera.position;old_basis=camera.basis
   if not actor.stair_active:break
  check(not actor.stair_active and app.state.home_floor==destination,"first-person stairs complete "+str(destination))
  check(clipped==0,"eye does not enter floor, roof or rails "+str(clipped))
  check(roll==0 and zooms==0,"stairs never roll or zoom the view")
  check(jumps==0 and turns==0,"stairs preserve bounded translation and slow turns")
 # Actual first-person fridge sequence keeps its transaction and view model.
 actor.position=Vector3(-1.15,.705,-3.82);actor.velocity=Vector3.ZERO
 for i in range(30):await frame()
 var drinks:int=app.state.home_drinks
 check(app.home_routine.open_fridge(),"fridge approach starts in first person")
 for i in range(1200):
  await frame()
  if app.home_routine.phase=="fridge":break
 check(app.home_routine.phase=="fridge" and app.home_routine.fridge.opened,"fridge visibly opens before taking")
 app.home_routine.take()
 for i in range(1200):
  await frame()
  if app.home_routine.phase=="fridge" and app.state.count("饮料")>0:break
 check(app.state.home_drinks==drinks-1 and app.state.count("饮料")==1,"taking commits exactly one bottle")
 app.home_routine.drink()
 var shown:=false
 var mouth_visible:=false
 for i in range(1800):
  await frame();shown=shown or rig.hands.bottle.visible
  if app.home_routine.phase=="drinking" and app.home_routine.elapsed>.8 and app.home_routine.elapsed<2:
   var mouth:Vector2=camera.unproject_position(rig.hands.bottle.to_global(Vector3(0,.2,0)))
   mouth_visible=mouth_visible or Rect2(Vector2.ZERO,size*Vector2(1,.9)).has_point(mouth)
  if not app.home_routine.fridge.opened and app.home_routine.phase=="" and app.state.count("空饮料瓶")==0:break
 check(shown,"drink animation shows the first-person bottle and hands")
 check(mouth_visible,"raised bottle mouth remains visibly inside the frame during the sip")
 check(not app.home_routine.fridge.opened,"fridge is closed after retreating")
 check(app.state.count("饮料")==0 and app.state.count("空饮料瓶")==0,"drink is consumed and its empty is disposed")
 # Real bed choreography: independent view, no roll, and looking around remains free.
 app.home_routine.cancel();app.state.home_floor=1;world.sync(app.state)
 actor.position=Vector3(-3,world.Villa.Dimensions.UPPER_FLOOR+.03,-1.45);actor.velocity=Vector3.ZERO
 for i in range(60):await frame()
 check(app.bed_session.begin(),"bed entry starts in first person")
 var invalid:=0
 for i in range(1800):
  await frame()
  if not camera.position.is_finite() or absf(camera.basis.x.y)>.001:invalid+=1
  if actor.bed_stage=="resting":break
 check(actor.bed_stage=="resting" and invalid==0,"lying down reaches a stable first-person rest without roll")
 for i in range(180):await frame()
 check(rig.pitch<deg_to_rad(-50),"lying down looks toward the real ceiling")
 rig.mouse_dragging=true;rig.gesture_drag(Vector2(40,90));await frame();rig.cancel_drag()
 var pitch:float=rig.pitch
 for i in range(180):await frame()
 check(absf(rig.pitch-pitch)<.001,"rest does not force the camera back after looking around")
 app.bed_session.finish()
 for i in range(1800):
  await frame()
  if actor.bed_stage=="":break
 check(actor.bed_stage=="","waking and dressing return control without switching camera type: %s at %s"%[actor.bed_stage,actor.position])
 for i in range(180):await frame()
 check(absf(camera.position.y-actor.position.y-1.85)<.03,"getting up restores standing eye height")
 check((camera.cull_mask&256)==0 and (camera.cull_mask&2)!=0,"all phases retain hidden self and real architecture")
 print("FIRST PERSON LIFE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
