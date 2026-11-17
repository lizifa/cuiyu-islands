extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame;await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;root.add_child(viewport)
 app=load("res://scenes/life_main.tscn").instantiate();viewport.add_child(app);app._close_drawers();app.paused=false
 await frames(30)
 var nav:Button=app.home_navigation;var actor:Node3D=app.world.player;var camera:Camera3D=app.world.camera
 nav.refresh()
 var home:Vector3=app.world.Villa.ENTRY;var toward:Vector3=home-camera.position;toward.y=0
 var forward:Vector3=-camera.basis.z;forward.y=0
 check(forward.normalized().dot(toward.normalized())>cos(deg_to_rad(36)) and not camera.is_position_behind(home) and Rect2(Vector2.ZERO,Vector2(viewport.size)).has_point(camera.unproject_position(home)),"initial clear camera keeps the villa inside the visible forward field")
 check(nav.visible and nav.text.contains("别墅") and nav.text.contains("米"),"persistent home cue names the destination and distance")
 check(absf(nav.bearing)<=deg_to_rad(36) and nav.direction_symbol() in ["↑","↗","↖"],"home guide matches the forward villa bearing after collision-safe entry framing")
 camera.look_at(camera.position+Vector3.LEFT);nav.refresh()
 check(nav.direction_symbol()!="↑","turning away updates the relative direction without moving the camera")
 var before:Transform3D=camera.transform;nav.refresh()
 check(camera.transform.is_equal_approx(before),"the guide never drives the camera")
 nav.go_home();check(app.auto_task.running and app.auto_task.job=="villa","home cue starts the existing safe return-home task")
 nav.go_home();check(not app.auto_task.running,"same cue cancels a pending return-home walk")
 nav.go_home();app.joystick.direction=Vector2.RIGHT;await frames(3)
 check(not app.auto_task.running,"manual stick input takes over from return-home navigation")
 app.joystick.reset();actor.position=Vector3(0,.7,3.2);actor.velocity=Vector3.ZERO
 var inventory:Dictionary=app.state.inventory.duplicate(true)
 nav.go_home()
 for i in range(3000):
  await frames(1)
  if app.state.location=="villa" or not app.auto_task.running:break
 check(app.state.location=="villa","return-home navigation reaches the real villa entrance: "+app.auto_task.status)
 nav.refresh();check(not nav.visible,"home cue hides after entering the villa")
 check(app.state.inventory==inventory,"walking home does not craft, gather or consume inventory")
 app.state.location="island";app.state.player_position=[11,1.4,2.2];app.world.sync(app.state)
 await frames(8);nav.refresh()
 check(nav.text.contains("进入别墅"),"the cue becomes enter-villa at the actual porch")
 nav.go_home();check(app.state.location=="villa","nearby cue enters the existing villa without searching for the gaze prompt")
 print("HOME NAVIGATION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
