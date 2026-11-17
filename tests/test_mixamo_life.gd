extends SceneTree
var failed:=0
func check(value:bool,message:String) -> void:
 if not value:failed+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var model=load("res://assets/kenney-protagonists/protagonist.scn").instantiate()
 var actor=load("res://scripts/life/player_controller.gd").new()
 root.add_child(actor);actor.add_child(model);actor.bind_visual(model)
 var gesture=load("res://scripts/life/home_gesture.gd").new()
 check(gesture.setup(actor),"gesture can acquire actor")
 var rig:Skeleton3D=gesture.rig
 var original:Array[Quaternion]=gesture.rotations.duplicate()
 var hand:int=actor._bone("LeftHand")
 var initial:Vector3=rig.get_bone_global_pose(hand).origin
 var max_motion:float=0
 for name:String in ["Waving","Drinking"]:
  var clip:Animation=gesture.LIFE_ACTIONS.get_animation(name)
  check(clip.length>0.4,"clip has actual motion duration: "+name)
  for sample in range(61):
   gesture.sample_mixamo(name,clip.length*sample/60.0)
   for bone in rig.get_bone_count():
    check(rig.get_bone_pose_rotation(bone).is_finite(),"finite bone pose")
   max_motion=maxf(max_motion,rig.get_bone_global_pose(hand).origin.distance_to(initial))
 check(max_motion>.1,"retargeted animation changes hand position")
 gesture.mocap_drink(4.0)
 gesture.clear()
 check(not actor.home_busy,"cancel releases movement")
 for bone in rig.get_bone_count():check(rig.get_bone_pose_rotation(bone).is_equal_approx(original[bone]),"cancel restores pose")
 actor.free()
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.inactive=false;app.paused=false
 app.world.player.position=Vector3(0,1,0)
 check(app.home_routine.begin_wave(),"wave starts from normal play")
 check(not app.home_routine.begin_wave(),"duplicate wave rejected")
 app.home_routine._physics_process(.3)
 var elapsed:float=app.home_routine.elapsed
 app.paused=true;app.home_routine._physics_process(.5)
 check(is_equal_approx(elapsed,app.home_routine.elapsed),"pause freezes action clock")
 app.paused=false;app.home_routine.cancel()
 check(app.home_routine.phase=="" and not app.world.player.home_busy,"wave cancellation cleans session")
 app.free()
 print("Mixamo life failures: ",failed);quit(1 if failed else 0)
