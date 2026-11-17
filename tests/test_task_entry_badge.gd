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
 app.world.player.set_physics_process(false);app._refresh()
 check(app.task_red_dot.visible,"unfinished tasks show red dot")
 check(app.task_red_dot.mouse_filter==Control.MOUSE_FILTER_IGNORE,"red dot cannot intercept task button")
 var count:=0
 for child:Node in app.safe_root.get_children():
  if child is Button and ("上船" in child.text or "我的船" in child.text):count+=1
 check(count==0,"no separate boat access card outside task list")
 app.task_menu_button.pressed.emit()
 check(app.task_drawer.visible and app.task_entries.get_node_or_null("EmbarkBoat")!=null,"task menu contains boat entry")
 app._close_drawers();app.world.player.position=app.world.DOCK
 app.task_entries.get_node("EmbarkBoat").pressed.emit()
 for frame in range(3):
  if app.world.player.boating:break
  app.auto_task.tick(1./60,Vector2.ZERO)
 check(app.world.player.boating,"boat task still boards at dock")
 app.world.player.velocity=Vector3.ZERO;app.world.disembark_boat()
 for building:String in ["篝火","木屋"]:app.state.buildings[building]=true
 for id:String in app.state.DAILY_TARGETS:app.state.daily.counts[id]=app.state.DAILY_TARGETS[id]
 for quest:Dictionary in app.state.QUESTS:app.state.claimed[quest.id]=true
 app._update_task_status()
 check(not app.task_red_dot.visible,"completed tasks clear red dot despite optional sailing being available")
 check(app.task_entries.get_node_or_null("EmbarkBoat")!=null,"optional boat action remains accessible without red dot")
 app.state.claimed.erase("fire");app._update_task_status()
 check(app.task_red_dot.visible and app.task_entries.get_node_or_null("ClaimMilestone")!=null,"claimable reward has matching red dot and action")
 app.task_entries.get_node("ClaimMilestone").pressed.emit();app._update_task_status()
 check(not app.task_red_dot.visible,"claiming final reward clears red dot")
 app.state.minute+=1440;app._update_task_status()
 check(app.task_red_dot.visible,"new daily tasks restore red dot")
 print("TASK ENTRY BADGE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
