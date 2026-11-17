extends SceneTree
var app: Node
var view: SubViewport
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n: int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func touch(point: Vector2,down: bool,index: int) -> void:
 var event:=InputEventScreenTouch.new();event.position=point;event.pressed=down;event.index=index;view.push_input(event,true)
func drag(point: Vector2,relative: Vector2,index: int) -> void:
 var event:=InputEventScreenDrag.new();event.position=point;event.relative=relative;event.index=index;view.push_input(event,true)
func click(point: Vector2) -> void:
 for down: bool in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;view.push_input(event,true)
func _initialize():call_deferred("run")
func run():
 view=SubViewport.new();view.size=Vector2i(1280,720);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false)
 await frames(4)
 var rig: Node=app.world.orbit
 var actor: CharacterBody3D=app.world.player
 check(not rig.rotation_mode and not rig.is_away(),"default view follows character without forced rotation")
 var yaw: float=rig.target_yaw;var pitch: float=rig.target_pitch
 touch(Vector2(630,320),true,1);drag(Vector2(632,320),Vector2(2,0),1)
 check(rig.target_pan==Vector3.ZERO,"tiny camera touch jitter is ignored")
 drag(Vector2(760,340),Vector2(128,20),1);await frames(5)
 check(rig.target_pan.length()>.5 and rig.pan_offset.length()>.1,"native blank-space drag pans actual camera")
 check(rig.target_yaw==yaw and rig.target_pitch==pitch,"default observation never changes compass bearing or elevation")
 await frames(10)
 check(rig.is_away() and rig.return_timer==0 and rig.touch_id==1,"holding observation keeps ownership without scheduling a return")
 app._sync_overlay_state()
 check(app.camera_return.visible and app.safe_root.get_global_rect().encloses(app.camera_return.get_global_rect()),"return-to-player control appears inside safe area")
 app.minimap._process(.2)
 check(app.minimap.view_polygon.size()>=3,"minimap includes current ground-view footprint")
 var map_bounds:=Rect2(Vector2(7,7),app.minimap.size-Vector2(14,14))
 var clipped := true
 for point: Vector2 in app.minimap.view_polygon:clipped=clipped and map_bounds.has_point(point)
 check(clipped,"minimap footprint is clipped to map bounds")
 check(app.minimap.observing and app.minimap.view_center.distance_to(actor.position)>.5,"minimap distinguishes observation focus from character")
 touch(Vector2(760,340),false,1);await frames(120);app._sync_overlay_state()
 check(rig.pan_offset.length()>.5 and rig.target_pan.length()>.5,"release preserves the chosen observation instead of springing back")
 check(app.camera_return.visible,"explicit return stays available while observing")
 var stick: Vector2=app.joystick.get_global_rect().get_center()
 var origin: Vector3=actor.position
 touch(stick+Vector2(70,0),true,0)
 touch(Vector2(630,320),true,1);drag(Vector2(760,340),Vector2(130,20),1)
 await frames(12)
 check(actor.position.distance_to(origin)>.1 and app.joystick.finger==0 and rig.touch_id==1,"left movement and right observation own independent fingers")
 check(rig.target_yaw==yaw,"looking elsewhere while moving preserves movement bearing")
 touch(stick,false,0)
 check(rig.touch_id==1,"releasing movement does not steal observation finger")
 app._sync_overlay_state();click(app.camera_return.get_global_rect().get_center());await frames(50)
 check(rig.target_pan==Vector3.ZERO and rig.pan_offset.length()<.1 and rig.touch_id==-1,"return button clears active observation gesture")
 touch(Vector2(760,340),false,1)
 rig.set_rotation_mode(true)
 touch(Vector2(630,320),true,1);drag(Vector2(760,340),Vector2(130,20),1);touch(Vector2(760,340),false,1)
 check(rig.target_yaw!=yaw and rig.rotation_mode,"explicit rotate mode retains free orbit")
 rig.return_to_player();await frames(30)
 check(not rig.rotation_mode and absf(angle_difference(rig.target_yaw,yaw))<.001,"return exits rotation mode and restores prior follow angle")
 app.state.minute=12*60;app.world.sync(app.state)
 check(app.world.look_at_sun(app.state) and rig.observing_sun and rig.rotation_mode,"sun remains an explicit observation mode")
 rig.return_to_player()
 check(not rig.observing_sun and not rig.rotation_mode,"return exits sun viewing safely")
 app._toggle_menu();var old_revision: int=rig.manual_revision
 touch(Vector2(630,320),true,1);drag(Vector2(760,340),Vector2(130,20),1);touch(Vector2(760,340),false,1)
 check(rig.manual_revision==old_revision,"menu overlay cannot begin a camera gesture in background")
 app._close_drawers()
 rig.pan_drag(Vector2(100000,100000))
 check(rig.target_pan.length()<=rig.pan_limit+.001,"observation offset is bounded")
 rig.cancel_drag();rig.return_to_player();await frames(40)
 var data: Dictionary=app.state.snapshot()
 rig.pan_drag(Vector2(100,0));rig.cancel_drag()
 check(app.state.snapshot()==data,"camera observation never mutates survival state")
 app.state.location="villa";app.state.home_floor=0;app.world.sync(app.state);await frames(3)
 check(rig.pan_offset==Vector3.ZERO and rig.target_pan==Vector3.ZERO,"scene transition clears old observation offset")
 rig.pan_drag(Vector2(100000,100000));rig._process(.5)
 check(rig.target_pan.length()<=4.001,"indoor observation respects a smaller limit")
 rig.pan_drag(Vector2(-100000,-100000));rig._process(.1)
 check(rig.pan_bounds.grow(.01).has_point(Vector2(rig.focus.x+rig.target_pan.x,rig.focus.z+rig.target_pan.z)),"observation center remains inside room bounds")
 rig.return_to_player();app.state.location="island";app.state.player_position=[0,.7,3.2];app.state.buildings["小船"]=true;app.world.sync(app.state)
 actor.position=app.world.DOCK;check(app.world.board_boat(app.state),"board for sea-map coverage")
 app.minimap._process(.2)
 check(app.minimap.extent==72,"sea map expands to cover navigable waters")
 app.world.disembark_boat();app.minimap._process(.2)
 check(app.minimap.extent==27,"land map restores normal scale after docking")
 rig.clear_observation(true)
 for i in range(120):rig._process(1.0/60)
 rig.mouse_dragging=true;rig.target_pan=Vector3(4,0,2)
 for i in range(30):rig._process(1.0/30)
 var thirty: Vector3=rig.pan_offset
 rig.clear_observation(true)
 for i in range(120):rig._process(1.0/60)
 rig.mouse_dragging=true;rig.target_pan=Vector3(4,0,2)
 for i in range(60):rig._process(1.0/60)
 check(rig.pan_offset.distance_to(thirty)<.0002,"pan smoothing matches at 30 and 60 updates per second")
 rig.clear_observation(true)
 app.queue_free();view.queue_free();await process_frame
 print("CAMERA OBSERVATION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
