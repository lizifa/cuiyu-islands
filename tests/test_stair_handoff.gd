extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frame() -> void:
 app.inactive=false;await physics_frame;await process_frame
 var dt:float=minf(app.get_process_delta_time(),.05)
 app.world._process(dt);app.world.orbit._process(dt)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=1;Engine.physics_ticks_per_second=120
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false)
 app.world.set_process(false);app.world.orbit.set_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[6,.705,2];app.world.sync(app.state)
 for i in range(30):await frame() # Finish the location-entry fade before testing stair cuts.
 var world:Node3D=app.world;var actor:CharacterBody3D=world.player;var camera:Camera3D=world.camera
 for destination:int in [1,0]:
  check(world.change_home_floor(app.state),"start traversal to floor "+str(destination))
  var prior_basis:Basis=camera.basis
  var prior_fov:float=camera.fov
  var max_turn:float=0
  var max_lens:float=0
  var missing:int=0
  var cuts:int=0
  var occluded:int=0
  for i in range(1800):
   await frame()
   max_turn=maxf(max_turn,prior_basis.get_rotation_quaternion().angle_to(camera.basis.get_rotation_quaternion()))
   max_lens=maxf(max_lens,absf(prior_fov-camera.fov))
   if not camera.is_position_in_frustum(actor.position+Vector3.UP*1.8):
    if missing<3:print("OFFSCREEN ",destination," actor ",actor.position," camera ",camera.position," forward ",-camera.basis.z)
    missing+=1
   if is_instance_valid(world.orbit.cut_overlay) and world.orbit.cut_overlay.modulate.a>.05:cuts+=1
   var all_blocked:bool=true
   for height:float in [.8,1.5,2.2]:
    for side:float in [-.3,0.,.3]:
     var sight:=PhysicsRayQueryParameters3D.create(camera.position,actor.position+Vector3.UP*height+camera.basis.x*side,17,[actor.get_rid()])
     if world.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():all_blocked=false
   if all_blocked:
    if occluded<3:print("BLOCKED ",destination," actor ",actor.position," camera ",camera.position)
    occluded+=1
   prior_basis=camera.basis;prior_fov=camera.fov
   if not actor.stair_active:break
  if world.orbit.comfort_mode:
   check(max_turn<deg_to_rad(30)*.05+.001,"entire stair traversal stays within the angular speed budget "+str(max_turn))
   check(max_lens<.001,"stair traversal never changes lens")
   check(missing==0,"actor remains in frame on every stair frame: "+str(missing))
   check(cuts==0,"stairs never invoke fade-covered cuts")
   check(occluded==0,"head or torso stays visible through the actual solid architecture: "+str(occluded))
  check(not actor.stair_active and app.state.home_floor==destination,"reach destination floor")
  check(world.indoor_camera.stair_weight<.02 if world.orbit.comfort_mode else world.indoor_camera.stair_weight>.98,"arrival retains the continuous room rig or optional cinematic follow")
  # All walls, floors and ceilings are rendered and remain physical.
  var visual_excludes:Array[RID]=[actor.get_rid()]
  for body:CollisionObject3D in world.props.find_children("*","CollisionObject3D",true,false):
   if not body.is_visible_in_tree():visual_excludes.append(body.get_rid())
  var clipped:=0;var hidden:=0;var maximum_step:float=0;var old:Vector3=camera.position
  # Observe the settled room after the deliberate fade-covered floor cut.
  for i in range(220 if world.orbit.comfort_mode else 100):
   await frame()
   var fade_covered:bool=is_instance_valid(world.orbit.cut_overlay) and world.orbit.cut_overlay.modulate.a>=.05
   if not fade_covered:maximum_step=maxf(maximum_step,old.distance_to(camera.position))
   old=camera.position
   var size:Vector2=camera.get_viewport().get_visible_rect().size
   var h:float=camera.near*tan(deg_to_rad(camera.fov)*.5);var w:float=h*size.x/maxf(1,size.y)
   for local:Vector3 in [Vector3.ZERO,Vector3(-w,-h,-camera.near),Vector3(-w,h,-camera.near),Vector3(w,-h,-camera.near),Vector3(w,h,-camera.near)]:
    var q:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.008;q.shape=sphere;q.transform.origin=camera.to_global(local);q.collision_mask=17;q.exclude=[actor.get_rid()]
    if not world.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():clipped+=1
   var focus:Vector3=actor.position+Vector3.UP*1.8
   var body_visible:=false
   for height:float in [1.2,1.8,2.2]:
    for side:float in [-.3,0.,.3]:
     var target:Vector3=actor.position+Vector3.UP*height+camera.basis.x*side
     var ray:=PhysicsRayQueryParameters3D.create(camera.position,target,17,visual_excludes)
     if camera.is_position_in_frustum(target) and world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():body_visible=true
   var visible_view:bool=not is_instance_valid(world.orbit.cut_overlay) or world.orbit.cut_overlay.modulate.a<.05
   if visible_view and not body_visible:hidden+=1
  check(clipped==0,"near-plane corners never enter white walls or ceilings "+str(destination))
  print("HANDOFF POSE ",destination," camera ",camera.position," actor ",actor.position," focus ",world.orbit.focus)
  check(hidden==0,"player remains visible across handoff "+str(destination)+" hidden "+str(hidden))
  check(maximum_step<.45,"handoff camera remains continuous "+str(maximum_step))
  check(world.indoor_camera.stair_weight<.02,"arrival blends back to room framing")
 print("STAIR HANDOFF: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
