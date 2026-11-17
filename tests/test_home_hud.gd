extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var app: Node
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n: int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func await_bed(target: String) -> void:
 for i in range(400):
  if app.world.player.bed_stage==target:return
  await frames(1)
 check(false,"bed sequence did not reach "+target)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 await frames(3);app._sync_overlay_state()
 var quick=app.safe_root.get_node("QuickAccess")
 check(quick.get_child(0).text=="任务" and quick.get_child(1).text=="背包" and quick.get_child(2).text=="设置","quick action order")
 check(not app.goal_button.visible and not app.track_controls.visible,"idle task tracker is collapsed")
 app._update_context()
 check(not app.world.focus_ring.visible,"passive nearby objects have no floor ring")
 app._start_task("wood");app._refresh();app._sync_overlay_state()
 check(app.goal_button.visible and app.track_controls.visible,"real job shows compact tracker and controls")
 check("木材" in app.goal_button.text and "/12" in app.goal_button.text,"tracker shows actual task progress")
 app.track_toggle.pressed.emit();app._sync_overlay_state()
 check(not app.auto_task.running and app.track_toggle.text=="继续","inline pause keeps resumable task")
 app.track_toggle.pressed.emit()
 check(app.auto_task.running,"inline continue resumes task")
 app._cancel_tracked_task()
 check(app.auto_task.job=="" and not app.goal_button.visible,"cancel collapses tracking without resetting earned progress")
 app.state.location="villa";app.state.home_floor=1;app.state.player_position=[-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45];app.world.sync(app.state);await frames(3)
 app._sync_overlay_state()
 check(app.safe_root.find_children("*","Button",false,false).all(func(b):return not "上船" in b.text),"indoors has no boat/instant-exit HUD")
 check(app.bed_session.begin(),"bed rest begins")
 app._sync_overlay_state();app._update_context()
 check(app.joystick.visible and app.movement_enabled(),"rest keeps joystick live")
 check(app.sprint_action.visible and app.build_action.visible and not app.sprint_action.active and not app.build_action.active and app.context_action.title=="起床" and app.context_action.active,"rest uses a single wake action")
 app.joystick.direction=Vector2(.8,0);await frames(6)
 check(app.world.player.bed_stage=="approaching_rack","stick cannot cancel lying down")
 await await_bed("resting");app.joystick.reset();app._sync_overlay_state()
 check(app.world.player.bed_stage=="resting","holding stick leaves actor resting in bed")
 app._nearby_interact();await await_bed("");app._sync_overlay_state()
 check(app.sprint_action.visible and app.build_action.visible,"normal controls restore after rest")
 app.world.player.position=Vector3(-3,(VillaDimensions.UPPER_FLOOR+.03),-1.45);await frames(3)
 check(app.bed_session.begin(),"bed can be used again")
 await await_bed("resting");app._nearby_interact();await await_bed("")
 check(app.world.player.bed_stage=="","right thumb wake action gets up")
 print("HOME HUD: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
