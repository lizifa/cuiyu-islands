extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.set_physics_process(false);app._close_drawers();app.inactive=false;app.paused=false
 await physics_frame;await physics_frame
 var actor:CharacterBody3D=app.world.player;actor.set_physics_process(false);app.world.orbit.set_process(false)
 actor.position=Vector3(-1,.68,16.1);actor.move_input=Vector2.ZERO
 var session:Node=app.fishing_session
 check(session.begin(),"start fishing")
 session.set_physics_process(false)
 check(not session.ripple.visible and not session.bobber.visible,"no ripple or floating float before casting")
 session._set_stage("charging");session._update_visual(0)
 check(not session.ripple.visible,"charging creates no water disturbance")
 session.cast_target=session.origin+Vector3(0,-.84,22)
 var count:int=session.water_impact_count
 session._set_stage("casting")
 for moment:float in [0.0,.2,.5,.85,1.1,1.19]:
  session.elapsed=moment;session._update_visual(0)
  check(not session.ripple.visible and not session.water_contact,"airborne float has no water ring at "+str(moment))
 check(session.water_impact_count==count,"airborne cast emits no impact")
 session.elapsed=session.CAST_DURATION-.01;session.wait_time=100;session._physics_process(.02)
 check(session.stage=="waiting" and session.water_contact and session.ripple.visible,"impact appears only after float reaches water")
 check(session.water_impact_count==count+1,"one impact per cast")
 check(Vector2(session.bobber.position.x-session.cast_target.x,session.bobber.position.z-session.cast_target.z).length()<.001,"impact coincides with actual float landing point")
 check(absf(session.ripple.position.y+.235)<.001,"water ripple lies on sea surface rather than beneath it")
 var age:float=session.impact_age
 for frame in range(30):session._physics_process(1./60)
 check(session.water_impact_count==count+1 and session.impact_age>age,"waiting ages the same impact instead of restarting it")
 var paused_age:float=session.impact_age;app.paused=true;session._physics_process(1);app.paused=false
 check(session.impact_age==paused_age,"pause freezes impact expansion")
 session._set_stage("bite");session._update_visual(.1)
 # A take sends a fresh ring out at the float, but it is not a new cast splash.
 check(session.water_impact_count==count+1 and session.impact_age<paused_age,"bite restarts the ripple at the float without a new splash")
 session._set_stage("reeling");session.progress=.5;session._update_visual(.1)
 check(Vector2(session.ripple.position.x-session.bobber.position.x,session.ripple.position.z-session.bobber.position.z).length()<.001,"reeling water disturbance follows float")
 session._set_stage("ready");session._update_visual(0)
 check(not session.ripple.visible and not session.water_contact,"new cast clears old water disturbance")
 session._set_stage("casting");session.elapsed=.4;session._update_visual(0);session._result("提竿过早")
 session._update_visual(0)
 check(not session.ripple.visible and session.water_impact_count==count+1,"early retrieval never creates a landing ripple")
 session.cancel()
 print("FISHING WATER CONTACT: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
