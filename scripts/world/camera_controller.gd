extends Camera3D
## CameraController —— 斜45°俯视镜头控制
## WASD 平移、Q/E 旋转、滚轮缩放，匹配参考图的经典海岛俯视视角。

@export var move_speed: float = 18.0
@export var rotate_speed: float = 60.0
@export var zoom_speed: float = 3.0
@export var min_height: float = 6.0
@export var max_height: float = 60.0

var _height: float = 30.0

func _ready() -> void:
	_height = global_position.y

func _process(delta: float) -> void:
	# 平移（基于旋转后的平面坐标，W 朝向镜头前方）
	var dir := Vector3.ZERO
	if Input.is_action_pressed("camera_move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("camera_move_backward"):
		dir += transform.basis.z
	if Input.is_action_pressed("camera_move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("camera_move_right"):
		dir += transform.basis.x
	dir.y = 0.0
	if dir.length() > 0.01:
		global_position += dir.normalized() * move_speed * delta

	# 旋转（绕世界 Y 轴）
	if Input.is_action_pressed("camera_rotate_left"):
		rotate_y(deg_to_rad(rotate_speed * delta))
	if Input.is_action_pressed("camera_rotate_right"):
		rotate_y(-deg_to_rad(rotate_speed * delta))

	# 缩放（改变高度，保持俯视角方向）
	var zoom := Input.get_axis("zoom_out", "zoom_in")
	if absf(zoom) > 0.001:
		_height = clampf(_height + zoom * zoom_speed * 3.0, min_height, max_height)
		# 沿自身视线方向拉近/拉远
		global_position = global_position + transform.basis.z * (zoom * zoom_speed * delta * 8.0)
		# 修正高度
		global_position.y = _height

## 确保相机正 Y 朝上，俯视角度固定
func _physics_process(_delta: float) -> void:
	pass
