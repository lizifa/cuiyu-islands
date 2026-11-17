extends SceneTree
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failed += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	root.add_child(view)
	var app = load("res://scenes/life_main.tscn").instantiate()
	view.add_child(app)
	app.set_process(false)
	app.inactive = false
	await process_frame
	await process_frame
	var player: CharacterBody3D = app.world.player
	player.set_physics_process(false)
	player.allowed = true
	player.position = Vector3(0,0.7,3.2)
	app.world.companion.position = Vector3(0,0.7,4.2)
	app.world.companion.set_physics_process(false)
	check(app.world.pet_companion(app.state), "pet starts approach action")
	for i in range(120): player._update_pet(1.0/60)
	check(player.pet_stage == "crouch" and player.pose_skeleton != null, "actor approaches then crouches")
	var hips: int = player._bone("Hips")
	check(player.pose_skeleton.get_bone_pose_position(hips).y < player.pose_positions[hips].y - 0.2, "hips lower during crouch")
	check(player.last_hand_target.distance_to(app.world.companion.position) < 1.5, "hand target follows actual pet head")
	var hand: int = player._bone("RightHand")
	var hand_world: Vector3 = player.pose_skeleton.global_transform * player.pose_skeleton.get_bone_global_pose(hand).origin
	print("Hand-to-head distance: ", hand_world.distance_to(player.last_hand_target))
	check(hand_world.distance_to(player.last_hand_target) < 0.05, "hand reaches pet head during stroke")
	for i in range(240): player._update_pet(1.0/60) if not player.pet_stage.is_empty() else null
	check(player.pet_stage.is_empty() and player.pose_skeleton == null, "stands up and restores animation")
	app.world.companion.position = player.position + Vector3(0,0,0.7)
	check(player.begin_pet(app.world.companion), "can repeat pet interaction")
	player.move_input = Vector2.RIGHT
	player._update_pet(0.1)
	check(player.pet_stage.is_empty(), "movement cancels pose cleanly")
	player.move_input = Vector2.ZERO
	for gender: String in ["male", "female"]:
		for pet: String in ["dog", "cat", "rabbit"]:
			app.state.profile.gender = gender
			app.state.profile.pet = pet
			app.world.sync(app.state)
			player = app.world.player
			player.allowed = true
			player.position = Vector3(0,0.7,3.2)
			app.world.companion.position = Vector3(0,0.7,4.2)
			app.world.companion.set_physics_process(false)
			check(app.world.pet_companion(app.state), "pet begins for %s/%s" % [gender,pet])
			for frame in range(120): player._update_pet(1.0/60)
			var hand_index: int = player._bone("RightHand")
			var current_hand: Vector3 = player.pose_skeleton.global_transform * player.pose_skeleton.get_bone_global_pose(hand_index).origin
			check(current_hand.distance_to(player.last_hand_target) < 0.07, "head contact for %s/%s" % [gender,pet])
			for side:String in ["Left","Right"]:
				var foot_pos:Vector3=player.pose_skeleton.global_transform*player.pose_skeleton.get_bone_global_pose(player._bone(side+"Foot")).origin
				check(absf(foot_pos.y-(player.position.y+.09*player.pose_skeleton.global_basis.get_scale().y))<.035,"crouching foot remains planted for %s/%s"%[gender,pet])
			var elapsed: float = player.pet_elapsed
			player.allowed = false
			player._physics_process(0.5)
			check(player.pet_elapsed == elapsed, "settings pause pet pose")
			player.cancel_pet()
	app._open_settings()
	app.layout_editor.begin_edit()
	check(app.layout_editor.selected == "group" and app.layout_editor.selection.item_count == 2, "only joystick and whole skill block are selectable")
	var before: Dictionary = app.layout_editor.draft.duplicate(true)
	app.layout_editor.move_selected(Vector2(-120,-70))
	var shifts := []
	for id: String in ["context","sprint","build"]:
		shifts.append(Vector2(app.layout_editor.draft[id].x - before[id].x, app.layout_editor.draft[id].y - before[id].y))
	check(shifts[0].is_equal_approx(shifts[1]) and shifts[1].is_equal_approx(shifts[2]), "entire skill block translates together")
	app.layout_editor.select("build")
	check(app.layout_editor.selected == "group", "single skill cannot split away from block")
	app.layout_editor.adjust("alpha",0.6)
	check(app.layout_editor.draft.context.alpha == 0.6 and app.layout_editor.draft.build.alpha == 0.6 and app.layout_editor.draft.sprint.alpha == 0.6, "opacity changes entire block")
	app.layout_editor.reset_draft()
	var spacing: Vector2 = app.layout_editor.rect_for("context",app.layout_editor.draft).get_center() - app.layout_editor.rect_for("sprint",app.layout_editor.draft).get_center()
	app.layout_editor.adjust("scale",1.4)
	var scaled_spacing: Vector2 = app.layout_editor.rect_for("context",app.layout_editor.draft).get_center() - app.layout_editor.rect_for("sprint",app.layout_editor.draft).get_center()
	check(scaled_spacing.is_equal_approx(spacing * 1.4), "block scales rigidly at screen edge without splitting buttons")
	app.layout_editor.cancel()
	app.state.coins = 999
	app.state.buildings["木屋"] = true
	app._confirm_reset_game()
	check(app.state.coins == 999 and app.confirmation.visible, "reset asks for confirmation without mutating progress")
	app.confirmation.hide()
	check(app._reset_game(), "confirmed reset succeeds")
	check(app.state.coins == 0 and app.state.buildings=={"小船":true} and app.state.minute == 480 and not app.state.profile.confirmed, "reset returns to fresh first-day state")
	check(app.arrival.visible and app.world.player.position.distance_to(Vector3(0,0.705,3.2)) < 0.2, "reset opens character selection at new spawn")
	view.queue_free()
	await process_frame
	print("PET BLOCK RESET: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
