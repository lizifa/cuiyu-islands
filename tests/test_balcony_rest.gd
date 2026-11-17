extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 var app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app._close_drawers();app.paused=false;app.inactive=false;app.set_process(false);app.set_physics_process(false)
 var floor_y:float=app.world.Villa.Dimensions.UPPER_FLOOR
 app.state.location="villa";app.state.home_floor=1;app.state.player_position=[-1.55,floor_y+.03,22.2];app.world.sync(app.state)
 await physics_frame;await physics_frame
 var actor:CharacterBody3D=app.world.player;actor.set_physics_process(false);app.world.set_process(false);app.world.orbit.set_process(false)
 var safe:Vector3=actor.position
 check(app.world.nearby_action().kind=="villa_balcony_rest","chair nearby prompt")
 check(app.sofa_session.begin_balcony(),"balcony recline begins")
 app.state.energy=50
 for frame in range(300):
  actor._update_sofa(1./60);app.sofa_session._physics_process(1./60);app.world.orbit.motion_enabled=true;app.world.orbit._process(1./60)
 check(actor.sofa_reclining and actor.sofa_seated,"resting uses reclined pose")
 var rig:Skeleton3D=actor.pose_skeleton
 var head:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("Head")).origin
 var hip:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("Hips")).origin
 check(head.z<hip.z-.35,"head leans back onto recliner")
 app._sync_overlay_state();app._update_context()
 check(app.sprint_action.visible and app.build_action.visible,"recliner shows contextual auxiliary buttons")
 app.sprint_action.pressed.emit();check(not app.sofa_session.rocking,"auxiliary toggles quiet reclining")
 app.build_action.pressed.emit();check(app.sofa_session.stretch_time==0,"auxiliary starts stretch")
 for frame in range(60):app.sofa_session._physics_process(1./60);actor._update_sofa(1./60)
 check(actor.sofa_stretch>.5,"stretch actually animates upper body")
 app.sofa_session.rocking=true;app.sofa_session._physics_process(.1)
 check(app.state.energy>50,"rest restores energy")
 check(app.world.save_position().is_equal_approx(safe),"save uses safe chair-side stand")
 check(app.world.orbit._body_framed(actor),"rest camera contains body")
 var balcony:Node=app.world.props.get_node("AccessibleUpperBalcony")
 check(absf(balcony.rocker.rotation.x)>.005,"chair gently rocks")
 var before:float=app.sofa_session.elapsed;app.paused=true;app.sofa_session._physics_process(1);check(app.sofa_session.elapsed==before,"pause freezes rest")
 app.paused=false;actor.move_input=Vector2.UP;app.sofa_session._physics_process(.1)
 check(app.sofa_session.active,"joystick cannot pull resting character out")
 app._update_context();check(app.context_action.title=="起身","rest action is stand up")
 app._nearby_interact()
 check(not app.sofa_session.active and not actor.sofa_reclining,"stand action clears rest")
 check(actor.position.is_equal_approx(safe) and actor.collision_mask==1,"stand restores safe position and collision")
 check(is_zero_approx(balcony.rocker.rotation.x),"chair settles after standing")
 print("BALCONY REST: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
