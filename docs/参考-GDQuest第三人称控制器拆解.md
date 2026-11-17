# 参考拆解：GDQuest 第三人称控制器（godot-4-3d-third-person-controller）

仓库：`gdquest-demos/godot-4-3d-third-person-controller`（1049★，GDScript）
关键文件：`player/player.gd`（296 行）、`player/camera_controller.gd`（104 行）、`player/gdbot/gdbot_skin.gd`（66 行）

这套控制器的做法很干净，一共六步，全部集中在 `_physics_process` 里。它**不做格点、不做四方向**，所以永远不会出现「必须先转 90 度」。

---

## 1. 输入 → 世界方向（相机相对）

```gdscript
func _get_camera_oriented_input() -> Vector3:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var input := Vector3.ZERO
	# 斜向不加速：45° 的合速度仍然是 1，不是 1.414
	input.x = -raw_input.x * sqrt(1.0 - raw_input.y * raw_input.y / 2.0)
	input.z = -raw_input.y * sqrt(1.0 - raw_input.x * raw_input.x / 2.0)

	input = _camera_controller.global_transform.basis * input   # 按相机朝向旋转
	input.y = 0.0                                               # 掐掉俯仰带来的 y
	return input
```

要点：
- 摇杆只给「屏幕空间」的 x/y，世界方向由**相机绕 Y 轴的朝向**乘出来，所以相机怎么转，人也跟着转；
- `sqrt(1 - y²/2)` 这个写法是它的招牌，斜着走不会比正着走快 41%；
- `input.y = 0` 一定要做，否则相机俯视时人会往地里钻。

## 2. 记住「最近一次有力的方向」，防止松手抖动

```gdscript
if _move_direction.length() > 0.2:
	_last_strong_direction = _move_direction.normalized()
```

摇杆回到 0 的瞬间，`_move_direction` 会变成 0（或极小值），如果直接拿它算朝向，人会抽一下。它把「超过 0.2 才更新」的方向存下来，转身只认这个值。

## 3. 朝向用四元数最短弧插值（不是直接赋值，也不是四方向）

```gdscript
func _orient_character_to_direction(direction: Vector3, delta: float) -> void:
	var left_axis := Vector3.UP.cross(direction)
	var rotation_basis := Basis(left_axis, Vector3.UP, direction).get_rotation_quaternion()
	var model_scale := _character_skin.transform.basis.get_scale()
	_character_skin.transform.basis = Basis(
		_character_skin.transform.basis.get_rotation_quaternion().slerp(
			rotation_basis,
			delta * rotation_speed,   # rotation_speed = 12
		)
	).scaled(model_scale)
```

- 用 `Basis(左轴, 上轴, 前向)` 直接构造「面朝 direction」的基，再 `slerp` 过去；
- 关键点：**旋转只作用于模型节点 `_character_skin`，不作用在 `CharacterBody3D` 本体**。碰撞胶囊永远正着站，模型自己在里面转 —— 这样转身不会把角色怼进墙里，也不会出现「转完才能走」；
- `rotation_speed = 12` 意味着大约 0.08 s 转 90°，肉眼是「顺滑甩过去」，不是瞬移也不是直角拐弯。

## 4. 速度：插值加速 + 死区

```gdscript
var y_velocity := velocity.y
velocity.y = 0.0
velocity = velocity.lerp(_move_direction * move_speed, acceleration * delta)   # acceleration = 6
if _move_direction.length() == 0 and velocity.length() < stopping_speed:       # stopping_speed = 1
	velocity = Vector3.ZERO
velocity.y = y_velocity
```

- y 速度单独存一份再塞回去，避免重力被插值拖成「慢慢往下飘」；
- `stopping_speed` 是个死区：摇杆松开后速度降到 1 m/s 就直接归零，人不会溜冰。

## 5. 动画：只管三个状态 + 一条混合参数

```gdscript
# gdbot_skin.gd
func idle() -> void: _main_state_machine.travel("Idle")
func move() -> void: _main_state_machine.travel("Move")
func jump() -> void: _main_state_machine.travel("Jump")
func fall() -> void: _main_state_machine.travel("Fall")

func set_walk_run_blending(value: float) -> void:
	_animation_tree.set("parameters/StateMachine/Move/WalkRunBlending/blend_amount", value)
	_animation_tree.set("parameters/StateMachine/Move/StepTimeScale/scale", lerpf(1.0, walk_run_ratio, value))
```

```gdscript
# player.gd 里每帧决定播什么
if is_on_floor():
	var xz_velocity := Vector3(velocity.x, 0, velocity.z)
	if xz_velocity.length() > stopping_speed:
		_character_skin.walk_run_blending = xz_velocity.length() / move_speed   # 0..1 → 走↔跑
		_character_skin.move()
	else:
		_character_skin.idle()
```

要点：
- 走和跑**不是两个 clip 二选一**，是同一个 BlendSpace 的 `blend_amount` 连续插值，所以速度变化时腿不会跳帧；
- 步频用 `StepTimeScale` 跟着混合值走（`walk` 与 `run` 时长比），跑快了脚步才不飘；
- 状态机只 travel 四个状态，动作（攻击）走 `AnimationNodeOneShot`，不和移动抢状态。

## 6. 卡墙兜底

```gdscript
var delta_position := position_after - position_before
if delta_position.length() < 0.001 and velocity.length() > 0.001:
	global_position += get_wall_normal() * 0.1
```

速度不为 0、但 `move_and_slide` 一步也没挪动 → 说明被卡住了，沿墙法线推 0.1 m 脱困。这是很实用的兜底，尤其小台阶、岩石缝。

---

## 对照：我们自己 `scripts/life/player_controller.gd`（第 163–235 行）

| GDQuest 的做法 | 我们现在的实现 | 结论 |
|---|---|---|
| 相机相对输入（`camera.basis * input`） | 第 164–168 行：`right/forward` 取 `camera.global_basis` 再乘 `input` | **已经一样**，我们的写法更朴素但等价 |
| 斜向归一化 `sqrt(1-y²/2)` | 无，用 `limit_length()` | 斜走会略快一点（最多 1.41→1.0 的差），影响小 |
| `_last_strong_direction` 防抖 | 无，直接用当帧 `direction`（长度 > 0.05 才转） | 松手瞬间可能抖一下 |
| 朝向 slerp（只转模型节点） | 第 228 行 `lerp_angle(visual.rotation.y, atan2(...), 1-exp(-8*delta))` | **已经是同一思路**，且只转 `visual`，做法正确 |
| 速度插值 + `stopping_speed` 死区 | 第 175 行 `Vector2.move_toward(..., 14*delta)` | 等价，我们的加速更快（14 vs 6） |
| 动画 `blend_amount` 连续混合 | 第 229–235 行：`idle/walk/run` **三选一 + speed_scale 变频** | 差别最大的一处：我们是离散切换，快慢只靠 `speed_scale` 补偿 |
| 卡墙推 0.1 m | 有 `_step_small_lip`（小台阶）与 `terrain_walkable` 回滚 | 场景不同，够用 |

**所以：自由行走这块我们本来就是 GDQuest 那套，不存在「必须先拐 90 度」。**

「走 90 度」出现在别处，按代码位置分三类，需要分别对待：

1. **上楼梯**：`_update_stairs` 是「先横向对齐到梯口，再沿梯轴前进」两段式，所以看起来先拐个直角。要顺，得做成一段弧线插值（起点→梯口中点→顶端），而不是先平移再抬升。
2. **预制体交互（哑铃/椅子/灶台/沙发）**：`start_work` 里 `visual.rotation.y = atan2(...)` 是**硬赋值**，不是 lerp（第 367 行）。用户站偏一点，模型就会「啪」地拧到正对方向 —— 这就是「转 90 度」的体感来源。改成 `lerp_angle` 并配合 0.15 s 的转身过渡即可。
3. **岛的入口触发点**：如果 `manual_stair_entry` 里有朝向判定，也会强制先朝某方向。

---

## 可以直接搬的三条

1. `_last_strong_direction`（松手不抖）+ `sqrt(1 - y²/2)` 斜向归一化 —— 各 3 行，无副作用；
2. **工作/交互动作里的 `atan2` 硬赋值 → `lerp_angle(..., 1 - exp(-10*delta))`**：这一条直接治「必须走 90 度才能用哑铃」；
3. 动画从「三选一」升级成 `AnimationTree` + `BlendSpace1D`（idle 0 / walk 0.5 / run 1），把 `animator.speed_scale` 只留给节奏微调。
