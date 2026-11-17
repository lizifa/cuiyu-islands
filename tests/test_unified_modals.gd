extends SceneTree
var passed:=0
var failed:=0
var app:Node
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func frames(n:int=3)->void:
 for i in range(n):await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false);app.set_physics_process(false);app.inactive=false;app.paused=false;app._close_drawers()
 app.world.player.set_physics_process(false)
 for dimensions:Vector2i in [Vector2i(1560,720),Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,960)]:
  view.size=dimensions;await frames();app.test_safe_override=Vector4(50,8,24,12) if dimensions.x==960 else Vector4.ZERO;app._layout_mobile();await frames()
  var expected:Vector2=app.modal_size()
  var panels:Array=[app.info_drawer,app.action_drawer,app.menu_drawer,app.task_drawer,app.map_drawer,app.layout_editor.settings,app.confirmation.window]
  # Show one at a time so container minimums participate in actual layout.
  for panel:Control in panels:
   panel.show();await frames();app.layout_modal(panel);await frames()
   if panel.size.distance_to(expected)>=2:print("SIZE ",dimensions," ",panel.name," actual ",panel.size," expected ",expected," min ",panel.get_combined_minimum_size())
   check(panel.size.distance_to(expected)<2,"same modal size "+str(dimensions)+" "+str(panel.name))
   check(app.safe_root.get_global_rect().encloses(panel.get_global_rect()),"modal remains in safe area "+str(panel.name))
   var close:Button=panel.find_child("ModalClose",true,false)
   check(close!=null and close.custom_minimum_size.x>=48,"top close icon has touch target "+str(panel.name))
   if close!=null:check(close.get_global_rect().position.y<panel.global_position.y+100,"close stays in header "+str(panel.name))
   panel.hide()
 app._open_settings();await frames()
 var settings:Control=app.layout_editor.settings
 check(not app.movement_enabled(),"settings blocks movement")
 settings.find_child("ModalClose",true,false).pressed.emit();await frames()
 check(not app.layout_editor.visible and app.movement_enabled(),"settings top close restores play")
 app._toggle_inventory();await frames();app.info_drawer.find_child("ModalClose",true,false).pressed.emit()
 check(not app.info_drawer.visible,"inventory closes from top")
 app._open_tasks();await frames();app.task_drawer.find_child("ModalClose",true,false).pressed.emit()
 check(not app.task_drawer.visible,"tasks close from top")
 var coins:int=app.state.coins;app._confirm_reset_game();await frames()
 app.confirmation.get_cancel_button().pressed.emit()
 check(not app.confirmation.visible and app.state.coins==coins,"top close cancels reset without mutation")
 check(app.confirmation.get_ok_button().text=="确认重置","destructive confirmation action remains explicit")
 app._show_help("测试帮助","说明\n".repeat(80));await frames()
 var help:Control=app.safe_root.get_children().back()
 check(help.get_script().resource_path.ends_with("game_dialog.gd") and help.visible,"help uses common in-canvas modal")
 check(not help.get_ok_button().visible,"help has no duplicate footer close button")
 check(not app._camera_can_drag(Vector2(500,200)),"help blocks camera dragging")
 help.get_cancel_button().pressed.emit();await frames()
 check(not app.paused and app.movement_enabled(),"help close restores prior pause state")
 app._show_credits();await frames()
 var credits:Control=app.safe_root.get_children().back()
 check(credits.window.size.distance_to(app.modal_size())<2 and not credits.get_ok_button().visible,"credits use common dimensions without footer dismissal")
 credits.get_cancel_button().pressed.emit();await frames()
 app._confirm_reset_game();await frames()
 var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 view.push_input(escape);await frames()
 check(not app.confirmation.visible and app.state.coins==coins,"Escape dismisses confirmation without executing reset")
 var extra:=0
 for b:Node in app.safe_root.find_children("*","Button",true,false):
  if b.text in ["关闭设置","关闭背包","关闭","收起","返回 · 保留当前选择"]:extra+=1
 check(extra==0,"no duplicate text close buttons remain")
 print("UNIFIED MODALS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
