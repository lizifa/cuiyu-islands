extends Node
## Gestures begin only after GUI handling. Releases always cancel, even over a UI panel.
signal manual_look
var manual_revision := 0
var first_person := false
var stable_third_person := false
# One final motion budget, independent of the requested shot's transition duration.
var cut_focus := Vector3.INF
var cut_overlay: ColorRect
var cut_tween: Tween
var frame_delta := 1.0/60
var motion_enabled := true
var comfort_mode := true
var motion_reset := true
const MAGNIFY_TURN:=2.6
const PAN_TURN_SCALE:=1.0
var yaw_speed := 0.0
var pitch_speed := 0.0
const ANGULAR_SPEED := deg_to_rad(30)
const ANGULAR_ACCEL := deg_to_rad(75)
const DRAG_THRESHOLD := 12.0
const MIN_PITCH := deg_to_rad(-65.0)
const MAX_PITCH := deg_to_rad(70.0)
const STORE := "user://camera.cfg"
var minimum_elevation := deg_to_rad(15)
var keep_subject := false
var observing_sun := false
var rotation_mode := false
var pan_offset := Vector3.ZERO
var target_pan := Vector3.ZERO
var view_focus := Vector3.ZERO
var pan_limit := 18.0
var pan_bounds := Rect2(-70,-70,140,140)
var return_timer := 0.0
var return_view: Dictionary = {}
var can_start := Callable()
var resolve_position := Callable()
var constrain_focus := Callable()
var present_view := Callable()
var frame_subject := Callable()
var resolve_observation := Callable()
var observation_blocked := false
const PAN_SPEED := 4.0
var base_camera_position := Vector3.INF
var pan_gesture_origin := Vector3.ZERO
var pan_gesture_delta := Vector2.ZERO
var pan_gesture_right := Vector3.RIGHT
var pan_gesture_forward := Vector3.FORWARD
var pan_gesture_units := 0.0
var pan_gesture_elevation := 1.0
var camera: Camera3D
var focus := Vector3.ZERO
var distance := 35.0
var target_distance := -1.0
var view_transition := 0.0
var yaw := 0.0
var pitch := 0.6
var target_yaw := 0.0
var target_pitch := 0.6
var initial_yaw := 0.0
var initial_pitch := 0.6
var mouse_dragging := false
var touch_id := -1
var accumulated := Vector2.ZERO
var past_threshold := false

func set_comfort(value: bool) -> void:
	comfort_mode=value;yaw_speed=0;pitch_speed=0
	if value and camera!=null:base_camera_position=camera.position-pan_offset
	if value:
		return_timer=0
		var world:=get_parent()
		if world.get("home_camera")!=null:
			world.home_camera.target_radius=world.home_camera.WIDE_RADIUS
			world.home_camera.target_height=world.home_camera.WIDE_HEIGHT
			world.home_camera.target_fov=world.home_camera.WIDE_FOV
			world.home_camera.saved_view.clear()
	if OS.get_cmdline_user_args().has("--test-mode"):return
	var config:=ConfigFile.new();config.set_value("camera","comfort",value);config.save(STORE)

func establish_view(at: Vector3, radius: float, elevation: float) -> void:
	# A player-triggered activity gets one deliberate cut, not a long orbit sweep.
	cut_focus=at;target_distance=radius;target_pitch=elevation
func fade_cut() -> void:
	if not is_instance_valid(cut_overlay):
		var layer:=CanvasLayer.new();layer.layer=1;add_child(layer)
		cut_overlay=ColorRect.new();layer.add_child(cut_overlay)
		cut_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cut_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
		cut_overlay.color=Color.BLACK
	if cut_tween!=null:cut_tween.kill()
	cut_overlay.modulate.a=1
	cut_tween=create_tween();cut_tween.tween_property(cut_overlay,"modulate:a",0.0,.25)

func setup(view_camera: Camera3D) -> void:
	process_priority=100
	camera = view_camera
	base_camera_position=camera.position
	if not OS.get_cmdline_user_args().has("--test-mode"):
		var config:=ConfigFile.new()
		if config.load(STORE)==OK:comfort_mode=bool(config.get_value("camera","comfort",true))
	var offset := camera.position - focus
	distance = offset.length()
	yaw = atan2(offset.x, offset.z)
	pitch = asin(offset.y / distance)
	initial_yaw = yaw
	initial_pitch = pitch
	target_yaw = yaw
	target_pitch = pitch

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_drag()

func cancel_drag() -> void:
	if comfort_mode and not rotation_mode:target_pan=pan_offset
	if not comfort_mode and not rotation_mode and target_pan.length_squared()>.0001:return_timer=.55
	mouse_dragging = false
	touch_id = -1
	accumulated = Vector2.ZERO
	past_threshold = false
	pan_gesture_delta=Vector2.ZERO

func is_away() -> bool:
	return rotation_mode or observing_sun or pan_offset.length()>.15 or target_pan.length()>.15
func clear_observation(immediate: bool=false, restore_orientation: bool=true) -> void:
	if (rotation_mode or observing_sun) and camera!=null:base_camera_position=camera.position-pan_offset
	cancel_drag();target_pan=Vector3.ZERO;return_timer=0
	if immediate:pan_offset=Vector3.ZERO
	if restore_orientation and not return_view.is_empty():
		target_yaw=return_view.yaw;target_pitch=return_view.pitch;target_distance=return_view.distance
	return_view.clear();rotation_mode=false;observing_sun=false
func return_to_player() -> void:
	manual_revision+=1;manual_look.emit()
	clear_observation();view_transition=.6
func set_rotation_mode(value: bool) -> void:
	manual_revision+=1;manual_look.emit()
	if value:
		if return_view.is_empty():return_view={"yaw":target_yaw,"pitch":target_pitch,"distance":target_distance if target_distance>0 else distance}
		cancel_drag();target_pan=Vector3.ZERO;rotation_mode=true;return_timer=0
	else:clear_observation()
func begin_sun_view() -> void:
	set_rotation_mode(true);observing_sun=true
func reset_view() -> void:
	clear_observation(false,false)
	manual_revision+=1
	manual_look.emit()
	observing_sun=false
	cancel_drag()
	target_yaw = initial_yaw
	target_pitch = initial_pitch

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and mouse_dragging:
		cancel_drag()
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		cancel_drag()

func _unhandled_input(event: InputEvent) -> void:
	if camera == null: return
	# 双指缩放不改变镜头臂长：人物在任何场景都保持同样大小，缩放只做水平转向。
	if event is InputEventMagnifyGesture:
		orbit_by_gesture((event.factor - 1.0) * MAGNIFY_TURN)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		orbit_by_gesture(-event.delta.x / maxf(get_viewport().get_visible_rect().size.x, 1.0) * TAU * PAN_TURN_SCALE)
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		if can_start.is_valid() and not can_start.call(event.position): return
	# Native screen events handle touch once; discard its generated mouse duplicate.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if touch_id >= 0: return
		mouse_dragging = true
		accumulated = Vector2.ZERO
		past_threshold = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_dragging and touch_id < 0:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			cancel_drag()
			return
		gesture_drag(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed and touch_id < 0:
		touch_id = event.index
		mouse_dragging = false
		accumulated = Vector2.ZERO
		past_threshold = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		gesture_drag(event.relative)
		get_viewport().set_input_as_handled()

func orbit_by_gesture(radians: float) -> void:
	if absf(radians) < .00001: return
	if stable_third_person and has_method("turn_by_gesture"):
		call("turn_by_gesture",radians)
		manual_look.emit()
		return
	view_transition=0
	observing_sun=false
	cancel_drag();target_pan=Vector3.ZERO
	manual_revision+=1
	manual_look.emit()
	target_yaw -= radians
	if target_distance > 0: distance = target_distance
func gesture_drag(relative: Vector2) -> void:
	if rotation_mode:rotate_drag(relative)
	else:pan_drag(relative)
func observation_limit() -> float:
	if not comfort_mode or camera==null:return pan_limit
	var radius:float=base_camera_position.distance_to(focus) if base_camera_position.is_finite() else distance
	return minf(pan_limit,maxf(.25,radius*tan(deg_to_rad(camera.fov)*.5)*.7))
func pan_drag(relative: Vector2) -> void:
	if not past_threshold:
		accumulated+=relative
		if accumulated.length()<DRAG_THRESHOLD:return
		relative=accumulated;past_threshold=true
		pan_gesture_origin=target_pan;pan_gesture_delta=Vector2.ZERO
		pan_gesture_right=camera.global_basis.x;pan_gesture_right.y=0;pan_gesture_right=pan_gesture_right.normalized()
		pan_gesture_forward=-camera.global_basis.z;pan_gesture_forward.y=0;pan_gesture_forward=pan_gesture_forward.normalized()
		var radius:float=maxf(.5,camera.position.distance_to(view_focus))
		pan_gesture_units=2*radius*tan(deg_to_rad(camera.fov)*.5)/maxf(get_viewport().get_visible_rect().size.y,1)
		pan_gesture_elevation=maxf(absf(camera.global_basis.z.y),.35)
	manual_revision+=1;manual_look.emit();view_transition=0;return_timer=0
	# One fixed basis and absolute gesture displacement: reversing an event
	# sequence returns to the same target even while the camera is obstructed.
	pan_gesture_delta+=relative
	target_pan=pan_gesture_origin+(-pan_gesture_right*pan_gesture_delta.x+pan_gesture_forward*pan_gesture_delta.y/pan_gesture_elevation)*pan_gesture_units
	target_pan=target_pan.limit_length(observation_limit());target_pan.y=0
func _update_pan(delta: float) -> void:
	if not mouse_dragging and touch_id<0 and return_timer>0:
		return_timer=maxf(0,return_timer-delta)
		if return_timer<=0:target_pan=Vector3.ZERO
	if target_pan.length_squared()>.0001:
		var desired := focus+target_pan
		desired.x=clampf(desired.x,pan_bounds.position.x,pan_bounds.end.x)
		desired.z=clampf(desired.z,pan_bounds.position.y,pan_bounds.end.y)
		target_pan=Vector3(desired.x-focus.x,0,desired.z-focus.z).limit_length(observation_limit())
	pan_offset=pan_offset.move_toward(target_pan,PAN_SPEED*delta) if comfort_mode else pan_offset.lerp(target_pan,1-exp(-7*delta))
	if pan_offset.length()<.01 and target_pan.length()<.01:pan_offset=Vector3.ZERO
	view_focus=focus+pan_offset

func rotate_drag(relative: Vector2) -> void:
	view_transition=0
	observing_sun=false
	var size := get_viewport().get_visible_rect().size
	if not past_threshold:
		accumulated += relative
		if accumulated.length() < DRAG_THRESHOLD: return
		relative = accumulated
		past_threshold = true
	manual_revision+=1
	manual_look.emit()
	# Same fraction of the visible viewport gives the same orbit on wide phones/tablets.
	target_yaw -= relative.x / maxf(size.x, 1) * TAU
	target_pitch = clampf(target_pitch + relative.y / maxf(size.y, 1) * PI, MIN_PITCH, MAX_PITCH)

func _process(delta: float) -> void:
	if camera == null or not motion_enabled: return
	delta=minf(delta,.05)
	frame_delta=delta
	if cut_focus.is_finite():
		focus=cut_focus;pan_offset=Vector3.ZERO;target_pan=Vector3.ZERO
		distance=target_distance;pitch=target_pitch;target_yaw=yaw
		yaw_speed=0;pitch_speed=0;motion_reset=true;cut_focus=Vector3.INF
		fade_cut()
	var previous_position:=camera.position
	var previous_pan:=pan_offset
	var previous_basis:=camera.basis
	_update_pan(delta)
	view_transition=maxf(0,view_transition-delta)
	var blend := 1.0 - exp(-(3.5 if view_transition>0 else 12.0) * delta)
	if target_distance>0: distance=move_toward(distance,target_distance,2.0*delta) if comfort_mode else lerpf(distance,target_distance,1-exp(-4*delta))
	if comfort_mode:
		yaw_speed=move_toward(yaw_speed,clampf(angle_difference(yaw,target_yaw)*3,-ANGULAR_SPEED,ANGULAR_SPEED),ANGULAR_ACCEL*delta)
		pitch_speed=move_toward(pitch_speed,clampf((target_pitch-pitch)*3,-ANGULAR_SPEED,ANGULAR_SPEED),ANGULAR_ACCEL*delta)
		yaw+=clampf(yaw_speed*delta,-absf(angle_difference(yaw,target_yaw)),absf(angle_difference(yaw,target_yaw)))
		pitch+=clampf(pitch_speed*delta,-absf(target_pitch-pitch),absf(target_pitch-pitch))
	else:
		yaw = lerp_angle(yaw, target_yaw, blend)
		pitch = lerpf(pitch, target_pitch, blend)
	var view_pitch := maxf(pitch,minimum_elevation) if keep_subject and not observing_sun and not rotation_mode else pitch
	var elevation := maxf(view_pitch, minimum_elevation)
	# Resolve the unpanned rig first. Observation never retracts the arm from
	# a rapidly moving focus point; camera and focus share the accepted offset.
	var shared_pan:bool=comfort_mode and not rotation_mode and not observing_sun
	if constrain_focus.is_valid():
		focus=constrain_focus.call(focus)
		var bounded:Vector3=constrain_focus.call(focus+pan_offset)
		pan_offset=bounded-focus
		var bounded_target:Vector3=constrain_focus.call(focus+target_pan)-focus
		if bounded_target.distance_squared_to(target_pan)>.000001:
			pan_gesture_origin=bounded_target;pan_gesture_delta=Vector2.ZERO
		target_pan=bounded_target
		if shared_pan:view_focus=bounded
	var base_focus:Vector3=focus if shared_pan else view_focus
	var desired_position := base_focus + Vector3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation)) * distance
	if shared_pan and base_camera_position.is_finite():camera.position=base_camera_position
	if resolve_position.is_valid():desired_position=resolve_position.call(base_focus,desired_position)
	base_camera_position=desired_position
	camera.position=previous_position
	if shared_pan and (pan_offset.length_squared()>.000001 or previous_pan.length_squared()>.000001):
		var requested:Vector3=desired_position+pan_offset
		var accepted:Vector3=requested
		if resolve_observation.is_valid():accepted=resolve_observation.call(previous_position,requested,delta)
		if not accepted.is_finite() or (accepted-desired_position).length()>observation_limit()+.01:
			# The normal rig is the recovery pose if an external change trapped
			# the camera. Hide the recovery cut rather than sweeping through solids.
			accepted=desired_position;pan_offset=Vector3.ZERO;cancel_drag();target_pan=Vector3.ZERO;pan_gesture_origin=Vector3.ZERO;pan_gesture_delta=Vector2.ZERO
			motion_reset=true;fade_cut()
		elif accepted.distance_to(previous_position)>PAN_SPEED*delta+.005 and not motion_reset:
			motion_reset=true;fade_cut()
		pan_offset=accepted-desired_position
		# Rebase only on a real obstacle, not ordinary speed limiting: no
		# accumulated pressure against a wall when the finger reverses.
		if accepted.distance_to(requested)>.001 and resolve_observation.is_valid() and observation_blocked:
			pan_gesture_origin+=pan_offset-target_pan;target_pan=pan_offset
		desired_position=accepted;view_focus=focus+pan_offset
	else:
		view_focus=base_focus
	camera.position=desired_position
	var look_target := view_focus
	if comfort_mode and frame_subject.is_valid():
		var subject:Vector3=frame_subject.call()
		if subject.is_finite():look_target=subject
	if camera.position.distance_squared_to(look_target)<.01:
		look_target=camera.position+Vector3(-sin(yaw)*cos(elevation),-sin(elevation),-cos(yaw)*cos(elevation))
	camera.look_at(look_target, Vector3.UP)
	# Continue the upward gesture by tilting the view, keeping the camera above ground.
	camera.rotate_object_local(Vector3.RIGHT, maxf(0, minimum_elevation - view_pitch))

	if comfort_mode and not motion_reset:
		# Collision and look-at changes share the same final orientation budget.
		var before:Quaternion=previous_basis.get_rotation_quaternion()
		var after:Quaternion=camera.basis.get_rotation_quaternion()
		var angle:float=before.angle_to(after)
		if angle>ANGULAR_SPEED*delta:
			var direction:Vector3=-(Basis(before.slerp(after,ANGULAR_SPEED*delta/angle))).z
			camera.look_at(camera.position+direction,Vector3.UP)
	if comfort_mode and frame_subject.is_valid():
		var subject:Vector3=frame_subject.call()
		var frame_size:Vector2=camera.get_viewport().get_visible_rect().size
		var safely_framed:bool=not camera.is_position_behind(subject) and Rect2(frame_size*.12,frame_size*.76).has_point(camera.unproject_position(subject)) if subject.is_finite() else true
		if subject.is_finite() and not safely_framed:
			# Keep the actor framed while the bounded look catches up at portals.
			# Holding translation is preferable to speeding up the camera turn.
			camera.position=previous_position
			camera.look_at(subject,Vector3.UP)
			var before:Quaternion=previous_basis.get_rotation_quaternion()
			var after:Quaternion=camera.basis.get_rotation_quaternion()
			var angle:float=before.angle_to(after)
			if angle>ANGULAR_SPEED*delta:camera.basis=Basis(before.slerp(after,ANGULAR_SPEED*delta/angle))
			base_camera_position=camera.position-pan_offset
	if comfort_mode and not motion_reset:_limit_upright_rotation(previous_basis,delta)
	motion_reset=false
	if present_view.is_valid():present_view.call()

func _limit_upright_rotation(before_basis:Basis,delta:float) -> void:
	var before:Quaternion=before_basis.get_rotation_quaternion()
	var after:Quaternion=camera.basis.get_rotation_quaternion()
	var angle:float=before.angle_to(after)
	var budget:float=ANGULAR_SPEED*delta
	if angle<=budget:return
	var fraction:float=budget/maxf(angle,.00001)
	# Removing roll after a quaternion blend can increase its actual angle.
	# Verify the upright result rather than assuming the blend obeys the budget.
	for i in range(8):
		var direction:Vector3=-Basis(before.slerp(after,fraction)).z
		camera.look_at(camera.position+direction,Vector3.UP)
		if before.angle_to(camera.basis.get_rotation_quaternion())<=budget+.0001:return
		fraction*=.75
	camera.basis=before_basis
