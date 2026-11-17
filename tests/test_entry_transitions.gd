extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.set_physics_process(false);app._close_drawers();app.inactive=false;app.paused=false
 await physics_frame;await physics_frame
 var world:Node3D=app.world;var actor:CharacterBody3D=world.player;var director:Node=app.interaction_director
 actor.set_physics_process(false);world.orbit.set_process(false)
 for pos:Vector3 in [Vector3(11,1.4,1),Vector3(10.5,1.4,1.3),Vector3(11.7,1.4,1.5)]:
  actor.position=pos;actor.velocity=Vector3.ZERO;actor.visual.rotation.y=.7
  var origin:Vector3=actor.position;var calls:Array=[]
  var point:Dictionary=world.find_interaction("villa_entry")
  check(director.request(point,func():calls.append(actor.position)),"entry can be requested close to threshold")
  check(calls.size()==1 and actor.position==origin and not director.active,"door entry does not backtrack to outside anchor")
  director.tick(.1,Vector2.ZERO);check(calls.size()==1,"entry executes only once")
 actor.position=Vector3(11,1.4,1);actor.visual.rotation.y=.7
 director.request(world.find_interaction("villa_entry"),func():world.enter_villa(app.state))
 check(app.state.location=="villa" and absf(angle_difference(actor.visual.rotation.y,PI))<.01,"entering home preserves inward heading")
 check(actor.move_input==Vector2.ZERO and actor.velocity==Vector3.ZERO,"door entry clears old movement")
 world.leave_villa(app.state);await physics_frame;await physics_frame
 actor.position=Vector3(11,1.4,3.5);actor.velocity=Vector3.ZERO
 var calls:Array=[]
 check(director.request(world.find_interaction("villa_entry"),func():calls.append(actor.position)),"farther entry uses physical approach")
 check(director.active and calls.is_empty(),"no long distance teleport")
 if not director.path.is_empty():
  var toward:Vector3=world.Villa.ENTRY-actor.position
  check((director.path[0]-actor.position).dot(toward)>=-.001,"initial waypoint does not send character backwards")
 actor.position=Vector3(11,1.4,1.4);var at:Vector3=actor.position
 check(director.tick(.016,Vector2.ZERO)==Vector2.ZERO and calls.size()==1 and actor.position==at,"approach completes as soon as door area is reached")
 for pos:Vector3 in [world.DOCK,world.DOCK+Vector3(0,0,-1),world.DOCK+Vector3(-.5,0,0)]:
  actor.position=pos;actor.velocity=Vector3.ZERO;actor.visual.rotation.y=.6
  var origin:Vector3=actor.position;var boarded:Array=[]
  check(director.request(world.find_interaction("boat"),func():boarded.append(actor.position)),"nearby boat can be requested")
  check(boarded.size()==1 and actor.position==origin and not director.active,"boarding does not walk back to dock anchor")
 actor.position=Vector3(11,1.4,1.1);actor.velocity=Vector3.ZERO
 app.auto_task.running=true;app.auto_task.job="villa";app.auto_task.stage="walk";app.auto_task.point=world.find_interaction("villa_entry")
 app.auto_task.path.assign([world.Villa.OUTSIDE_SPAWN])
 check(app.auto_task.tick(1./60,Vector2.ZERO)==Vector2.ZERO and app.state.location=="villa","automatic home arrival also stops inside doorway area")
 world.leave_villa(app.state);await physics_frame;await physics_frame
 actor.position=world.DOCK+Vector3(0,0,-.5);actor.visual.rotation.y=.6;actor.velocity=Vector3.ZERO
 app.auto_task.running=true;app.auto_task.job="embark";app.auto_task.stage="walk";app.auto_task.point=world.find_interaction("boat");app.auto_task.path.assign([world.DOCK])
 check(app.auto_task.tick(1./60,Vector2.ZERO)==Vector2.ZERO and actor.boating,"automatic boarding completes in dock area")
 check(absf(angle_difference(actor.visual.rotation.y,.6))<.01,"automatic boarding does not add a face-dock turn")
 actor.velocity=Vector3.ZERO;world.disembark_boat()
 actor.position=world.DOCK;actor.visual.rotation.y=.6
 check(director.request(world.find_interaction("boat"),func():world.board_boat(app.state)),"actual boat entry request")
 check(actor.boating and absf(angle_difference(actor.visual.rotation.y,.6))<.01,"boarding preserves starting heading")
 var previous:float=actor.visual.rotation.y;var total:=0.0;var maximum:=0.0
 for frame in range(130):
  actor.rowing_pose.tick(1./60,0)
  var turn:float=absf(angle_difference(previous,actor.visual.rotation.y));maximum=maxf(maximum,turn);total+=turn;previous=actor.visual.rotation.y
 check(actor.rowing_pose.ready() and absf(angle_difference(actor.visual.rotation.y,actor.boat_heading+PI))<.01,"seating ends in correct rowing orientation")
 check(total<=PI+.01 and maximum<.12,"seating turns by shortest arc without full spin or snap")
 check(director.path.is_empty() and not director.active,"no residual approach after boarding")
 print("ENTRY TRANSITIONS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
