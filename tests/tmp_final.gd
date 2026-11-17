extends SceneTree
## Developer-only rendered tour. Uses fresh test state; never loads or writes a real save.
var app: Node
var records: Array[Dictionary] = []
var output := "/tmp/finalcheck"
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
 DirAccess.make_dir_recursive_absolute(output)
 app=load("res://scenes/life_main.tscn").instantiate();app.test_mode=true;root.add_child(app)
 app.arrival.open();await capture("boy-select")
 app.arrival.confirm();app._close_drawers();app.paused=false
 await place("island",Vector3(0,.7,3.2),Vector3(0,2,-8));await capture("boy-island")
 print("FINAL DONE");quit()
