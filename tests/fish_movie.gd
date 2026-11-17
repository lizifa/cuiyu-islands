extends SceneTree
## 电脑端「钓鱼录屏」：真跑 life_main，自动钓鱼脚本走完整流程，同时按帧抓视口出 JPG 序列，
## 之后再合成 mp4（tools/jpg_sequence_to_mp4.swift）。
## 用法：QGYH_AUTOPILOT=fishing Godot --path . --script res://tests/fish_movie.gd -- --test-mode
const OUT_DIR := "/tmp/fishmovie"
const SECONDS := 58.0
const FPS := 15.0

var app: Node
var saved := 0
var clock := 0.0
var next_at := 0.0
var last_stage := ""


func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# 清掉上一次的帧，避免混进旧序列
	var dir := DirAccess.open(OUT_DIR)
	if dir != null:
		for name in dir.get_files():
			dir.remove(name)
	app = load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app)
	app.set_process(true)
	app.set_physics_process(true)
	app.inactive = false
	app.paused = false
	await frames(20)
	app.state.location = "island"
	app.state.minute = 9 * 60
	app.state.energy = 100
	app.state.hunger = 95
	app.state.thirst = 95
	app.world.sync(app.state)
	var limit := SECONDS
	var override := OS.get_environment("FISH_MOVIE_SECONDS")
	if override != "":
		limit = float(override)
	var elapsed := 0.0
	while elapsed < limit:
		await physics_frame
		var step := 1.0 / Engine.physics_ticks_per_second
		elapsed += step
		clock += step
		if clock >= next_at:
			next_at += 1.0 / FPS
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image != null:
				image.save_jpg("%s/%05d.jpg" % [OUT_DIR, saved], 0.72)
				saved += 1
		var session: Node = app.get("fishing_session")
		if session != null:
			var stage := str(session.get("stage"))
			if stage != last_stage:
				last_stage = stage
				print("MOVIE stage=", stage, " t=", "%.1f" % elapsed, " frame=", saved, " msg=", app.state.last_message)
	print("MOVIE_DONE frames=", saved)
	quit()
