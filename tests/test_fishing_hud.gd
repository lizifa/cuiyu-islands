extends SceneTree
var app: Node
var view: SubViewport
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(count: int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func touch(control: Control,down: bool) -> void:
 app._update_context()
 var event := InputEventScreenTouch.new();event.position=control.get_global_rect().get_center();event.index=0;event.pressed=down
 view.push_input(event,true)
func set_stage(value: String) -> void:
 app.fishing_session._set_stage(value);app.fishing_session._update_visual();app._update_context()
func _initialize():call_deferred("run")
func run():
 view=SubViewport.new();view.size=Vector2i(1280,720);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false)
 await frames(3)
 var session: Node=app.fishing_session
 var actor: CharacterBody3D=app.world.player
 var preferences: Dictionary=app.layout_editor.saved.duplicate(true)
 actor.position=Vector3(-1,.68,15.7)
 check(session.begin(),"begin fishing HUD fixture")
 session.set_physics_process(false);session.fish_roll=.99
 for i in range(600):session._update_visual(1./60);app.world.orbit.motion_enabled=true;app.world.orbit._process(1./60)
 session.sync_controls()
 check(session.stage=="ready" and app.context_action.title=="甩竿","entering station offers an explicit cast action")
 app.state.inventory["饵料"]=2
 touch(app.sprint_action,true);touch(app.sprint_action,false)
 check(session.stage=="chumming" and session.bait_return_stage=="ready","bait can be thrown before casting")
 session.chummed=false;set_stage("ready")
 touch(app.context_action,true)
 check(session.stage=="charging","native primary press starts cast charging")
 touch(app.context_action,false)
 check(session.panel.find_children("*","Button",true,false).is_empty(),"status HUD contains no duplicate action buttons")
 check(not app.goal_button.visible and app.task_menu_button!=null,"fishing removes unrelated task and boat cards")
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
  view.size=dimensions;app.test_safe_override=Vector4(50,8,50,28)
  await frames(3);app._layout_mobile();await frames(3)
  var safe: Rect2=app.safe_root.get_global_rect()
  for phase: String in ["waiting","bite","reeling","net_ready","landing","storing","result"]:
   session.tension=.4;session.progress=.4;set_stage(phase)
   app.world._process(2);app.world.orbit._process(2);await frames(3)
   session._layout_hud()
   var rect: Rect2=session.panel.get_global_rect()
   check(safe.encloses(rect),"compact HUD respects safe area %s %s"%[dimensions,phase])
   check(rect.size.y<=96 and rect.end.y<safe.position.y+200,"HUD remains compact at top %s %s"%[dimensions,phase])
   var head: Vector2=app.world.camera.unproject_position(actor.position+Vector3.UP*2.4)
   var feet: Vector2=app.world.camera.unproject_position(actor.position)
   var body := Rect2(Vector2(minf(head.x,feet.x)-40,minf(head.y,feet.y)),Vector2(absf(head.x-feet.x)+80,absf(head.y-feet.y)))
   check(not rect.intersects(body),"recommended fishing camera keeps character clear of HUD %s %s"%[dimensions,phase])
   for row: HBoxContainer in [session.progress_row,session.tension_row]:
    var caption: Label=row.get_child(0)
    check(caption.autowrap_mode==TextServer.AUTOWRAP_OFF and caption.size.x>=40,"meter caption stays horizontal")
   if session.float_hint.visible:
    check(safe.encloses(session.float_hint.get_global_rect()) and not session.float_hint.get_global_rect().intersects(body),"float prompt stays clear of player and safe area")
  set_stage("waiting");await frames(2)
  check(not session.progress_row.visible and not session.tension_row.visible and session.panel.size.y<=40,"waiting only shows one short line")
  check(app._camera_can_drag(session.panel.get_global_rect().get_center()),"informational fishing HUD does not block orbit gesture")
 set_stage("waiting");app.state.inventory["浆果"]=1;app.state.inventory["饵料"]=0;session.chummed=false;session.sync_controls()
 check(app.context_action.title=="等待" and not app.context_action.active,"waiting disables premature primary input")
 check(app.sprint_action.title=="制饵" and app.build_action.title=="收竿离开","auxiliary controls are repurposed without moving group")
 touch(app.sprint_action,true);touch(app.sprint_action,false)
 check(app.state.count("饵料")==3 and not app.sprinting,"native auxiliary touch crafts bait instead of sprinting")
 check(app.sprint_action.badge=="3" and app.sprint_action.title=="撒饵","bait count appears in compact badge")
 touch(app.sprint_action,true);touch(app.sprint_action,false)
 check(session.stage=="chumming" and app.state.count("饵料")==2,"same native auxiliary touch throws one bait")
 set_stage("bite");touch(app.context_action,true);touch(app.context_action,false)
 check(session.stage=="hooking","single primary control strikes when fish bites")
 set_stage("reeling");touch(app.context_action,true);await frames(2)
 check(app.context_action.held,"primary native long-press owns reeling")
 check(app.sprint_action.title=="卸力" and app.sprint_action.active,"reeling exposes an unload-tension auxiliary action")
 session.auxiliary();check(not app.context_action.held and not session.held,"unload action releases reeling input")
 touch(app.context_action,false)
 check(not app.context_action.held,"release unloads tension input")
 app.paused=true;app._sync_overlay_state();session._layout_hud()
 check(not session.panel.visible and not session.float_hint.visible,"pause hides fishing HUD and floating prompt")
 app.paused=false;app._sync_overlay_state();set_stage("waiting")
 touch(app.build_action,true);touch(app.build_action,false)
 check(not session.active and not app.action_drawer.visible,"native exit touch leaves fishing instead of opening crafting")
 check(app.build_action.title=="建造" and app.sprint_action.title=="奔跑" and app.sprint_action.badge.is_empty(),"normal control labels and badge restore")
 check(not app.goal_button.visible and app.task_entries.get_node_or_null("EmbarkBoat")!=null,"boat entry stays in task list while idle tracker is collapsed")
 check(app.layout_editor.saved==preferences,"temporary fishing controls never mutate saved layout")
 app.queue_free();view.queue_free();await process_frame
 print("FISHING HUD: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
