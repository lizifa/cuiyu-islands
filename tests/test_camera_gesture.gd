extends SceneTree
## 双指缩放只做水平转向，绝不改变镜头臂长 / 人物在三种环境保持同一屏幕高度。

var passed := 0
var failed := 0

func check(ok: bool, name: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(name)

func run() -> void:
	var life_world = load("res://scripts/life/life_world.gd")
	var world = life_world.new()
	get_root().add_child(world)
	await process_frame
	await process_frame
	var rig = world.orbit
	var stc = world.stable_camera if "stable_camera" in world else null

	# 1. 双指放大不拉近：arm 恒定
	var arm_before: float = rig.distance
	var target_before: float = rig.target_distance
	var ev := InputEventMagnifyGesture.new()
	ev.factor = 1.35
	rig._unhandled_input(ev)
	check(is_equal_approx(rig.distance, arm_before), "pinch keeps current arm")
	check(rig.target_distance == target_before, "pinch keeps target arm")
	check(absf(angle_difference(rig.target_yaw, rig.initial_yaw)) > .001, "pinch turns the camera horizontally")

	# 2. 双指缩小同样不拉远
	var arm2: float = rig.distance
	ev = InputEventMagnifyGesture.new()
	ev.factor = 0.62
	rig._unhandled_input(ev)
	check(is_equal_approx(rig.distance, arm2), "pinch out keeps arm")

	# 3. 两指拖动只转水平角，不改俯仰
	var pitch_before: float = rig.target_pitch
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(60, 40)
	rig._unhandled_input(pan)
	check(is_equal_approx(rig.target_pitch, pitch_before), "pan keeps pitch")
	check(absf(angle_difference(rig.target_yaw, rig.initial_yaw)) > .001, "pan turns horizontally")

	# 4. 三种环境共用同一镜头臂，人物屏幕高度一致
	var stc_script = load("res://scripts/life/stable_third_person_camera.gd")
	check(is_equal_approx(stc_script.OUTDOOR_DISTANCE, stc_script.INDOOR_DISTANCE), "outdoor and indoor arms match")
	check(is_equal_approx(stc_script.BOAT_DISTANCE, stc_script.OUTDOOR_DISTANCE), "boat arm matches outdoor")
	print("CAMERA GESTURE: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _init() -> void:
	await run()
