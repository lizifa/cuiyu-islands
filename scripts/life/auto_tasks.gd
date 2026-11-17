extends Node
signal changed
const STEP := 0.6
const State = preload("res://scripts/life/life_state.gd")
const JOBS := {"wood": "采集木材 ×12", "stone": "拾石 ×8", "fiber": "采纤维 ×8", "fire": "建造篝火", "shelter": "搭建庇护所", "house": "建造我的家", "boat": "前往码头上船", "embark": "前往码头上船", "villa": "回家 · 海景别墅"}
const RESOURCES := {"木材": "伐木", "石材": "拾石", "纤维": "采纤维"}
var app: Node
var job := ""
var running := false
var stage := "idle"
var status := "选择目标，人物会自行前往并完成劳作。"
var goal_count := 0
var item := ""
var action := ""
var recipe := ""
var point: Dictionary = {}
var path: Array[Vector3] = []
var grid: AStarGrid2D
var heights: Dictionary = {}
var graph_key := ""
var stalled := 0.0
var previous := Vector3.ZERO
var elapsed := 0.0
var allow_night := false
var started_day := -1

func start(id: String) -> bool:
	if id=="boat":id="embark" # Compatibility for an older tracked repair task.
	if not JOBS.has(id): return false
	if not app.state.island_visit.is_empty():status="探索中，请先返回船上并返航主岛，再安排劳作。";changed.emit();return false
	if State.DAILY_TARGETS.has(id) and app.state.daily_done(id):
		status = "今天这项任务已完成，明天会刷新。"; changed.emit(); return false
	if id == "embark":
		var reason: String = app.world.boarding_block_reason(app.state)
		if not reason.is_empty(): status = reason; changed.emit(); return false
	if app.state.location != "island" or app.world.player.boating:
		status = "请先回到岛上并靠岸，再安排劳作。"; changed.emit(); return false
	if app.interaction_director!=null:
		app.interaction_director.cancel()
		app.interaction_director.begin_task_view()
	stop("")
	job = id
	started_day = app.state.day()
	item = {"wood": "木材", "stone": "石材", "fiber": "纤维"}.get(id, "")
	goal_count = int(State.DAILY_TARGETS.get(id, 0))
	running = true
	allow_night = false
	stage = "plan"
	status = "正在安排：" + JOBS[job]
	changed.emit()
	return true

func stop(reason: String = "已取消任务，进度与获得的材料保留。") -> void:
	running = false
	stage = "idle"
	path.clear()
	if app != null and app.world.player != null: app.world.player.cancel_work()
	if not reason.is_empty(): status = reason
	changed.emit()

func pause_job(reason: String = "已暂停，可点击继续执行。") -> void:
	running = false
	status = reason
	app.world.player.cancel_work()
	stage = "plan"
	changed.emit()

func resume_job(night: bool = false) -> void:
	if job.is_empty(): return
	allow_night = night
	started_day = app.state.day()
	running = true
	stage = "plan"
	changed.emit()

func tick(delta: float, manual: Vector2) -> Vector2:
	if manual.length() > 0.12:
		if running: stop("已手动接管人物，任务停止。")
		return manual
	if not running or not app.movement_enabled(): return Vector2.ZERO
	var state: RefCounted = app.state
	var actor: CharacterBody3D = app.world.player
	if State.DAILY_TARGETS.has(job) and state.day() != started_day: pause_job("新的一天，任务清单已刷新，请重新选择或继续。"); return Vector2.ZERO
	if stage == "plan" and job not in ["embark", "villa"] and _completed(): stop(_completion_message()); return Vector2.ZERO
	if state.location != "island" or actor.boating: pause_job("先回岛靠岸，再继续任务。"); return Vector2.ZERO
	if job not in ["embark", "villa"]:
		if state.energy < 10: pause_job("精力不足，请休息后继续。"); return Vector2.ZERO
		if state.hunger < 15 or state.thirst < 15: pause_job("先吃饭喝水，再继续劳作。"); return Vector2.ZERO
		if not allow_night and _is_night(): pause_job("天黑了，建议收工；也可选择继续夜间劳作。"); return Vector2.ZERO
	if stage=="walk" and job in ["villa","embark"] and app.world.transition_in_range("villa_entry" if job=="villa" else "boat"):
		path.clear();stage="act";actor.velocity=Vector3.ZERO
	match stage:
		"plan": _plan()
		"walk":
			if path.is_empty(): stage = "act"; return Vector2.ZERO
			var waypoint: Vector3 = path[0]
			var offset := waypoint - actor.position
			offset.y = 0
			if offset.length() < 0.18:
				path.pop_front(); stalled = 0; return Vector2.ZERO
			if actor.position.distance_to(previous) < delta * 0.15: stalled += delta
			else: stalled = 0
			previous = actor.position
			if stalled > 2: graph_key = ""; pause_job("道路受阻，请移动人物后继续。"); return Vector2.ZERO
			var right: Vector3 = app.world.camera.global_basis.x
			var forward: Vector3 = -app.world.camera.global_basis.z
			right.y = 0; forward.y = 0
			var direction := offset.normalized()
			return Vector2(direction.dot(right.normalized()), -direction.dot(forward.normalized())) * minf(1, offset.length() / maxf(delta * actor.WALK_SPEED, 0.01))
		"act":
			if not app.interaction_director.align_task(point,delta):return Vector2.ZERO
			if job == "villa":
				var entered: bool = app.world.enter_villa(state)
				if entered:
					stop("欢迎回家，别墅一楼有客厅、餐厅和厨房。")
					app._save(false)
					app._refresh()
				else: pause_job(state.last_message)
				return Vector2.ZERO
			if job == "embark":
				var boarded: bool = app.world.board_boat(state)
				if boarded:
					stop("已上船，用摇杆划船出海；回码头可靠岸。")
					app._save(false)
					app._refresh()
				else: pause_job(state.last_message)
				return Vector2.ZERO
			if not _in_range(): pause_job("请在目标外侧留出操作距离，再继续任务。"); return Vector2.ZERO
			if not actor.start_work(action if recipe.is_empty() else "施工", point.pos): pause_job("人物正在进行其他交互。"); return Vector2.ZERO
			stage = "work"
			status = (action if recipe.is_empty() else "施工：" + recipe) + " · 正在动手"
			changed.emit()
		"work":
			if not actor.work_done: return Vector2.ZERO
			if not _in_range(): actor.cancel_work(); pause_job("已离开目标，操作取消。"); return Vector2.ZERO
			actor.cancel_work()
			var success: bool = state.labor(action) if recipe.is_empty() else state.craft(recipe)
			if not success: pause_job(state.last_message); return Vector2.ZERO
			app.world.sync(state)
			app.world.pulse()
			app._save(false)
			if not state.save_error.is_empty(): pause_job("存档失败，请重试保存后继续。"); return Vector2.ZERO
			app._refresh()
			stage = "plan"
	return Vector2.ZERO

func _plan() -> void:
	var state: RefCounted = app.state
	if job in ["embark", "villa"]:
		recipe = ""
		action = ""
		var key := str(state.buildings)
		if grid == null or graph_key != key: _build_graph(); graph_key = key
		if not _route_to("boat" if job == "embark" else "villa_entry"): pause_job("前往目标的路线受阻，请移动后继续。"); return
		stage = "walk"
		stalled = 0
		previous = app.world.player.position
		status = "前往码头尽头，准备上船" if job == "embark" else "沿林间道路回家，准备进入别墅"
		changed.emit()
		return
	recipe = ""
	action = ""
	if not item.is_empty():
		if state.daily_done(job): stop(_completion_message()); return
		action = RESOURCES[item]
	else:
		if job == "house":
			for step: String in State.HOUSE_STAGES:
				if not state.buildings.has(step): recipe = step; break
		else: recipe = {"fire": "篝火", "shelter": "庇护所", "boat": "小船"}[job]
		if recipe.is_empty() or state.buildings.has(recipe): stop(_completion_message()); return
		for material: String in State.RECIPES[recipe]:
			if state.count(material) < int(State.RECIPES[recipe][material]):
				action = RESOURCES.get(material, "")
				break
		if not action.is_empty(): recipe = ""
	if recipe.is_empty():
		var gain_item: String = {"伐木": "木材", "拾石": "石材", "采纤维": "纤维"}[action]
		if not state.can_exchange({}, {gain_item: 4}): pause_job("背包已满，请先使用或出售物品。"); return
	var key: String = str(state.buildings)
	if graph_key != key or grid == null:
		_build_graph()
		graph_key = key
	var kind := action if recipe.is_empty() else ("boat" if recipe == "小船" else "house")
	if not _route_to(kind): pause_job("找不到可达的目标，请移动人物后继续。"); return
	stage = "walk"
	stalled = 0
	previous = app.world.player.position
	status = "前往" + (action + "地点" if recipe.is_empty() else ("码头上船" if recipe == "小船" else "营地施工：" + recipe))
	changed.emit()

func _in_range() -> bool:
	var pos: Vector3 = app.world.player.position
	var distance := Vector2(pos.x - point.pos.x, pos.z - point.pos.z).length()
	return distance <= float(point.range) and distance >= float(point.get("min_range", 0.0)) - 0.03

func _build_graph() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(-60, -75, 121, 136)
	grid.cell_size = Vector2.ONE * STEP
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	heights.clear()
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = app.world.player.BODY_RADIUS + 0.08
	shape.height = 1.6
	query.shape = shape
	query.collision_mask = 1
	var tree_query := PhysicsShapeQueryParameters3D.new()
	var tree_shape := CylinderShape3D.new()
	tree_shape.radius=app.world.player.TREE_RADIUS+.05
	tree_shape.height=app.world.player.TREE_HEIGHT
	tree_query.shape=tree_shape;tree_query.collision_mask=8
	var excludes: Array[RID] = []
	for body: StaticBody3D in app.world.forest.find_children("*", "StaticBody3D", true, false):
		for collider: Node in body.get_children():
			if collider is CollisionShape3D and collider.shape is ConcavePolygonShape3D: excludes.append(body.get_rid())
	if is_instance_valid(app.world.companion):excludes.append(app.world.companion.get_rid())
	query.exclude = excludes
	var physics: PhysicsDirectSpaceState3D = app.world.get_world_3d().direct_space_state
	for x in range(-40, 41):
		for z in range(-40, 41):
			var id := Vector2i(x, z)
			var pos := Vector3(x * STEP, 0, z * STEP)
			if not app.world.terrain_walkable(pos): grid.set_point_solid(id); continue
			pos.y = app.world.terrain_height(pos.x, pos.z)
			heights[id] = pos.y
			query.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.87, 0))
			tree_query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*(app.world.player.TREE_HEIGHT*.5+.03))
			if not physics.intersect_shape(query, 1).is_empty() or not physics.intersect_shape(tree_query,1).is_empty(): grid.set_point_solid(id)
	# Block steep transitions in addition to dry terrain checks.
	for id: Vector2i in heights:
		for shift: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			if heights.has(id + shift) and absf(heights[id] - heights[id + shift]) > 0.32: grid.set_point_solid(id)

func _route_to(kind: String) -> bool:
	var origin: Vector3 = app.world.player.position
	var start := Vector2i(roundi(origin.x / STEP), roundi(origin.z / STEP))
	if not grid.is_in_boundsv(start): return false
	if grid.is_point_solid(start):
		var found := false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var cell := start + Vector2i(dx, dz)
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell): start = cell; found = true; break
			if found: break
		if not found: return false
	var candidates: Array[Dictionary] = []
	var points: Array = app.world.interaction_points
	if recipe == "篝火": points = [{"kind": kind, "pos": Vector3(-1,0.7,2), "range": 1.5, "min_range": 1.0}]
	elif recipe == "庇护所": points = [{"kind": kind, "pos": Vector3(3,0.7,0), "range": 2.2, "min_range": 1.2}]
	for candidate: Dictionary in points:
		if candidate.kind != kind: continue
		var distance := origin.distance_to(candidate.pos)
		candidates.append({"point": candidate, "distance": distance})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	for entry: Dictionary in candidates:
		var candidate: Dictionary = entry.point.duplicate()
		if kind == "boat": candidate.range = 1.2
		var center := Vector2i(roundi(candidate.pos.x / STEP), roundi(candidate.pos.z / STEP))
		var radius := ceili(float(candidate.range) / STEP)
		var best_path: Array[Vector2i] = []
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var cell := center + Vector2i(dx, dz)
				if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
				var distance := Vector2(cell.x * STEP - candidate.pos.x, cell.y * STEP - candidate.pos.z).length()
				if distance > float(candidate.range) - 0.2 or distance < float(candidate.get("min_range", 0.0)) + 0.18: continue
				var route := grid.get_id_path(start, cell)
				if not route.is_empty() and (best_path.is_empty() or route.size() < best_path.size()): best_path = route
		if best_path.is_empty(): continue
		point = candidate
		path.clear()
		for cell: Vector2i in best_path: path.append(Vector3(cell.x * STEP, heights[cell] + 0.03, cell.y * STEP))
		return true
	return false

func _completed() -> bool:
	if not item.is_empty(): return app.state.daily_done(job)
	if job == "embark": return app.world.player.boating
	if job == "villa": return app.state.location == "villa"
	if job == "house": return app.state.buildings.has("木屋")
	var building: String = {"fire": "篝火", "shelter": "庇护所", "boat": "小船"}.get(job, "")
	return not building.is_empty() and app.state.buildings.has(building)

func _is_night() -> bool:
	var rise: float = [6.0,5.0,6.0,7.0][app.state.season()]
	var setting: float = [18.0,20.0,18.0,17.0][app.state.season()]
	return app.state.hour() < rise or app.state.hour() >= setting

func cancel_job() -> void:
	stop("已取消任务，已获得的材料保留。")
	job = ""
	item = ""
	goal_count = 0
	changed.emit()

func _completion_message() -> String:
	if job == "boat": return "小船可直接使用，请前往码头上船。"
	return "任务完成：" + JOBS[job]
