extends SceneTree
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func _initialize():
 if "--test-mode" not in OS.get_cmdline_user_args():quit(1);return
 call_deferred("run")
func run():
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);await frames(4)
 check(app.world.terrain_walkable(Vector3(0,.65,10)) and is_equal_approx(app.world.terrain_height(0,10),.65),"expanded pier has physical-height walking surface")
 var query:=PhysicsRayQueryParameters3D.create(Vector3(-.1,2,10),Vector3(-.1,0,10),1)
 var hit:Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(query)
 check(not hit.is_empty() and absf(hit.position.y-.65)<.01,"new pier area has solid floor")
 check(app.world.terrain_height(-1.15,18.6)<0,"bridge extension leaves the hanging keep net over water")
 check(app.world.terrain_walkable(app.world.DOCK),"original boarding stance remains walkable")
 for gender:String in ["male","female"]:
  app.state.profile.gender=gender;app.world.sync(app.state);await frames(3)
  var actor:Node3D=app.world.player;actor.position=Vector3(-1,.68,16.1)
  var session:Node=app.fishing_session;check(session.begin(),"gait fixture "+gender);session.set_physics_process(false)
  actor.pose_fishing("landing",3.4,Vector3.UP)
  var landing_feet:Array[Vector3]=[]
  for side:String in ["Left","Right"]:landing_feet.append(actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone(side+"Foot")).origin)
  var steps:RefCounted=actor.fishing_steps
  var previous:Array[Vector3]=[];var first:Array[Vector3]=[];var last:Array[Vector3]=[]
  var largest:float=0;var crossed:=false;var width:=true;var peak:float=0;var planted:=true
  for i in range(331):
   var time:float=float(i)/60;actor.pose_fishing("storing",time,Vector3.UP)
   var sample:Array[Vector3]=[]
   for side:int in range(2):
    var foot:int=actor._bone(("Left" if side==0 else "Right")+"Foot")
    var point:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(foot).origin
    sample.append(point)
    if i==0:first.append(point)
    else:largest=maxf(largest,point.distance_to(previous[side]))
    if signf(point.x-actor.position.x)!=signf(steps.stance[side].origin.x):crossed=true
    peak=maxf(peak,point.y-first[side].y)
    if time<2.2:planted=planted and point.distance_to(first[side])<.01
   width=width and absf(sample[0].x-sample[1].x)>.4
   previous=sample;last=sample
  check(first[0].distance_to(landing_feet[0])<.01 and first[1].distance_to(landing_feet[1])<.01,"landing-to-storage retains original foot placement "+gender)
  check(not crossed and width,"left/right feet never swap or close across midline "+gender)
  check(largest<.045,"entering walking and stopping keeps feet continuous "+gender+" "+str(largest))
  check(planted and peak>.04,"standing feet remain planted before a real swing "+gender)
  check(absf(last[0].z-first[0].z-.65)<.015 and absf(last[1].z-first[1].z-.65)<.015,"both steps finish forward at original stance "+gender)
  session.cancel()
 print("FISHING STEP CONTINUITY: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
