extends SceneTree
var passed:=0
var failed:=0
var app:Node
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n:int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func _initialize():
 if "--test-mode" not in OS.get_cmdline_user_args():quit(1);return
 call_deferred("run")
func run():
 var view:=SubViewport.new();view.size=Vector2i(1280,592);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false)
 await frames(4)
 for size:Vector2i in [Vector2i(1280,592),Vector2i(1280,720),Vector2i(1024,768)]:
  view.size=size;await frames(3);app._open_arrival();await frames(3)
  var picker:Control=app.arrival
  var screen:=Rect2(Vector2.ZERO,Vector2(size))
  check(screen.encloses(picker.confirm_button.get_global_rect()),"confirmation always visible "+str(size))
  check(picker.character_wheel.values.size()==12 and picker.pet_wheel.values.size()==6,"complete wheel choices")
  picker.pet_wheel.set_value("none",true)
  check(picker.pet=="none" and not picker.pet_name_input.editable,"no-pet card disables partner name")
  picker.pet_wheel.set_value("dog",true);picker.character_wheel.set_value("skater_heart",true)
  check(picker.pet=="dog" and picker.character_id=="skater_heart" and picker.character_wheel.get_value()=="skater_heart","selection updates model and highlight")
  app._close_drawers()
 app._open_settings()
 check(app.layout_editor.settings.find_children("*","Button",true,false).all(func(button):return button.text!="自定义布局"),"custom layout entry removed")
 app._close_drawers()
 check(app.world.terrain_walkable(Vector3(1.3,.65,10)) and is_equal_approx(app.world.terrain_height(1.3,10),.65),"wider pier supports walking")
 check(app.world.terrain_walkable(Vector3(-2.45,.65,15)) and is_equal_approx(app.world.terrain_height(-2.45,15),.65),"expanded fishing deck supports walking")
 app.world.player.position=app.world.DOCK;await frames(8)
 check(Vector2(app.world.player.position.x-app.world.DOCK.x,app.world.player.position.z-app.world.DOCK.z).length()<.1,"rail leaves docking stance unobstructed")
 app.world.player.position=Vector3(-1,.68,16.1);await frames(3)
 check(app.fishing_session.begin(),"fishing begins on expanded platform")
 var session:Node=app.fishing_session;session.stage="reeling";session.elapsed=.6;session.progress=.3;session.big_fish=true
 session.tension=.15
 for i in range(80):session._update_visual(1.0/60)
 var low:float=session.rod_segments[7].position.z
 session.tension=.9
 for i in range(80):session._update_visual(1.0/60)
 check(session.rod_segments[7].position.z>low+.25,"high tension visibly bends the blank")
 # 段间留搭接量藏接缝，可见杆长 = 段高 + 7 个步进，弯杆时不伸长。
 var h:float=session.rod_segments[0].mesh.height
 var span:float=h+7*.33
 check(absf(span-2.755)<.02,"rod bends without stretching its length")
 var tip:Vector3=session.rod_segments[7].to_global(Vector3(0,h*.5,0))
 check(tip.distance_to(session.rod.position+session.rod.global_basis.y*span)>.6,"tip visibly departs from straight axis")
 session.cancel();app.world.player.position=Vector3(0,.7,3.2);await frames(4)
 for kind:String in ["dog","cat","rabbit"]:
  app.state.profile.pet=kind;app.world.sync(app.state);await frames(3)
  var pet:CharacterBody3D=app.world.companion;pet.set_physics_process(false)
  var rig:Skeleton3D=pet.visual.find_children("*","Skeleton3D",true,false)[0]
  var foot:int=rig.find_bone("LeftFrontFoot")
  var positions:Array[Vector3]=[]
  for i in range(12):
   var before:Vector3=pet.position;pet.position.x+=.035;pet._advance_gait(1.0/60,before);positions.append(rig.get_bone_global_pose(foot).origin)
  var motion:float=0
  for point:Vector3 in positions:motion=maxf(motion,point.distance_to(positions[0]))
  check(motion>.03,"actual foot bones move while travelling "+kind+" "+str(motion))
  var phase:float=pet.gait_phase;app.world.player.allowed=false;pet._advance_gait(.5,pet.position-Vector3.RIGHT*.1)
  check(is_equal_approx(phase,pet.gait_phase),"paused gait freezes "+kind)
  app.world.player.allowed=true;pet._advance_gait(.3,pet.position)
  check(pet.gait_kind=="idle","standing returns to idle "+kind)
 print("SCENE REFRESH: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
