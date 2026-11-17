extends RefCounted
## Plans over real water/obstacles, then drives the same collision-aware controller as the joystick.
var world: Node3D
var active := false
var path: Array[Vector3] = []
var stalled := 0.0
var previous := Vector3.ZERO
var status := ""
func cancel(message: String="") -> void:
	active=false
	path.clear()
	if not message.is_empty():
		status=message
		world.navigation_state.say(message)
func start() -> bool:
	if not world.player.boating: return false
	cancel()
	if Vector2(world.player.position.x-world.MOORING.x,world.player.position.z-world.MOORING.z).length()<.5:
		return world.disembark_boat()
	var origin:Vector3=world.player.position
	if Vector2(origin.x,origin.z).length()>55:
		var global_route:Array[Vector3]=_ocean_route(origin,Vector3(8,.05,32))
		if global_route.is_empty():return _fail("暂时没有安全返航路线，请先驶离岸边后重试。")
		path.append_array(global_route);origin=global_route.back()
	var grid := AStarGrid2D.new()
	grid.region=Rect2i(-58,-58,117,117)
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var query := PhysicsShapeQueryParameters3D.new()
	var broad := CylinderShape3D.new()
	broad.radius=1.85; broad.height=.8
	var narrow := BoxShape3D.new()
	narrow.size=Vector3(1.7,.8,3.6)
	query.collision_mask=5
	query.exclude=[world.player.get_rid()]
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	for x in range(-58,59):
		for z in range(-58,59):
			var id := Vector2i(x,z)
			var pos := Vector3(x,.05,z)
			if not world.navigable_water(pos):grid.set_point_solid(id);continue
			query.shape=narrow if x>=5 and x<=7 and z>=17 and z<=24 else broad
			query.transform=Transform3D(Basis.IDENTITY,pos+Vector3(0,.1,0))
			if not space.intersect_shape(query,1).is_empty():grid.set_point_solid(id)
	var start_id := Vector2i(roundi(origin.x),roundi(origin.z))
	var berth := Vector2i(roundi(world.MOORING.x),roundi(world.MOORING.z))
	var goal := berth+Vector2i(0,6)
	if not grid.is_in_boundsv(start_id):return _fail("已超出可返航海域，请先驶回海图范围。")
	grid.set_point_solid(start_id,false)
	if grid.is_point_solid(goal) or grid.is_point_solid(berth):return _fail("泊位被挡住了，请稍后重试自动靠岸。")
	var route := grid.get_id_path(start_id,goal)
	if route.is_empty():return _fail("暂时找不到安全返航路线，请手动驶离障碍后重试。")
	for cell: Vector2i in route:path.append(Vector3(cell.x,.05,cell.y))
	# Align lengthwise in open water before entering the narrow berth.
	for z in range(goal.y-1,berth.y-1,-1):path.append(Vector3(berth.x,.05,z))
	active=true;stalled=0;previous=world.player.position
	status="正在自动返航，摇杆可随时接管。"
	world.navigation_state.say(status)
	return true
func _fail(message: String) -> bool:
	cancel(message)
	return false
func tick(delta: float, manual: Vector2) -> Vector2:
	if manual.length()>.12:
		if active:cancel("已手动接管航船。")
		return manual
	if not active:return manual
	if not world.player.boating:cancel();return Vector2.ZERO
	var actor: CharacterBody3D=world.player
	if path.size()<=1 and actor.position.distance_to(world.MOORING)<.5:
		if actor.velocity.length()<.5:
			cancel()
			world.disembark_boat()
			status="已安全靠岸。"
			world.navigation_state.log_event("船已停稳靠岸，回到自己的码头。")
		return Vector2.ZERO
	if path.is_empty():cancel("返航中断，请重新选择自动靠岸。");return Vector2.ZERO
	var offset: Vector3=path[0]-actor.position
	offset.y=0
	while offset.length()<.35 and path.size()>1:
		path.pop_front();offset=path[0]-actor.position;offset.y=0
	if actor.position.distance_to(previous)<delta*.1:stalled+=delta
	else:stalled=0
	previous=actor.position
	if stalled>2.5:cancel("前方受阻，自动靠岸已暂停，请手动调整后重试。");return Vector2.ZERO
	var right: Vector3=world.camera.global_basis.x
	var forward: Vector3=-world.camera.global_basis.z
	right.y=0;forward.y=0
	var direction := offset.normalized()
	return Vector2(direction.dot(right.normalized()),-direction.dot(forward.normalized()))*minf(1,offset.length()*.7)

func _safe_segment(a:Vector3,b:Vector3) -> bool:
	var heading:float=atan2(b.x-a.x,b.z-a.z)
	var steps:int=maxi(1,ceili(a.distance_to(b)/1.5))
	for index in range(1,steps+1):
		var point:Vector3=a.lerp(b,index/float(steps))
		if not world.navigable_water(point) or not world.boat_heading_is_clear(point,heading):return false
	return true
func _ocean_route(origin:Vector3,goal:Vector3) -> Array[Vector3]:
	var step:=8.0
	var grid:=AStarGrid2D.new()
	var low:=Vector2i(maxi(-75,floori(minf(origin.x,goal.x)/step)-12),maxi(-75,floori(minf(origin.z,goal.z)/step)-12))
	var high:=Vector2i(mini(75,ceili(maxf(origin.x,goal.x)/step)+12),mini(75,ceili(maxf(origin.z,goal.z)/step)+12))
	grid.region=Rect2i(low,high-low+Vector2i.ONE);grid.cell_size=Vector2.ONE*step;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for x in range(low.x,high.x+1):
		for z in range(low.y,high.y+1):
			var clear:=true
			for offset:Vector2 in [Vector2.ZERO,Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4),Vector2(3,3),Vector2(-3,3),Vector2(3,-3),Vector2(-3,-3)]:
				if not world.navigable_water(Vector3(x*step+offset.x,.05,z*step+offset.y)):clear=false;break
			if not clear:grid.set_point_solid(Vector2i(x,z))
	var start:=Vector2i(roundi(origin.x/step),roundi(origin.z/step));var end:=Vector2i(roundi(goal.x/step),roundi(goal.z/step))
	var best:=Vector2i(9999,9999);var distance:=INF
	for x in range(start.x-5,start.x+6):
		for z in range(start.y-5,start.y+6):
			var candidate:=Vector2i(x,z)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):continue
			var point:=Vector3(x*step,.05,z*step);var span:float=point.distance_to(origin)
			if span<distance and _safe_segment(origin,point):best=candidate;distance=span
	var result:Array[Vector3]=[]
	if best.x==9999 or not grid.is_in_boundsv(end) or grid.is_point_solid(end):return result
	var route:Array[Vector2i]=grid.get_id_path(best,end)
	for cell:Vector2i in route:result.append(Vector3(cell.x*step,.05,cell.y*step))
	return result
