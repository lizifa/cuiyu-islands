extends SceneTree
var app: Node
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n: int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func finish() -> void:
 for i in range(600):
  if not app.interaction_director.active:return
  await frames(1)
 check(false,"approach/action did not finish")
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=8;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 await frames(3)
 var world: Node3D=app.world
 var actor: CharacterBody3D=world.player
 var director: Node=app.interaction_director
 check(world.interaction_points.all(func(p):return is_instance_valid(p.get("anchor"))),"all static interactions own stand and view anchors")
 var tree: Dictionary=world.interaction_points.filter(func(p):return p.kind=="伐木" and p.pos.distance_to(Vector3(-5,.675,-2))<.2)[0]
 check(tree.anchor.get_parent()==tree.owner and tree.anchor.facing!=null and tree.anchor.camera_hint!=null,"tree prefab owns stand, facing and camera markers")
 var fishing: Dictionary=world.find_interaction("shore_fish")
 check(fishing.anchor.get_parent().name=="ShoreFishingPlatform","fishing markers belong to platform prefab")
 actor.position=Vector3(-5,.705,0);actor.velocity=Vector3.ZERO;actor.visual.rotation.y=0
 var yaw: float=world.orbit.target_yaw
 world.show_interaction(tree)
 check(actor.visual.rotation.y==0 and world.orbit.target_yaw==yaw,"proximity hint never forces character or camera orientation")
 app._nearby_interact()
 check(director.active and app.state.count("木材")==0,"click starts physical approach without immediate reward")
 world.orbit.rotate_drag(Vector2(90,0));var manual_yaw: float=world.orbit.target_yaw
 var face_samples := 0
 for i in range(600):
  if not director.active:break
  await frames(1)
  if director.stage=="facing":face_samples+=1
 check(not director.active and app.state.count("木材")==4,"approach turn and real work award one harvest")
 check(face_samples>=2,"large facing change takes multiple physics frames")
 var direction: Vector3=tree.pos-actor.position;direction.y=0
 check(absf(angle_difference(actor.visual.rotation.y,atan2(direction.x,direction.z)))<.05,"character finishes facing the actual tree")
 check(world.orbit.target_yaw==manual_yaw,"manual camera takeover survives later automatic facing")
 await frames(15)
 check(app.state.count("木材")==4,"finished interaction cannot duplicate harvest")
 actor.position=Vector3(-5,.705,0);actor.velocity=Vector3.ZERO;actor.visual.rotation.y=0
 check(director.request(tree,func():app._act(app.state.labor.bind("伐木"))),"second tree approach can begin")
 app.joystick.direction=Vector2.RIGHT;await frames(2);app.joystick.reset()
 check(not director.active and app.state.count("木材")==4 and not actor.working,"joystick cancels pending action before reward")
 actor.position=Vector3(-5,.705,0);actor.velocity=Vector3.ZERO;actor.visual.rotation.y=0
 director.request(tree,func():app._act(app.state.labor.bind("伐木")))
 for i in range(300):
  if director.stage=="perform":break
  await frames(1)
 check(director.stage=="perform" and actor.working,"manual interaction plays existing work pose")
 var paused_elapsed: float=actor.work_elapsed
 var paused_position: Vector3=actor.position
 app.paused=true;await frames(10)
 check(director.active and actor.work_elapsed==paused_elapsed and actor.position==paused_position and app.state.count("木材")==4,"pause freezes approach action without reward")
 app.paused=false
 app.joystick.direction=Vector2.RIGHT;await frames(2);app.joystick.reset()
 check(not director.active and not actor.working and app.state.count("木材")==4,"cancelling work clears pose and does not charge labor")
 var blocker := StaticBody3D.new();var collider := CollisionShape3D.new();var box := BoxShape3D.new()
 box.size=Vector3(2.5,2,2);collider.shape=box;blocker.add_child(collider);world.add_child(blocker);blocker.position=Vector3(-1,1.7,15.55)
 actor.position=Vector3(3,.7,15.1);await frames(2)
 check(not director.request(fishing,func():app._act(app.fishing_session.begin)) and not app.fishing_session.active,"blocked anchor rejects interaction instead of teleporting through object")
 blocker.free();await frames(2)
 actor.position=Vector3(-1,.68,15.0);actor.velocity=Vector3.ZERO;actor.move_input=Vector2.ZERO
 check(director.request(fishing,func():app._act(app.fishing_session.begin)),"clear fishing approach starts")
 await finish()
 check(app.fishing_session.active,"fishing begins after approach and turn")
 check(absf(angle_difference(actor.visual.rotation.y,0))<.05,"fisher faces open sea before cast")
 world.orbit.rotate_drag(Vector2(100,0))
 var chosen_yaw: float=world.orbit.target_yaw
 var chosen_pitch: float=world.orbit.target_pitch
 var chosen_distance: float=world.orbit.target_distance
 app.fishing_session._set_stage("reeling")
 check(world.orbit.target_yaw==chosen_yaw and world.orbit.target_pitch==chosen_pitch and world.orbit.target_distance==chosen_distance,"reeling does not override manual camera")
 app.fishing_session.cancel()
 check(world.orbit.target_yaw==chosen_yaw,"ending fishing does not undo manual view")
 actor.position=Vector3(-5,.705,0);actor.velocity=Vector3.ZERO
 director.request(tree,func():app._act(app.state.labor.bind("伐木")))
 check(director.active and app._reset_game() and not director.active,"reset cancels pending interaction immediately")
 await frames(12)
 check(app.state.count("木材")==0,"old callback cannot award resources after reset")
 app.queue_free();await process_frame
 print("INTERACTION ANCHORS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
