extends SceneTree
var failed := 0
var passed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var app = load("res://scenes/life_main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	app.inactive = false
	var settings: Node = app.performance_settings
	settings.mobile = true
	settings.set_saver(true)
	check(settings.desired_cap()==30 and is_equal_approx(root.scaling_3d_scale,.8),"mobile default 30fps and 80 percent 3D scale")
	check(app.world.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_ORTHOGONAL,"single shadow map budget in saver mode")
	check(app.world.forest.batching and not app.world.forest.tree_batches.is_empty(),"saver batches trees without removing collision nodes")
	var forest: Node3D = app.world.forest
	var tree: Node3D = forest.trees[0]
	var links: Array = forest.batch_links[tree.get_instance_id()]
	check(links.all(func(link): return not link.mesh.visible),"batched tree mesh is not drawn twice")
	var center: Vector3 = tree.position+Vector3(0,2.7,0)
	forest.reveal_player(center+Vector3(0,0,5),center-Vector3(0,0,5))
	check(links.all(func(link): return link.mesh.visible and link.obstructing),"occluding tree switches back to individual transparent rendering")
	check(tree.find_child("TreeObstacle",true,false).collision_layer==9,"batching keeps solid tree physics active")
	settings.set_saver(false)
	check(settings.desired_cap()==60 and root.scaling_3d_scale==1,"60fps full resolution remains selectable")
	check(not app.world.forest.batching,"full quality restores individual tree geometry")
	app.paused = true
	check(settings.desired_cap()==15,"pause limits rendering to 15fps")
	app.inactive = true
	check(settings.desired_cap()==5,"background rendering limited to five fps")
	app.paused = false; app.inactive = false
	app.perf_probe = true
	var minute: float = app.state.minute
	app._process(30)
	check(app.state.minute==minute,"measurement mode freezes survival clock")
	settings.mobile = false
	settings.apply()
	app.queue_free()
	await process_frame
	print("PERFORMANCE SETTINGS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
