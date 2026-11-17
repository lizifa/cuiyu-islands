extends SceneTree
## 电脑端演示脚本：不是断言，而是把游戏真跑起来、按剧本操作，配合 --write-movie 逐帧出图。
## 用法：Godot --path . --script res://tests/sim_demo.gd -- --test-mode --write-movie /tmp/sim/shot.png --fixed-fps 30
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in range(n):await physics_frame
func stick(dir:Vector2)->void:
	if app.joystick!=null:
		if app.joystick.has_method("set_direction"):app.joystick.set_direction(dir)
		else:app.joystick.direction=dir
	app.state.player_position=[app.world.player.position.x,app.world.player.position.y,app.world.player.position.z]
var app:Node
var shot_index:=0
func mark(text:String)->void:
	await RenderingServer.frame_post_draw
	await physics_frame
	var image:=root.get_texture().get_image()
	if image!=null:
		shot_index+=1
		var path:="/tmp/sim/%02d.png"%shot_index
		image.save_png(path)
		print("DEMO_SHOT ",path)
	print("DEMO_MARK ",Engine.get_physics_frames()," ",text)
func run()->void:
	app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app)
	app.set_process(true);app.set_physics_process(true);app.inactive=false;app.paused=false
	await frames(24)
	var world:Node3D=app.world
	var player:CharacterBody3D=world.player
	app.state.location="island";app.state.minute=9*60;app.state.energy=100;app.state.hunger=95;app.state.thirst=95
	world.sync(app.state)
	await frames(20)
	mark("岛上出生点，正面视角")
	player.position=world.DOCK
	stick(Vector2(0,-1))
	await frames(70)
	stick(Vector2.ZERO)
	await frames(10)
	mark("往前走到码头边")
	# 长按拖拽转视角（真实触摸通道）
	var orbit=world.orbit
	var point:=Vector2(root.get_visible_rect().size.x*.55,root.get_visible_rect().size.y*.45)
	var down:=InputEventScreenTouch.new();down.index=0;down.position=point;down.pressed=true
	root.push_input(down)
	await frames(12)
	mark("手指按住不动（长按）")
	for i in range(18):
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=point+Vector2((i+1)*26,0);drag.relative=Vector2(26,0)
		orbit._unhandled_input(drag)
		await frames(2)
	mark("横向拖拽，镜头水平转动")
	var up:=InputEventScreenTouch.new();up.index=0;up.position=point+Vector2(468,0);up.pressed=false
	root.push_input(up)
	await frames(60)
	mark("松手后视角保持")
	# 走向别墅并进门
	player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+3.0)
	await frames(10)
	player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.4)
	await frames(6)
	world.enter_villa(app.state)
	await frames(45)
	mark("进入别墅一层客厅")
	player.position=world.Villa.STAIR_ENTRY
	await frames(90)   # 真机上玩家是走到楼梯口的，镜头需要一点时间收进楼梯构图
	world.change_home_floor(app.state)
	await frames(120)
	mark("走上二楼卧室")
	player.position=world.Villa.STAIR_ENTRY
	await frames(90)
	world.change_home_floor(app.state)
	await frames(140)
	mark("下到一楼")
	player.position=Vector3(world.Villa.ENTRY.x,0,world.Villa.ENTRY.z+1.2)
	await frames(8)
	world.leave_villa(app.state)
	await frames(30)
	mark("走出别墅回到岛上")
	# 自动接任务走路
	app.state.location="island";app.state.island_visit={}
	world.sync(app.state)
	player.position=world.DOCK
	await frames(15)
	var started:bool=app.auto_task.start("villa")
	print("DEMO_AUTOTASK started=",started)
	await frames(150)
	mark("自动接任务：人物自己往别墅走")
	await frames(150)
	mark("自动走路进行中")
	app.auto_task.stop("")
	await frames(20)
	# 去青湾镇
	app.state.hunger=90;app.state.thirst=90
	app.state.location="island";world.sync(app.state)
	var gone:bool=app.state.travel("town")
	print("DEMO_TRAVEL town=",gone)
	if gone:
		world.sync(app.state)
		await frames(60)
		mark("青湾镇港口集市")
		stick(Vector2(1,0))
		await frames(50)
		stick(Vector2.ZERO)
		await frames(20)
		app.state.travel("island")
		world.sync(app.state)
		await frames(60)
		mark("返航主岛")
	print("DEMO_DONE frames=",Engine.get_physics_frames())
	quit()
