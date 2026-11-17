extends Node3D
## 海里的大个头：鲨鱼绕岛巡游、追小鱼，靠得太近会撞船；鲸鱼慢慢游过并浮上来喷水。
## 全部行为都在本脚本里推进，方便 headless 检查（`step(delta)` 可单独调用）。
const SHARK_ASSET := "res://assets/polyfork/reef-shark-base.glb"
const SHARK_SCALE := 2.8
const SHARK_DEPTH := -0.85
const ATTACK_RANGE := 2.6
const ALERT_RANGE := 9.0
var world: Node3D
var sharks: Array[Dictionary] = []
var whales: Array[Dictionary] = []
var prey: Array[Dictionary] = []
var attack_events := 0
var last_attack_text := ""
var elapsed := 0.0
var repel_cooldown := 0.0
var scale_size := 1.0
func setup(owner_world: Node3D) -> void:
	world = owner_world
	name = "SeaGiants"
	for index in range(2): _add_shark(index)
	_add_whale()
	for index in range(10): _add_prey(index)
	set_physics_process(true)
func _physics_process(delta: float) -> void:
	step(delta)
func step(delta: float) -> void:
	if world == null or world.navigation_state == null: return
	var visible_now: bool = world.navigation_state.location == "island"
	visible = visible_now
	if not visible_now: return
	elapsed += delta
	_step_sharks(delta)
	_step_whale(delta, whales[0] if not whales.is_empty() else {})
	_step_prey(delta)
func _add_shark(index: int) -> void:
	var packed := load(SHARK_ASSET) as PackedScene
	if packed == null: return
	var node := packed.instantiate() as Node3D
	node.scale = Vector3.ONE * SHARK_SCALE
	add_child(node)
	_tint(node)
	var tail := node.find_child("Tail", true, false)
	node.position = Vector3(cos(TAU * index / 2.0 + .4) * (27.0 + index * 12.0), SHARK_DEPTH, sin(TAU * index / 2.0 + .4) * (27.0 + index * 12.0))
	sharks.append({"node":node,"angle":TAU * index / 2.0 + .4,"radius":27.0 + index * 12.0,"speed":0.010 + index * .004,"hunting":false,"cooldown":0.0,"tail":tail,"lunge":0.0})
func _add_whale() -> void:
	var node := Node3D.new()
	node.name = "GiantWhale"
	add_child(node)
	var body := SphereMesh.new()
	body.radial_segments = 16; body.rings = 8
	var shell := MeshInstance3D.new(); shell.mesh = body
	shell.scale = Vector3(1.6, 1.15, 5.4)
	shell.material_override = world.material(Color("35525e"))
	node.add_child(shell)
	var belly := SphereMesh.new()
	belly.radial_segments = 12; belly.rings = 6
	var belly_mesh := MeshInstance3D.new(); belly_mesh.mesh = belly
	belly_mesh.scale = Vector3(1.45, .9, 4.6)
	belly_mesh.position = Vector3(0, -.38, .1)
	belly_mesh.material_override = world.material(Color("cfdcd8"))
	node.add_child(belly_mesh)
	var fluke := BoxMesh.new(); fluke.size = Vector3(3.4, .22, 1.3)
	var tail := MeshInstance3D.new(); tail.mesh = fluke
	tail.position = Vector3(0, .1, -5.3)
	tail.rotation = Vector3(deg_to_rad(12), deg_to_rad(18), 0)
	tail.material_override = world.material(Color("2b444f"))
	node.add_child(tail)
	for side: float in [-1.0, 1.0]:
		var fin := BoxMesh.new(); fin.size = Vector3(1.5, .16, .9)
		var pectoral := MeshInstance3D.new(); pectoral.mesh = fin
		pectoral.position = Vector3(side * 1.4, -.1, 1.5)
		pectoral.rotation = Vector3(0, side * deg_to_rad(28), side * deg_to_rad(18))
		pectoral.material_override = world.material(Color("3d5b66"))
		node.add_child(pectoral)
	var blowhole := GPUParticles3D.new()
	blowhole.amount = 52; blowhole.lifetime = 1.5; blowhole.one_shot = true
	blowhole.emitting = false
	blowhole.position = Vector3(0, 1.05, 1.4)
	blowhole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spout_process := ParticleProcessMaterial.new()
	spout_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spout_process.emission_sphere_radius = .18
	spout_process.direction = Vector3(0, 1, .25)
	spout_process.spread = 14
	spout_process.initial_velocity_min = 3.6
	spout_process.initial_velocity_max = 6.2
	spout_process.gravity = Vector3(0, -4.5, 0)
	spout_process.scale_min = .6; spout_process.scale_max = 1.6
	blowhole.process_material = spout_process
	var drop := SphereMesh.new(); drop.radius = .12; drop.height = .24
	drop.radial_segments = 6; drop.rings = 3
	var spray := StandardMaterial3D.new()
	spray.albedo_color = Color("e8f4f6")
	spray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spray.albedo_color.a = .85
	spray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = spray
	blowhole.draw_pass_1 = drop
	node.add_child(blowhole)
	whales.append({"node":node,"angle":1.1,"radius":58.0,"speed":0.0016,"timer":12.0,"spouting":0.0,"spout":blowhole,"bob":0.0})
func _add_prey(index: int) -> void:
	var node := Node3D.new()
	node.name = "BaitBall%d" % index
	add_child(node)
	var body := SphereMesh.new(); body.radial_segments = 8; body.rings = 4
	var mesh := MeshInstance3D.new(); mesh.mesh = body
	mesh.scale = Vector3(.1, .18, .42)
	mesh.material_override = world.material(Color("dfe9e2"))
	node.add_child(mesh)
	var fin := BoxMesh.new(); fin.size = Vector3(.02, .16, .14)
	var tail := MeshInstance3D.new(); tail.mesh = fin
	tail.position = Vector3(0, .02, -.42)
	mesh.add_child(tail)
	var angle := TAU * index / 10.0
	prey.append({"node":node,"origin":Vector3(cos(angle) * (18 + index), -.55, sin(angle) * (18 + index)),"phase":angle,"speed":0.0,"fleeing":0.0})
func _tint(root: Node) -> void:
	# Polyfork 的 GLB 用 COLOR_0 顶点色承载配色，需要打开顶点色作为 albedo。
	if root is MeshInstance3D and root.mesh != null:
		for index in range(root.mesh.get_surface_count()):
			var arrays: Array = root.mesh.surface_get_arrays(index)
			if arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > 0:
				var original: Material = root.get_active_material(index)
				if original is StandardMaterial3D:
					var colored := original.duplicate() as StandardMaterial3D
					colored.vertex_color_use_as_albedo = true
					root.set_surface_override_material(index, colored)
	for child in root.get_children(): _tint(child)
func _step_sharks(delta: float) -> void:
	repel_cooldown = maxf(0.0, repel_cooldown - delta)
	var player: Node3D = world.player
	var boating: bool = player != null and player.boating
	for shark: Dictionary in sharks:
		var node: Node3D = shark.node
		shark.cooldown = maxf(0.0, shark.cooldown - delta)
		var at: Vector3 = node.position
		var cruising := Vector3(cos(shark.angle) * shark.radius, SHARK_DEPTH, sin(shark.angle) * shark.radius)
		var target_point := cruising
		var speed := 3.4
		var hunt := false
		var chasing_fish := false
		if boating:
			var to_player: Vector3 = player.position - node.position
			to_player.y = 0
			if to_player.length() < ALERT_RANGE + 3.0: hunt = true
		if not hunt:
			# 追小鱼：附近有鱼群就压低身子冲一段。
			for fish: Dictionary in prey:
				if node.position.distance_to(fish.node.position) < 7.0:
					hunt = true
					chasing_fish = true
					target_point = fish.node.position
					break
		if hunt:
			# 追鱼群时只是突进一小段，追船才是真正的冲刺。
			speed = 4.0 if chasing_fish else 6.4
			if boating and not chasing_fish:
				target_point = Vector3(player.position.x, SHARK_DEPTH, player.position.z)
			shark.lunge = minf(1.0, shark.lunge + delta * 2.4)
		else:
			shark.lunge = maxf(0.0, shark.lunge - delta * 1.4)
			shark.angle += shark.speed * delta
		var flat: Vector3 = at.lerp(target_point, 1.0 - exp(-(speed / maxf(at.distance_to(target_point), .001)) * delta))
		flat.y = lerpf(SHARK_DEPTH, SHARK_DEPTH - .12, shark.lunge)
		node.position = flat
		var heading: Vector3 = target_point - at
		if Vector2(heading.x, heading.z).length() > .01:
			node.rotation.y = atan2(heading.x, heading.z)
		if shark.tail != null:
			(shark.tail as Node3D).rotation.y = sin(elapsed * (6.0 if hunt else 3.2)) * .35
		if boating and shark.cooldown <= 0.0:
			var reach: Vector3 = player.position - node.position
			reach.y = 0
			if reach.length() < ATTACK_RANGE:
				shark.cooldown = 7.0
				_bump_boat(player, node.position)
# 船上最近的鲨鱼距离；不划船时返回 INF，技能槽据此决定要不要切成「驱赶鲨鱼」。
func shark_threat() -> float:
	if world == null or world.player == null or not world.player.boating:return INF
	var best := INF
	for shark: Dictionary in sharks:
		var node: Node3D = shark.node
		var gap := Vector2(node.position.x - world.player.position.x, node.position.z - world.player.position.z).length()
		if gap < best: best = gap
	return best
func repel_ready() -> bool:
	return repel_cooldown <= 0.0 and shark_threat() <= 12.0
# 用船桨拍水把靠过来的鲨鱼赶开：把鲨鱼推远并让它长时间不敢再冲。
func repel() -> bool:
	if not repel_ready():return false
	repel_cooldown = 6.0
	var player: Node3D = world.player
	for shark: Dictionary in sharks:
		var node: Node3D = shark.node
		var away := Vector2(node.position.x - player.position.x, node.position.z - player.position.z)
		if away.length() > 12.0:continue
		if away.length() < .01: away = Vector2(0,1)
		away = away.normalized()
		node.position += Vector3(away.x,0,away.y) * 7.0
		shark.cooldown = maxf(shark.cooldown, 9.0)
		shark.lunge = 0.0
		shark.angle = atan2(node.position.z, node.position.x)
	last_attack_text = "船桨拍水，鲨鱼退开了。"
	if world.navigation_state != null: world.navigation_state.say(last_attack_text)
	if world.boat_wake != null: world.boat_wake.burst(player.position, 2.6)
	return true

func _bump_boat(player: Node3D, from: Vector3) -> void:
	var away: Vector3 = player.position - from
	away.y = 0
	if away.length() < .01: away = Vector3(0, 0, 1)
	away = away.normalized()
	player.position += away * 1.6
	attack_events += 1
	last_attack_text = "鲨鱼撞了船舷！稳住船身，别贴它太近。"
	if world.navigation_state != null: world.navigation_state.say(last_attack_text)
	if world.boat_wake != null: world.boat_wake.burst(player.position, 2.2)
func _step_whale(delta: float, whale: Dictionary) -> void:
	if whale.is_empty(): return
	var node: Node3D = whale.node
	whale.angle += whale.speed * delta
	whale.bob += delta
	var at := Vector3(cos(whale.angle) * whale.radius, -1.15 + sin(whale.bob * .35) * .12, sin(whale.angle) * whale.radius)
	node.position = at
	node.rotation.y = atan2(cos(whale.angle), sin(whale.angle)) + PI
	whale.timer -= delta
	if whale.timer <= 0.0 and whale.spouting <= 0.0:
		whale.spouting = 1.6
		whale.timer = 24.0 + randf() * 10.0
		(whale.spout as GPUParticles3D).restart()
		(whale.spout as GPUParticles3D).emitting = true
	if whale.spouting > 0.0:
		whale.spouting -= delta
		if whale.spouting <= 0.0:
			(whale.spout as GPUParticles3D).emitting = false
func _step_prey(delta: float) -> void:
	for fish: Dictionary in prey:
		var node: Node3D = fish.node
		var threat := INF
		var threat_at := Vector3.ZERO
		for shark: Dictionary in sharks:
			var gap: float = node.position.distance_to((shark.node as Node3D).position)
			if gap < threat: threat = gap; threat_at = (shark.node as Node3D).position
		if threat < 6.5:
			fish.fleeing = 1.2
			var away: Vector3 = node.position - threat_at
			away.y = 0
			if away.length() > .01:
				node.position += away.normalized() * 4.8 * delta
		else:
			fish.fleeing = maxf(0.0, fish.fleeing - delta)
			fish.phase += delta * .7
			var orbit_point: Vector3 = fish.origin + Vector3(cos(fish.phase) * 1.4, 0, sin(fish.phase) * 1.4)
			node.position = node.position.lerp(orbit_point, 1.0 - exp(-2.0 * delta))
		var motion: Vector3 = threat_at - node.position
		if Vector2(motion.x, motion.z).length() > .01:
			node.rotation.y = atan2(motion.x, motion.z)
