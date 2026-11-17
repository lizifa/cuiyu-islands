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
 app.world.player.set_physics_process(false);app.state.energy=0;app.state.hunger=90;app.state.thirst=90
 app.world.sync(app.state);app._refresh()
 check(app.task_entries.get_node_or_null("EmbarkBoat")!=null,"tasks offer embark without separate boat HUD")
 var inventory:Dictionary=app.state.inventory.duplicate();var minute:float=app.state.minute
 app.world.player.position=app.world.DOCK
 app._open_boat_status()
 for frame in range(240):
  if app.world.player.boating:break
  app.inactive=false;app.interaction_director.tick(1./60,Vector2.ZERO);await physics_frame
 check(app.world.player.boating,"zero energy can board a ready boat without repair")
 check(not app.confirmation.visible,"no repair confirmation")
 check(app.state.inventory==inventory and app.state.minute==minute,"boarding does not consume materials or rest time")
 app.world.disembark_boat();app.world.player.position=app.world.DOCK;app.state.hunger=10
 app._open_boat_status()
 check(app.confirmation.visible and not app.world.player.boating,"food safety still explains departure restriction")
 check(not "修船" in app.confirmation.dialog_text,"safety prompt never requests repair")
 print("BOAT ACCESS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
