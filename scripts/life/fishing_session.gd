extends Node
const Catalog=preload("res://scripts/life/fish_catalog.gd")
const Storage=preload("res://scripts/life/fishing_storage.gd")
const Landing = preload("res://scripts/life/fishing_landing.gd")
const Platform = preload("res://scripts/life/fishing_platform.gd")
const CAST_WINDUP:=.25
const CAST_FLIGHT:=.95
const CAST_DURATION:=CAST_WINDUP+CAST_FLIGHT
var bite_audio:AudioStreamPlayer
var bite_audio_enabled:=true
var joining_position := Vector3.INF
var join_distance:=0.0
var join_dir:=Vector3.ZERO
var join_from:=Vector3.ZERO
var view_group:=""
var cast_power:float=.65
var cast_target:Vector3=Platform.FLOAT
var app: Node
var active := false
var big_fish := false
var fish_roll := 1.0
var size_roll:float=.5
var species_roll:float=.5
var fish_species:String="bass"
var fish_mass:float=.65
var chummed := false
var bait_return_stage:="waiting"
var seat_blend := 0.0
var net_tool: Node3D
var bait_cloud: MultiMeshInstance3D
var action_title := "等待"
var rows: VBoxContainer
var progress_row: HBoxContainer
var tension_row: HBoxContainer
var float_hint: Label
var stage := ""
var elapsed := 0.0
var wait_time := 3.0
var tension := .35
var bend_load:float=.08
var progress := 0.0
var danger := 0.0
var held := false
var awarded := false
var landed := false
var water_contact:=false
var impact_age:=0.0
var water_impact_count:=0
var ripple: MeshInstance3D
var reel_handle: Node3D
var origin := Vector3.ZERO
var view: Node3D
var camera_state: Dictionary = {}
var camera_revision := -1
var rod_segments: Array[MeshInstance3D] = []
var reel_angle := 0.0
var rod: Node3D
var rod_tube: MeshInstance3D
var bobber: MeshInstance3D
var fish: Node3D
var fish_center:=Vector3.ZERO
var line: ImmediateMesh
var line_node:MeshInstance3D
var panel: PanelContainer
var hint: Label
var progress_bar: ProgressBar
var tension_bar: ProgressBar
func setup(owner_app: Node) -> void:
	app=owner_app
	if app.world.orbit.first_person or app.world.orbit.stable_third_person:_setup_bite_audio()
	panel=PanelContainer.new();panel.name="FishingStatus"
	panel.add_theme_stylebox_override("panel",app.compact_panel(Color("142e354d"),6))
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	app.safe_root.add_child(panel)
	rows=VBoxContainer.new();rows.add_theme_constant_override("separation",4);panel.add_child(rows)
	hint=app.label("钓台垂钓",16);hint.name="FishingPhase"
	hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.clip_text=true
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.y=22;rows.add_child(hint)
	progress_row=HBoxContainer.new();rows.add_child(progress_row)
	progress_bar=_meter(progress_row,"收线","收线进度")
	tension_row=HBoxContainer.new();rows.add_child(tension_row)
	tension_bar=_meter(tension_row,"张力","鱼线张力：太高断线，太低脱钩")
	for node: Control in panel.find_children("*","Control",true,false):node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	float_hint=app.label("",20,Color("ffe3a0"));float_hint.name="FishingFloatHint"
	float_hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	float_hint.clip_text=true;float_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	float_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	float_hint.add_theme_color_override("font_outline_color",Color("142e35"))
	float_hint.add_theme_constant_override("outline_size",5)
	float_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	app.safe_root.add_child(float_hint)
	app.safe_root.resized.connect(_layout_hud)
	panel.hide();float_hint.hide()
func _meter(row: HBoxContainer, title: String, tooltip: String) -> ProgressBar:
	row.add_theme_constant_override("separation",8)
	var caption: Label=app.label(title,14)
	caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	caption.custom_minimum_size.x=40
	row.add_child(caption)
	var meter := ProgressBar.new();meter.show_percentage=false
	meter.tooltip_text=tooltip;meter.custom_minimum_size=Vector2(100,8)
	meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var background := StyleBoxFlat.new();background.bg_color=Color("183b4399");background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new();fill.bg_color=Color("8fcbb5");fill.set_corner_radius_all(4)
	meter.add_theme_stylebox_override("background",background);meter.add_theme_stylebox_override("fill",fill)
	row.add_child(meter)
	return meter
func _view_group(value: String) -> String:
	match value:
		"waiting", "chumming": return "wait"
		"bite", "standing", "hooking", "reeling": return "fight"
		"net_ready", "landing": return "net"
		"storing", "result": return "bag"
		_: return "ready"
func _view_spec(group: String) -> Array:
	match group:
		"wait": return [Vector3(0,.95,5.0),PI-.42,11.0,15.0]
		# 景别要能容下「整个人 + 鱼竿杆梢 + 抄网」：原来的 4.2~5.2 米近距离会把杆梢顶出画面。
		"fight": return [Vector3(0,1.25,1.6),PI-.34,6.8,24.0]
		"net": return [Vector3(-.3,1.2,3.0),PI-.55,10.0,20.0]
		"bag": return [Vector3(-.3,1.2,2.6),PI-.55,9.6,20.0]
		_: return [Vector3(0,1.05,.1),PI-.55,6.5,12.0]
func _apply_view(value: String) -> void:
	# One deliberate cut per beat: sit-and-cast close, waiting two-shot with the
	# float, low fight angle on the bent rod, then the net and the keep net.
	var orbit: Node = app.world.orbit
	if not orbit.stable_third_person or orbit.first_person or orbit.manual_view_locked: return
	if value=="ready" and joining_position.is_finite(): return
	var group: String = _view_group(value)
	var spec: Array = _view_spec(group)
	var changed: bool = group != view_group
	orbit.focus_activity("fishing",origin+spec[0],spec[1],spec[2],deg_to_rad(spec[3]),changed)
	if changed:
		view_group=group
		if is_instance_valid(orbit.cut_overlay) or changed: orbit.fade_cut()
func show_keep() -> void:
	var total: int = app.state.kept_portions()
	if total <= 0:
		app.state.say("鱼护是空的，先钓上一条。")
		return
	var lines: PackedStringArray = []
	for fish: Dictionary in app.state.fish_keep:
		var species: String = str(fish.get("species",""))
		var fish_name: String = str(Catalog.DATA.get(species,{}).get("name",species))
		lines.append("%s · %d 份 · 约 %.1f 公斤"%[fish_name,int(fish.get("portions",1)),float(fish.get("weight",0))])
	app._show_help("鱼护 · 共 %d 份"%total,"%s\n\n收竿离开时自动装入背包；鲜鱼可带回加工鱼干。"%"\n".join(lines))
func sync_controls() -> void:
	if not active:return
	for slot:Control in [app.context_action,app.sprint_action,app.build_action,app.boat_stop_action,app.boat_home_action]:slot.show()
	app.boat_stop_action.clear_skill();app.boat_home_action.clear_skill()
	var enabled: bool=app.movement_enabled()
	var settling: bool=app.world.orbit.stable_third_person and not app.world.orbit.activity_settled
	app.context_action.set_title("就位中" if settling else action_title)
	app.context_action.active=enabled and not settling and stage in ["ready","charging","bite","reeling","net_ready","result"]
	app.sprint_action.set_title("已撒饵" if chummed else ("撒饵" if app.state.count("饵料")>0 else "制饵"))
	app.sprint_action.set_badge(str(app.state.count("饵料")) if app.state.count("饵料")>0 and not chummed else "")
	app.sprint_action.active=enabled and stage in ["ready","waiting"] and not chummed
	app.sprint_action.show()
	if stage=="reeling":
		app.sprint_action.set_title("卸力");app.sprint_action.set_badge("");app.sprint_action.active=enabled
	elif stage=="result":
		app.sprint_action.set_title("钓具");app.sprint_action.set_badge("");app.sprint_action.active=enabled
	app.build_action.set_title("收竿离开");app.build_action.active=enabled
	app.boat_stop_action.set_title("鱼护");app.boat_stop_action.set_badge(str(app.state.kept_portions()))
	app.boat_stop_action.active=enabled and stage not in ["landing","storing"]
func _process(_delta: float) -> void:
	_layout_hud()
func _layout_hud() -> void:
	if not is_instance_valid(panel):return
	if not active or not app.movement_enabled():
		panel.hide();float_hint.hide();return
	panel.show()
	var fighting: bool=stage in ["reeling","net_ready","landing","storing"]
	progress_row.visible=fighting or stage=="charging";
	(progress_row.get_child(0) as Label).text="蓄力" if stage=="charging" else "收线";tension_row.visible=stage=="reeling"
	panel.modulate.a=.65 if stage=="waiting" else 1.0
	var width: float=minf(400,maxf(240,app.safe_root.size.x-540))
	var height: float=rows.get_combined_minimum_size().y+12
	var header: Control=app.safe_root.get_node("MobileHeader")
	panel.position=Vector2(maxf(12,app.safe_root.size.x-width-12),header.position.y+header.size.y+8)
	panel.size=Vector2(width,height)
	# Let the compact HUD use the free top space instead of rotating the world
	# to keep the actor out of its way. The minimap keeps its own left column.
	var local_canvas:Transform2D=app.safe_root.get_global_transform_with_canvas().affine_inverse()
	var actor_head:Vector2=Vector2(-1000,-1000) if app.world.orbit.first_person else local_canvas*app.world.camera.unproject_position(app.world.player.position+Vector3.UP*2.4)
	var actor_feet:Vector2=Vector2(-1000,-1000) if app.world.orbit.first_person else local_canvas*app.world.camera.unproject_position(app.world.player.position)
	var actor_bounds:=Rect2(Vector2(minf(actor_head.x,actor_feet.x)-40,minf(actor_head.y,actor_feet.y)),Vector2(absf(actor_head.x-actor_feet.x)+80,absf(actor_head.y-actor_feet.y)))
	var left:float=clampf((local_canvas*app.minimap.get_global_rect().end).x+12,12,maxf(12,app.safe_root.size.x-width-12))
	for x:float in [maxf(12,app.safe_root.size.x-width-12),left,(app.safe_root.size.x-width)*.5]:
		var candidate:=Rect2(Vector2(x,panel.position.y),panel.size)
		if not candidate.intersects(actor_bounds):panel.position.x=x;break
	float_hint.hide()
	var text := ""
	if stage=="waiting" and app.world.orbit.first_person:text="◉ 浮漂"
	elif stage=="bite":text="咬钩了！提竿"
	elif stage=="net_ready":text="鱼已收近 · 使用抄网"
	elif stage=="reeling" and tension>.82:text="张力过高 · 松开卸力"
	elif stage=="reeling" and tension<.15:text="鱼线太松 · 长按收线"
	if text.is_empty() or not is_instance_valid(bobber):return
	var at: Vector3=fish.to_global(fish_center) if stage=="net_ready" else bobber.global_position
	var camera: Camera3D=app.world.camera
	if camera.is_position_behind(at):return
	var inverse: Transform2D=app.safe_root.get_global_transform_with_canvas().affine_inverse()
	var screen: Vector2=inverse*camera.unproject_position(at)
	var box := Rect2(Vector2(clampf(screen.x-110,12,app.safe_root.size.x-232),clampf(screen.y-44,panel.position.y+panel.size.y+8,app.safe_root.size.y-240)),Vector2(220,32))
	var head: Vector2=Vector2(-1000,-1000) if app.world.orbit.first_person else inverse*camera.unproject_position(app.world.player.position+Vector3.UP*2.4)
	var feet: Vector2=Vector2(-1000,-1000) if app.world.orbit.first_person else inverse*camera.unproject_position(app.world.player.position)
	var actor_box := Rect2(Vector2(minf(head.x,feet.x)-45,minf(head.y,feet.y)-12),Vector2(absf(head.x-feet.x)+90,absf(head.y-feet.y)+24))
	if not app.world.orbit.first_person and box.intersects(actor_box):return
	for control: Control in [app.joystick,app.context_action,app.sprint_action,app.build_action,app.minimap,header,app.safe_root.get_node("MobileStatus"),app.safe_root.get_node("QuickAccess")]:
		var occupied := Rect2(control.global_position-app.safe_root.global_position,control.size)
		if box.intersects(occupied):return
	float_hint.text=text;float_hint.position=box.position;float_hint.size=box.size;float_hint.show()
func begin() -> bool:
	if active or not app.movement_enabled(): return false
	var actor: CharacterBody3D = app.world.player
	if app.state.location!="island" or actor.boating or not Platform.within_reach(actor.position):
		return app.state.say("走到船旁的钓鱼台，再开始垂钓。")
	if app.perf_probe: return false
	if not actor.begin_fishing(Platform.SEAT): return app.state.say("先结束当前动作，再拿起鱼竿。")
	if not app.state.start_shore_fishing(): actor.end_fishing(); return false
	if app.auto_task.running: app.auto_task.stop("")
	active=true; awarded=false; landed=false; held=false
	app.sprinting=false;app.sprint_action.reset()
	origin=Platform.SEAT
	joining_position=actor.position
	join_from=actor.position
	join_dir=(origin-actor.position).normalized()
	view_group=""
	big_fish=false;fish_roll=randf();size_roll=randf();species_roll=randf();fish_species=Catalog.catch_id(false,species_roll,false,_island_key());fish_mass=.65;chummed=false;seat_blend=0
	progress=0; tension=.35;bend_load=.08; danger=0; reel_angle=0
	camera_revision=app.interaction_director.camera_revision if app.interaction_director.executing else app.world.orbit.manual_revision
	camera_state=app.interaction_director.before_view.duplicate() if app.interaction_director.executing else app.interaction_director.view_snapshot()
	app.interaction_director.recommend(app.world.find_interaction("shore_fish"),camera_revision)
	join_distance=maxf(.001,actor.position.distance_to(origin))
	if join_distance<.06:
		# Already standing at the stool: sit down right away.
		joining_position=Vector3.INF
		actor.fishing_return=origin
		_apply_view("ready")
	else:
		# Approach shot: keep the pier in view while the actor walks the last
		# metre, then cut to the seated close-up on arrival.
		app.world.orbit.begin_activity_view("fishing",origin+Vector3(0,1,9.5),PI-.55,16,deg_to_rad(16))
		app.world.orbit.activity_settled=false
	wait_time=randf_range(4.5,7)
	_build_visual()
	panel.show()
	cast_target=Platform.FLOAT;cast_power=.65
	_set_stage("ready")
	if is_instance_valid(app.world.fish_keeper):app.world.fish_keeper.sync(app.state)
	app._sync_overlay_state()
	app._save(false)
	return true
func cancel(pack:bool=true) -> void:
	if not active: return
	if pack:app.state.pack_keep_net()
	if is_instance_valid(app.world.fish_keeper):app.world.fish_keeper.set_mouth(app.world.fish_keeper.REST);app.world.fish_keeper.sync(app.state)
	active=false; stage=""; held=false;joining_position=Vector3.INF
	# Step back off the stool to the approach spot instead of standing inside it.
	if join_from.is_finite(): app.world.player.fishing_return=join_from
	if app.world.orbit.stable_third_person:app.world.orbit.end_activity_view("fishing")
	if bite_audio!=null:bite_audio.stop()
	app.world.orbit.view_transition=1.5
	if not app.world.orbit.comfort_mode and app.world.orbit.manual_revision==camera_revision and not camera_state.is_empty() and app.state.location=="island" and not app.world.player.boating:
		app.world.orbit.target_yaw=camera_state.yaw
		app.world.orbit.target_pitch=camera_state.pitch
		app.world.orbit.target_distance=camera_state.distance
	elif app.world.player.boating: app.world.orbit.target_distance=18
	camera_state.clear()
	app.world.player.end_fishing()
	if is_instance_valid(app.world.fish_keeper):app.world.fish_keeper.hide()
	if is_instance_valid(view): view.queue_free()
	panel.hide();float_hint.hide()
	app._update_context()
	app._sync_overlay_state()
	app._save(false)
func interact() -> void:
	if not active or not app.movement_enabled(): return
	match stage:
		"ready":
		 # 第一人称由独立相机 rig 接管，orbit 的取景安定标志在这里永远是旧值，不能拿它卡住抛竿。
			if not app.world.orbit.first_person and not app.world.orbit.activity_settled:return
			_set_stage("charging")
		"bite": _set_stage("standing" if big_fish else "hooking")
		"net_ready": _set_stage("landing")
		"waiting", "casting": _result("还没咬钩，提竿太早了。")
		"result":
			if joining_position.is_finite():return
			# Reuse the live session: sit back down and cast again in place.
			_reset_cast()
			_set_stage("ready")
func auxiliary() -> void:
	if not active or not app.movement_enabled():return
	if stage=="reeling":held=false;app.context_action.reset()
	elif stage=="result":toggle_equipment()
	else:use_bait()
func toggle_equipment() -> void:
	app._show_fishing_help()
func use_bait() -> void:
	if not active or not app.movement_enabled() or stage not in ["ready","waiting"] or chummed:return
	if app.state.count("饵料")==0:
		var made: bool=app.state.craft("饵料")
		hint.text="饵料 ×3 已备 · 再点撒饵" if made else "缺少浆果 · 制饵需要浆果 ×1"
	else:
		app.state.exchange({"饵料":1},{})
		chummed=true;bait_return_stage=stage
		wait_time=maxf(1.5,(wait_time-elapsed)*.6)
		_set_stage("chumming")
	sync_controls()
	app._save(false)
func big_fish_probability() -> float:
	return (.5 if chummed else .3)+(.05 if app.state.buildings.has("好鱼竿") else 0)
func _set_stage(value: String) -> void:
	var previous_stage:String=stage
	if value in ["ready","charging","casting","result","storing"]:
		water_contact=false
		if is_instance_valid(ripple):ripple.hide()
	if value=="waiting" and previous_stage=="casting":
		water_contact=true;impact_age=0;water_impact_count+=1
	if value=="bite" and water_contact:
		# A take sends out a fresh ring at the float, not a faded cast splash.
		impact_age=0
	stage=value; elapsed=0; danger=0
	if stage=="bite":
		if bite_audio_enabled and bite_audio!=null:bite_audio.play()
		big_fish=fish_roll<big_fish_probability()
		fish_mass=lerpf(1.5,3.5,size_roll) if big_fish else lerpf(.4,.95,size_roll)
		fish_species=Catalog.catch_id(big_fish,species_roll,false,_island_key());_replace_fish()
	if stage=="standing":app.haptics.play("hook")
	if stage=="landing":net_tool.visible=true
	if stage in ["casting","bite","hooking"] and not (stage=="hooking" and big_fish):
		app.haptics.play({"casting":"cast","bite":"bite","hooking":"hook"}[stage])
	if app.world.orbit.stable_third_person:
		_apply_view(stage)
	elif stage=="reeling" and not app.world.orbit.comfort_mode and app.world.orbit.manual_revision==camera_revision:
		app.world.orbit.target_distance=22
		app.world.orbit.target_pitch=deg_to_rad(32)
	elif stage=="landing" and not app.world.orbit.comfort_mode and app.world.orbit.manual_revision==camera_revision:
		app.world.orbit.target_distance=7
		app.world.orbit.target_pitch=deg_to_rad(27)
		app.world.orbit.target_yaw=.85
		app.world.orbit.view_transition=.85
	elif stage=="waiting" and not app.world.orbit.comfort_mode and app.world.orbit.manual_revision==camera_revision:
		app.world.orbit.target_yaw=PI-.45;app.world.orbit.target_distance=28;app.world.orbit.target_pitch=deg_to_rad(35);app.world.orbit.view_transition=.85
	elif stage=="storing" and not app.world.orbit.comfort_mode and app.world.orbit.manual_revision==camera_revision:
		app.world.orbit.target_yaw=0;app.world.orbit.target_distance=6.5;app.world.orbit.target_pitch=deg_to_rad(27);app.world.orbit.view_transition=.85
	match stage:
		"ready":hint.text="按住右下甩竿蓄力 · 松手抛出";action_title="甩竿"
		"charging":hint.text="蓄力中 · 松手甩竿";action_title="松手甩竿"
		"casting": hint.text="甩竿入海 · 留意浮漂"; action_title="甩竿中"
		"waiting": hint.text="坐等咬钩 · 右下可撒饵"; action_title="等待"
		"chumming": hint.text="正在撒饵 · 提高大鱼概率"; action_title="撒饵中"
		"standing": hint.text="大鱼上钩！起身稳住海竿"; action_title="起身"
		"bite": hint.text="咬钩了！现在提竿！"; action_title="提竿"
		"hooking": hint.text="提竿中鱼 · 准备收线"; action_title="中鱼！"
		"reeling": hint.text=("大鱼搏斗 · 长按收线，松开卸力" if big_fish else "长按收线 · 松开卸力"); action_title="收线"
		"net_ready": hint.text="鱼已收近 · 点击右下抄网"; action_title="抄网"
		"storing":hint.text="摘钩 · 将鱼装入鱼护";action_title="装鱼中"
		"landing": hint.text="抄网入水 · 托住鱼身，稳稳提起"; action_title="抄鱼中"
		"result": action_title="再甩竿"
	sync_controls()
	_layout_hud()
## 当前下竿位置属于哪座岛（主岛返回空串，用默认鱼池）。
func _island_key() -> String:
	if app==null or app.world==null:return ""
	var exploration=app.world.exploration
	if exploration==null or app.world.player.boating:return ""
	var island:Node3D=exploration.island_at(app.world.player.position)
	return String(island.spec.id) if island!=null else ""

func _reset_cast() -> void:
	awarded=false;landed=false;held=false;chummed=false;big_fish=false
	progress=0;tension=.35;bend_load=.08;danger=0;reel_angle=0
	fish_roll=randf();size_roll=randf();species_roll=randf()
	fish_species=Catalog.catch_id(false,species_roll,false,_island_key());fish_mass=.65
	cast_target=Platform.FLOAT;cast_power=.65
func _return_to_seat(message: String) -> void:
	# Keep fishing: step back from the keep net, sit down, and hand the cast
	# button back instead of leaving the player standing by the keep net.
	app.world.player.fishing_anchor=origin
	# fishing_return 是「站起来以后站哪」，一次钓鱼开始时定下的位置，
	# 中途回座位不能把它改成钓凳位置，否则收竿会站到凳子上。

	joining_position=app.world.player.position
	join_from=joining_position
	join_distance=maxf(.001,joining_position.distance_to(origin))
	join_dir=(origin-joining_position).normalized()
	_set_stage("result")
	if not message.is_empty():hint.text=message
func _result(message: String) -> void:
	_set_stage("result")
	hint.text=message
	app.haptics.play("land" if landed else "escape")
	held=false
	app.state.say(message)
	app._refresh()
func _physics_process(delta: float) -> void:
	if not active: return
	var actor: CharacterBody3D = app.world.player
	if app.state.location!="island" or actor.boating or actor.fishing_stage.is_empty() or (stage not in ["casting","storing","result"] and not joining_position.is_finite() and actor.position.distance_to(origin)>.5):
		cancel(); return
	if not app.movement_enabled():
		held=false
		if bite_audio!=null:bite_audio.stop()
		if stage=="charging":_set_stage("ready")
		app.context_action.reset()
		panel.hide()
		return
	panel.show()
	if actor.move_input.length()>.15: cancel(); return
	elapsed+=delta
	match stage:
		"charging":
			cast_power=clampf(elapsed/1.5,.15,1)
			if not (app.context_action.held or Input.is_physical_key_pressed(KEY_SPACE)) and elapsed>.12:
				cast_target=origin+Vector3(0,-.84,lerpf(12,28,cast_power));_set_stage("casting")
		"casting":
			if elapsed>=CAST_DURATION: _set_stage("waiting")
		"chumming":
			if elapsed>=1.1: _set_stage(bait_return_stage)
		"standing":
			if elapsed>=.7:_set_stage("hooking")
		"waiting":
			if elapsed>=wait_time: _set_stage("bite")
		"bite":
			if elapsed>=2.0: _result("提竿晚了，鱼已经游走。")
		"hooking":
			if elapsed>=.4: _set_stage("reeling")
		"reeling":
			var pulling: bool = held or app.context_action.held or Input.is_physical_key_pressed(KEY_SPACE)
			if pulling and fposmod(elapsed,1.4)>.7: reel_angle+=delta*8
			tension=clampf(tension+delta*((.5 if big_fish else .42) if pulling else -.55),0,1)
			if pulling: progress=minf(1,progress+delta*(.3 if app.state.buildings.has("好鱼竿") else .24)*(.65 if big_fish else 1.0))
			else: progress=maxf(0,progress-delta*.015)
			if tension>.82: app.haptics.play("tension")
			elif tension<.15: app.haptics.play("slack")
			elif pulling: app.haptics.play("reel")
			if tension>.97 or tension<.03: danger+=delta
			else: danger=0
			if danger>.5: _result("鱼线绷断，鱼跑了。" if tension>.97 else "鱼线太松，鱼脱钩了。")
			elif progress>=1: _set_stage("net_ready" if big_fish else "landing")
		"landing":
			if elapsed>=Landing.DURATION and not awarded:
				awarded=true
				landed=app.state.secure_shore_fish(fish_species,2 if big_fish else 1,fish_mass)
				if landed:_set_stage("storing")
				else:_result(app.state.last_message)
				app._save(false)
		"storing":
			if elapsed>=Storage.DURATION:
				app.state.stow_pending_fish();app.world.fish_keeper.set_mouth(app.world.fish_keeper.REST);app.world.fish_keeper.sync(app.state)
				_return_to_seat("%s 已装入鱼护 · 走回钓位"%Catalog.DATA[fish_species].name);app._save(false)
	# Sit for the cast and the wait; stand to strike, to scoop the net, and to
	# step through the stow, so the feet stay planted on those beats.
	var seated_target := 1.0
	if joining_position.is_finite() or stage in ["standing","landing","storing"]: seated_target=0.0
	elif big_fish and stage in ["hooking","reeling"]: seated_target=0.0
	seat_blend=move_toward(seat_blend,seated_target,delta*(3.2 if seated_target>seat_blend else 4.2))
	sync_controls()
	_update_visual(delta)
	progress_bar.value=(cast_power if stage=="charging" else progress)*100
	tension_bar.value=tension*100
	tension_bar.modulate=Color("ff8468") if tension>.82 or tension<.15 else Color("91d6ad")
## 按当前弯度生成一根连续的锥形杆身：8 个折点连成一条曲线，
## 用 SurfaceTool 一次成面，弯折处没有段与段的接缝（旧版 8 根圆柱在弯杆时
## 接头会留下台阶，看上去像“断了几节”）。
func _shape_rod(load:float) -> Vector3:
	var points:Array[Vector3]=[Vector3.ZERO]
	var tip:Vector3=Vector3.ZERO
	for i in range(8):
		var bend:float=load*pow((i+.5)/8.0,1.8)
		tip+=Vector3(0,cos(bend),sin(bend))*.33
		points.append(tip)
		var segment:MeshInstance3D=rod_segments[i]
		segment.position=(points[i]+points[i+1])*.5
		segment.basis=Basis(Quaternion(Vector3.UP,(points[i+1]-points[i]).normalized()))
		segment.scale=Vector3.ONE
	_rebuild_blank(points)
	return tip
func _rebuild_blank(points:Array[Vector3]) -> void:
	if not is_instance_valid(rod_tube):return
	var sides:=8
	var rings:Array=[]  # 每环 8 个顶点
	for r in range(points.size()):
		var here:Vector3=points[r]
		var ahead:Vector3=points[mini(r+1,points.size()-1)]
		var behind:Vector3=points[maxi(r-1,0)]
		var axis:Vector3=(ahead-behind)
		if axis.length()<.0001:axis=Vector3.UP
		var frame:=Basis(Quaternion(Vector3.UP,axis.normalized()))
		var radius:float=lerpf(.032,.008,float(r)/float(points.size()-1))
		var ring:Array[Vector3]=[]
		for k in range(sides):
			var angle:=TAU*float(k)/sides
			ring.append(here+frame*Vector3(cos(angle)*radius,0,sin(angle)*radius))
		rings.append(ring)
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark:=Color("41565a")
	var light:=Color("93ac96")
	for r in range(rings.size()-1):
		var tint:Color=dark if r<4 else light
		for k in range(sides):
			var k2:=(k+1)%sides
			var a:Vector3=rings[r][k]
			var b:Vector3=rings[r][k2]
			var c:Vector3=rings[r+1][k2]
			var d:Vector3=rings[r+1][k]
			for vertex:Vector3 in [a,b,c,a,c,d]:
				tool.set_color(tint)
				tool.add_vertex(vertex)
	tool.generate_normals()
	rod_tube.mesh=tool.commit()
func _mesh(parent: Node3D, mesh: Mesh, color: Color, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=app.world.material(color)
	node.position=position
	parent.add_child(node)
	return node
func _build_visual() -> void:
	view=Node3D.new(); view.name="ActiveFishingTackle"
	app.world.add_child(view)
	rod=Node3D.new(); view.add_child(rod)
	rod_tube=MeshInstance3D.new(); rod_tube.name="RodBlank"
	var blank_material:=StandardMaterial3D.new()
	# 竿身是竹木色，不是半透明的灰白塑料条；金属度归零，不然低角度会反光发白。
	blank_material.albedo_color=Color("a9805a")
	blank_material.vertex_color_use_as_albedo=true
	blank_material.roughness=.82
	blank_material.metallic=0.0
	rod_tube.material_override=blank_material
	rod_tube.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rod.add_child(rod_tube)
	rod_segments.clear()
	for i in range(8):
		var shaft := CylinderMesh.new()
		shaft.radial_segments=8;shaft.height=.445
		shaft.bottom_radius=lerpf(.032,.008,i/8.0)
		shaft.top_radius=lerpf(.032,.008,(i+1)/8.0)
		var piece:MeshInstance3D=_mesh(rod,shaft,Color("536b6d") if i<3 else Color("b7c9b6"),Vector3(0,(i+.5)*.33,0))
		# 细杆自投影会在接头处压出暗痕，看起来像断了几节；杆身不投影。
		piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visible=false
		rod_segments.append(piece)
	var reel := CylinderMesh.new()
	reel.radial_segments=12
	reel.top_radius=.075; reel.bottom_radius=.075; reel.height=.07
	_mesh(rod,reel,Color("4d7880"),Vector3(.06,.15,0)).rotation.z=PI/2
	reel_handle=Node3D.new()
	rod.add_child(reel_handle)
	reel_handle.position=Vector3(.12,.15,0)
	var crank := BoxMesh.new()
	crank.size=Vector3(.025,.14,.025)
	_mesh(reel_handle,crank,Color("d3c194"),Vector3(0,.05,0))
	# A proper low-poly bobber: ivory belly, saffron shoulder, thin antenna and a
	# hot tip so it still reads as a float when it sits 20 m out.
	var belly := CylinderMesh.new()
	belly.top_radius=.052;belly.bottom_radius=.034;belly.height=.05;belly.radial_segments=10
	bobber=_mesh(view,belly,Color("f4ecd8"),cast_target)
	bobber.name="FishingFloat"
	var shoulder := CylinderMesh.new()
	shoulder.top_radius=.013;shoulder.bottom_radius=.053;shoulder.height=.055;shoulder.radial_segments=10
	_mesh(bobber,shoulder,Color("f0952f"),Vector3(0,.052,0))
	var antenna := CylinderMesh.new()
	antenna.top_radius=.0045;antenna.bottom_radius=.0045;antenna.height=.08;antenna.radial_segments=6
	_mesh(bobber,antenna,Color("df5a2e"),Vector3(0,.118,0))
	var cap := SphereMesh.new();cap.radius=.012;cap.height=.024;cap.radial_segments=8;cap.rings=4
	var tip:=_mesh(bobber,cap,Color("ff6a45"),Vector3(0,.162,0))
	var tip_material:StandardMaterial3D=tip.material_override
	tip_material.emission_enabled=true;tip_material.emission=Color("ff6a45").srgb_to_linear()
	tip_material.emission_energy_multiplier=.7
	line=ImmediateMesh.new()
	line_node = _mesh(view,line,Color("fff5c6"),Vector3.ZERO)
	(line_node.material_override as StandardMaterial3D).shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	(line_node.material_override as StandardMaterial3D).cull_mode=BaseMaterial3D.CULL_DISABLED
	bobber.hide()
	var surface:=PlaneMesh.new();surface.size=Vector2(4,4);surface.subdivide_width=8;surface.subdivide_depth=8
	ripple=_mesh(view,surface,Color.WHITE,cast_target)
	var ripple_material:=ShaderMaterial.new();ripple_material.shader=preload("res://shaders/fishing_ripple.gdshader")
	ripple.material_override=ripple_material;ripple.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ripple.hide()
	_replace_fish()
	net_tool=preload("res://scripts/life/fishing_gear.gd").net(app.world,view);net_tool.visible=false
	bait_cloud=MultiMeshInstance3D.new();bait_cloud.name="ThrownBait"
	var particles := MultiMesh.new();particles.transform_format=MultiMesh.TRANSFORM_3D
	var pellet := SphereMesh.new();pellet.radius=.035;pellet.height=.07;pellet.radial_segments=6;pellet.rings=4
	pellet.material=app.world.material(Color("be9256"));particles.mesh=pellet;particles.instance_count=12
	bait_cloud.multimesh=particles;view.add_child(bait_cloud);bait_cloud.visible=false
func _replace_fish() -> void:
	if is_instance_valid(fish):fish.queue_free()
	fish=Catalog.create(fish_species,app.world);fish.scale=Vector3.ONE*.55;view.add_child(fish)
	var bounds:=AABB();var first:=true
	for mesh:MeshInstance3D in fish.find_children("*","MeshInstance3D",true,false):
		var box:AABB=(fish.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	fish_center=bounds.get_center();fish.hide()
func _update_visual(delta:float=1.0/60) -> void:
	var join_walk:float=-1.0
	if joining_position.is_finite():
		# Walk the last metre with the real pose anchored to the moving body,
		# instead of freezing the cast pose and sliding it into place.
		joining_position=joining_position.move_toward(origin,delta*1.35)
		join_walk=1.0-clampf(joining_position.distance_to(origin)/join_distance,0,1)
		app.world.player.fishing_anchor=joining_position
		if joining_position.distance_to(origin)<.001:
			joining_position=Vector3.INF
			app.world.player.fishing_anchor=origin
			# The cast must start from the stool, not rewind to the approach spot.
			app.world.player.fishing_return=origin
			_apply_view("ready")
			if stage=="result":
				hint.text="已装入鱼护 · 按住右下继续甩竿"
			elif stage=="ready":
				hint.text="坐回钓位 · 按住右下继续甩竿"
	var night:float=1-smoothstep(.12,.5,app.state.daylight())
	var float_material:StandardMaterial3D=bobber.material_override
	float_material.emission_enabled=true;float_material.emission=Color("ffd9a8").srgb_to_linear();float_material.emission_energy_multiplier=night*1.2
	if stage=="storing" or (stage=="result" and landed):
		var time:float=elapsed if stage=="storing" else Storage.DURATION
		app.world.player.pose_fishing("storing",time,Vector3.UP,0,0)
		var message:String=hint.text;Storage.render(self,time)
		if stage=="result":hint.text=message;fish.hide();app.world.fish_keeper.set_mouth(app.world.fish_keeper.REST)
		return
	Catalog.animate(fish,elapsed,stage in ["net_ready","landing"])
	reel_handle.rotation.x=reel_angle
	var holding_net:bool=stage=="landing" or (stage=="result" and landed)
	var landing_time:float=elapsed if stage=="landing" else Landing.DURATION
	var angle := .5
	if stage=="casting": angle=lerpf(2.15,.35,smoothstep(0,.85,elapsed))
	elif stage=="waiting" or stage=="chumming": angle=.5+sin(elapsed*1.1)*.03
	elif stage=="hooking" or holding_net: angle=lerpf(.5,1.2,clampf((landing_time if holding_net else elapsed)/.4,0,1))
	elif stage=="reeling": angle=.45+sin(fposmod(elapsed,1.4)/1.4*PI)*.65
	var direction := Vector3(0,sin(angle),cos(angle))
	var phase:float=landing_time if holding_net else (elapsed/CAST_DURATION if stage=="casting" else elapsed)
	var net_grip := Vector3.INF
	if holding_net:
		var scoop:Dictionary=Landing.pose(origin,landing_time)
		net_grip=(origin+Vector3(.2,1.25,.48)+direction*.24).lerp(scoop.hand,scoop.reach)
	var grip: Vector3 = app.world.player.pose_fishing("landing" if holding_net else stage,phase,direction,reel_angle,seat_blend,net_grip,tension,held or app.context_action.held or Input.is_physical_key_pressed(KEY_SPACE))
	if join_walk>=0: app.world.player.fishing_join_walk(join_walk,join_dir)
	var mass:float=maxf(1.5,fish_mass) if big_fish else minf(.95,fish_mass)
	fish.scale=Vector3.ONE*(lerpf(.9,1.05,clampf((mass-1.5)/2,0,1)) if big_fish else lerpf(.5,.65,clampf((mass-.4)/.55,0,1)))
	bait_cloud.visible=stage=="chumming"
	if stage=="chumming":
		var t := clampf(elapsed/1.1,0,1)
		var start := origin+Vector3(-.3,1.1,.4)
		for i in range(12):
			var spread := Vector3(sin(i*2.4),0,cos(i*2.4))*.7
			var point := start.lerp(cast_target+spread,t)+Vector3.UP*sin(t*PI)*4
			bait_cloud.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
	# 鱼护只在真正抄鱼的那几秒亮出来，平时飘在半空里像一块浮板。
	net_tool.visible=holding_net or stage=="net_ready"
	if holding_net:
		var left: int = app.world.player._bone("LeftHand")
		var hand: Vector3=(app.world.player.pose_skeleton.global_transform*app.world.player.pose_skeleton.get_bone_global_pose(left)).origin
		net_tool.position=hand
		Landing.place_net(net_tool,hand,Landing.pose(origin,landing_time).hoop)
	rod.position=grip
	var water_target:Vector3=cast_target
	if stage=="reeling":
		water_target=cast_target.lerp(origin+Vector3(-.6,-.74,2.35),progress)
		water_target.x+=sin(elapsed*2.5)*progress*(.8 if big_fish else .3)
	elif stage=="net_ready":water_target=origin+Vector3(-.6,-.74,2.35)
	elif stage=="landing":water_target=net_tool.get_node("NetHead").global_position-Vector3.UP*.27
	var pull:Vector3=(water_target-grip).normalized()
	var plane:Vector3=pull-direction*pull.dot(direction)
	if plane.length()<.01:plane=Vector3.DOWN-direction*Vector3.DOWN.dot(direction)
	plane=plane.normalized();rod.basis=Basis(direction.cross(plane).normalized(),direction,plane)
	var target_load:float=.035
	if stage=="reeling":target_load=clampf(.25+tension*(1.25+mass*.13)+mass*.16*(.35+tension*.65)+sin(elapsed*3.1)*.07,.12,2.2)
	elif stage=="hooking":target_load=minf(2.1,1.1+mass*.25)
	elif stage=="net_ready":target_load=.8+mass*.12
	elif stage=="landing":target_load=lerpf(.75,.08,smoothstep(Landing.CATCH_TIME,Landing.DURATION,elapsed))
	bend_load=lerpf(bend_load,target_load,1-exp(-8*delta))
	var tip_local:Vector3=_shape_rod(bend_load)
	var tip:Vector3=rod.transform*tip_local
	var endpoint := cast_target
	if stage=="casting":
		endpoint=_cast_endpoint(tip)
	elif stage=="bite": endpoint.y-=.22
	elif stage=="reeling": endpoint=water_target
	elif stage=="net_ready":
		endpoint=origin+Vector3(-.6,-.74,2.35)
		fish.visible=true;fish.position=endpoint+Vector3.UP*sin(elapsed*5)*.08-fish.basis*fish_center
	elif holding_net:
		var scoop:Dictionary=Landing.pose(origin,landing_time)
		endpoint=scoop.fish
		fish.visible=true;fish.rotation=Vector3(sin(elapsed*15)*(.08 if scoop.caught else .18),PI/2,0)
		fish.position=endpoint-fish.basis*fish_center
	elif stage=="result":
		endpoint=Landing.pose(origin,Landing.DURATION).fish if landed else grip+Vector3(-.35,-.4,.1)
		fish.visible=landed
		fish.position=endpoint-fish.basis*fish_center
	if stage in ["waiting","reeling"]: endpoint.y+=sin(elapsed*5)*.035
	bobber.position=endpoint
	bobber.visible=stage not in ["ready","charging","net_ready","landing","result"]
	line_node.visible=stage not in ["ready","charging"]
	_update_water_ripple(delta)
	line.clear_surfaces()
	line.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var across: Vector3 = app.world.camera.global_basis.x*.012
	for i in range(8):
		var t0 := i/8.0
		var t1 := (i+1)/8.0
		# Slack while waiting; the line snaps taut the moment a fish takes.
		var sag:float=lerpf(.18,.02,tension) if stage=="reeling" else (.0 if stage in ["bite","hooking","standing","net_ready"] else .25)
		var a := tip.lerp(endpoint,t0)-Vector3.UP*sin(t0*PI)*sag
		var b := tip.lerp(endpoint,t1)-Vector3.UP*sin(t1*PI)*sag
		for vertex: Vector3 in [a-across,a+across,b+across,a-across,b+across,b-across]: line.surface_add_vertex(vertex)
	line.surface_end()

func _cast_endpoint(tip:Vector3) -> Vector3:
	var t:float=clampf((elapsed-CAST_WINDUP)/CAST_FLIGHT,0,1)
	return tip.lerp(cast_target,t)+Vector3.UP*sin(t*PI)*3.5

func _update_water_ripple(delta:float) -> void:
	if not is_instance_valid(ripple):return
	ripple.visible=water_contact and stage in ["waiting","bite","standing","hooking","reeling","chumming"]
	if not ripple.visible:return
	impact_age+=maxf(delta,0)
	# The plane follows the float in X/Z, while its shader follows the actual sea surface.
	ripple.global_position=Vector3(bobber.global_position.x,-.235,bobber.global_position.z)
	ripple.material_override.set_shader_parameter("impact_age",impact_age)
	ripple.material_override.set_shader_parameter("ripple_strength",1.2 if stage in ["bite","standing"] else (1.0 if stage!="reeling" else .65))

func present_first_person(hands:Node3D) -> void:
	if not active or not is_instance_valid(rod):return
	var camera:Camera3D=app.world.camera
	if stage=="storing" or (stage=="result" and landed):
		var t:float=elapsed if stage=="storing" else Storage.DURATION
		var data:Dictionary=Storage.frame(origin,t)
		var point:Vector3=hands.left_world()+camera.basis*Vector3(0,-.07,-.08)
		var keeper:Node3D=app.world.fish_keeper
		var mouth:Vector3=keeper.REST.lerp(hands.left_world()+Vector3(0,-.1,0),smoothstep(3.1,4.1,t)).lerp(keeper.REST,data["return"])
		keeper.set_mouth(mouth)
		fish.global_position=point.lerp(keeper.point_at(data.release*.8),data.release)-fish.basis*fish_center
		fish.visible=stage=="storing" and t<5.05
		return
	var grip:Vector3=hands.right_world()
	var angle:float=.3
	if stage=="charging":angle=lerpf(.3,1.25,cast_power)
	elif stage=="casting":angle=lerpf(1.9,.3,smoothstep(0,.85,elapsed))
	elif stage in ["hooking","reeling"]:angle=.38+sin(fposmod(elapsed,1.4)/1.4*PI)*.23
	var direction:Vector3=camera.global_basis*Vector3(0,sin(angle),-cos(angle))
	var endpoint:Vector3=bobber.global_position
	var pull:Vector3=(endpoint-grip).normalized()
	var plane:Vector3=pull-direction*pull.dot(direction)
	if plane.length()<.01:plane=Vector3.DOWN-direction*Vector3.DOWN.dot(direction)
	plane=plane.normalized();rod.global_position=grip;rod.global_basis=Basis(direction.cross(plane).normalized(),direction,plane)
	var tip_local:Vector3=_shape_rod(bend_load)
	var tip:Vector3=rod.to_global(tip_local)
	if stage in ["ready","charging"]:
		line_node.hide();bobber.hide();ripple.hide();return
	line_node.show()
	if stage=="casting":
		endpoint=_cast_endpoint(tip);bobber.global_position=endpoint
	if stage=="landing":
		var scoop:Dictionary=Landing.pose(origin,elapsed)
		Landing.place_net(net_tool,hands.left_world(),scoop.hoop)
		if scoop.caught:fish.global_position=scoop.hoop-Vector3.UP*.27-fish.basis*fish_center
		endpoint=fish.global_position+fish.basis*fish_center
	reel_handle.rotation.x=reel_angle
	line.clear_surfaces();line.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var across:Vector3=camera.global_basis.x*.009
	for i in range(12):
		var t0:float=i/12.;var t1:float=(i+1)/12.
		var sag:float=lerpf(.18,.02,tension) if stage=="reeling" else (.0 if stage in ["bite","hooking","standing","net_ready"] else .25)
		var a:Vector3=tip.lerp(endpoint,t0)-Vector3.UP*sin(t0*PI)*sag
		var b:Vector3=tip.lerp(endpoint,t1)-Vector3.UP*sin(t1*PI)*sag
		for vertex:Vector3 in [a-across,a+across,b+across,a-across,b+across,b-across]:line.surface_add_vertex(vertex)
	line.surface_end()

func _setup_bite_audio() -> void:
	var config:=ConfigFile.new()
	if not app.test_mode and config.load("user://fishing_audio.cfg")==OK:bite_audio_enabled=bool(config.get_value("audio","bite",true))
	bite_audio=AudioStreamPlayer.new();bite_audio.name="FishingBiteCue";bite_audio.volume_db=-12;add_child(bite_audio)
	var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=22050
	var data:=PackedByteArray();var samples:int=int(22050*.24);data.resize(samples*2)
	for i in range(samples):
		var time:float=i/22050.;var local:float=time if time<.1 else time-.13
		var envelope:float=sin(PI*clampf(local/.09,0,1)) if local>=0 and local<.09 else 0
		var frequency:float=880 if time<.1 else 1100
		data.encode_s16(i*2,int(sin(TAU*frequency*time)*envelope*.22*32767))
	wave.data=data;bite_audio.stream=wave
func set_bite_audio(value:bool) -> void:
	bite_audio_enabled=value
	if not value and bite_audio!=null:bite_audio.stop()
	if app.test_mode:return
	var config:=ConfigFile.new();config.set_value("audio","bite",value);config.save("user://fishing_audio.cfg")

func _exit_tree() -> void:
	if is_instance_valid(bite_audio):
		bite_audio.stop()
		bite_audio.stream=null
