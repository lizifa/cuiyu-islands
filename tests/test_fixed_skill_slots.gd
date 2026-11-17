extends SceneTree
var passed:=0
var failed:=0
var app:Node
var slots:Array=[]
var positions:Array[Vector2]=[]
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func inspect(label:String)->void:
 app._sync_overlay_state();app._update_context()
 check(app.action_pad.is_visible_in_tree(),"gameplay shows skill group "+label)
 for i in range(5):
  check(slots[i].is_visible_in_tree(),"slot always visible "+label+" "+str(i))
  check(slots[i].position.distance_to(positions[i])<.01,"slot never moves "+label+" "+str(i))
func _initialize()->void:call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.size=Vector2i(1560,720);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false);app.set_physics_process(false);app.inactive=false;app.paused=false;app._close_drawers()
 for frame in range(4):await process_frame
 app._layout_mobile()
 for frame in range(4):await process_frame
 var actor:CharacterBody3D=app.world.player;actor.set_physics_process(false);app._update_context()
 slots=[app.context_action,app.sprint_action,app.build_action,app.boat_stop_action,app.boat_home_action]
 for slot:Control in slots:positions.append(slot.position)
 check(app.action_pad.get_child_count()==5,"exactly five fixed slots")
 inspect("walk")
 check((slots[3].title=="查看" and slots[3].active) or (not slots[3].active and slots[3].title==""),"slot four is either a real inspect or a grey placeholder")
 check(not slots[4].active and slots[4].title=="","slot five stays grey on plain ground")
 var inventory:Dictionary=app.state.inventory.duplicate(true);var stopped:bool=app.boat_session.stopped
 slots[3]._press();slots[4]._press()
 check(app.state.inventory==inventory and app.boat_session.stopped==stopped and not app.world.return_pilot.active,"empty slots never execute callbacks")
 actor.bed_stage="rest";inspect("bed")
 check(app.context_action.title=="起床" and app.context_action.active,"bed keeps wake in slot one")
 check(app.sprint_action.title in ["睡到清晨","短休两小时"] and app.boat_stop_action.title=="查看" and app.boat_stop_action.active,"bed fills five slots: rest and inspect")
 check(app.build_action.title in ["开床头灯","关床头灯"] or app.build_action.title=="","bed slots the bedside lamp, grey with a reason before the villa room loads")
 check(app.boat_home_action.title=="整理床铺" or (app.boat_home_action.title=="" and not app.boat_home_action.active),"bed slots tidy or grey placeholder")
 actor.bed_stage="";actor.sofa_seated=true;inspect("sofa")
 check(app.context_action.title=="起身" and app.sprint_action.title in ["打开电视","关闭电视"],"sofa fills five slots: get up and tv")
 check(app.boat_stop_action.title=="查看" and app.boat_stop_action.active,"sofa fills inspect slot")
 actor.sofa_seated=false;actor.home_busy=true;inspect("home action");actor.home_busy=false
 actor.stair_active=true;inspect("stairs");actor.stair_active=false
 actor.position=Vector3(-1,.68,16.1);actor.move_input=Vector2.ZERO
 check(app.fishing_session.begin(),"fishing starts")
 app.fishing_session.set_physics_process(false)
 for stage:String in ["ready","charging","casting","waiting","reeling","storing","result"]:
  app.fishing_session._set_stage(stage);inspect("fishing "+stage)
  check(slots[3].title=="鱼护" and slots[4].title=="" and not slots[4].active,"fishing shows the keep net in slot four and leaves slot five grey")
 app.fishing_session.cancel()
 actor.position=app.world.DOCK;app.world.board_boat(app.state);inspect("boat")
 check(slots[3].title=="停船" and slots[4].title=="返航主岛","boat restores its two contextual skills in same slots")
 app._open_tasks();check(not app.action_pad.is_visible_in_tree(),"task popup hides entire group")
 app._close_drawers();app._confirm_reset_game();check(not app.action_pad.is_visible_in_tree(),"confirmation hides entire group")
 app.confirmation.get_cancel_button().pressed.emit();check(app.action_pad.is_visible_in_tree(),"closing popup restores five slots")
 actor.velocity=Vector3.ZERO;app.world.disembark_boat()
 for gender:String in ["male","female"]:
  app.state.profile.gender=gender;app.world.sync(app.state)
  var preview:Node3D=app.world.character_model(gender);app.world.add_child(preview)
  check(app.world.player.visual.scale.distance_to(preview.scale*(2./3))<.001,"playable character is two-thirds previous model scale "+gender)
  preview.queue_free()
 print("FIXED SKILL SLOTS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
