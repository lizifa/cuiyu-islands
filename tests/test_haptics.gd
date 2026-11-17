extends SceneTree
var app: Node
var now := 1000
var pulses: Array[String] = []
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value:passed+=1
	else:failed+=1;push_error(message)
func frames(n: int) -> void:
	for i in range(n):
		now+=100
		app.inactive=false
		await physics_frame
func until(stage: String) -> void:
	for i in range(500):
		if app.fishing_session.stage==stage:return
		await frames(1)
	check(false,"fishing failed to reach "+stage)
func interact_ready() -> void:
	app._nearby_interact()
	for frame in range(500):
		if not app.interaction_director.active:return
		app.inactive=false
		await physics_frame
	check(false,"interaction approach did not finish")
func _initialize():call_deferred("run")
func run():
	Engine.time_scale=8
	Engine.physics_ticks_per_second=120
	app=load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	app.inactive=false
	var feedback: Node=app.haptics
	feedback.clock=func():return now
	feedback.played.connect(func(event,_duration,_amplitude):pulses.append(event))
	check(feedback.enabled,"haptics enabled by default")
	check(feedback.play("reel"),"first reel pulse allowed")
	now+=10
	check(not feedback.play("reel"),"repeated physics frames cannot spam vibration")
	now+=70
	check(not feedback.play("reel"),"reel event has its own cooldown")
	now+=570
	check(feedback.play("reel"),"reel allows one short pulse after 650ms")
	now+=10
	check(not feedback.play("hook"),"global gap prevents stacked pulses")
	now+=1000
	check(feedback.play("bite"),"bite has a discrete signal")
	check(feedback.PULSES.bite[1]>feedback.PULSES.reel[1] and feedback.PULSES.land[1]>feedback.PULSES.reel[1],"bite and landing are stronger than ordinary winding")
	app.paused=true;now+=1000
	check(not feedback.play("land"),"pause suppresses feedback")
	app.paused=false;app.inactive=true
	check(not feedback.play("land"),"background suppresses feedback")
	app.inactive=false;app.perf_probe=true
	check(not feedback.play("land"),"performance probe never vibrates")
	app.perf_probe=false
	var before: Dictionary=app.state.snapshot()
	feedback.set_enabled(false)
	check(not feedback.play("land"),"settings can silence feedback")
	check(app.state.snapshot()==before,"preference does not mutate survival state")
	app._open_settings()
	var toggle: CheckButton=app.layout_editor.settings.find_child("FishingHaptics",true,false)
	var saver: CheckButton=app.layout_editor.settings.find_child("PerformanceSaver",true,false)
	check(not toggle.button_pressed and saver.button_pressed==app.performance_settings.saver,"settings reflect independent haptics and performance preferences")
	check(toggle.custom_minimum_size.y>=44,"feedback toggle has a mobile touch target")
	app._close_drawers()
	feedback.set_enabled(true);feedback.reset();pulses.clear();now+=1000
	app.world.player.position=Vector3(-1,.68,15.7)
	await interact_ready()
	app.fishing_session.fish_roll=.99
	check(pulses==["cast"],"actual cast emits one light pulse")
	await until("bite")
	check(pulses.count("bite")==1,"bite state emits one noticeable pulse")
	await frames(2)
	await interact_ready()
	check(pulses.count("hook")==1,"user strike emits hook feedback")
	await until("reeling")
	app.fishing_session.tension=.85
	app.fishing_session.held=true
	await frames(1)
	check(pulses.has("tension"),"high tension emits warning pulse")
	app.fishing_session.tension=.1
	app.fishing_session.held=false
	await frames(1)
	check(pulses.has("slack"),"low tension emits distinct light warning")
	app.fishing_session.tension=.4
	for i in range(650):
		if app.fishing_session.stage!="reeling":break
		app.fishing_session.held=app.fishing_session.tension<.65
		await frames(1)
	await until("result")
	check(app.fishing_session.landed and pulses.has("reel"),"real winding gives intermittent feedback and still lands fish")
	check(pulses.count("land")==1,"inventory award emits one landing pulse")
	var pulse_count := pulses.size()
	await frames(20)
	check(pulses.size()==pulse_count,"result frames do not repeat success vibration")
	app.fishing_session.cancel()
	app.queue_free()
	await process_frame
	print("HAPTICS: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
