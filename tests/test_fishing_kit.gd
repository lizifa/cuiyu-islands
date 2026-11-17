extends SceneTree
const Platform=preload("res://scripts/life/fishing_platform.gd")
var app: Node
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n: int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func until(value: String) -> void:
 for i in range(500):
  if app.fishing_session.stage==value:return
  await frames(1)
 check(false,"did not reach "+value+" current "+app.fishing_session.stage)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=8;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 await frames(3)
 var state: RefCounted=app.state
 var session: Node=app.fishing_session
 var actor: CharacterBody3D=app.world.player
 check(app.world.props.find_child("FishingStoolSeat",true,false)!=null,"fishing station keeps one stool")
 for name_value:String in ["LandingNet","RodRest","SpareSeaRod","TackleBox","BaitBucket","FishMeasuringMat","FishingPliers","HookRemover","SpareFloat"]:
  check(app.world.props.find_child(name_value,true,false)==null,"idle station removes "+name_value)
 check(is_instance_valid(app.world.fish_keeper) and not app.world.fish_keeper.visible,"fish keeper stays hidden until fishing")
 var legacy: Dictionary=state.snapshot();legacy.inventory.erase("饵料")
 check(state.restore(legacy) and state.count("饵料")==0,"legacy inventory migrates without losing progress or granting free bait")
 state.energy=0;state.inventory["浆果"]=1
 actor.position=Vector3(-1,.68,15.7)
 check(session.begin() and state.energy==0,"zero-energy player can cast without resting")
 check(app.world.fish_keeper.visible,"storage equipment appears only while fishing")
 for i in range(600):
  if app.world.orbit.activity_view_ready("fishing"):break
  await frames(1)
 session.interact() # Explicit press/release cast after the third-person view settles.
 session.fish_roll=.15
 await until("waiting");await frames(10)
 check(session.seat_blend>.9,"waiting eases into seated posture")
 var hip: int=actor._bone("Hips")
 var hip_y: float=(actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(hip)).origin.y
 check(absf(hip_y-(Platform.SEAT.y+.48))<.08,"hips align with actual stool seat")
 var starting_energy: float=state.energy
 app._process(1)
 check(state.energy==starting_energy,"normal fishing clock does not drain energy")
 session.use_bait()
 check(state.count("浆果")==0 and state.count("饵料")==3 and state.energy==0,"bait crafting consumes one berry and creates three portions without fatigue")
 session.use_bait()
 check(session.stage=="chumming" and state.count("饵料")==2,"chumming spends exactly one bait")
 session.use_bait()
 check(state.count("饵料")==2,"repeated taps cannot spend bait during throw")
 await frames(3)
 check(session.bait_cloud.visible,"thrown bait is represented in the world")
 await until("bite")
 check(session.big_fish,"chumming upgrades the same roll into a big-fish bite")
 session.interact();check(session.stage=="standing","big bite starts a standing transition")
 await until("reeling")
 var standing_y: float=(actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(hip)).origin.y
 check(session.seat_blend<.05 and standing_y>hip_y+.4,"big-fish fight visibly stands up from stool")
 for i in range(800):
  if session.stage!="reeling":break
  session.held=session.tension<.65;await frames(1)
 check(session.stage=="net_ready" and state.count("鲜鱼")==0,"big fish awaits an explicit net scoop before reward")
 await frames(12)
 check(state.count("鲜鱼")==0,"waiting at shoreline never awards fish automatically")
 session.interact();await frames(4)
 check(session.net_tool.visible and session.stage=="landing","net is held and scoops during landing")
 await until("result")
 check(session.landed and state.count("鲜鱼")==0 and state.kept_portions()==2,"successful big fish yields two fresh-fish portions once")
 await frames(15)
 check(state.count("鲜鱼")==0 and state.kept_portions()==2,"landing cannot duplicate reward")
 var return_pos: Vector3=actor.fishing_return
 check(app.world.save_position()==return_pos,"save records safe standing position outside stool")
 session.cancel()
 check(actor.position==return_pos and actor.collision_mask==1,"leaving stool restores position and physics")
 state.inventory["浆果"]=0;state.inventory["饵料"]=0
 var before: Dictionary=state.snapshot()
 check(not state.craft("饵料") and state.inventory==before.inventory,"missing bait materials never mutate inventory")
 check(state.labor("捕鱼") and state.energy==0,"legacy fishing action also works at zero energy without fatigue")
 app.state.profile.gender="female";app.world.sync(app.state);await frames(3)
 actor.position=Vector3(-1,.68,15.7)
 check(session.begin(),"female character can use seated shore kit")
 for i in range(600):
  if app.world.orbit.activity_view_ready("fishing"):break
  await frames(1)
 session.interact()
 session.fish_roll=.99
 await until("waiting");await frames(10)
 var female_hip: int=actor._bone("Hips")
 var female_y: float=(actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(female_hip)).origin.y
 check(absf(female_y-(Platform.SEAT.y+.48))<.08,"female hips align with same stool seat")
 session.cancel()
 app.queue_free();await process_frame
 print("FISHING KIT: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
