extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,message:String):
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func frames(count:int):
 for i in count:await process_frame
func run():
 var view=SubViewport.new();view.size=Vector2i(1280,592);view.own_world_3d=true;root.add_child(view)
 var app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false);app.set_physics_process(false)
 await frames(4)
 for viewport_size:Vector2i in [Vector2i(1280,592),Vector2i(1280,720),Vector2i(1024,768)]:
  view.size=viewport_size;await frames(3);app._open_arrival();await frames(3)
  var picker=app.arrival
  check(Rect2(Vector2.ZERO,Vector2(viewport_size)).encloses(picker.confirm_button.get_global_rect()),"confirmation remains visible "+str(viewport_size))
  check(picker.character_wheel.size.y>=144 and picker.pet_wheel.size.y>=144,"both wheels retain three touch rows "+str(viewport_size))
  var before=app.state.profile.duplicate(true)
  picker.character_wheel._scroll(5.2)
  check(picker.character_id==picker.character_wheel.values[5] and picker.preview.get_child(0).get_meta("character_id")==picker.character_id,"wheel position updates character and real 3D preview")
  check(app.state.profile==before,"scrolling does not write player save")
  picker.pet_wheel._scroll(5)
  check(picker.pet=="none" and not picker.pet_name_input.editable and picker.preview.get_child_count()==1,"solo center hides companion and disables name")
  picker.pet_wheel._scroll(3)
  check(picker.pet=="cloud" and picker.pet_name_input.editable and picker.preview.get_child_count()==2,"cloud center restores companion preview")
  picker.character_wheel.velocity=8
  check(picker.confirm(),"confirm current rolling selection")
  check(is_zero_approx(picker.character_wheel.velocity) and is_equal_approx(picker.character_wheel.scroll_position,5),"confirmation stops inertia at nearest center")
  check(app.state.profile.character_id==picker.character_wheel.values[5] and app.state.profile.pet=="cloud","saved character and companion match wheel centers")
  app._open_arrival()
  check(picker.character_wheel.get_value()==app.state.profile.character_id and picker.pet_wheel.get_value()=="cloud","reopening restores saved center positions")
  var confirmed=app.state.profile.duplicate(true)
  picker.character_wheel._scroll(11);picker.pet_wheel._scroll(4);app._close_drawers()
  check(app.state.profile==confirmed,"closing without save cancels changed centers")
 app.queue_free();view.queue_free();await process_frame
 print("ARRIVAL WHEELS: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
