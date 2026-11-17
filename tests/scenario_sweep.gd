extends SceneTree
## 电脑端多场景自动扫测：用真实帧把各种玩法跑一遍，抓运行时错误和状态异常。
var passed:=0
var failed:=0
var issues:Array[String]=[]
var app:Node
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;issues.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app)
	app.set_process(true);app.set_physics_process(true);app._close_drawers();app.inactive=false;app.paused=false
	await physics_frame;await physics_frame
	var world:Node3D=app.world
	var player:CharacterBody3D=world.player
	app.state.location="island";app.state.minute=9*60;world.sync(app.state)
	await run_frames(30)
	await scene_walk(world,player)
	await scene_fishing(world,player)
	await scene_fishing_catch(world,player)
	await scene_boat(world,player)
	await scene_villa(world,player)
	await scene_bridges(world,player)
	await scene_giants(world,player)
	await scene_hud(world,player)
	await scene_gesture(world,player)
	await scene_island_pools(world,player)
	await scene_characters(world,player)
	await scene_state_roundtrip(world,player)
	await scene_weather(world,player)
	await scene_camera_drag(world,player)
	await scene_stairs(world,player)
	await scene_auto_walk(world,player)
	await scene_entry_flow(world,player)
	await scene_town(world,player)
	await scene_scan()
	print("SCENARIO SWEEP: %d passed, %d failed"%[passed,failed])
	for item:String in issues:print("  ISSUE: "+item)
	quit(1 if failed else 0)

func run_frames(count:int)->void:
	for i in range(count):
		await physics_frame

func wait_until(cond:Callable,limit:int)->bool:
	for i in range(limit):
		if cond.call():return true
		await physics_frame
	return false

func stick(dir:Vector2)->void:
	# 走真实的摇杆通道，这样 life_main 才会算 manual_world_direction
	if app.joystick!=null:
		if app.joystick.has_method("set_direction"):app.joystick.set_direction(dir)
		else:app.joystick.direction=dir
	app.state.player_position=[app.world.player.position.x,app.world.player.position.y,app.world.player.position.z]

func scene_walk(world:Node3D,player:CharacterBody3D)->void:
	# 岛上来回走，检查地面吸附与坐标有效性
	player.position=world.DOCK+Vector3(0,1,0);player.velocity=Vector3.ZERO
	var dirs:Array[Vector2]=[Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0)]
	var bad:=0
	for dir:Vector2 in dirs:
		stick(dir)
		await run_frames(45)
		if not player.position.is_finite() or player.position.y< -1.0:bad+=1
	stick(Vector2.ZERO)
	await run_frames(20)
	check(bad==0,"walking keeps the player on finite terrain")
	check(is_finite(player.position.y),"player height is finite after walking")

func scene_fishing(world:Node3D,player:CharacterBody3D)->void:
	player.position=Vector3(-1,.68,17.3);player.velocity=Vector3.ZERO
	await run_frames(6)
	var fishing:Node=app.fishing_session
	check(fishing.begin(),"shore fishing starts at the platform")
	if not fishing.active:
		return
	var stages:Dictionary={}
	var frames:=0
	var cast_done:=false
	while fishing.active and frames<1500:
		frames+=1
		stages[fishing.stage]=true
		if fishing.stage=="ready" and not cast_done and app.world.orbit.activity_settled:
			cast_done=true
			fishing.interact()
		elif fishing.stage in ["hooking","standing"]:
			fishing.interact()
		await physics_frame
	check(stages.has("waiting"),"fishing reaches the waiting stage (stages: %s)"%str(stages.keys()))
	check(stages.has("hooking") or stages.has("standing") or stages.has("landing") or stages.has("result"),
		"fishing reaches the bite/fight stage (stages: %s)"%str(stages.keys()))
	check(player.fishing_stage!="" or not fishing.active,"player holds the fishing pose while fishing")
	fishing.cancel(false)
	await run_frames(20)
	check(is_finite(player.position.y),"player position stays valid after fishing")

func scene_fishing_catch(world:Node3D,player:CharacterBody3D)->void:
	# 全流程钓一条鱼上岸：甩竿→咬钩涟漪→提竿→收线→入护→自己走回钓位继续钓鱼。
	var platform_script=preload("res://scripts/life/fishing_platform.gd")
	player.position=Vector3(-1,.68,17.3);player.velocity=Vector3.ZERO
	await run_frames(6)
	var fishing:Node=app.fishing_session
	if not fishing.begin():
		check(false,"catch loop can start the fishing session")
		return
	var cast_done:=false
	var impacts:=int(fishing.water_impact_count)
	var saw_bite:=false
	var saw_reeling:=false
	var saw_storing:=false
	var frames:=0
	while fishing.active and frames<2400:
		frames+=1
		match fishing.stage:
			"ready":
				if not cast_done and app.world.orbit.activity_settled:
					cast_done=true
					fishing.interact()
			"bite":
				saw_bite=true
				fishing.interact()
			"reeling":
				saw_reeling=true
				fishing.held=fishing.tension<.62
			"net_ready":
				fishing.interact()
			"storing":
				saw_storing=true
			"result":
				if not fishing.joining_position.is_finite():
					break
		await physics_frame
	fishing.held=false
	check(cast_done,"catch loop got the cast away")
	check(saw_bite,"catch loop reached a real bite")
	check(int(fishing.water_impact_count)>impacts,"a bite sends a fresh ripple at the float (impacts %d -> %d)"%[impacts,int(fishing.water_impact_count)])
	check(saw_reeling,"catch loop reached the reeling fight")
	check(saw_storing or not fishing.active,"catch loop lands the fish and stows it")
	var seat:Vector3=platform_script.SEAT
	check(Vector2(player.position.x-seat.x,player.position.z-seat.z).length()<1.2,
		"player walks back to the fishing seat (%.2f m off)"%Vector2(player.position.x-seat.x,player.position.z-seat.z).length())
	check(not player.fishing_stage.is_empty(),"player keeps the fishing pose after stowing")
	fishing.cancel(false)
	await run_frames(20)

func scene_boat(world:Node3D,player:CharacterBody3D)->void:
	player.position=world.DOCK;player.velocity=Vector3.ZERO
	await run_frames(10)
	var boarded:bool=world.board_boat(app.state)
	check(boarded,"player boards the boat at the dock")
	if not boarded:return
	var wake:Node=world.boat_wake
	stick(Vector2(0,-1))
	app.sprinting=true
	await run_frames(150)
	check(player.position.is_finite(),"boating keeps the boat in valid water")
	check(world.navigable_water(player.position),"boat stays in navigable water")
	check(wake.boost>0.05 or not wake.boost_events.is_empty(),"boat wake reacts to rowing (boost=%.2f)"%wake.boost)
	stick(Vector2.ZERO)
	app.sprinting=false
	await run_frames(60)
	check(wake.boost<0.6,"wake fades when the boat stops (boost=%.2f)"%wake.boost)
	# 鲨鱼靠近应触发撞船事件
	var giants:Node=world.sea_giants
	if giants.sharks.size()>0:
		var shark:Dictionary=giants.sharks[0]
		shark.node.position=player.position+Vector3(1.2,0,0)
		await run_frames(40)
		check(int(giants.attack_events)>0,"shark bumps the boat when it gets close")
	check(player.boating,"player is still boating after the encounter")
	stick(Vector2.ZERO)
	# 先把船靠回码头并下船，后续场景才能在岛上进行
	player.position=world.MOORING
	await run_frames(20)
	world.disembark_boat()
	await run_frames(10)
	check(not player.boating,"player gets back off the boat at the mooring")

func scene_villa(world:Node3D,player:CharacterBody3D)->void:
	player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.4)
	await run_frames(4)
	check(world.enter_villa(app.state),"player enters the villa")
	if app.state.location!="villa":return
	await run_frames(20)
	check(is_finite(player.position.x),"player position valid indoors")
	check(app.state.home_floor==0,"villa entry starts on the ground floor")
	# 客厅沙发坐下、开关电视、起身
	player.position=Vector3(world.Villa.SOFA_STAND.x,world.Villa.SOFA_STAND.y,world.Villa.SOFA_STAND.z)
	await run_frames(6)
	check(app.sofa_session.begin(),"player sits on the living room sofa")
	await run_frames(30)
	if app.sofa_session.active:
		app.sofa_session.toggle_tv()
		await run_frames(20)
		check(is_finite(player.position.y),"sofa time keeps the player at a valid spot")
		app.sofa_session.finish()
		await run_frames(20)
	check(not player.sofa_seated,"player stands up from the sofa")
	# 上楼到卧室睡觉
	player.position=world.Villa.STAIR_ENTRY
	await run_frames(10)
	# headless 下没有真实视口像素，"镜头构图已就绪"这道闸永远不满足；
	# 换成标准第三人称（非舒适模式）时该闸直接放行，与真机正常档一致。
	world.orbit.comfort_mode=false
	var climbed:bool=world.change_home_floor(app.state)
	if climbed:
		await run_frames(40)
	check(app.state.home_floor in [0,1],"home floor stays a valid level")
	if app.state.home_floor==1:
		var sleep_point:Dictionary=world.find_interaction("villa_sleep")
		if not sleep_point.is_empty():player.position=sleep_point.pos
		await run_frames(10)
		check(app.bed_session.begin(),"player lies on the bedroom bed")
		await run_frames(30)
		if app.bed_session.active:
			app.bed_session.sleep_to_morning()
			await run_frames(40)
			check(app.state.minute>=300,"sleeping advances the clock")
			app.bed_session.finish()
			await run_frames(20)
		check(player.bed_stage=="","player gets out of bed")
	# 下楼（必须站在楼梯口），再出门
	player.position=world.Villa.STAIR_ENTRY
	await run_frames(10)
	if app.state.home_floor==1:world.change_home_floor(app.state)
	var done:bool=await wait_until(func(): return not player.stair_active, 2600)
	check(done,"stair ride finishes instead of deadlocking at the stair mouth")
	player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.2)
	await run_frames(6)
	check(world.leave_villa(app.state),"player can leave the villa from the porch")
	await run_frames(20)
	check(app.state.location=="island","player is back on the island after leaving")

func scene_bridges(world:Node3D,player:CharacterBody3D)->void:
	var bridges:Node=world.bridges
	var ids:Array=bridges.bridges.keys()
	check(ids.size()>0,"bridges are built for every island")
	var id:String=String(ids[0])
	var data:Dictionary=bridges.bridges[id]
	var origin:Vector3=data.origin
	var dir:Vector3=data.dir
	var length:float=float(data.length)
	world.exploration.activate(world.exploration.find(id))
	player.position=origin+dir*0.6+Vector3(0,0.05,0);player.velocity=Vector3.ZERO
	stick(Vector2(dir.x,dir.z))
	var walked:=0
	for i in range(110):
		await physics_frame
		if bridges.height_at(player.position)!=-INF:walked+=1
	stick(Vector2.ZERO)
	await run_frames(10)
	check(walked>30,"player walks along the bridge deck (%d frames on the deck)"%walked)
	check(absf(player.position.y-data.surface)<1.0,"player stands on the bridge surface (y=%.2f, deck=%.2f)"%[player.position.y,float(data.surface)])
	var past:Vector3=origin+dir*(length+0.6)
	check(bridges.height_at(past)==-INF,"bridge deck ends before open water")

func scene_giants(world:Node3D,player:CharacterBody3D)->void:
	var giants:Node=world.sea_giants
	var finite:=true
	for shark in giants.sharks:
		if not shark.node.position.is_finite():finite=false
	for whale in giants.whales:
		if not whale.node.position.is_finite():finite=false
	for fish in giants.prey:
		if not fish.node.position.is_finite():finite=false
	check(finite,"all sea giants stay at valid coordinates")
	check(giants.whales.size()==1 and giants.sharks.size()==2,"giants keep their configured numbers")
	for island:Node3D in world.seascape.islands:
		var pool:Dictionary=island.creature_pool()
		for animal:Dictionary in island.wildlife:
			if not animal.node.position.is_finite():finite=false
		check(island.wildlife.size()>0,"island %s keeps its own creatures"%str(island.spec.id))
	check(finite,"island wildlife stays at valid coordinates")

func scene_hud(world:Node3D,player:CharacterBody3D)->void:
	# 换几种分辨率，右下五个技能都必须落在安全区里、互不重叠、尺寸随屏幕缩放。
	var sizes:Array[Vector2i]=[Vector2i(2436,1125),Vector2i(2532,1170),Vector2i(2048,1536),Vector2i(1334,750)]
	for size in sizes:
		root.size=size
		await run_frames(6)
		app._update_context()
		# Control 坐标是画布单位（受拉伸策略影响），不能拿窗口像素直接比；
		# 用技能层实际占据的矩形当参照，等价于玩家看到的右下安全区。
		var pad:Rect2=app.action_pad.get_global_rect()
		var rects:Array[Rect2]=[]
		var circles:Array=[]  # [center, diameter] —— 圆按钮要按圆判重叠，按矩形框会误报
		for key in app.SKILL_SLOTS:
			var control:Control=app._skill_control(key)
			if control==null:continue
			var r:=control.get_global_rect()
			rects.append(r)
			check(r.size.x>=40 and r.size.y>=40,"skill %s has a usable size at %s (%s)"%[key,str(size),str(r.size)])
			check(r.position.x>=pad.position.x-1 and r.position.y>=pad.position.y-1 and r.end.x<=pad.end.x+1 and r.end.y<=pad.end.y+1,
				"skill %s stays inside the safe area at %s (%s in %s)"%[key,str(size),str(r),str(pad)])
			var center:=r.get_center()
			circles.append([center,r.size.x])
			if not (center.x>pad.get_center().x and center.y>pad.get_center().y):
				print("HUD_SLOT %s size=%s center=%s pad=%s padcenter=%s"%[key,str(size),str(center),str(pad),str(pad.get_center())])
			check(center.x>pad.get_center().x and center.y>pad.get_center().y,
				"skill %s sits in the lower-right corner at %s"%[key,str(size)])
		var overlaps:=0
		var tightest:=INF
		for i in range(circles.size()):
			for j in range(i+1,circles.size()):
				var gap:float=(circles[i][0] as Vector2).distance_to(circles[j][0])
				var need:float=(float(circles[i][1])+float(circles[j][1]))*.5
				tightest=minf(tightest,gap/need)
				if gap<need*.82:overlaps+=1
		check(overlaps==0,"skill buttons do not overlap at %s (%d overlaps, tightest %.2f)"%[str(size),overlaps,tightest])
	root.size=Vector2i(2436,1125)
	await run_frames(6)
	app._update_context()

func scene_gesture(world:Node3D,player:CharacterBody3D)->void:
	# 双指缩放只许改水平朝向，不许改相机距离（否则人物环境比例会漂）。
	var orbit:Node=world.orbit
	var before_distance:float=orbit.target_distance
	var before_yaw:float=orbit.target_yaw
	orbit.orbit_by_gesture(0.6)
	print("GESTURE yaw %.3f -> %.3f dist %.2f -> %.2f stable=%s fp=%s"%[before_yaw,orbit.target_yaw,before_distance,orbit.target_distance,str(orbit.stable_third_person),str(orbit.first_person)])
	await run_frames(4)
	print("GESTURE after frames yaw=%.3f dist=%.2f" % [orbit.target_yaw,orbit.target_distance])
	check(absf(orbit.target_distance-before_distance)<0.01,
		"pinch gesture keeps the camera distance (%.2f -> %.2f)"%[before_distance,orbit.target_distance])
	check(absf(orbit.target_yaw-before_yaw)>0.05,"pinch gesture still turns the camera horizontally")
	# 直接喂一个放大手势事件，确认不会改 distance
	var pinch:=InputEventMagnifyGesture.new()
	pinch.factor=1.35
	root.push_input(pinch)
	await run_frames(4)
	check(absf(orbit.target_distance-before_distance)<0.01,
		"magnify input never changes the camera distance (now %.2f)"%orbit.target_distance)

func scene_island_pools(world:Node3D,player:CharacterBody3D)->void:
	var catalog=preload("res://scripts/life/fish_catalog.gd")
	var seen:Dictionary={}
	for island:Node3D in world.seascape.islands:
		var key:String=String(island.spec.id)
		var pool:Array=catalog.island_pool(key)
		check(pool.size()>0,"island %s has a fish pool"%key)
		var signature:=str(pool)
		seen[signature]=true
		var species:Array=catalog.SHORE
		var outside:=0
		for i in range(200):
			var id:String=catalog.catch_id(false,randf(),false,key)
			if not pool.has(id) and not species.has(id):outside+=1
		check(outside==0,"island %s only catches its own shore fish"%key)
	check(seen.size()>=3,"island fish pools differ from each other")

func scene_characters(world:Node3D,player:CharacterBody3D)->void:
	# 男女角色都换成了 Polyfork 的两个基础模型：必须真的带骨骼，且游戏里等高。
	var heights:Dictionary={}
	for gender in ["male","female"]:
		var model:Node3D=world.character_model(gender)
		check(model!=null,"%s character model loads"%gender)
		if model==null:continue
		var playable:Node3D=model.duplicate()
		world.add_child(playable)
		await run_frames(6)
		var bones:Array=playable.find_children("*","Skeleton3D",true,false)
		check(bones.size()>0,"%s character has a skeleton rig"%gender)
		var animators:Array=playable.find_children("*","AnimationPlayer",true,false)
		var clips:=0
		for animator:AnimationPlayer in animators:clips+=animator.get_animation_list().size()
		check(clips>=2,"%s character ships idle/walk clips (%d)"%[gender,clips])
		var bounds:=AABB()
		var first:=true
		for mesh:MeshInstance3D in playable.find_children("*","MeshInstance3D",true,false):
			var box:AABB=mesh.get_aabb()
			bounds=bounds.merge(box) if not first else box
			first=false
		heights[gender]=bounds.size.y*float(playable.scale.y)
		playable.queue_free()
		await run_frames(4)
	check(heights.size()==2,"both character models measured")
	if heights.size()==2:
		var diff:float=absf(float(heights["male"])-float(heights["female"]))
		check(diff<0.15,"male and female characters stand the same height (%.2f vs %.2f)"%[heights["male"],heights["female"]])
		for gender in heights:
			check(float(heights[gender])>1.4 and float(heights[gender])<2.6,"%s character height is in range (%.2f)"%[gender,heights[gender]])

func scene_state_roundtrip(world:Node3D,player:CharacterBody3D)->void:
	var state=app.state
	var before_name:String=String(state.profile.name)
	var before_energy:float=state.energy
	check(state.craft("饵料") or state.count("浆果")==0,"crafting a bait either succeeds or explains the missing berry")
	state.energy=maxf(10,state.energy-25)
	var path:="user://sweep_state.json"
	var dir:=DirAccess.open("user://")
	for suffix in ["", ".tmp", ".bak"]:
		if dir!=null and dir.file_exists("sweep_state.json"+suffix):dir.remove("sweep_state.json"+suffix)
	check(state.save_game(path)==OK,"state saves to a scratch file")
	var LifeState=load("res://scripts/life/life_state.gd")
	var loaded=LifeState.new()
	check(loaded.load_game(path),"a fresh state loads the saved file")
	check(String(loaded.profile.name)==before_name,"profile name survives the round trip")
	check(absf(loaded.energy-state.energy)<0.01,"energy survives the round trip (%.1f vs %.1f)"%[loaded.energy,state.energy])
	check(loaded.fish_keep.size()==state.fish_keep.size(),"fish keep count survives the round trip")
	if dir!=null and dir.file_exists("sweep_state.json"):dir.remove("sweep_state.json")
	state.energy=before_energy
	await run_frames(6)

func scene_weather(world:Node3D,player:CharacterBody3D)->void:
	# 夜雨 + 大风下必须照常跑帧，不出现无效坐标。
	app.state.minute=3*1440+22*60
	world.sync(app.state)
	await run_frames(30)
	check(is_finite(player.position.y),"player stays valid at night in bad weather")
	check(world.navigation_state.location=="island","night weather keeps the island loaded")
	check(app.state.weather().length()>0,"weather has a name (%s)"%app.state.weather())
	app.state.minute=9*60
	world.sync(app.state)
	await run_frames(10)

func cam_yaw(orbit:Node)->float:
	# 稳定第三人称把拖拽结果写在 requested_yaw，基类 orbit 只给双指路径同步 target_yaw。
	if orbit.get("requested_yaw")!=null: return float(orbit.requested_yaw)
	return float(orbit.target_yaw)

func find_drag_point()->Vector2:
	# 真实玩家不会恰好按在按钮上：先扫描屏幕上的可拖拽区域，顺便量出死区比例。
	var area:Vector2=root.get_visible_rect().size
	var free:=0;var total:=0;var best:=Vector2(-1,-1)
	for ix in range(8):
		for iy in range(5):
			var p:=Vector2(area.x*(.34+ix*.08),area.y*(.14+iy*.17))
			total+=1
			if app._camera_can_drag(p):
				free+=1
				if best.x<0:best=p
	print("DRAG_AREA free=%d/%d view=%s window=%s" % [free,total,str(area),str(root.size)])
	check(free>=total*0.5,"most of the screen starts a camera drag (%d/%d)"%[free,total])
	return best

func scene_camera_drag(world:Node3D,player:CharacterBody3D)->void:
	# 真机最常用的手势：单指长按后横向拖拽 = 只水平转视角，不移动人物、不改变人物大小。
	# 先把窗口回到 16:9 的 1280×720：canvas_items 拉伸下只有这样窗口坐标才和画布坐标一一对应，
	# 注入的触摸点才落在真正的屏幕上（前面换分辨率测 HUD 留下的比例会让点被缩放偏掉）。
	root.size=Vector2i(1280,720)
	await run_frames(10)
	world.orbit.comfort_mode=false
	player.position=world.DOCK;player.velocity=Vector3.ZERO
	stick(Vector2.ZERO)
	await run_frames(24)
	var orbit=world.orbit
	var yaw0:float=cam_yaw(orbit)
	var pos0:Vector3=player.position
	var arm0:float=float(orbit.get("current_arm")) if orbit.get("current_arm")!=null else float(orbit.distance)
	var point:=find_drag_point()
	if point.x<0:point=Vector2(root.get_visible_rect().size.x*.55,root.get_visible_rect().size.y*.5)
	var down:=InputEventScreenTouch.new();down.index=0;down.position=point;down.pressed=true
	root.push_input(down)
	await run_frames(8)
	check(orbit.touch_id>=0,"the press reaches the camera instead of dying on a dead zone")
	for i in range(10):
		# 拖拽事件直接喂给相机的输入处理器：headless 下 Window.push_input 会按拉伸比
		# 把 relative 放大 20 倍，测出来的灵敏度不真实；触摸按下仍走真实通道验证死区。
		var drag:=InputEventScreenDrag.new()
		drag.index=0;drag.position=point+Vector2((i+1)*48,0);drag.relative=Vector2(48,0)
		orbit._unhandled_input(drag)
		await physics_frame
	var up:=InputEventScreenTouch.new();up.index=0;up.position=point+Vector2(480,0);up.pressed=false
	root.push_input(up)
	await run_frames(6)
	var turned:float=absf(angle_difference(yaw0,cam_yaw(orbit)))
	check(turned>0.40,"long-press drag turns the camera horizontally (%.2f rad)"%turned)
	check(Vector2(player.position.x-pos0.x,player.position.z-pos0.z).length()<0.35,"drag does not walk the player away")
	check(orbit.gesture_lock,"drag puts the camera under manual control")
	var yaw1:float=cam_yaw(orbit)
	var still:=InputEventScreenTouch.new();still.index=0;still.position=point;still.pressed=true
	root.push_input(still)
	await run_frames(70)
	var lift:=InputEventScreenTouch.new();lift.index=0;lift.position=point;lift.pressed=false
	root.push_input(lift)
	await run_frames(6)
	check(absf(angle_difference(yaw1,cam_yaw(orbit)))<0.06,"holding a finger still does not drift the camera")
	await run_frames(120)
	check(absf(angle_difference(yaw1,cam_yaw(orbit)))<0.40,"manual angle survives a few seconds")
	# 双指捏合只做水平转向，镜头臂长（=人物在画面里的大小）必须一字不变
	var magnify:=InputEventMagnifyGesture.new();magnify.factor=1.65;magnify.position=point
	root.push_input(magnify)
	await run_frames(12)
	var arm1:float=float(orbit.get("current_arm")) if orbit.get("current_arm")!=null else float(orbit.distance)
	check(absf(arm1-arm0)<0.10,"pinch never changes the camera arm (%.2f -> %.2f)"%[arm0,arm1])
	check(absf(angle_difference(yaw1,cam_yaw(orbit)))>0.05,"pinch turns the camera horizontally")

func scene_stairs(world:Node3D,player:CharacterBody3D)->void:
	# 上下楼梯各两趟：不能卡在楼梯口、楼层状态必须回到一层。
	if app.state.location!="villa":
		player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.4)
		await run_frames(4)
		world.enter_villa(app.state)
	await run_frames(14)
	world.orbit.comfort_mode=false
	for trip in range(2):
		player.position=world.Villa.STAIR_ENTRY
		await run_frames(10)
		var from_floor:int=app.state.home_floor
		world.change_home_floor(app.state)
		var settled:bool=await wait_until(func(): return not player.stair_active,2600)
		check(settled,"stair ride %d finishes without deadlocking"%(trip+1))
		check(app.state.home_floor in [0,1],"floor stays valid after ride %d"%(trip+1))
		check(is_finite(player.position.y),"player lands on a finite height after ride %d"%(trip+1))
		await run_frames(12)
	check(app.state.home_floor==0,"two stair rides return the player to the ground floor")
	# 爬楼途中拖视角：只转镜头，不该把楼梯流程打断
	player.position=world.Villa.STAIR_ENTRY
	await run_frames(8)
	world.change_home_floor(app.state)
	await run_frames(10)
	var orbit=world.orbit
	var yaw0:float=cam_yaw(orbit)
	if player.stair_active:
		var down:=InputEventScreenTouch.new();down.index=0;down.position=Vector2(700,300);down.pressed=true
		root.push_input(down)
		for i in range(6):
			var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(700+(i+1)*50,300);drag.relative=Vector2(50,0)
			root.push_input(drag)
			await physics_frame
		var up:=InputEventScreenTouch.new();up.index=0;up.position=Vector2(1000,300);up.pressed=false
		root.push_input(up)
	check(absf(angle_difference(yaw0,cam_yaw(orbit)))>0.1,"camera can still be turned while climbing stairs")
	var settled:bool=await wait_until(func(): return not player.stair_active,2600)
	check(settled,"stair ride survives a camera drag")
	if app.state.home_floor==1:
		player.position=world.Villa.STAIR_ENTRY
		await run_frames(10)
		world.change_home_floor(app.state)
		await wait_until(func(): return not player.stair_active,2600)
	player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.2)
	await run_frames(6)
	world.leave_villa(app.state)
	await run_frames(16)
	check(app.state.location=="island","stairs scene ends back on the island")

func scene_auto_walk(world:Node3D,player:CharacterBody3D)->void:
	# 自动接任务：从码头点「回家·海景别墅」，人物自己走过去，不该中途卡死。
	app.state.location="island";app.state.island_visit={};app.state.hunger=85;app.state.thirst=85;app.state.energy=90
	world.sync(app.state)
	player.position=world.DOCK+Vector3(0,.5,0);player.velocity=Vector3.ZERO
	stick(Vector2.ZERO)
	await run_frames(12)
	var goal:Vector3=world.Villa.ENTRY
	var dist0:float=player.position.distance_to(goal)
	var started:bool=app.auto_task.start("villa")
	check(started,"auto walk accepts the villa destination")
	if started:
		check(app.auto_task.running,"auto walk starts rolling")
		await run_frames(90)
		check(player.position.distance_to(goal)<dist0-1.0,"auto walk closes the distance to the villa")
		var arrived:bool=await wait_until(func(): return not app.auto_task.running or player.position.distance_to(goal)<5.5,1600)
		check(arrived,"auto walk reaches the villa instead of stalling")
		check(player.position.is_finite(),"auto walk keeps a finite position")
		app.auto_task.stop("")
		await run_frames(8)
		check(not app.auto_task.running,"auto walk can be cancelled")
	stick(Vector2.ZERO)

func scene_entry_flow(world:Node3D,player:CharacterBody3D)->void:
	# 进入游戏的第一个界面（选人物/伙伴）：开、换性别、预览、确认，整条链要通。
	var screen=app.arrival
	check(screen!=null,"arrival screen node exists")
	if screen==null:return
	var profile0:Dictionary=app.state.profile.duplicate(true)
	screen.open()
	await run_frames(8)
	check(screen.visible,"arrival screen opens")
	var other:String="female" if String(profile0.gender)=="male" else "male"
	screen._select_gender(other)
	await run_frames(8)
	check(screen.preview!=null and is_instance_valid(screen.preview),"arrival preview shows the chosen character")
	check(world.character_model(other)!=null,"world can build the %s model shown in the preview"%other)
	screen._select_gender(String(profile0.gender))
	await run_frames(8)
	screen.name_input.text=String(profile0.name)
	var ok:bool=screen.confirm()
	check(ok,"arrival confirm is accepted with a valid profile")
	await run_frames(6)
	check(not screen.visible,"arrival screen closes after confirm")
	check(bool(app.state.profile.confirmed),"profile is marked confirmed after start")
	check(world.character_model(String(app.state.profile.gender))!=null,"world shows the chosen character")
	app.state.profile=profile0
	world.sync(app.state)

func scene_town(world:Node3D,player:CharacterBody3D)->void:
	# 去青湾镇走一圈再回岛：换场景后人物、镜头、交互点都要还在。
	if app.state.location=="villa":
		player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.2)
		await run_frames(4)
		world.leave_villa(app.state)
	app.state.hunger=90;app.state.thirst=90;app.state.energy=90
	app.state.location="island";world.sync(app.state)
	await run_frames(8)
	var gone:bool=app.state.travel("town")
	check(gone,"town route is available in good weather")
	if gone:
		world.sync(app.state)
		await run_frames(30)
		check(app.state.location=="town","state lands in the town")
		check(player.position.is_finite(),"town keeps a finite player position")
		check(world.orbit!=null,"town keeps the camera node")
		stick(Vector2(1,0))
		await run_frames(30)
		stick(Vector2.ZERO)
		check(player.position.is_finite(),"walking in town stays finite")
		var back:bool=app.state.travel("island")
		check(back,"return route from town works")
		world.sync(app.state)
		await run_frames(30)
		check(app.state.location=="island","player returns to the island")
		check(player.position.is_finite(),"returning keeps a finite position")

func scene_scan()->void:
	# 其余入口场景也要能实例化，脚本错误会在这种加载里暴露。
	for path:String in ["res://scenes/main.tscn","res://scenes/island_main.tscn"]:
		var packed:PackedScene=load(path)
		check(packed!=null,"%s loads"%path)
		if packed==null:continue
		var node:Node=packed.instantiate()
		root.add_child(node)
		await run_frames(6)
		check(is_instance_valid(node),"@%s runs a few frames"%path)
		node.queue_free()
		await run_frames(4)
