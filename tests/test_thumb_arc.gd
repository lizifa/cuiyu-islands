extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.own_world_3d=true;root.add_child(view)
 var app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false);app.set_physics_process(false);app.inactive=false;app.paused=false;app._close_drawers()
 app.world.player.set_physics_process(false);app.world._set_boating(true)
 for dimensions:Vector2i in [Vector2i(1560,720),Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,960)]:
  view.size=dimensions;app.test_safe_override=Vector4(50,8,24,12) if dimensions.x==960 else Vector4.ZERO
  for frame in range(4):await process_frame
  app._layout_mobile()
  for frame in range(4):await process_frame
  app._update_context()
  var controls:Array=[app.context_action,app.sprint_action,app.build_action,app.boat_stop_action,app.boat_home_action]
  var safe:Rect2=app.safe_root.get_global_rect()
  for i in range(controls.size()):
   var item:Control=controls[i]
   check(safe.encloses(item.get_global_rect()),"thumb action stays inside safe area "+str(dimensions)+" "+str(i))
   check(minf(item.size.x,item.size.y)>=48,"minimum mobile touch target")
   for j in range(i+1,controls.size()):check(not item.get_global_rect().grow(-2).intersects(controls[j].get_global_rect().grow(-2)),"separate action touch regions "+str(i)+" / "+str(j))
  var main:Vector2=app.context_action.get_global_rect().get_center()
  var sprint:Vector2=app.sprint_action.get_global_rect().get_center()
  var build:Vector2=app.build_action.get_global_rect().get_center()
  check(absf(main.x-sprint.x)<2 and sprint.y<main.y-100,"acceleration is above the main action")
  check(build.x<sprint.x-100 and absf(build.y-sprint.y)<2,"auxiliary is upper-left in the arc")
  check(safe.end.x-app.context_action.get_global_rect().end.x>=35 and safe.end.y-app.context_action.get_global_rect().end.y>=60,"main action has right and bottom breathing room")
 print("THUMB ARC: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
