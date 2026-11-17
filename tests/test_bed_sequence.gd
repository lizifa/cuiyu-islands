extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n:int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.state.location="villa";app.state.home_floor=1;app.state.player_position=[-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45];app.world.sync(app.state)
 await frames(3)
 var actor=app.world.player
 check(app.bed_session.begin(),"start authored bed sequence")
 var entry:Array[String]=[];var biggest:=0.;var clothing_removed:=false
 for i in range(500):
  var before:Vector3=actor.position
  if not actor.bed_stage in entry:entry.append(actor.bed_stage)
  await frames(1)
  biggest=maxf(biggest,before.distance_to(actor.position))
  if actor.bed_motion!=null and not actor.bed_motion.clothing_on:clothing_removed=true
  if actor.bed_stage=="resting":break
 print("ENTRY ",entry," pos ",actor.position," max step ",biggest)
 check(entry==["approaching_rack","undressing","hanging_cloak","approaching_bed","sitting_down","removing_shoes","boarding","lying_down"],"remove cloak, approach, board, recline in order")
 check(actor.bed_stage=="resting","entry reaches resting")
 check(actor.bed_motion.footwear.shoes.size()==2 and not actor.bed_motion.footwear.source.visible,"equipped shoes removed and pair left beside bed")
 check(clothing_removed,"cloak removed by clothing gesture")
 check(actor.bed_motion!=null and actor.bed_motion.hung and actor.bed_motion.outfit.global_position.distance_to(actor.bed_motion.rack_hook)<.01,"resting clothes hang on rack rather than bed")
 check(actor.bed_motion.garment_body!=null and actor.bed_motion.garment_body.collision_layer==1,"hanging clothes retain physical collision")
 check(actor.bed_motion!=null and actor.bed_motion.eyes_closed>.99,"resting eyes closed")
 check(biggest<.3,"entry has no position teleport")
 var pause:Vector3=actor.position;app.paused=true;await frames(10)
 check(actor.position.distance_to(pause)<.001,"pause freezes choreography")
 app.paused=false
 app.bed_session.finish()
 var exit:Array[String]=[];var planted:=false;biggest=0
 for i in range(500):
  var before:Vector3=actor.position
  if actor.bed_stage!="" and not actor.bed_stage in exit:exit.append(actor.bed_stage)
  if actor.bed_stage=="getting_off":
   var skeleton:Skeleton3D=actor.pose_skeleton
   var foot:Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(actor._bone("LeftFoot")).origin
   planted=planted or absf(foot.y-(actor.bed_return.y+.09*skeleton.global_basis.get_scale().y))<.04
  await frames(1);biggest=maxf(biggest,before.distance_to(actor.position))
  if actor.bed_stage=="":break
 print("EXIT ",exit," pos ",actor.position," max step ",biggest)
 check(exit==["eyes_opening","sitting_up","moving_feet","putting_shoes","getting_off","stepping_clear","taking_cloak","dressing"],"open eyes, sit, plant feet, get off, walk clear, dress in order")
 check(actor.bed_stage=="","wake sequence completes")
 check(planted,"feet reach floor before standing")
 check(biggest<.3,"wake has no position teleport")
 var cape=actor.visual.find_child("attach-neck-mesh",true,false)
 check(cape==null or cape.visible,"cape restored after dressing")
 check(actor.visual.find_child("attach-feet-mesh",true,false).visible,"shoes restored after sitting to put them on")
 check(actor.collision_mask==1 and actor.collision_layer==2,"standing collision restored")
 check(actor.bed_motion==null and app.world.find_children("BedOutfit","Node3D",true,false).is_empty(),"held garment cleaned up")
 await frames(2)
 # Female profile uses the same motion chain and removes only clothing actually equipped.
 app.state.profile.gender="female";app.world.sync(app.state);actor.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45);await frames(3)
 check(app.bed_session.begin(),"female bed sequence begins")
 for i in range(300):
  await frames(1)
  if actor.bed_stage=="resting":break
 check(actor.bed_stage=="resting" and actor.bed_motion.covers.size()==2,"female reaches rest with two eyelids")
 app.bed_session.finish();await frames(3)
 var wake_stage:String=actor.bed_stage;var wake_time:float=actor.bed_motion.elapsed
 app.bed_session.finish()
 check(actor.bed_stage==wake_stage and actor.bed_motion.elapsed>=wake_time,"repeated wake cannot restart choreography")
 for i in range(300):
  await frames(1)
  if actor.bed_stage=="":break
 check(actor.bed_stage=="" and actor.visual.find_child("attach-hat-mesh",true,false).visible,"female finishes with hat restored")
 await frames(2);actor.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45);await frames(2)
 check(app.bed_session.begin(),"start interrupted entry")
 for i in range(250):
  await frames(1)
  if actor.bed_stage=="boarding":break
 var last:Vector3=actor.position;app.bed_session.finish();var interruption_jump:=0.
 for i in range(300):
  await frames(1);interruption_jump=maxf(interruption_jump,last.distance_to(actor.position));last=actor.position
  if actor.bed_stage=="":break
 check(actor.bed_stage=="" and interruption_jump<.3,"early wake transitions continuously from boarding")
 await frames(2);actor.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45);await frames(2);app.bed_session.begin()
 for i in range(300):
  await frames(1)
  if actor.bed_stage=="resting":break
 var inventory:Dictionary=app.state.inventory.duplicate()
 app.bed_session.cancel()
 check(actor.bed_motion==null and actor.bed_stage=="" and actor.collision_mask==1,"forced cancellation restores normal motion")
 check(app.world.find_children("BedOutfit","Node3D",true,false).is_empty() and actor.visual.find_children("BedEyelids","Node3D",true,false).is_empty(),"cancel cleans up garment and eyelids")
 check(app.state.inventory==inventory,"choreography consumes no resources")
 app.bed_session.begin();await frames(3);app.queue_free();await process_frame
 print("BED SEQUENCE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
