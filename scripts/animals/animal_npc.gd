extends Node3D
## AnimalNPC —— 小动物通用逻辑
## 在出生点附近随机游荡、轻微上下浮动；鼠标左键点击可投喂，攒够好感解锁图鉴。

@export var wander_radius: float = 2.2
@export var wander_speed: float = 0.8
@export var bob_speed: float = 1.6
@export var affinity_to_friend: int = 30   # 需要多少好感成为朋友

var _home: Vector3
var _target: Vector3
var _affinity: int = 0
var _bob_time: float = 0.0
var _is_friend: bool = false
var _pick_new_target: float = 0.0
var _area: Area3D

func _ready() -> void:
	_home = get_meta("home_pos", global_position)
	_target = _home
	# 点击投喂检测
	_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	_area.add_child(shape)
	add_child(_area)
	_area.input_event.connect(_on_click)
	_await_move()

func _await_move() -> void:
	while is_inside_tree():
		await get_tree().create_timer(2.0 + randf_range(0, 2.0)).timeout
		# 在允许范围内挑一个新目标
		var a := randf_range(0, TAU)
		var r := randf_range(0.2, wander_radius)
		_target = _home + Vector3(cos(a) * r, 0, sin(a) * r)
		_pick_new_target = 0.0

func _process(delta: float) -> void:
	_bob_time += delta * bob_speed
	# 轻微上下浮动（表现动物呼吸/走动）
	global_position.y = _home.y + sin(_bob_time) * 0.06
	# 朝向目标缓动
	var to_target: Vector3 = _target - global_position
	to_target.y = 0
	if to_target.length() > 0.15:
		global_position.x += to_target.normalized().x * wander_speed * delta
		global_position.z += to_target.normalized().z * wander_speed * delta
		# 面朝移动方向
		look_at(global_position + to_target.normalized(), Vector3.UP)

func _on_click(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_feed()

func _feed() -> void:
	if _is_friend:
		_bubble("它已经是你的好朋友啦！")
		return
	_affinity += 10
	if _affinity >= affinity_to_friend:
		_is_friend = true
		GameManager.unlock_animal(get_meta("animal_name", "小动物"))
		_bubble("「%s」和你成为好朋友了！" % get_meta("animal_name", "小动物"))
	else:
		_bubble("「%s」很喜欢你！好感 +10" % get_meta("animal_name", "小动物"))
		# 投喂回礼
		GameManager.add_resource("浆果", 1)

# 在头顶显示一句话气泡
func _bubble(text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color(0.1, 0.1, 0.1)
	label.position = Vector3(0, 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", 1.9, 1.4)
	tween.tween_callback(label.queue_free)
