extends Node3D
## Collectable —— 可采集资源
## 鼠标左键点击后拾取，加入背包并消失（过一会重生）。

@export var respawn_time: float = 4.0

var _area: Area3D
var _meshes: Array[Node3D] = []
var _respawn_timer: float = 0.0
var _collected: bool = false

func _ready() -> void:
	# 收集本节点下所有可见 Mesh，用于隐藏/显示
	for child in get_children():
		if child is MeshInstance3D:
			_meshes.append(child)
	# 点击检测区域（覆盖整个采集物范围）
	_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape.shape = sphere
	_area.add_child(shape)
	add_child(_area)
	_area.input_event.connect(_on_click)

func _on_click(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	GameManager.add_resource(get_meta("item_name", "野花"), 1)
	_show_meshes(false)
	_respawn_timer = respawn_time

func _process(delta: float) -> void:
	if _collected:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_collected = false
			_show_meshes(true)

func _show_meshes(show: bool) -> void:
	for m in _meshes:
		m.visible = show
	_area.monitoring = show
