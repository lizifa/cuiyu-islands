extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var passed := 0
var failed := 0
var app: Node
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(count: int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func await_bed(target: String) -> void:
 for i in range(400):
  if app.world.player.bed_stage==target:return
  await frames(1)
 check(false,"bed sequence did not reach "+target)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[6,.705,2];app.world.sync(app.state)
 await frames(4)
 var actor=app.world.player
 check(app.world.change_home_floor(app.state),"stairs start at physical entrance")
 check(app.state.home_floor==0 and actor.stair_active,"no instant floor switch")
 check(not app.world.change_home_floor(app.state),"duplicate climb is rejected")
 var pause_position: Vector3=actor.position
 app.paused=true;await frames(12)
 check(actor.position.distance_to(pause_position)<.001,"paused stair traversal stays still")
 check(app.world.save_position().distance_to(actor.stair_return)<.01,"stair save uses starting landing")
 app.paused=false
 var max_y: float=actor.position.y
 var biggest_jump := 0.0
 for i in range(1100):
  var before: Vector3=actor.position
  await frames(1)
  max_y=maxf(max_y,actor.position.y);biggest_jump=maxf(biggest_jump,actor.position.distance_to(before))
  if not actor.stair_active:break
 print("UPPER ",actor.position," floor ",app.state.home_floor," jump ",biggest_jump)
 check(app.state.home_floor==1 and actor.position.y>VillaDimensions.UPPER_FLOOR-.05,"walks up to real upper storey")
 check(biggest_jump<.18,"continuous stair movement without teleport")
 check(app.world.villa_rooms.size()==2,"both floor scenes stay loaded")
 check(app.world.villa_rooms[0].visible and app.world.villa_rooms[1].visible,"sealed interior retains both connected floors")
 actor.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45);await frames(3)
 app.state.energy=40;app.state.health=70
 check(app.bed_session.begin(),"bed rest starts near upstairs bed")
 check(not app.bed_session.begin(),"duplicate rest has no reward")
 await await_bed("resting")
 check(actor.bed_stage=="resting","visible recline completes before rest")
 for suffix: String in ["LeftFoot","RightFoot"]:
  var bone: int=actor._bone(suffix)
  var foot: Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(bone).origin
  check(absf(foot.y-actor.bed_anchor.y)<.2,"relaxed legs stay on mattress: "+suffix)
 check(absf(actor.visual.rotation.x+PI*.5)<.01,"actor lies horizontally")
 var cloak=actor.visual.find_child("attach-neck-mesh",true,false)
 check(cloak==null or not cloak.visible,"cape is removed while lying down")
 check(app.world.save_position().distance_to(actor.bed_return)<.01,"save uses safe bedside floor")
 var energy: float=app.state.energy
 app.paused=true;await frames(20)
 check(is_equal_approx(energy,app.state.energy),"paused bed rest earns nothing")
 app.paused=false;await frames(30)
 check(app.state.energy>energy,"lying rest recovers energy gradually")
 app.bed_session.finish();await await_bed("")
 check(actor.bed_stage=="" and actor.collision_mask==1 and actor.collision_layer==2,"rising restores physical movement")
 check(cloak==null or cloak.visible,"cape is restored after getting up")
 check(actor.position.distance_to(Vector3(-2.95,(VillaDimensions.UPPER_FLOOR+.03),-2.75))<.08,"gets up and dresses beside coat rack")
 actor.position=Vector3(6,(VillaDimensions.UPPER_FLOOR+.03),2);await frames(3)
 check(app.world.change_home_floor(app.state),"downstairs can be requested")
 for i in range(1100):
  await frames(1)
  if not actor.stair_active:break
 print("LOWER ",actor.position," floor ",app.state.home_floor)
 check(app.state.home_floor==0 and actor.position.y<.8,"walks downstairs to ground floor")
 # A blocked flight must restore the original floor, feet collider and companion.
 var wall=StaticBody3D.new();wall.position=Vector3(9.25,.675,2.5);app.world.add_child(wall)
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2.5,5,.3);collider.shape=box;wall.add_child(collider)
 await frames(2)
 check(app.world.change_home_floor(app.state),"blocked stair request starts normally")
 await frames(160)
 check(not actor.stair_active and app.state.home_floor==0,"blocked stairs recover instead of changing floors")
 check(not actor.walking_shapes[1].disabled,"foot collision restored after stair recovery")
 check(app.world.companion==null or app.world.companion.is_physics_processing(),"companion recovers after failed climb")
 wall.queue_free();await frames(2)
 app.state.home_floor=1;app.state.profile.gender="female";app.world.sync(app.state)
 actor.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45);await frames(3)
 app.state.minute=22*60
 check(app.bed_session.begin(),"female character can lie on the upstairs bed")
 await await_bed("resting")
 var skeleton: Skeleton3D=actor.visual.find_children("*","Skeleton3D",true,false)[0]
 var head_bone := -1
 for bone in range(skeleton.get_bone_count()):
  if str(skeleton.get_bone_name(bone)).ends_with("Head"):head_bone=bone
 var head: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(head_bone).origin
 check(head.x>-5.8 and head.x<-3.8 and head.z>-5.69 and head.z<-2.4 and head.y>VillaDimensions.UPPER_FLOOR+.175,"head lies over mattress/pillow inside bed footprint")
 app.bed_session.sleep_to_morning();await frames(20)
 app.bed_session.finish();await await_bed("")
 check(not app.state.flags.get("slept",false) and app.state.hour()==22,"early waking does not award overnight sleep")
 check(app.bed_session.begin(),"bed can be used again after getting up")
 await await_bed("resting");app.bed_session.sleep_to_morning();await frames(180);await await_bed("")
 check(app.state.flags.get("slept",false) and app.state.hour()==6,"overnight sleep commits once after visible sleep")
 check(actor.bed_stage=="","overnight sleep ends standing at bedside")
 print("HOME ACTIONS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
