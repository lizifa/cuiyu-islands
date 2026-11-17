extends Node3D
## Boat —— 小木船航行
## 鼠标左键点击海面（射线检测到世界 Y=0 平面）设定目标，船面朝目标驶去，抵达后停下。

@export var sail_speed: float = 4.5

var _target: Vector3
var _has_target: bool = false
var _arrive_dist: float = 1.2

func _ready() -> void:
	_target = global_position

func _unhandled_input(event: InputEvent) -> void:
	# 仅在剧情结束后允许航行交互，避免误触
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_target()

func _pick_target() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var space := get_world_3d().direct_space_state
	var origin := cam.project_ray_origin(get_viewport().get_mouse_position())
	var dir := cam.project_ray_normal(get_viewport().get_mouse_position())
	# 只跟水面（y=0）平面求交
	if dir.y >= -0.0001:
		return
	var t := -origin.y / dir.y
	if t <= 0:
		return
	var point := origin + dir * t
	# 忽略离船太近的点击，避免抖动
	if point.distance_to(global_position) < 2.0:
		return
	_target = point
	_has_target = true

func _physics_process(delta: float) -> void:
	if not _has_target:
		return
	var to_target: Vector3 = _target - global_position
	to_target.y = 0
	var dist := to_target.length()
	if dist < _arrive_dist:
		_has_target = false
		return
	# 缓转向目标方向
	var forward := -global_transform.basis.z  # 船的 +Z 朝前
	var dir := to_target.normalized()
	var angle := forward.angle_to(dir)
	var turn := clampf(angle, 0.0, 1.5) * delta * 3.0
	var cross := forward.cross(dir)
	if cross.y < 0:
		turn = -turn
	global_rotate(Vector3.UP, turn)
	# 前进
	global_position += forward * sail_speed * delta
