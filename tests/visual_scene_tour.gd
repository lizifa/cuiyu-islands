extends SceneTree
## Developer-only rendered tour. Uses fresh test state; never loads or writes a real save.
var app: Node
var records: Array[Dictionary] = []
var output := "/tmp/qgyh-visual-tour"
func _initialize() -> void:
 call_deferred("run")
func frames(count: int) -> void:
 for i in range(count):
  app.inactive=false
  await process_frame
func capture(label: String) -> void:
 await frames(12)
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 var path := output.path_join("%02d-%s.png" % [records.size(),label])
 var error := image.save_png(path)
 var camera: Camera3D=app.world.camera
 records.append({"scene":label,"image":path,"saved":error==OK,"camera":str(camera.position),"finite":camera.position.is_finite(),"roll":camera.rotation.z})
 print("VISUAL TOUR: ",label," -> ",path)
 FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
func place(location: String, point: Vector3, facing: Vector3, floor_index: int=0) -> void:
 app.home_routine.cancel();app.sofa_session.finish();app.fishing_session.cancel(false)
 app.interaction_director.cancel();app.joystick.reset()
 app.state.location=location;app.state.home_floor=floor_index;app.state.player_position=[point.x,point.y,point.z]
 app.world.sync(app.state);app.world.player.position=point;app.world.player.velocity=Vector3.ZERO
 app._close_drawers();app.paused=false
 # Let the scene-entry eye context settle before choosing the review bearing.
 await frames(3)
 var rig:Node=app.world.orbit
 rig.cancel_drag();rig.auto_point=Vector3.INF
 var direction:=facing-(point+Vector3.UP*1.85)
 rig.yaw=atan2(-direction.x,-direction.z);rig.target_yaw=rig.yaw
 rig.pitch=-atan2(direction.y,Vector2(direction.x,direction.z).length());rig.target_pitch=rig.pitch
 await frames(45)
func run() -> void:
 if OS.has_feature("mobile"):output="user://visual-tour"
 DirAccess.make_dir_recursive_absolute(output)
 app=load("res://scenes/life_main.tscn").instantiate();app.test_mode=true;root.add_child(app)
 app.arrival.open();await capture("character-selection")
 app.arrival.confirm();app._close_drawers();app.paused=false
 await place("island",Vector3(0,.7,3.2),Vector3(0,2,-8));await capture("island-day")
 app.layout_editor.open_settings();await capture("settings");app.layout_editor.hide();app._sync_overlay_state()
 app._toggle_inventory();await capture("inventory");app._close_drawers()
 app.state.minute=22*60;app.world.sync(app.state);await capture("island-night")
 app.state.minute=9*60
 await place("island",app.world.FishingPlatform.POINT,app.world.FishingPlatform.FLOAT)
 assert(app.fishing_session.begin(),"fishing must start");await capture("fishing-ready")
 app.fishing_session.interact();app.context_action.held=true;await frames(30)
 app.context_action.held=false;await frames(50);await capture("fishing-float")
 var fishing:Node=app.fishing_session
 fishing.fish_roll=0;fishing._set_stage("bite");fishing.interact();await frames(45);await capture("fishing-big-fish")
 fishing._set_stage("landing");await frames(45);await capture("fishing-net")
 fishing._physics_process(3.5);await capture("fishing-storage");fishing.cancel(false)
 await place("town",Vector3(0,.7,3.2),Vector3(-3,1.6,0));await capture("town")
 await place("city",Vector3(0,.7,3.2),Vector3(-3,1.6,0));await capture("city")
 await place("villa",Vector3(0,.705,5),Vector3(-6,2,1));await capture("villa-ground-floor")
 app.world.player.position=app.world.Villa.SOFA_STAND
 app.sofa_session.begin();await frames(90);app.sofa_session.toggle_tv();await capture("sofa-television");app.sofa_session.finish()
 await place("villa",Vector3(-1.15,.705,-3.82),Vector3(-1.5,1.8,-4.7))
 app.home_routine.open_fridge()
 for i in range(900):
  await frames(1)
  if app.home_routine.phase=="fridge":break
 await capture("fridge-open");app.home_routine.take()
 for i in range(500):
  await frames(1)
  if app.state.count("饮料")>0 and app.home_routine.phase=="fridge":break
 await capture("fridge-bottle");app.home_routine.drink()
 for i in range(700):
  await frames(1)
  if app.home_routine.phase=="drinking":break
 await frames(18);await capture("drink-closeup");app.home_routine.cancel()
 await place("villa",Vector3(6,.705,2),Vector3(9,2,0))
 app.world.change_home_floor(app.state);await frames(100);await capture("stairs-first-person")
 for i in range(1800):
  await frames(1)
  if not app.world.player.stair_active:break
 await capture("villa-upper-floor")
 await place("villa",Vector3(-3,app.world.Villa.Dimensions.UPPER_FLOOR+.03,-1.45),Vector3(-5,8,-3),1)
 app.bed_session.begin()
 for i in range(1000):
  await frames(1)
  if app.world.player.bed_stage=="resting":break
 await capture("bed-rest");app.bed_session.finish()
 for i in range(1000):
  await frames(1)
  if app.world.player.bed_stage=="":break
 await capture("bed-wake")
 await place("villa",Vector3(5,app.world.Villa.Dimensions.UPPER_FLOOR+.03,1),Vector3(5,8,-3),1);await capture("bathroom")
 await place("island",Vector3(0,.7,3.2),Vector3(0,2,-8));await capture("tour-finished")
 print("VISUAL TOUR COMPLETE: ",records.size()," checkpoints; test state only")
 # Keep the playable test window open for manual inspection.
