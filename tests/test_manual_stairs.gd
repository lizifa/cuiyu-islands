extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frame() -> void:
 app.inactive=false;await physics_frame
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[9.25,.705,2.9];app.world.sync(app.state)
 var actor:CharacterBody3D=app.world.player;actor.stair_view_ready=Callable() # Physics/pose coverage; camera pacing is covered by test_stair_handoff.
 for i in range(4):await frame()
 check(not actor.manual_stair_entry.is_valid(),"joystick has no stair-entry callback")
 check(not app.world.try_manual_stairs(Vector3.FORWARD),"walking never starts assisted stairs")
 for i in range(60):
  var right:Vector3=app.world.camera.global_basis.x;right.y=0
  var forward:Vector3=-app.world.camera.global_basis.z;forward.y=0
  app.joystick.direction=Vector2(Vector3.FORWARD.dot(right.normalized()),-Vector3.FORWARD.dot(forward.normalized()));await frame()
 app.joystick.reset()
 check(not actor.stair_active and actor.position.y<.85 and actor.position.z>2.3,"physical entry gate prevents unassisted ramp climbing")
 actor.position=Vector3(6,.705,2);await frame()
 check(app.world.change_home_floor(app.state),"one-tap upstairs starts")
 app.joystick.direction=Vector2.LEFT
 var jump:float=0;var manual_takeover:=false
 for i in range(1500):
  if not actor.stair_active:break
  var before:Vector3=actor.position;await frame();jump=maxf(jump,before.distance_to(actor.position))
  manual_takeover=manual_takeover or actor.stair_manual
 app.joystick.reset()
 check(not manual_takeover,"stick cannot take over assisted traversal")
 check(app.state.home_floor==1 and not actor.stair_active,"assisted ascent completes despite held stick")
 check(jump<.2,"assisted traversal remains continuous")
 check(not app.world.change_home_floor(app.state,true),"legacy manual request is rejected")
 check(app.world.change_home_floor(app.state),"one-tap downstairs remains available")
 for i in range(1500):
  if not actor.stair_active:break
  await frame()
 check(app.state.home_floor==0 and not actor.stair_active,"assisted descent completes")
 check(actor.walking_shapes.size()<2 or not actor.walking_shapes[1].disabled,"foot collision restored")
 print("ASSISTED STAIRS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
