extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new()
 check(state.buildings.has("小船"),"new game has ready boat")
 check(not state.RECIPES.has("小船"),"no boat construction recipe")
 var saved:Dictionary=state.snapshot();saved.buildings.erase("小船");saved.inventory["木材"]=7;saved.inventory["纤维"]=3
 check(state.restore(saved) and state.buildings.has("小船"),"old unrepaired save receives ready boat")
 check(state.count("木材")==7 and state.count("纤维")==3,"migration does not charge materials")
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var wake:Node3D=world.boat_wake;wake.set_physics_process(false)
 check(world.find_interaction("boat").title=="上船","dock prompt offers boarding")
 world.player.position=world.DOCK
 check(world.board_boat(state),"fresh ready boat boards directly")
 world.player.set_physics_process(false)
 wake.tick(.1,Vector3(0,.05,23),true)
 for frame in range(60):wake.tick(1./30,Vector3(0,.05,23+frame*4./30),true)
 var regular:int=wake.emission_count
 check(regular>10,"movement emits visible wake instances")
 var old_center:Vector3=wake.particles[0].center
 for frame in range(30):wake.tick(1./30,Vector3(frame*4./30,.05,31),true)
 check(wake.particles[0].center.is_equal_approx(old_center),"turning preserves earlier world-space wake")
 wake.clear();wake.emission_count=0;wake.tick(.1,Vector3(0,.05,23),true)
 for frame in range(60):wake.tick(1./30,Vector3(0,.05,23+frame*7./30),true)
 check(wake.emission_count>regular,"acceleration produces denser wake")
 var before:int=wake.emission_count
 for frame in range(120):wake.tick(1./30,Vector3(0,.05,23+59*7./30),true)
 check(wake.emission_count==before,"stationary boat emits no wake")
 check(wake.particles.all(func(p):return p.age>=wake.LIFE),"old wake fades after stopping")
 check(wake.particles.size()==wake.LIMIT,"foam pool stays bounded")
 var count:int=wake.emission_count;wake.tick(.1,Vector3(50,.05,50),true)
 check(wake.emission_count==count,"teleport creates no foam bridge")
 wake.clear();wake.emission_count=0
 wake.tick(.1,Vector3(0,.05,25),true,0)
 for frame in range(12):wake.tick(1./30,Vector3((frame+1)*4./30,.05,25),true,0)
 check(wake.emission_count==0,"sideways movement during a hull turn does not spray a transverse wake")
 wake.clear();wake.tick(.1,Vector3(0,.05,25),true,0)
 var at:=Vector3(0,.05,25);var old_angle:=0.0;var maximum_jump:=0.0;var last_center:=Vector3.INF;var stern_error:=0.0
 for frame in range(90):
  var angle:float=frame*PI/90
  var direction:=Vector3(sin(angle),0,cos(angle))
  var previous_stern:Vector3=at-Vector3(sin(old_angle),0,cos(old_angle))*1.45
  at+=direction*4./30
  var stern:Vector3=at-direction*1.45
  var before_count:int=wake.emission_count
  wake.tick(1./30,at,true,angle)
  if wake.emission_count>before_count:
   var p:Dictionary=wake.particles[posmod(wake.next_slot-1,wake.LIMIT)]
   var nearest:Vector3=Geometry3D.get_closest_point_to_segment(p.center,previous_stern,stern)
   stern_error=maxf(stern_error,p.center.distance_to(nearest))
   if last_center.is_finite():maximum_jump=maxf(maximum_jump,last_center.distance_to(p.center))
   last_center=p.center
  old_angle=angle
 check(stern_error<.002,"curved wake originates on the actual stern path")
 check(maximum_jump<.65,"turning wake is sampled continuously without jumping")
 var prior:int=wake.emission_count
 for frame in range(60):wake.tick(1./30,at,true,old_angle+frame*.04)
 check(wake.emission_count==prior,"turning a stationary boat creates no foam ring")
 wake.clear();wake.emission_count=0;wake.tick(.1,Vector3(0,.05,25),true,0)
 var doubled:=false;var off_center:=false;var too_wide:=false;var too_short:=false
 for frame in range(90):
  var count_before:int=wake.emission_count
  wake.tick(1./30,Vector3(0,.05,25+(frame+1)*4./30),true,0)
  if wake.emission_count-count_before>1:doubled=true
  for slot in range(wake.LIMIT):
   if wake.particles[slot].age>=wake.LIFE:continue
   var transform:Transform3D=wake._foam_transform(wake.particles[slot])
   if absf(transform.origin.x)>.01:off_center=true
   if transform.basis.get_scale().x>.75:
    too_wide=true
   if transform.basis.get_scale().z<transform.basis.get_scale().x*4:
    too_short=true
 check(not doubled,"one wake sample per travelled interval")
 check(not off_center,"wake stays on stern centreline without twin side trails")
 check(not too_wide and not too_short,"wake remains a narrow elongated blade")
 var cruising:Transform3D=wake._foam_transform({"center":Vector3.ZERO,"forward":Vector3.BACK,"speed":4.0})
 check(cruising.basis.get_scale().x>.5 and cruising.basis.get_scale().z>2.7,"single wake is enlarged at cruising speed")
 print("READY BOAT WAKE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
