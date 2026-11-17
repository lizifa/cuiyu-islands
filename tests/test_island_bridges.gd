extends SceneTree
## 岛屿木桥：岛岛有桥、桥面可走、栏杆外不可走、划船不被桥面挡住。
var passed:=0
var failed:=0
var app:Node
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app)
	app.set_process(false);app.set_physics_process(false);app._close_drawers();app.inactive=false;app.paused=false
	await physics_frame;await physics_frame
	var world:Node3D=app.world
	var bridges:Node=world.bridges
	var islands:Array=world.seascape.islands
	check(bridges!=null and islands.size()>0,"bridges exist and islands are built")
	check(bridges.bridges.size()==islands.size(),"every island gets exactly one bridge")
	for island:Node3D in islands:
		var id:String=String(island.spec.id)
		check(bridges.has_bridge(id),"bridge built for "+id)
		var data:Dictionary=bridges.bridges[id]
		var origin:Vector3=data.origin
		var dir:Vector3=data.dir
		var length:float=float(data.length)
		var deck:float=float(data.surface)
		# 桥头压岛岸、桥尾在水面外
		var start_height:float=world.island_ground_height(origin+dir*0.2)
		check(absf(start_height-deck)<0.45,"bridge mouth meets the shore on "+id)
		var beyond:Vector3=origin+dir*(length+1.2)
		check(world.island_ground_height(beyond)<0.05,"bridge ends over open water on "+id)
		# 桥面可走、桥外不可走
		var mid:Vector3=origin+dir*(length*0.6)
		check(is_equal_approx(bridges.height_at(mid),deck),"deck height applies on "+id)
		check(world.terrain_walkable(mid),"player can walk the bridge on "+id)
		var side:Vector3=mid+Vector3(-dir.z,0,dir.x)*(bridges.DECK_WIDTH*0.5+0.4)
		check(bridges.height_at(side)==-INF,"railing keeps the player off the side on "+id)
		# 桥面只抬高一侧：横向外侧仍是水，划船能过
		var water:Vector3=beyond
		check(bridges.height_at(water)==-INF,"water stays water past the bridge end on "+id)
	# 上船时不把桥面当地面，避免船只被桥挡路
	var probe:Vector3=bridges.bridges.values()[0].origin+bridges.bridges.values()[0].dir*3.0
	world.player.boating=false
	var walk_height:float=world.island_ground_height(probe)
	world.player.boating=true
	var boat_height:float=world.island_ground_height(probe)
	world.player.boating=false
	check(walk_height>boat_height,"deck only counts for walking, not for boating")
	print("ISLAND BRIDGES: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
