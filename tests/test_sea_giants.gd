extends SceneTree
## 海里的大个头：鲨鱼、鲸鱼、鱼群与船尾大水花的 headless 检查。
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
	var player:CharacterBody3D=world.player
	player.set_physics_process(false)
	app.state.location="island"
	app.state.minute=8*60
	world.sync(app.state)
	var giants:Node=world.sea_giants
	giants.set_physics_process(false)
	check(giants!=null and giants.sharks.size()==2,"two sharks patrol the island sea")
	check(giants.whales.size()==1 and giants.prey.size()==10,"one whale and a bait ball of ten small fish")
	for shark in giants.sharks:
		check(shark.node.is_inside_tree() and shark.node.position.y<-0.6,"sharks swim below the surface line")
	check(absf(giants.whales[0].node.position.y)<3.0,"whale floats just under the surface")
	# 鲸鱼喷水
	var whale:Dictionary=giants.whales[0]
	whale.timer=0.0
	giants.step(.1)
	check(whale.spouting>0.0 and whale.spout.emitting,"whale spouts water when it surfaces")
	check(whale.timer>20.0,"spout is followed by a long cooldown")
	for i in range(60):giants.step(.1)
	check(whale.spout.emitting==false or whale.spouting<=0.0,"spout stops instead of spraying forever")
	# 鲨鱼追小鱼：鱼群被逼近后逃开
	var shark:Dictionary=giants.sharks[0]
	shark.cooldown=0.0
	var fish:Dictionary=giants.prey[0]
	fish.node.position=shark.node.position+Vector3(1.2,-0.2,1.2)
	var gap_before:float=fish.node.position.distance_to(shark.node.position)
	for i in range(20):giants.step(.05)
	var gap_after:float=fish.node.position.distance_to(shark.node.position)
	check(gap_after>gap_before+.4,"small fish flee when a shark closes in")
	check(giants.sharks[0].lunge>0.0,"shark speeds up into a hunt")
	# 靠太近撞船
	player.boating=true
	player.position=shark.node.position+Vector3(1.0,0,1.0)
	var events:int=giants.attack_events
	giants.step(.05)
	check(giants.attack_events==events+1,"a shark bumping the hull counts as an attack")
	check(giants.last_attack_text.contains("鲨鱼"),"the bump is reported to the player")
	check(player.position.distance_to(shark.node.position)>1.6,"the boat is shoved away from the shark")
	check(world.boat_wake.emission_count>0,"the bump raises a splash at the boat")
	# 船上「驱赶鲨鱼」：鲨鱼贴近时可用，按一下把鲨鱼推远并让它长时间不敢再冲
	player.boating=true
	player.position=shark.node.position+Vector3(1.0,0,1.0)
	check(giants.shark_threat()<=12.0 and giants.repel_ready(),"threat unlocks the repel skill while boating")
	var gap_start:float=shark.node.position.distance_to(player.position)
	check(giants.repel() and shark.node.position.distance_to(player.position)>gap_start+4.0,"repel shoves the shark away")
	check(not giants.repel_ready(),"repel goes on cooldown")
	check(giants.last_attack_text.contains("鲨鱼") and world.boat_wake.emission_count>0,"repel reports back with a splash")
	check(giants.sharks[0].cooldown>=9.0,"a repelled shark holds off for a while")
	player.boating=false
	player.position=Vector3(10,0.05,10)
	giants.step(.05)
	check(giants.attack_events==events+1,"sharks do not attack a player standing ashore")
	# 船加速时船尾大水花
	var wake:Node=world.boat_wake
	var at:=Vector3(20,.05,20)
	var heading:=0.0
	for i in range(30):
		at+=Vector3(sin(heading),0,cos(heading))*7.0/60.0
		wake.tick(1.0/60.0,at,true,heading)
	check(wake.boost>0.5,"a sprinting boat builds a boost wake")
	check(wake.boost_events>0,"boost emits extra stern wash")
	check(wake.boost_spray.emitting,"boost shows a stern spray effect")
	for i in range(60):
		wake.tick(1.0/60.0,at,true,heading)
	check(wake.boost<0.2 and not wake.boost_spray.emitting,"coasting lets the boost splash fade away")
	wake.clear()
	app.queue_free()
	await process_frame
	print("SEA GIANTS: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
