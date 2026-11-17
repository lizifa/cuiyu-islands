extends Node
const FRIDGE_STAND:=Vector3(-1.15,.705,-3.82)
const FRIDGE_CLEAR:=Vector3(-1.8,.705,-2.6)
var app:Node
var phase:=""
var elapsed:=0.0
var throw_start:=Vector3.INF
var bottle_source:=Vector3.ZERO
var gesture:RefCounted
var owner_visual:Node3D
var panel:PanelContainer
var label:Label
var buttons:HBoxContainer
var drink_button:Button
var fridge:Node3D
var approach_anchor:Marker3D
var pending_take:=false
var pending_drink:=false
var drink_heading:float=0
func setup(owner_app:Node) -> void:
 app=owner_app;app.world.player.home_cancel=cancel
 panel=PanelContainer.new();panel.name="FridgeControls";panel.add_theme_stylebox_override("panel",app.panel());app.safe_root.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);panel.offset_left=-265;panel.offset_right=265;panel.offset_top=-125;panel.offset_bottom=-20
 var rows:=VBoxContainer.new();panel.add_child(rows);label=app.label("冰箱",17);rows.add_child(label);buttons=HBoxContainer.new();rows.add_child(buttons)
 app.button(buttons,"取一瓶饮料",take);drink_button=app.button(buttons,"喝饮料",drink)
 app.button(buttons,"补充 · 2贝币",restock);app.button(rows,"离开 / 取消",cancel);panel.hide()
func ready_actor() -> bool:
 var actor=app.world.player
 return app.movement_enabled() and not actor.home_busy and not actor.sofa_seated and actor.bed_stage=="" and not actor.stair_active and actor.pet_stage=="" and not actor.working
func frame_fridge() -> void:
 app.world.home_camera.begin(app.world,"household",Vector3(-1.5,1.75,-3.65),.95,3.9,2.35)
func open_fridge() -> bool:
 if not ready_actor() or app.state.location!="villa" or app.state.home_floor!=0:return false
 fridge=app.world.villa_room.get_node("HomeFridge");pending_take=false;panel.show();buttons.hide()
 label.text="走到冰箱前，伸手开门…";frame_fridge()
 return approach(begin_open)
func approach(callback:Callable) -> bool:
 if gesture!=null:gesture.clear();gesture=null
 phase="approach_fridge"
 if is_instance_valid(approach_anchor):approach_anchor.queue_free()
 approach_anchor=preload("res://scripts/life/interaction_anchor.gd").new();app.world.props.add_child(approach_anchor)
 approach_anchor.configure(FRIDGE_STAND,Vector3(-1.5,1.5,-4.7),Vector3(2,2,3));approach_anchor.arrival_radius=.06;approach_anchor.exact_stand=true
 var point:Dictionary={"kind":"villa_fridge_take","title":"冰箱","pos":FRIDGE_STAND,"range":1.2,"anchor":approach_anchor}
 if not app.interaction_director.request(point,callback):cancel();return false
 return true
func refresh() -> void:
 label.text="冰箱饮料 %d 瓶 · 背包 %d 瓶"%[app.state.home_drinks,app.state.count("饮料")]
 drink_button.disabled=app.state.count("饮料")<1
 if is_instance_valid(fridge):fridge.show_stock(app.state.home_drinks)
func restock() -> void:
 if phase!="fridge" or not app.movement_enabled():return
 app._act(app.state.restock_drink);refresh()
func take() -> void:
 if phase!="fridge" or not ready_actor():return
 if app.state.home_drinks<1:app.state.say("冰箱没有饮料了，先补充库存。");return
 if not app.state.can_exchange({},{"饮料":1}):app.state.say("背包满了，先腾出位置。");return
 buttons.hide()
 if not fridge.opened:
  pending_take=true;approach(begin_open)
 elif app.world.player.position.distance_to(FRIDGE_STAND)>.22:approach(begin_take)
 else:begin_take()
func begin_pose() -> bool:
 if not ready_actor():return false
 var held:MeshInstance3D
 var held_side:String="Right"
 if gesture!=null:
  held=gesture.prop;held_side=gesture.held_side;gesture.prop=null;gesture.clear()
 app.auto_task.stop("");gesture=preload("res://scripts/life/home_gesture.gd").new()
 if not gesture.setup(app.world.player):
  if is_instance_valid(held):held.queue_free()
  gesture=null;return false
 gesture.prop=held;gesture.set_held_side(held_side);owner_visual=app.world.player.visual;elapsed=0;return true
func begin_open() -> void:
 if not begin_pose():cancel();return
 phase="opening";label.text="伸手打开冰箱…"
func begin_take() -> void:
 if gesture!=null:gesture.release_pose()
 if not begin_pose():cancel();return
 phase="taking";label.text="伸手取出饮料…";gesture.set_held_side("Left");gesture.make_bottle(app.world)
 var index:int=clampi(app.state.home_drinks-1,0,fridge.bottles.size()-1)
 bottle_source=fridge.bottles[index].global_position+Vector3.UP*.15;gesture.prop.global_position=bottle_source
func drink() -> void:
 if phase!="fridge" or app.state.count("饮料")<1:return
 if is_instance_valid(fridge) and fridge.opened:
  if not begin_pose():return
  begin_retreat();pending_take=false;pending_drink=true;return
 begin_drink()
func begin_drink() -> void:
 if not begin_pose():return
 phase="turning_drink";buttons.hide();gesture.set_held_side("Left");gesture.make_bottle(app.world);label.text="转身离开冰箱门前，拿起饮料…"
 var actor:CharacterBody3D=app.world.player
 var away:Vector3=actor.position-fridge.global_position if is_instance_valid(fridge) else Vector3.BACK
 drink_heading=atan2(away.x,away.z)
 app.world.home_camera.drink(app.world,actor,drink_heading,gesture.held_side)
func begin_retreat() -> void:
 gesture.release_pose();app.world.player.home_busy=true
 phase="retreating";elapsed=0;buttons.hide();label.text="拿稳饮料，后退让开冰箱门…"
 if app.world.player.animator!=null:app.world.player.animator.play(app.world.player.walk_clip,.15,-1,true)
func go_bin() -> void:
 app.world.home_camera.release(app.world,"household")
 phase="to_bin";label.text="喝完了，走到垃圾桶旁丢空瓶…"
 if not app.interaction_director.request(app.world.find_interaction("villa_bin"),begin_discard):cancel()
func begin_discard() -> bool:
 if app.state.count("空饮料瓶")<1:return app.state.say("没有需要丢弃的空瓶。")
 var bin_point:Dictionary=app.world.find_interaction("villa_bin")
 if bin_point.is_empty() or not app.world.interactable(bin_point):return app.state.say("走近垃圾桶并面对着它。")
 if not begin_pose():return false
 app.world.home_camera.begin(app.world,"household",Vector3(-6.7,1.5,-2.9),.7,3.5,2.3)
 phase="discarding";throw_start=Vector3.INF;panel.show();buttons.hide();gesture.make_bottle(app.world);label.text="把空瓶投入垃圾桶…";return true
func begin_sink(kind:String) -> bool:
 if not ready_actor():return false
 if kind=="cooking" and app.state.count("鲜鱼")<2:return app.state.say("需要 2 条鲜鱼才能烹饪鱼干。")
 if not begin_pose():return false
 phase="filling" if kind=="water" else kind;panel.show();buttons.hide();label.text="接水，拿起杯子喝水…" if kind=="water" else "站在灶台前烹饪鱼干…"
 var actor:CharacterBody3D=app.world.player
 app.world.home_camera.begin(app.world,"household",actor.position+Vector3(0,1.1,-.35),.65,3.5,2.3)
 if kind=="water":gesture.set_held_side("Left");gesture.make_bottle(app.world)
 else:
  phase="cooking_setup";gesture.make_spoon(app.world)
  var side:Vector3=actor.visual.global_basis.x.normalized()
  var bearing:Vector3=side
  app.world.home_camera.begin(app.world,"household",Vector3(-3.4,1.95,-4.35),atan2(bearing.x,bearing.z),1.8,3.05,60)
 return true
func begin_wave() -> bool:
 if app.world.player.boating or not ready_actor() or phase!="":return false
 if not begin_pose():return false
 phase="waving";panel.hide();return true

func cancel() -> void:
 if phase in ["approach_fridge","to_bin"] and app.interaction_director.active:app.interaction_director.cancel()
 if gesture!=null:gesture.clear();gesture=null
 app.world.player.home_busy=false;app.world.player.home_move_direction=Vector3.ZERO
 if is_instance_valid(fridge):
  if app.world.player.position.z> -3.05:fridge.opened=false
  fridge.show_stock(app.state.home_drinks)
 owner_visual=null;pending_take=false;pending_drink=false
 if is_instance_valid(approach_anchor):approach_anchor.queue_free();approach_anchor=null
 app.world.home_camera.release(app.world,"household");phase="";panel.hide()
func _physics_process(delta:float) -> void:
 if phase=="":return
 if (phase!="waving" and (app.state.location!="villa" or app.state.home_floor!=0)) or (owner_visual!=null and (not is_instance_valid(owner_visual) or owner_visual!=app.world.player.visual)):cancel();return
 if not app.movement_enabled():return
 if phase in ["approach_fridge","to_bin"]:
  if gesture!=null:gesture.carry()
  if not app.interaction_director.active:cancel()
  return
 if phase=="fridge":
  if gesture!=null:gesture.carry()
  if app.world.player.manual_stair_input.length()>.2 or app.world.player.position.distance_to(Vector3(-1.5,.705,-2.6))>2.5:cancel()
  return
 if app.world.player.manual_stair_input.length()>.2:cancel();return
 elapsed+=delta
 var actor:CharacterBody3D=app.world.player
 if phase=="waving":
  var duration:float=gesture.LIFE_ACTIONS.get_animation("Waving").length
  var weight:float=smoothstep(0,.25,elapsed)*(1-smoothstep(1.65,2.0,elapsed))
  gesture.sample_mixamo("Waving",fmod(elapsed,duration),weight)
  if elapsed>=2.0:cancel()
 elif phase=="opening":
  var handle:Vector3=fridge.hinge.to_global(Vector3(1.12,1.5,.08))
  gesture.tick(handle,smoothstep(0,.4,elapsed)*(1-smoothstep(1.1,1.4,elapsed)),0,"Left")
  if elapsed>.4:fridge.opened=true
  if elapsed>1.45:
   gesture.release_pose()
   if pending_take:pending_take=false;begin_take()
   else:phase="fridge";buttons.show();refresh()
 elif phase=="taking":
  gesture.tick(bottle_source,smoothstep(0,.45,elapsed)*(1-smoothstep(.65,1.2,elapsed)))
  if elapsed<.45:gesture.prop.global_position=bottle_source
  if elapsed>=1.2:
   if app.state.take_fridge_drink():app._save(false);begin_retreat()
   else:cancel()
  fridge.show_stock(app.state.home_drinks-(1 if phase=="taking" else 0))
 elif phase=="retreating":
  var offset:Vector3=FRIDGE_CLEAR-actor.position;offset.y=0
  actor.home_move_direction=offset.normalized()
  actor.velocity=offset.normalized()*minf(.9,offset.length()/maxf(delta,.001));actor.velocity.y=-2;actor.move_and_slide();gesture.carry()
  if offset.length()<.07:
   actor.velocity=Vector3.ZERO;actor.home_move_direction=Vector3.ZERO;actor.home_busy=false
   if begin_pose():phase="closing";label.text="用空闲的手关上冰箱…"
   else:cancel()
  elif elapsed>4:
   app.state.say("退让位置受阻，请移开后重试；饮料已保留。");cancel()
 elif phase=="closing":
  var handle:Vector3=fridge.hinge.to_global(Vector3(1.05,1.15,.08))
  gesture.tick(handle,smoothstep(0,.3,elapsed)*(1-smoothstep(1,1.35,elapsed)),0,"Right")
  if elapsed>.3:fridge.opened=false
  if elapsed>1.4:
   gesture.release_pose()
   if pending_drink:pending_drink=false;begin_drink()
   else:
    app.world.home_camera.release(app.world,"household");phase="fridge";buttons.show();refresh()
 elif phase in ["turning_drink","turning_water"]:
  actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,drink_heading,1-exp(-5*delta));gesture.carry()
  if elapsed>1.25 and absf(angle_difference(actor.visual.rotation.y,drink_heading))<.04:
   phase="water" if phase=="turning_water" else "drinking";elapsed=0;gesture.set_held_side("Left");label.text="举起杯瓶，慢慢喝水…"
 elif phase=="filling":
  gesture.tick(Vector3(-5.9,1.85,-4.25),smoothstep(0,.4,elapsed)*(1-smoothstep(.8,1.1,elapsed)))
  if elapsed>=1.1:
   var away:Vector3=actor.position-Vector3(-5.9,.705,-4.8);drink_heading=atan2(away.x,away.z)
   app.world.home_camera.drink(app.world,actor,drink_heading,gesture.held_side);phase="turning_water";elapsed=0
 elif phase in ["drinking","water"]:
  gesture.mocap_drink(elapsed)
  if elapsed>=gesture.LIFE_ACTIONS.get_animation("Drinking").length:
   if phase=="water":
    gesture.clear();gesture=null;app._act(app.state.drink);cancel()
   elif app.state.drink_beverage():gesture.release_pose();app.world.sync(app.state);app._save(false);go_bin()
   else:cancel()
 elif phase=="cooking_setup":
  gesture.carry()
  if elapsed>=1:phase="cooking";elapsed=0
 elif phase=="cooking":
  var pot:=Vector3(-3.4,1.9,-4.35)
  gesture.tick(pot+Vector3(sin(elapsed*4)*.08,.18,cos(elapsed*4)*.08+.08),.95,-.4)
  actor._reach_arm("Left",pot+Vector3(.3,0,0),.65)
  if elapsed>=2.6:gesture.clear();gesture=null;app._act(app.state.craft.bind("鱼干"));cancel()
 elif phase=="discarding":
  gesture.tick(Vector3(-7,1.45,-3.2),smoothstep(0,.65,elapsed))
  if elapsed>=.65 and is_instance_valid(gesture.prop):
   if not throw_start.is_finite():throw_start=gesture.prop.global_position
   var progress:float=smoothstep(.65,1.25,elapsed)
   gesture.prop.global_position=throw_start.lerp(Vector3(-7,1.43,-3.2),progress)+Vector3.UP*sin(progress*PI)*.18
  if elapsed>=1.25:app.state.discard_bottle();app._save(false);app._refresh();cancel()
func _exit_tree() -> void:
 if gesture!=null:gesture.clear()
