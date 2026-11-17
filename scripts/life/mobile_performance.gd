extends Node
## Explicit frame budget. UI stays at native resolution; only 3D is scaled.
var app: Node
var saver := true
var mobile := false
var last_cap := -1
const STORE := "user://performance.cfg"
func setup(owner_app: Node) -> void:
	app = owner_app
	mobile = OS.has_feature("mobile")
	var config := ConfigFile.new()
	if config.load(STORE) == OK: saver = bool(config.get_value("display","saver",true))
	if not app.test_mode: apply()
func set_saver(value: bool) -> void:
	saver = value
	apply()
	if app.test_mode: return
	var config := ConfigFile.new()
	config.set_value("display","saver",saver)
	config.save(STORE)
func apply() -> void:
	var viewport: Viewport = app.get_viewport()
	viewport.scaling_3d_scale = 0.65 if mobile and saver else 1.0
	# 4x MSAA 在手机上很贵（带宽 + 每个图元多采样），省电模式直接关掉，靠 0.65 倍缩放兜画质。
	viewport.msaa_3d = Viewport.MSAA_DISABLED if mobile and saver else Viewport.MSAA_4X
	# 物理只跑 30Hz：移动/交互用手感够用，发热大头是 60Hz 的物理步进。
	Engine.physics_ticks_per_second = 30 if mobile and saver else 60
	app.world.forest.set_tree_batching(mobile and saver)
	if mobile:
		app.world.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if saver else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		app.world.sun.directional_shadow_max_distance = 20 if saver else 45
	_update_cap()
func desired_cap() -> int:
	var cap := 30 if mobile and saver else 60
	if app.inactive: cap = 5
	elif app.paused or app._drawers_open(): cap = mini(cap,15)
	elif mobile and saver and _idle():
		# 人没动、没在做任何活动时没必要按 30 帧烧 GPU：站着看风景时降到 24。
		cap = 24
	return cap
func _idle() -> bool:
	var player: Node3D = app.world.player if app.world != null else null
	if player == null: return false
	if player.velocity.length() > .12: return false
	if player.stair_active or player.home_busy or player.sofa_seated or player.boating: return false
	if not player.fishing_stage.is_empty() or not player.bed_stage.is_empty(): return false
	if app.world.orbit != null and app.world.orbit.activity_key != "": return false
	return true
func _update_cap() -> void:
	if app.test_mode: return
	var cap := desired_cap()
	if cap != last_cap: Engine.max_fps = cap; last_cap = cap
func _process(_delta: float) -> void:
	if app != null: _update_cap()
