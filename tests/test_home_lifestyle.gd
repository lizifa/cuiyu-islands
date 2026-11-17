extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n:int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func ready_fridge() -> void:
 for i in range(500):
  await frames(1)
  if app.home_routine.phase=="fridge":return
 check(false,"fridge action reaches a stable state")
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[3.4,.705,11];app.world.sync(app.state)
 await frames(4)
 var actor=app.world.player;var routine=app.home_routine
 check(is_equal_approx(app.world.Villa.Dimensions.BOUNDS.get_area(),19.6*12.2*2*1.3),"house expands horizontally another thirty percent")
 check(app.world.terrain_walkable(Vector3(0,.705,16)),"new living space is walkable")
 check(app.sofa_session.begin_dining(),"sit at actual dining chair")
 await frames(20)
 check(actor.sofa_seated and app.sofa_session.mode=="dining","chair session uses visible seated pose")
 var food:int=app.state.count("浆果");app.state.hunger=40
 app.sofa_session.begin_eating()
 check(app.state.count("浆果")==food,"food not consumed before first bite")
 await frames(55)
 check(app.state.count("浆果")==food-1 and app.state.hunger>60,"one food consumed by eating gesture")
 app.sofa_session.finish();check(not actor.sofa_seated,"can leave dining chair")
 actor.position=Vector3(-1.5,.705,-2.9);await frames(3)
 app.world.indoor_camera.retained_angle=PI/2
 var viewing_yaw:float=app.world.orbit.target_yaw
 check(routine.open_fridge(),"open fridge near kitchen")
 await ready_fridge()
 var fridge=app.world.villa_room.get_node("HomeFridge")
 print("FRIDGE angle ",fridge.angle," actual ",fridge.hinge.rotation.y)
 check(fridge.angle< -1 and fridge.hinge.rotation.y< -1,"fridge door opens physically")
 check(is_equal_approx(app.world.orbit.target_yaw,viewing_yaw),"fridge keeps the player chosen viewing side")
 var stock:int=app.state.home_drinks
 routine.take()
 for i in range(450):
  await frames(1)
  if routine.phase=="fridge" and not fridge.opened and app.state.count("饮料")>0:break
 print("TAKE state ",routine.phase," actor ",actor.position)
 check(app.state.home_drinks==stock-1 and app.state.count("饮料")==1,"one bottle moves from shelf to inventory")
 app.state.thirst=20
 routine.drink()
 for i in range(400):
  await frames(1)
  if routine.phase=="drinking":break
 await frames(15)
 var elapsed:float=routine.elapsed;app.paused=true;await frames(10)
 check(is_equal_approx(routine.elapsed,elapsed),"pause freezes drinking")
 app.paused=false
 var saw_empty:=false;var saw_walking:=false
 for i in range(1200):
  await frames(1)
  if app.state.count("空饮料瓶")>0:saw_empty=true
  if routine.phase=="to_bin":saw_walking=true
  if routine.phase=="":break
 print("DRINK state ",routine.phase," actor ",actor.position," bottles ",app.state.count("空饮料瓶"))
 check(app.state.count("饮料")==0 and app.state.thirst>40,"drink consumed once and thirst restored")
 check(saw_empty and saw_walking,"drink produces an empty bottle and starts real walk to bin")
 check(routine.phase=="" and app.state.count("空饮料瓶")==0,"bottle discarded only after reaching bin")
 check(actor.position.distance_to(Vector3(-6.4,.705,-2.5))<1.5,"character actually arrives at bin")
 # Cancellation keeps the resource, and profile replacement cannot leave the body locked.
 actor.position=Vector3(-1.5,.705,-2.9);app.state.inventory["饮料"]=1;await frames(3);routine.open_fridge();await ready_fridge();routine.drink();await frames(10);routine.cancel()
 check(app.state.count("饮料")==1 and not actor.home_busy,"cancel before finishing keeps drink and restores controls")
 routine.open_fridge();await ready_fridge();routine.drink()
 for i in range(450):
  await frames(1)
  if routine.phase=="to_bin":break
 app.joystick.direction=Vector2.RIGHT;await frames(3);app.joystick.reset()
 print("CANCEL_DRINK ",routine.phase," drinks ",app.state.count("饮料")," empties ",app.state.count("空饮料瓶"))
 check(routine.phase=="" and app.state.count("空饮料瓶")==1,"manual takeover keeps empty bottle until actual disposal")
 actor.position=Vector3(-6.4,.705,-2.5);await frames(3)
 check(routine.begin_discard(),"can discard retained bottle after walking to bin")
 await frames(30)
 check(app.state.count("空饮料瓶")==0,"one retained bottle discarded exactly once")
 actor.position=Vector3(-1.5,.705,-2.9);app.state.inventory["饮料"]=1;await frames(3)
 routine.open_fridge();await ready_fridge();routine.drink();await frames(5);app.state.profile.gender="female";app.world.sync(app.state);await frames(3)
 check(not actor.home_busy and routine.phase=="","changing character cancels gesture safely")
 var data:Dictionary=app.state.snapshot();var restored=load("res://scripts/life/life_state.gd").new()
 check(restored.restore(data) and restored.home_drinks==app.state.home_drinks,"fridge stock persists in save")
 data.erase("home_drinks");data.inventory.erase("饮料");data.inventory.erase("空饮料瓶")
 check(restored.restore(data) and restored.home_drinks==6 and restored.count("饮料")==0,"old saves gain household defaults")
 var isolated=load("res://scripts/life/life_state.gd").new();isolated.location="villa";isolated.inventory["木材"]=80;isolated.inventory["浆果"]=0
 check(not isolated.take_fridge_drink() and isolated.home_drinks==6,"full backpack cannot remove fridge stock")
 isolated.inventory["木材"]=0;isolated.home_drinks=0;isolated.coins=1
 check(not isolated.restock_drink() and isolated.coins==1,"restock never overdrafts coins")
 isolated.coins=2
 check(isolated.restock_drink() and isolated.home_drinks==1 and isolated.coins==0,"restock has explicit one-bottle cost")
 isolated.home_drinks=6;isolated.coins=10
 check(not isolated.restock_drink() and isolated.coins==10,"full fridge cannot charge for restock")
 var corrupt:Dictionary=isolated.snapshot();corrupt.home_drinks=7
 check(not restored.restore(corrupt),"out-of-range fridge stock is rejected")
 actor.position=Vector3(-1.5,.705,-2.9);app.state.inventory["饮料"]=1;routine.open_fridge();await ready_fridge();routine.drink();await frames(3)
 app.queue_free();await process_frame
 print("HOME LIFESTYLE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
