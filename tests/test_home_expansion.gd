extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var app:Node
var passed:=0
var failed:=0
func check(value:bool,message:String) -> void:
 if value:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func _initialize():call_deferred("run")
func run():
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.set_physics_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[6,.705,2];app.world.sync(app.state)
 await frames(4)
 var room:Node3D=app.world.villa_room
 for gear:String in ["Treadmill","ExerciseBike","DumbbellRack","YogaMat"]:
  var node:Node=room.get_node("HomeGym/"+gear)
  check(node.find_children("*","CollisionShape3D",true,false).size()>0,gear+" has physical collision")
 check(room.tv_screen.mesh is QuadMesh,"television uses a physical display surface")
 check(room.tv_screen.position.x<-10,"television is on west living room wall")
 var tv:Node=room.get_node("HomeTelevision")
 app.world.player.allowed=true;app.world.set_home_tv(true)
 check(tv.player.stream is VideoStreamTheora,"television loads supplied video")
 check(tv.screen_material.albedo_texture==tv.player.get_video_texture(),"screen displays decoded video texture")
 await frames(70)
 check(tv.player.stream_position>.1,"video timeline advances")
 tv.toggle_pause();await frames(3)
 var position:float=tv.player.stream_position
 await frames(20)
 check(absf(tv.player.stream_position-position)<.05,"pause freezes the video")
 tv.toggle_pause();app.world.player.allowed=false;await frames(5)
 check(tv.player.paused,"game pause suspends decoder")
 app.world.player.allowed=true;app.state.location="island";await frames(5)
 check(tv.player.paused,"leaving house suspends decoder")
 app.state.location="villa";tv.set_volume(-8)
 check(is_equal_approx(tv.player.volume_db,-8),"volume control reaches player")
 app.world.set_home_tv(false);check(not tv.player.is_playing(),"off stops video")
 var stairs=load("res://scripts/life/villa_stairwell.gd")
 for floor_index:int in [0,1]:
  for x:float in [5.5,6.8,7.5,8.4]:
   check(stairs.can_start(Vector3(x,.705+floor_index*VillaDimensions.RISE,2.7),Vector3.RIGHT,floor_index),"broad landing entry %s/%s"%[floor_index,x])
 check(not stairs.can_start(Vector3(9.25,.705,3),Vector3.BACK,0),"walking away never reenters stairs")
 print("HOME EXPANSION: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
