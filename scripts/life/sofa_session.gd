extends Node
## A visible, interruptible home rest. Rewards accrue only during active play.
var app: Node
var active := false
var panel: PanelContainer
var tv_button: Button
var media_controls:HBoxContainer
var pause_button:Button
var label: Label
var mode:="sofa"
var eat_button:Button
var food_time:float=-1
var food_committed:=false
var food_prop:MeshInstance3D
var elapsed := 0.0
var rocking:=true
var stretch_time:float=-1
func setup(owner_app: Node) -> void:
	app = owner_app
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", app.panel())
	app.safe_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -205; panel.offset_right = 205
	panel.offset_top = -150; panel.offset_bottom = -20
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	label = app.label("坐在沙发上休息 · 正在恢复", 19)
	rows.add_child(label)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	tv_button = app.button(buttons,"打开电视",toggle_tv)
	eat_button=app.button(buttons,"吃东西",begin_eating);eat_button.hide()
	app.button(buttons,"起身",finish)
	media_controls=HBoxContainer.new();rows.add_child(media_controls)
	pause_button=app.button(media_controls,"暂停播放",func():
		var television:Node=app.world.villa_room.get_node("HomeTelevision")
		television.toggle_pause();pause_button.text="继续播放" if television.user_paused else "暂停播放")
	for adjustment:int in [-1,1]:
		app.button(media_controls,"音量−" if adjustment<0 else "音量+",func():
			var television:Node=app.world.villa_room.get_node("HomeTelevision")
			television.set_volume(television.volume_db+adjustment*4))
	panel.hide()
func begin() -> bool:
	if active or app.state.location != "villa" or app.state.home_floor != 0: return false
	var actor: CharacterBody3D = app.world.player
	var origin: Vector3 = actor.position
	if Vector2(origin.x-app.world.Villa.SOFA_STAND.x,origin.z-app.world.Villa.SOFA_STAND.z).length() > 1.6: return app.state.say("先走到客厅沙发旁，再坐下休息。")
	if app.auto_task.running: app.auto_task.stop("")
	if not actor.sit_on_sofa(app.world.Villa.SOFA_SEAT,app.world.villa_room.sofa_surface(),app.world.Villa.SOFA_FACING): return false
	mode="sofa";tv_button.show();eat_button.hide();media_controls.show();label.text="坐在沙发上休息 · 正在恢复"
	app.world.home_camera.sofa(app.world)
	active = true
	elapsed = 0
	panel.show()
	tv_button.text = "关闭电视" if app.world.home_tv_on else "打开电视"
	app.state.log_event("坐在沙发上歇一会儿，体力会慢慢恢复；也可以打开电视。")
	return true
func toggle_tv() -> void:
	if not active or not app.movement_enabled(): return
	app.world.set_home_tv(not app.world.home_tv_on)
	tv_button.text = "关闭电视" if app.world.home_tv_on else "打开电视"
func finish() -> void:
	if not active: return
	active = false
	app.world.home_camera.release(app.world,"sofa" if mode=="sofa" else "eating")
	if mode in ["dining","balcony"] and app.world.orbit.stable_third_person:app.world.orbit.end_activity_view("balcony_rest" if mode=="balcony" else mode)
	if mode=="balcony":
		var balcony:Node=app.world.props.get_node_or_null("AccessibleUpperBalcony")
		if balcony!=null:balcony.set_rock(0)
	food_time=-1
	if is_instance_valid(food_prop):food_prop.queue_free();food_prop=null
	app.world.player.leave_sofa()
	if mode=="balcony" and app.world.on_balcony() and app.world.orbit.stable_third_person:
		app.world.orbit.begin_activity_view("balcony",app.world.player.position+Vector3.UP*1.2,.65,7.0,deg_to_rad(16))
	panel.hide()
	app._save(false)
func _physics_process(delta: float) -> void:
	if not active: return
	if app.state.location != "villa" or app.state.home_floor != (1 if mode=="balcony" else 0) or not app.world.player.sofa_seated:
		finish(); return
	if not app.movement_enabled(): return
	if mode!="balcony" and app.world.player.move_input.length() > 0.15:
		finish(); return
	if food_time>=0:
		food_time+=delta;app.world.player.seated_eat_time=food_time
		if is_instance_valid(food_prop) and app.world.player.pose_skeleton!=null:
			var rig:Skeleton3D=app.world.player.pose_skeleton
			food_prop.global_position=rig.global_transform*rig.get_bone_global_pose(app.world.player._bone("RightHand")).origin
		if food_time>=.9 and not food_committed:
			food_committed=true;app._act(app.state.eat)
		if food_time>=2.3:
			app.world.home_camera.release(app.world,"eating")
			food_time=-1;app.world.player.seated_eat_time=-1
			if is_instance_valid(food_prop):food_prop.queue_free();food_prop=null
		label.text="坐着吃东西…" if food_time>=0 else "坐在餐桌旁 · 可以吃东西"
		eat_button.disabled=food_time>=0
	if mode=="dining":return
	if app.perf_probe: return
	elapsed += delta
	if mode=="balcony":
		var balcony:Node=app.world.props.get_node_or_null("AccessibleUpperBalcony")
		if balcony!=null:balcony.set_rock(elapsed,app.world.player.sofa_blend if rocking else 0.0)
		app.world.player.sofa_rock=sin(elapsed*.85)*.035 if rocking else 0.0
		if stretch_time>=0:
			stretch_time+=delta
			app.world.player.sofa_stretch=sin(clampf(stretch_time/2.8,0,1)*PI)
			if stretch_time>=2.8:stretch_time=-1;app.world.player.sofa_stretch=0
	app.state.energy = minf(100,app.state.energy + delta / 6.0)
	app.state.health = minf(100,app.state.health + delta / 6.0)

func begin_dining(selected_chair:Node3D=null) -> bool:
	if active or app.state.location!="villa" or app.state.home_floor!=0:return false
	var actor:CharacterBody3D=app.world.player
	var selected:Node3D=selected_chair
	var distance:float=actor.position.distance_to(selected.global_position) if is_instance_valid(selected) else INF
	for chair:Node3D in app.world.villa_room.find_children("DiningChair*","Node3D",false,false):
		var d:float=actor.position.distance_to(chair.global_position)
		if selected_chair==null and d<distance:distance=d;selected=chair
	if selected==null or distance>2.2:return app.state.say("走近餐桌，正面对着它再坐下。")
	if not app.world.facing_point({"pos":app.world.villa_room.to_global(app.world.Villa.DINING_CENTER),"range":2.4}):return app.state.say("先正面对餐桌再坐下。")
	var anchor:Vector3=selected.global_position;anchor.y=app.world.terrain_height(anchor.x,anchor.z)+.03
	var facing:Vector3=selected.global_basis.z.normalized()
	if not actor.sit_on_sofa(anchor,selected.global_position.y+.6,atan2(facing.x,facing.z),.38):return false
	active=true;mode="dining";elapsed=0;food_time=-1
	if app.world.orbit.stable_third_person:
		app.world.orbit.begin_activity_view("dining",anchor+Vector3.UP*1.55,atan2(facing.x,.85),6.2,deg_to_rad(18))
	if not app.world.orbit.comfort_mode:app.world.orbit.target_yaw=(.8 if facing.x>0 else -.8)-app.world.indoor_camera.retained_angle
	app.world.orbit.view_transition=.8
	media_controls.hide();tv_button.hide();eat_button.show();eat_button.disabled=false
	label.text="坐在餐桌旁 · 可以吃东西";panel.show();app.state.log_event("在餐桌旁坐下，准备吃东西。");return true
func begin_eating() -> void:
	if not active or mode!="dining" or food_time>=0 or not app.movement_enabled():return
	var found:=false
	for item:String in ["浆果","蔬菜","鱼干","鲜鱼"]:
		if app.state.count(item)>0:found=true;break
	if not found:app.state.say("背包里没有可以吃的食物。");return
	app.world.home_camera.begin(app.world,"eating",app.world.player.position+Vector3.UP*.95,atan2(app.world.player.visual.global_basis.z.x,app.world.player.visual.global_basis.z.z)+.6,2.9,2.25,60)
	food_time=0;food_committed=false;eat_button.disabled=true
	food_prop=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.075;sphere.height=.15;sphere.radial_segments=10;sphere.rings=5;food_prop.mesh=sphere
	food_prop.material_override=app.world.material(Color("c27c43"));app.world.add_child(food_prop)
	var rig:Skeleton3D=app.world.player.pose_skeleton
	food_prop.global_position=rig.global_transform*rig.get_bone_global_pose(app.world.player._bone("RightHand")).origin

func begin_balcony() -> bool:
	if active or not app.world.on_balcony():return false
	var at:Vector3=Vector3(-3,app.world.Villa.Dimensions.UPPER_FLOOR+.03,22.2)
	var actor:CharacterBody3D=app.world.player
	if actor.position.distance_to(at+Vector3.RIGHT*1.45)>1.8:return app.state.say("先走到阳台摇摇椅旁。")
	if not actor.sit_on_sofa(at,at.y+.84,0):return false
	actor.sofa_reclining=true
	if app.auto_task.running:app.auto_task.stop("")
	active=true;mode="balcony";elapsed=0;food_time=-1;rocking=true;stretch_time=-1
	tv_button.hide();eat_button.hide();media_controls.hide();label.text="躺在摇摇椅上看海 · 正在恢复精力";panel.show()
	app.sprinting=false;app.sprint_action.reset()
	if app.world.orbit.stable_third_person:app.world.orbit.begin_activity_view("balcony_rest",at+Vector3(0,1.25,-.25),.95,7.5,deg_to_rad(18))
	app.state.log_event("躺进摇摇椅，听着海浪歇一会儿；点击起身离开。")
	return true

func toggle_rocking() -> void:
	if not active or mode!="balcony" or not app.movement_enabled():return
	rocking=not rocking
	label.text="轻轻摇晃 · 听海休息" if rocking else "静静躺着 · 看海休息"
	app._update_context()
func stretch() -> void:
	if not active or mode!="balcony" or stretch_time>=0 or not app.movement_enabled():return
	stretch_time=0;label.text="伸个懒腰，放松一下"
