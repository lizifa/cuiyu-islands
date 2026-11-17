extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frame() -> void:
 app.inactive=false;await physics_frame
func _initialize():call_deferred("run")
func run():
 Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.world.orbit.comfort_mode=false # Exercise optional close-up cameras.
 app.state.location="villa";app.state.home_floor=1;app.state.player_position=[-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45];app.world.sync(app.state)
 for gender:String in ["male","female"]:
  app.state.profile.gender=gender;app.world.sync(app.state)
  var actor:CharacterBody3D=app.world.player;actor.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45)
  for i in range(4):await frame()
  var surface:float=app.world.villa_room.bed_surface()
  check(surface-VillaDimensions.UPPER_FLOOR>.45 and surface-VillaDimensions.UPPER_FLOOR<.8,"bed mattress has a reachable sitting height "+gender)
  check(app.bed_session.begin(),"start bed motion "+gender)
  check(app.world.home_camera.owner_key=="bed" and app.world.home_camera.target_radius<4.5,"clothing camera owns a closer shot "+gender)
  var old:Dictionary={};var boundary_jump:float=0;var contact_error:float=0;var minimum_foot:float=INF;var rested:=false
  var bed_motion_seen:=false
  for i in range(4000):
   await frame()
   if actor.bed_stage=="":break
   var rig:Skeleton3D=actor.pose_skeleton;var motion:RefCounted=actor.bed_motion
   var phase:String=actor.bed_stage
   var feet:Array[Vector3]=[]
   for side:String in ["Left","Right"]:feet.append(rig.global_transform*rig.get_bone_global_pose(actor._bone(side+"Foot")).origin)
   if not old.is_empty() and (phase!=old.phase or motion.elapsed<.24):
    for side in range(2):boundary_jump=maxf(boundary_jump,feet[side].distance_to(old.feet[side]))
   if phase in ["removing_shoes","putting_shoes"] and motion.elapsed>.3:
    var progress:float=motion.elapsed/1.6;var inactive_side:int=1 if progress<.5 else 0
    contact_error=maxf(contact_error,feet[inactive_side].distance_to(motion._ground_foot(inactive_side)))
   for foot:Vector3 in feet:minimum_foot=minf(minimum_foot,foot.y)
   if phase=="boarding":bed_motion_seen=app.world.home_camera.owner_key=="bed" and app.world.home_camera.target_fov==64
   if phase=="resting" and not rested:
    var pelvis:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("Hips")).origin
    check(pelvis.y>surface+.07 and feet[0].y>surface+.05,"lying body stays above mattress "+gender)
    app.bed_session.finish();rested=true
   old={"phase":phase,"feet":feet}
  check(rested and actor.bed_stage=="","full entry and wake sequence completes "+gender)
  check(boundary_jump<.09,"foot phase transitions are continuous "+gender+" maximum "+str(boundary_jump))
  check(contact_error<.045,"seated foot contacts are reachable "+gender+" maximum "+str(contact_error))
  check(minimum_foot>=4.96,"feet do not sink through floor "+gender)
  check(bed_motion_seen,"bedside action uses its own framing "+gender)
  for i in range(2):await frame()
  check(app.world.home_camera.owner_key=="","wake releases bed camera "+gender)
 print("BED CONTACTS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
