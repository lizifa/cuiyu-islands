extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var state=load("res://scripts/life/life_state.gd").new();var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var actor:CharacterBody3D=world.player;actor.position=world.DOCK;world.board_boat(state);actor.allowed=true
 var origin:Vector3=actor.position
 for frame in range(60):
  var right:Vector3=world.camera.global_basis.x;var forward:Vector3=-world.camera.global_basis.z;right.y=0;forward.y=0
  actor.move_input=Vector2(Vector3.BACK.dot(right.normalized()),-Vector3.BACK.dot(forward.normalized()))
  await physics_frame
 check(actor.position.distance_to(origin)<.01 and not actor.rowing_pose.ready(),"boat stays still while seating and taking oars")
 for frame in range(180):
  var right:Vector3=world.camera.global_basis.x;var forward:Vector3=-world.camera.global_basis.z;right.y=0;forward.y=0
  actor.move_input=Vector2(Vector3.BACK.dot(right.normalized()),-Vector3.BACK.dot(forward.normalized()))
  await physics_frame
 check(actor.position.z>origin.z+3,"manual navigation starts once ready")
 check(actor.rowing_pose.strength>.9,"real boat movement drives rowing pose")
 actor.move_input=Vector2.ZERO
 for frame in range(40):await physics_frame
 check(actor.rowing_pose.strength<.01,"stopped boat returns to ready pose")
 check(world.return_pilot.start(),"automatic return remains available")
 var automatic_rows:=false
 for frame in range(1000):
  if not actor.boating:break
  actor.move_input=world.return_pilot.tick(1./60,Vector2.ZERO)
  await physics_frame
  if actor.rowing_pose!=null and actor.rowing_pose.strength>.5:automatic_rows=true
 check(automatic_rows,"automatic return also drives actual rowing")
 check(not actor.boating and actor.rowing_pose==null,"automatic docking restores walking pose")
 print("ROWING NAVIGATION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
