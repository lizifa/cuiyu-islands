extends Node3D
## Flying —— 海鸥飞行逻辑：绕岛屿上空圆形盘旋，并轻微上下起伏。

@export var radius: float = 3.5
@export var speed: float = 1.2
@export var altitude: float = 6.0

var _center: Vector3
var _angle: float = 0.0

func _ready() -> void:
	_center = Vector3(global_position.x, altitude, global_position.z)
	_angle = randf_range(0, TAU)

func _physics_process(delta: float) -> void:
	_angle += delta * speed
	var target := Vector3(
		_center.x + cos(_angle) * radius,
		_center.y + sin(_angle * 3.0) * 0.5,
		_center.z + sin(_angle) * radius
	)
	# 平滑跟随
	global_position = global_position.lerp(target, 1.0 - exp(-3.0 * delta))
	# 面朝运动方向
	var dir: Vector3 = target - global_position
	if dir.length() > 0.05:
		look_at(global_position + dir, Vector3.UP)
