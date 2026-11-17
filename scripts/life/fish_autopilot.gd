extends Node
## 演示用自动钓鱼：只有设置环境变量 QGYH_AUTOPILOT=fishing 时才会被 life_main 挂上。
## 走真实钓鱼流程（坐上钓位 → 蓄力 → 抛竿 → 等咬钩 → 提竿 → 收线 → 落网 → 再来一竿），
## 目的是在模拟器/真机上录一段「用户自己钓上鱼」的屏，不改任何数值。
const SEAT := Vector3(-1.0, 0.68, 16.45)

var app: Node
var elapsed := 0.0
var phase := "boot"
var hold_clock := 0.0
var result_clock := 0.0
var caught := 0
var last_stage := ""
var heartbeat := 0.0
var reel_ticks := 0


func setup(owner_app: Node) -> void:
	app = owner_app
	elapsed = 0.0


func _process(delta: float) -> void:
	if app == null:
		return
	var session: Node = app.get("fishing_session")
	if session == null:
		return
	elapsed += delta
	if phase == "boot":
		var arrival: Control = app.get("arrival")
		if arrival != null and arrival.visible:
			# 开场选人物界面：走一次真实的「确认」按钮，之后才允许移动。
			if elapsed > 1.2:
				app.call("_on_arrival_completed")
				arrival.hide()
			return
		if elapsed > 1.6:
			_walk_to_seat()
			phase = "cast"
		return
	var stage: String = str(session.get("stage"))
	var active: bool = bool(session.get("active"))
	if stage != last_stage:
		last_stage = stage
		print("FISHDEMO stage=", stage, " active=", active, " tension=", session.get("tension"), " progress=", session.get("progress"))
	heartbeat += delta
	if heartbeat > 2.0:
		heartbeat = 0.0
		print("FISHDEMO tick phase=", phase, " settled=", app.world.orbit.activity_settled, " tension=", session.get("tension"), " prog=", session.get("progress"), " stage=", stage, " active=", active, " caught=", caught, " pos=", app.world.player.position, " loc=", app.state.location, " msg=", app.state.last_message)
	if phase == "cast":
		if not active:
			session.call("begin")
			return
		if stage == "ready":
			_start_charge(session)
			return
		if stage == "bite":
			session.call("interact")
			return
		# 已经抛出去了，进入正常控线段（等咬钩 / 收线 / 落网）。
		if stage in ["charging", "casting", "waiting", "hooking", "reeling", "net_ready", "landing", "storing", "result"]:
			phase = "fish"
		else:
			return
	if not active:
		phase = "cast"
		return
	match stage:
		"ready":
			_start_charge(session)
		"bite":
			session.call("interact")
		"reeling":
			# 张力高了就松手卸力，松了再长按收线，像人手来回控线。
			var tension_now: float = float(session.get("tension"))
			session.set("held", tension_now < 0.5)
			reel_ticks += 1
			if reel_ticks % 6 == 0:
				print("FISHDEMO reel tension=", tension_now, " held=", session.get("held"), " ctx=", app.context_action.held, " prog=", session.get("progress"))
		"net_ready":
			session.set("held", false)
			hold_clock += delta
			if hold_clock > 1.0:
				hold_clock = 0.0
				session.call("interact")
		"landing", "storing":
			session.set("held", false)
		"result":
			session.set("held", false)
			result_clock += delta
			if result_clock > 2.6:
				result_clock = 0.0
				caught += 1
				session.call("interact")
		_:
			session.set("held", false)


func _walk_to_seat() -> void:
	var actor: CharacterBody3D = app.world.player
	actor.position = SEAT + Vector3(0.0, 0.0, 1.1)
	actor.velocity = Vector3.ZERO


func _start_charge(session: Node) -> void:
	var orbit: Node = app.world.orbit
	if orbit != null and not bool(orbit.get("activity_settled")):
		return
	# 第一下先「提竿」进入蓄力态，再按住蓄力、到点松手抛出去。
	session.call("interact")
	session.set("held", true)
	hold_clock += get_process_delta_time()
	if hold_clock > 1.0:
		hold_clock = 0.0
		session.set("held", false)
