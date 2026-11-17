extends CharacterBody3D
var exercise_return:=Vector3.INF
var manual_world_direction:=Vector3.INF
var manual_stair_entry:=Callable()
var stair_manual:=false
var manual_stair_input:=Vector2.ZERO
var stair_route:Array[Vector3]=[]
var stair_view_ready:=Callable()
var manual_stairs=preload("res://scripts/life/manual_stairs.gd").new()
var stair_motion=preload("res://scripts/life/stair_motion.gd").new()
var stair_active := false
var stair_path: Array[Vector3] = []
var stair_finished := Callable()
var stair_stalled := 0.0
# 镜头构图闸的超时兜底：真机上相机偶尔会被墙体挡住而一直构不好图，
# 老实现会让玩家永远卡在楼梯口，这里超时后直接放行，楼梯照常走完。
const STAIR_VIEW_TIMEOUT := 0.6
var stair_view_wait := 0.0
var stair_view_blocked := false
var stair_return := Vector3.ZERO
var stair_best := INF
var bed_motion: RefCounted
var bed_stage := ""
var bed_return := Vector3.ZERO
var bed_anchor := Vector3.ZERO
var bed_blend := 0.0
var bed_visual_transform := Transform3D.IDENTITY
var bed_hidden: Dictionary = {}
var terrain_height := Callable()
var tree_motion := Callable()
var terrain_walkable := Callable()
var settled_position := Vector3.INF
var sofa_seated := false
var sofa_reclining:=false
var sofa_rock:=0.0
var sofa_stretch:=0.0
var sofa_return := Vector3.ZERO
var sofa_blend := 0.0
var sofa_origin := Vector3.ZERO
var sofa_anchor := Vector3.ZERO
var home_cancel:=Callable()
var home_move_direction:=Vector3.ZERO
var home_busy:=false
var sofa_yaw:=PI
var sofa_foot_distance:=.52
var seated_eat_time:float=-1
var sofa_hip_offset := -0.56
var grounded_pose=preload("res://scripts/life/grounded_pose.gd")
var pet_hip_drop:=0.0
var pet_feet:Array[Vector3]=[]
var fishing_stage := ""
var fishing_animation=preload("res://scripts/life/fishing_animation.gd").new()
var fishing_return := Vector3.ZERO
var fishing_steps=preload("res://scripts/life/fishing_steps.gd").new()
var fishing_anchor := Vector3.ZERO
var fishing_hip_offset := -.7
var working := false
var work_done := false
var work_yaw := 0.0
var _last_strong_dir := Vector3.ZERO
var work_elapsed := 0.0
var work_kind := ""
var work_tool: Node3D
var pet_target: Node3D
var pet_stage := ""
var pet_elapsed := 0.0
var pose_skeleton: Skeleton3D
var pose_positions: Array[Vector3] = []
var pose_rotations: Array[Quaternion] = []
var last_hand_target := Vector3.ZERO
var walking_shapes: Array[CollisionShape3D] = []
var hull_collider: CollisionShape3D
var boat_heading := 0.0
var boat_heading_clear := Callable()
var boating := false
var sea_walkable := Callable()
var rowing_pose:RefCounted
var boat_visual: Node3D
var camera: Camera3D
var visual: Node3D
var animator: AnimationPlayer
var idle_clip: StringName
var walk_clip: StringName
var run_clip: StringName
var move_input := Vector2.ZERO
var sprint := false
var allowed := true
const BODY_RADIUS := 0.4
const TREE_RADIUS := 0.68
const TREE_HEIGHT := 2.5
const WALK_SPEED := 2.6
const RUN_SPEED := 4.2

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	walking_shapes.append(shape)
	var feet := CollisionShape3D.new()
	var footprint := CylinderShape3D.new()
	footprint.radius=BODY_RADIUS
	footprint.height=.28
	feet.shape=footprint
	feet.position.y=.15
	add_child(feet)
	walking_shapes.append(feet)
	hull_collider=CollisionShape3D.new()
	hull_collider.name="BoatHullCollider"
	hull_collider.shape=preload("res://scripts/life/boat_hull.gd").shape(1.1,-.3)
	hull_collider.disabled=true
	add_child(hull_collider)
	for pair: Array in [["player_left", KEY_A, KEY_LEFT], ["player_right", KEY_D, KEY_RIGHT], ["player_up", KEY_W, KEY_UP], ["player_down", KEY_S, KEY_DOWN]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0], 0.16)
			for key: int in [pair[1], pair[2]]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(pair[0], event)

func bind_visual(model: Node3D) -> void:
	visual = model
	animator = null
	idle_clip = &""
	walk_clip = &""
	run_clip = &""
	for child: Node in visual.find_children("*", "AnimationPlayer", true, false):
		animator = child
		for clip: StringName in animator.get_animation_list():
			var lower := str(clip).to_lower()
			if "idle" in lower: idle_clip = clip
			elif "walk" in lower: walk_clip = clip
			elif "run" in lower: run_clip = clip
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		break

func _physics_process(delta: float) -> void:
	if camera == null: return
	if home_busy:
		velocity=Vector3.ZERO
		return
	if stair_active:
		if allowed:
			var before:Vector3=position
			_update_stairs(delta)
			if stair_active:stair_motion.tick(delta,before)
		return
	if bed_stage!="":
		if allowed:_update_bed(delta)
		return
	if not fishing_stage.is_empty(): return
	if sofa_seated:
		if allowed: _update_sofa(delta)
		return
	if working:
		if allowed: _update_work(delta)
		return
	if not pet_stage.is_empty():
		if allowed: _update_pet(delta)
		return
	var input := move_input.limit_length() if allowed else Vector2.ZERO
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0
	forward.y = 0
	var direction := (right.normalized() * input.x - forward.normalized() * input.y).limit_length()
	# 记住「最近一次有力的方向」：摇杆回中时朝向不要跟着抖回去
	if direction.length() > 0.2: _last_strong_dir = direction.normalized()
	if not boating and allowed and manual_world_direction.is_finite():direction=manual_world_direction
	if not boating and direction.length()>.2 and manual_stair_entry.is_valid() and manual_stair_entry.call(direction):return
	var speed := (7.0 if sprint else 4.0) if boating else (RUN_SPEED if sprint else WALK_SPEED)
	if boating or not allowed:
		velocity.x=direction.x*speed;velocity.z=direction.z*speed
	else:
		var planar:Vector2=Vector2(velocity.x,velocity.z).move_toward(Vector2(direction.x,direction.z)*speed,14*delta)
		velocity.x=planar.x;velocity.z=planar.y
	if boating:
		if rowing_pose!=null and not rowing_pose.ready():direction=Vector3.ZERO;velocity=Vector3.ZERO
		if direction.length()>.05:
			var next_heading := lerp_angle(boat_heading,atan2(direction.x,direction.z),1-exp(-5*delta))
			if not boat_heading_clear.is_valid() or boat_heading_clear.call(position,next_heading): boat_heading=next_heading
			else:
				# Take the available fraction of a turn instead of freezing all steering.
				var clear_heading := boat_heading
				var blocked_heading := next_heading
				for attempt in range(6):
					var partial := lerp_angle(clear_heading,blocked_heading,.5)
					if boat_heading_clear.call(position,partial): clear_heading=partial
					else: blocked_heading=partial
				boat_heading=clear_heading
		hull_collider.rotation.y=boat_heading
		var previous_sea := position
		var next := position+Vector3(velocity.x,0,velocity.z)*delta
		velocity.y=0
		if not sea_walkable.is_valid() or sea_walkable.call(next): move_and_slide()
		else: velocity=Vector3.ZERO
		if sea_walkable.is_valid() and not sea_walkable.call(position): position=previous_sea
		position.y=.05
		if rowing_pose==null or rowing_pose.ready():visual.rotation.y=boat_heading+PI
		if boat_visual!=null: boat_visual.rotation.y=boat_heading
		if rowing_pose!=null:
			var travelled:float=Vector2(position.x-previous_sea.x,position.z-previous_sea.z).length()
			rowing_pose.tick(delta,travelled/maxf(delta,.001))
		return
	if tree_motion.is_valid():
		var motion: Vector3=tree_motion.call(position,Vector3(velocity.x,0,velocity.z)*delta)
		velocity.x=motion.x/maxf(delta,.0001)
		velocity.z=motion.z/maxf(delta,.0001)
	velocity.y = -0.2 if is_on_floor() else velocity.y - 12 * delta
	if direction.length()>.05 and is_on_floor() and is_on_wall(): _step_small_lip(direction)
	var previous := position
	var settled := direction.length_squared() < 0.0001 and is_on_floor() and position.distance_squared_to(settled_position) < 0.000001
	if not settled:
		move_and_slide()
		if tree_motion.is_valid():
			var corrected: Vector3=tree_motion.call(previous,position-previous)
			position=previous+corrected
	settled_position = position
	if terrain_walkable.is_valid() and not settled:
		if not terrain_walkable.call(position):
			position = previous
			velocity = Vector3.ZERO
		var floor_y: float = terrain_height.call(position.x, position.z)
		if position.y < floor_y - 0.1:
			position.y = floor_y + 0.03
			velocity.y = 0
	if visual != null and direction.length() > 0.05:
		var face_dir := direction if direction.length() > 0.2 else _last_strong_dir
		if face_dir.length() > 0.05:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(face_dir.x, face_dir.z), 1 - exp(-8 * delta))
	if animator != null:
		var moving := Vector2(position.x-previous.x,position.z-previous.z).length()>delta*.1
		var clip := idle_clip if not moving else (run_clip if sprint and not run_clip.is_empty() else walk_clip)
		if not clip.is_empty() and animator.current_animation != clip: animator.play(clip, 0.22)
		var actual_speed:float=Vector2(position.x-previous.x,position.z-previous.z).length()/maxf(delta,.001)
		var cadence:float=clampf(actual_speed/(3.6 if sprint else 2.0),.55,1.5) if moving else 1.0
		animator.speed_scale=lerpf(animator.speed_scale,cadence,1-exp(-8*delta))

func begin_pet(target: Node3D) -> bool:
	if not fishing_stage.is_empty() or sofa_seated or boating or working or not pet_stage.is_empty() or not is_instance_valid(target): return false
	pet_target = target
	pet_stage = "approach"
	pet_elapsed = 0
	return true

func cancel_pet() -> void:
	if pose_skeleton != null:
		for i in range(pose_positions.size()):
			pose_skeleton.set_bone_pose_position(i, pose_positions[i])
			pose_skeleton.set_bone_pose_rotation(i, pose_rotations[i])
		pose_skeleton.clear_bones_global_pose_override()
	pose_skeleton = null
	pose_positions.clear()
	pose_rotations.clear()
	pet_stage = ""
	if is_instance_valid(pet_target):pet_target.petting=0
	pet_target = null
	visual.position.y = 0
	if animator != null and not idle_clip.is_empty(): animator.play(idle_clip, 0.15)

func _update_pet(delta: float) -> void:
	if not is_instance_valid(pet_target) or boating or move_input.length() > 0.2:
		cancel_pet()
		return
	pet_elapsed += delta
	var toward := _pet_head_position() - position
	toward.y = 0
	if toward.length() > 0.01: visual.rotation.y = lerp_angle(visual.rotation.y, atan2(toward.x, toward.z), minf(1, delta * 12))
	if pet_stage == "approach":
		if toward.length() > 0.60:
			velocity = toward.normalized() * minf(1.8, (toward.length() - 0.56) / maxf(delta, 0.001))
			velocity.y = -1
			var previous := position
			move_and_slide()
			if not terrain_walkable.call(position): position = previous
			if animator != null and not walk_clip.is_empty(): animator.play(walk_clip)
			if pet_elapsed > 2: cancel_pet()
			return
		velocity = Vector3.ZERO
		if animator != null:
			animator.play(idle_clip)
			animator.advance(0)
			animator.stop(true)
		for skeleton: Skeleton3D in visual.find_children("*", "Skeleton3D", true, false):
			pose_skeleton = skeleton
			break
		if pose_skeleton == null: cancel_pet(); return
		for i in range(pose_skeleton.get_bone_count()):
			pose_positions.append(pose_skeleton.get_bone_pose_position(i))
			pose_rotations.append(pose_skeleton.get_bone_pose_rotation(i))
		pet_feet.clear()
		for side:String in ["Left","Right"]:
			var foot:Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(_bone(side+"Foot")).origin
			foot.y=position.y+.09*pose_skeleton.global_basis.get_scale().y;pet_feet.append(foot)
		var hips:Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(_bone("Hips")).origin
		var target_y:float=clampf(_pet_head_position().y-.05,position.y+.33,position.y+.46)
		pet_hip_drop=(hips.y-target_y)/pose_skeleton.global_basis.get_scale().y
		pet_stage = "crouch"
		pet_elapsed = 0
	var blend := smoothstep(0, 0.65, pet_elapsed) * (1 - smoothstep(2.65, 3.4, pet_elapsed))
	pose_skeleton.clear_bones_global_pose_override()
	for i in range(pose_positions.size()):
		var bone_name := str(pose_skeleton.get_bone_name(i))
		var rotation := pose_rotations[i]
		var offset := Vector3.ZERO
		if bone_name.ends_with("Hips"): offset.y = -pet_hip_drop * blend
		elif bone_name.ends_with("UpLeg"): rotation = pose_rotations[i]
		elif bone_name.ends_with("Leg"): rotation = pose_rotations[i]
		elif bone_name.ends_with("Spine"): rotation *= Quaternion(Vector3.RIGHT, 0.55 * blend)
		pose_skeleton.set_bone_pose_position(i, pose_positions[i] + offset)
		pose_skeleton.set_bone_pose_rotation(i, rotation)
	for side in range(pet_feet.size()):grounded_pose.leg(self,side,pet_feet[side],blend)
	if blend > 0.1:
		var head := _pet_head_position()
		head += visual.global_basis.z * sin(pet_elapsed * 8) * 0.045
		last_hand_target = head
		_reach_head(head, blend)
	if pet_elapsed >= 3.4: cancel_pet()

var last_bend_axis := Vector3.RIGHT
func _bone(suffix: String) -> int:
	for i in range(pose_skeleton.get_bone_count()):
		if str(pose_skeleton.get_bone_name(i)).ends_with(suffix): return i
	return -1

func _reach_head(world_target: Vector3, weight: float) -> void:
	_reach_arm("Right",world_target,weight)

func _reach_arm(side: String, world_target: Vector3, weight: float) -> void:
	var upper := _bone(side+"Arm")
	var lower := _bone(side+"ForeArm")
	var hand := _bone(side+"Hand")
	if upper < 0 or lower < 0 or hand < 0: return
	var a := pose_skeleton.get_bone_global_pose(upper)
	var b := pose_skeleton.get_bone_global_pose(lower)
	var c := pose_skeleton.get_bone_global_pose(hand)
	var target := pose_skeleton.to_local(world_target)
	var length1 := a.origin.distance_to(b.origin)
	var length2 := b.origin.distance_to(c.origin)
	var direction := (target - a.origin).normalized()
	var distance := clampf(a.origin.distance_to(target), 0.03, length1 + length2 - 0.005)
	var along := (length1 * length1 - length2 * length2 + distance * distance) / (2 * distance)
	var bend := direction.cross(Vector3.UP).normalized()
	# 目标接近竖直时叉积会退化，沿用它上一次的有效弯肘轴，别硬塞 RIGHT（那会把肘甩到体侧外）。
	if bend.length() < 0.1: bend = last_bend_axis
	else: last_bend_axis = bend
	var elbow := a.origin + direction * along + bend * sqrt(maxf(0, length1 * length1 - along * along))
	var wrist := a.origin + direction * distance
	var first_axis := (b.origin - a.origin).normalized()
	var second_axis := (c.origin - b.origin).normalized()
	a.basis = Basis(Quaternion(first_axis, (elbow - a.origin).normalized())) * a.basis
	b.basis = Basis(Quaternion(second_axis, (wrist - elbow).normalized())) * b.basis
	b.origin = elbow
	c.origin = wrist
	pose_skeleton.set_bone_global_pose_override(upper, a, weight, true)
	pose_skeleton.set_bone_global_pose_override(lower, b, weight, true)
	pose_skeleton.set_bone_global_pose_override(hand, c, weight, true)

func _pet_head_position() -> Vector3:
	for node: Node3D in pet_target.visual.find_children("*Head*", "Node3D", true, false):
		return node.global_position + Vector3(0, 0.09, 0)
	return pet_target.position + Vector3(0, 0.45, 0)

func start_work(kind: String, target: Vector3) -> bool:
	if not fishing_stage.is_empty() or sofa_seated or working or boating or not pet_stage.is_empty(): return false
	work_kind = kind
	work_elapsed = 0
	work_done = false
	working = true
	velocity = Vector3.ZERO
	var direction := target - position
	# 不再硬拧到正对目标：记下目标朝向，交给 _update_work 每帧插值过去，
	# 人站在原地就能转，不用先走一步再拐直角。
	work_yaw = atan2(direction.x, direction.z)
	if animator != null:
		animator.play(idle_clip)
		animator.advance(0)
		animator.stop(true)
	for skeleton: Skeleton3D in visual.find_children("*", "Skeleton3D", true, false): pose_skeleton = skeleton; break
	if pose_skeleton != null:
		for i in range(pose_skeleton.get_bone_count()):
			pose_positions.append(pose_skeleton.get_bone_pose_position(i))
			pose_rotations.append(pose_skeleton.get_bone_pose_rotation(i))
		var hand := _bone("RightHand")
		if hand >= 0 and kind != "采纤维":
			var attachment := BoneAttachment3D.new()
			attachment.bone_name = pose_skeleton.get_bone_name(hand)
			pose_skeleton.add_child(attachment)
			work_tool = attachment
			var shaft := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.025; cylinder.bottom_radius = 0.03; cylinder.height = 0.5
			var wood := StandardMaterial3D.new(); wood.albedo_color = Color("99663e")
			cylinder.material = wood
			shaft.mesh = cylinder
			shaft.position.y = 0.15
			attachment.add_child(shaft)
			var head := MeshInstance3D.new()
			var metal := BoxMesh.new()
			metal.size = Vector3(0.22, 0.14, 0.07) if kind == "伐木" else Vector3(0.18, 0.12, 0.12)
			var steel := StandardMaterial3D.new(); steel.albedo_color = Color("9dadab"); steel.metallic = 0.4
			metal.material = steel
			head.mesh = metal
			head.position.y = 0.4
			attachment.add_child(head)
	return true

func _update_work(delta: float) -> void:
	# 站定后用最短弧把身体转向工作点（约 0.2 s 转 90°），不再瞬间对正。
	if visual != null: visual.rotation.y = lerp_angle(visual.rotation.y, work_yaw, 1 - exp(-9 * delta))
	if work_done: return
	work_elapsed += delta
	var swing := sin(work_elapsed * 8)
	if pose_skeleton != null:
		for i in range(pose_rotations.size()):
			var bone := str(pose_skeleton.get_bone_name(i))
			var angle := 0.0
			if bone.ends_with("RightArm"): angle = -1.0 + swing * 0.6
			elif bone.ends_with("RightForeArm"): angle = -0.55 + swing * 0.25
			elif bone.ends_with("Spine"): angle = 0.12 + swing * 0.06
			pose_skeleton.set_bone_pose_rotation(i, pose_rotations[i] * Quaternion(Vector3.RIGHT, angle))
	if work_elapsed >= 1.8: work_done = true

func cancel_work() -> void:
	if not working: return
	if is_instance_valid(work_tool): work_tool.queue_free()
	work_tool = null
	working = false
	work_done = false
	cancel_pet()

func sit_on_sofa(anchor: Vector3,cushion_y:float=-1,seat_yaw:float=PI,foot_distance:float=.52) -> bool:
	sofa_yaw=seat_yaw;sofa_foot_distance=foot_distance;sofa_reclining=false;sofa_rock=0
	if not fishing_stage.is_empty() or working or boating or sofa_seated or not pet_stage.is_empty(): return false
	sofa_return = position
	sofa_origin = position
	sofa_anchor = anchor
	sofa_seated = true
	sofa_blend = 0
	velocity = Vector3.ZERO
	collision_mask = 0
	if animator != null:
		animator.play(idle_clip)
		animator.advance(0)
		animator.stop(true)
	for skeleton: Skeleton3D in visual.find_children("*","Skeleton3D",true,false): pose_skeleton = skeleton; break
	if pose_skeleton != null:
		for i in range(pose_skeleton.get_bone_count()):
			pose_positions.append(pose_skeleton.get_bone_pose_position(i))
			pose_rotations.append(pose_skeleton.get_bone_pose_rotation(i))
		var hip := _bone("Hips")
		if hip >= 0:
			var hips: Vector3 = pose_skeleton.global_transform * pose_skeleton.get_bone_global_pose(hip).origin
			var scale_y:float=pose_skeleton.global_basis.get_scale().y
			sofa_hip_offset = ((cushion_y if cushion_y>=0 else anchor.y+.3125)+.23*scale_y - hips.y) / scale_y
	return true
func _update_sofa(delta: float) -> void:
	sofa_blend = minf(1,sofa_blend + delta * 1.6)
	var blend := smoothstep(0,1,sofa_blend)
	position = sofa_origin.lerp(sofa_anchor,blend)
	visual.rotation.y = lerp_angle(visual.rotation.y,sofa_yaw,minf(1,delta * 9))
	if pose_skeleton == null: return
	pose_skeleton.clear_bones_global_pose_override()
	for i in range(pose_positions.size()):
		var bone := str(pose_skeleton.get_bone_name(i))
		var angle := 0.0
		var offset := Vector3.ZERO
		if bone.ends_with("Hips"):
			offset.y = sofa_hip_offset * blend
			if sofa_reclining:angle=-.95+sofa_rock
		elif bone.ends_with("UpLeg"): angle = -.62 if sofa_reclining else -PI / 2
		elif bone.ends_with("Leg"): angle = .12 if sofa_reclining else 0.4
		elif bone.ends_with("Foot"): angle = .05 if sofa_reclining else PI / 2 - 0.4
		elif bone.ends_with("Spine"): angle = -0.08
		elif bone.ends_with("ForeArm"): angle = -0.7
		elif bone.ends_with("Arm"): angle = -0.25
		pose_skeleton.set_bone_pose_position(i,pose_positions[i]+offset)
		pose_skeleton.set_bone_pose_rotation(i,pose_rotations[i]*Quaternion(Vector3.RIGHT,angle*blend))
	if sofa_reclining:
		if sofa_stretch>0:
			var head:Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(_bone("Head")).origin
			for side:String in ["Left","Right"]:_reach_arm(side,head+Vector3.UP*.25+visual.global_basis.x.normalized()*(.45 if side=="Left" else -.45),sofa_stretch)
		return
	for side in range(2):
		var scale_y:float=pose_skeleton.global_basis.get_scale().y
		var foot:Vector3=position+visual.global_basis.z.normalized()*sofa_foot_distance+visual.global_basis.x.normalized()*(.14 if side==0 else -.14)*scale_y
		foot.y=sofa_anchor.y+.09*scale_y
		grounded_pose.leg(self,side,foot,blend)

	if seated_eat_time>=0:
		var head:Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(_bone("Head")).origin
		var lift:float=smoothstep(0,.65,seated_eat_time)*(1-smoothstep(1.7,2.3,seated_eat_time))
		_reach_arm("Right",head-Vector3.UP*.09+visual.global_basis.z.normalized()*.12,lift)

func leave_sofa() -> void:
	if not sofa_seated: return
	sofa_seated = false;sofa_reclining=false;sofa_rock=0;sofa_stretch=0;seated_eat_time=-1
	position = sofa_return
	collision_mask = 1
	velocity = Vector3.ZERO
	cancel_pet()

func begin_fishing(anchor: Vector3 = Vector3.INF) -> bool:
	if not fishing_stage.is_empty() or working or boating or sofa_seated or not pet_stage.is_empty(): return false
	fishing_stage = "casting"
	fishing_return=position;fishing_anchor=position if anchor==Vector3.INF else anchor
	velocity = Vector3.ZERO
	visual.rotation.y = 0
	if animator != null:
		animator.play(idle_clip)
		animator.advance(0)
		animator.stop(true)
	for skeleton: Skeleton3D in visual.find_children("*","Skeleton3D",true,false): pose_skeleton = skeleton; break
	if pose_skeleton == null: fishing_stage = ""; return false
	for i in range(pose_skeleton.get_bone_count()):
		pose_positions.append(pose_skeleton.get_bone_pose_position(i))
		pose_rotations.append(pose_skeleton.get_bone_pose_rotation(i))
	fishing_steps.capture(self)
	_fishing_seat_offset()
	return true
func _fishing_seat_offset() -> void:
	var hip := _bone("Hips")
	if hip>=0:
		var height: float=(pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(hip)).origin.y-position.y
		fishing_hip_offset=(.48-height)/pose_skeleton.global_basis.get_scale().y
func fishing_join_walk(walked: float,direction: Vector3) -> void:
	# Two planted steps during the last metre into the stool, so the approach
	# reads as walking instead of a frozen fishing pose sliding forward.
	if pose_skeleton==null:return
	var scale_y: float=pose_skeleton.global_basis.get_scale().y
	var forward: Vector3=direction.normalized() if direction.length()>.001 else visual.global_basis.z.normalized()
	var side_axis: Vector3=forward.cross(Vector3.UP).normalized()
	for side: int in range(2):
		var phase: float=fposmod(walked*2.0+(0.0 if side==0 else .5),1.0)
		var lift: float=sin(phase*PI)*.14
		var stride: float=(phase-.5)*.36
		var planted: Vector3=position+forward*stride+side_axis*(.14 if side==0 else -.14)*scale_y+Vector3.UP*(.09*scale_y+lift*scale_y)
		grounded_pose.leg(self,side,planted,1)
func pose_fishing(stage: String, phase: float, rod_direction: Vector3, reel_angle: float=0.0, seated: float=0.0, net_grip: Vector3=Vector3.INF, line_load:float=.35, pulling:bool=true) -> Vector3:
	var scoop_lean:float=preload("res://scripts/life/fishing_landing.gd").pose(fishing_anchor,phase).lean if stage=="landing" else 0.0
	fishing_stage = stage
	collision_mask=0
	position=fishing_return.lerp(fishing_anchor,smoothstep(0,.65,phase)) if stage=="casting" else fishing_anchor
	if stage=="storing":position=preload("res://scripts/life/fishing_storage.gd").frame(fishing_anchor,phase).actor
	pose_skeleton.clear_bones_global_pose_override()
	for i in range(pose_positions.size()):
		var offset := Vector3.ZERO
		var name_value := str(pose_skeleton.get_bone_name(i))
		if name_value.ends_with("Hips"):offset.y=fishing_hip_offset*seated-.28*scoop_lean/pose_skeleton.global_basis.get_scale().y
		pose_skeleton.set_bone_pose_position(i,pose_positions[i]+offset)
		var rotation := pose_rotations[i]
		if name_value.ends_with("UpLeg"):rotation*=Quaternion(Vector3.RIGHT,-PI*.5*seated)
		elif name_value.ends_with("Leg"):rotation*=Quaternion(Vector3.RIGHT,PI*.5*seated)
		var bone := str(pose_skeleton.get_bone_name(i))
		if bone.ends_with("Spine"):
			if stage=="casting": rotation*=Quaternion(Vector3.UP,-.25*sin(phase*PI))
			elif stage=="reeling": rotation*=Quaternion(Vector3.RIGHT,-.08*sin(fposmod(phase,1.4)/1.4*PI))
			elif stage=="landing":rotation*=Quaternion(Vector3.RIGHT,.22*scoop_lean)
		pose_skeleton.set_bone_pose_rotation(i,rotation)
	var animated:bool=fishing_animation.apply(self,stage,phase,line_load,pulling)
	if scoop_lean>.0001:
		for side:int in range(2):
			var foot:int=_bone(("Left" if side==0 else "Right")+"Foot")
			var planted:Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(foot).origin+Vector3.UP*.28*scoop_lean
			grounded_pose.leg(self,side,planted,1)
	var lift := sin(phase*PI)*.2 if stage=="casting" else (.18*sin(fposmod(phase,1.4)/1.4*PI) if stage=="reeling" else 0.0)
	var grip := position+Vector3(.2,1.25+lift-.6*seated,.48)
	if seated>.001:
		# A lower pelvis puts the standing grip out of arm reach, so the seated
		# grip is anchored to the actual shoulder and stays reachable.
		var shoulder := _bone("RightArm")
		if shoulder>=0:
			var shoulder_pos: Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(shoulder).origin
			grip=grip.lerp(shoulder_pos+Vector3(.16,.1+lift*.5,.38),seated)
	if animated:
		var animated_hand:Vector3=pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(_bone("RightHand")).origin
		grip=grip.lerp(animated_hand,.75)
	if stage=="storing":grip=preload("res://scripts/life/fishing_storage.gd").frame(fishing_anchor,phase).right
	_reach_arm("Right",grip,1)
	var left_target := grip+rod_direction*.24
	if stage=="reeling":
		left_target=grip+rod_direction*.15+Vector3(.12,0,0)+Basis(Quaternion(Vector3.UP,rod_direction))*Vector3(0,cos(reel_angle)*.07,sin(reel_angle)*.07)
	if stage=="chumming":left_target=position+Vector3(-.3,.9+sin(phase*PI)*.3,.3+sin(phase*PI)*.65)
	if seated>.35:
		# 坐在钓凳上时把两只脚按到甲板面上，而不是整体抬高骨架（抬骨架会把坐姿
		# 顶到接近站立的高度，站起来就看不出变化，脚也解决不了穿模）。
		var deck:float=fishing_anchor.y+.02
		for side:int in range(2):
			var foot:int=_bone(("Left" if side==0 else "Right")+"Foot")
			if foot<0:continue
			var planted:Vector3=(pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(foot)).origin
			if planted.y<deck-.001:
				planted.y=deck
				grounded_pose.leg(self,side,planted,1)
	
	if net_grip!=Vector3.INF:left_target=net_grip
	if stage=="storing":left_target=preload("res://scripts/life/fishing_storage.gd").frame(fishing_anchor,phase).left
	_reach_arm("Left",left_target,1)
	if stage=="storing":fishing_steps.apply(self,fishing_anchor,phase)
	var hand := _bone("RightHand")
	return pose_skeleton.global_transform*pose_skeleton.get_bone_global_pose(hand).origin if hand>=0 else grip
func end_fishing() -> void:
	if fishing_stage.is_empty(): return
	fishing_stage = ""
	fishing_animation.clear()
	position=fishing_return
	collision_mask=1
	velocity = Vector3.ZERO
	cancel_pet()

func _step_small_lip(direction: Vector3) -> void:
	# A flat foot collider blocks roots, but must still cross a 4 cm porch lip.
	var ahead := position+direction*.5
	var ray := PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*.12,ahead-Vector3.UP*.02,1)
	ray.exclude=[get_rid()]
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.8: return
	var rise: float=hit.position.y-position.y
	if rise<.005 or rise>.1:return
	var clearance := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new();shape.radius=BODY_RADIUS;shape.height=1.68
	clearance.shape=shape;clearance.collision_mask=1;clearance.exclude=[get_rid()]
	clearance.transform=Transform3D(Basis.IDENTITY,position+Vector3.UP*(rise+.86))
	if space.intersect_shape(clearance,1).is_empty(): position.y+=rise+.02

func start_stairs(points: Array[Vector3], finished: Callable, manual:bool=false) -> void:
	stair_motion.setup(self)
	stair_manual=manual;stair_route=points.duplicate();manual_stairs.setup(self,points)
	stair_return=points[0]
	if walking_shapes.size()>1:walking_shapes[1].set_deferred("disabled",true)
	stair_active=true;stair_path=points.duplicate();stair_finished=finished;stair_stalled=0;stair_best=INF
	stair_view_wait=0;stair_view_blocked=false
	velocity=Vector3.ZERO
func _update_stairs(delta: float) -> void:
	if stair_path.is_empty():
		stair_motion.finish()
		stair_active=false;velocity=Vector3.ZERO
		if walking_shapes.size()>1:walking_shapes[1].set_deferred("disabled",false)
		var done := stair_finished;stair_finished=Callable()
		if done.is_valid():done.call(true)
		return
	var target: Vector3=stair_path[0]
	if stair_view_ready.is_valid() and not stair_view_blocked and not stair_view_ready.call(target):
		stair_view_wait+=delta
		if stair_view_wait<STAIR_VIEW_TIMEOUT:
			velocity=Vector3.ZERO
			return
		# 相机迟迟不能构图（被墙挡住等），放弃等待继续上楼，避免无限卡死。
		stair_view_blocked=true
	var offset := target-position
	var flat := Vector3(offset.x,0,offset.z)
	if flat.length()<.1 and absf(offset.y)<.18:
		stair_path.pop_front();stair_best=INF;stair_stalled=0;return
	var direction := flat.normalized()
	var heading:float=atan2(direction.x,direction.z)
	visual.rotation.y=lerp_angle(visual.rotation.y,heading,1-exp(-10*delta))
	# 以前这里是「没转到 40° 以内就不许动」，所以每到平台拐角都要停下先拐个直角。
	# 现在边走边转：只按对齐程度放慢速度，只有基本背对（>100°）时才原地转完再走。
	var align := cos(angle_difference(visual.rotation.y, heading))
	if align < -0.2:
		velocity=Vector3.ZERO
		return
	var pace := clampf(align, 0.2, 1.0)
	var stair_geometry=preload("res://scripts/life/villa_stairwell.gd")
	var on_steps:bool=position.z>stair_geometry.BACK+.05 and position.z<stair_geometry.FRONT-.05 and (absf(position.x-9.25)<1.05 or absf(position.x-12.0)<1.05)
	velocity=direction*minf((0.7 if on_steps else 1.15)*pace,flat.length()/maxf(delta,.001))
	if is_on_floor():
		velocity=velocity.slide(get_floor_normal())
		velocity.y-=.2
	else:velocity.y=-2.0
	move_and_slide()
	if animator!=null and animator.current_animation!=walk_clip:animator.play(walk_clip,.15)
	var remaining := position.distance_to(target)
	if remaining<stair_best-.01:stair_best=remaining;stair_stalled=0
	else:stair_stalled+=delta
	if stair_stalled>2:cancel_stairs()
func finish_stairs(completed:bool) -> void:
	stair_motion.finish()
	stair_active=false;stair_path.clear();velocity=Vector3.ZERO
	stair_view_wait=0;stair_view_blocked=false
	if walking_shapes.size()>1:walking_shapes[1].set_deferred("disabled",false)
	var done:=stair_finished;stair_finished=Callable()
	if done.is_valid():done.call(completed)
func cancel_stairs() -> void:
	if not stair_active:return
	stair_motion.finish()
	stair_active=false;stair_path.clear();position=stair_return;velocity=Vector3.ZERO
	stair_view_wait=0;stair_view_blocked=false
	if walking_shapes.size()>1:walking_shapes[1].set_deferred("disabled",false)
	var done := stair_finished;stair_finished=Callable()
	if done.is_valid():done.call(false)

func lie_on_bed(anchor: Vector3) -> bool:
	if stair_active or bed_stage!="" or sofa_seated or working or boating or not pet_stage.is_empty() or not fishing_stage.is_empty():return false
	bed_stage="undressing";bed_blend=0;bed_return=position;bed_anchor=anchor
	bed_visual_transform=visual.transform
	velocity=Vector3.ZERO;collision_mask=0;collision_layer=0
	if animator!=null:
		animator.play(idle_clip);animator.advance(.1);animator.stop(true)
	for skeleton: Skeleton3D in visual.find_children("*","Skeleton3D",true,false):pose_skeleton=skeleton;break
	pose_positions.clear();pose_rotations.clear()
	if pose_skeleton!=null:
		for i in range(pose_skeleton.get_bone_count()):
			pose_positions.append(pose_skeleton.get_bone_pose_position(i));pose_rotations.append(pose_skeleton.get_bone_pose_rotation(i))
		pose_skeleton.reset_bone_poses()
		var hip := _bone("Hips")
		if hip>=0:
			var center := pose_skeleton.get_bone_global_pose(hip).origin
			for side: String in ["Left","Right"]:
				var arm := _bone(side+"Arm")
				if arm<0:continue
				var sign_x := signf(pose_skeleton.get_bone_global_pose(arm).origin.x-center.x)
				_reach_arm(side,pose_skeleton.global_transform*(center+Vector3(sign_x*.27,.02,.06)),1.0)
	bed_hidden.clear()
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) in ["attach-neck-mesh","attach-hat-mesh"]:bed_hidden[mesh]=mesh.visible
	bed_motion=preload("res://scripts/life/bed_motion.gd").new()
	bed_motion.setup(self)
	return true

func rise_from_bed() -> void:
	if bed_motion!=null:bed_motion.wake()
func _update_bed(delta: float) -> void:
	if bed_motion!=null:bed_motion.tick(delta)
func bed_phase_label() -> String:
	return bed_motion.label() if bed_motion!=null else ""
func cancel_bed() -> void:
	if bed_stage=="":return
	if bed_motion!=null:bed_motion.dispose();bed_motion=null
	bed_stage="";bed_blend=0;position=bed_return;visual.transform=bed_visual_transform
	for mesh: MeshInstance3D in bed_hidden:
		if is_instance_valid(mesh):mesh.visible=bed_hidden[mesh]
	bed_hidden.clear();collision_mask=1;collision_layer=2;velocity=Vector3.ZERO
	cancel_pet()
	if animator!=null:animator.speed_scale=1;animator.play(idle_clip,.15)

func _exit_tree() -> void:
	if bed_motion!=null:bed_motion.dispose(false);bed_motion=null
