extends CharacterBody3D
var held_for_interaction:=false
var interaction_wait_target:=Vector3.ZERO
var collider: CollisionShape3D
var world: Node3D
var visual: Node3D
var animation: AnimationPlayer
var clips: Dictionary = {}
var activity=preload("res://scripts/life/companion_activity.gd").new()
var trail: Array[Vector3] = []
var last_player := Vector3.ZERO
var last_place := ""
var clock := 0.0
var petting := 0.0
var was_boating := false
var recovery_retry := 0.0
var gait_phase:float=0
var gait_hold:float=0
var gait_kind:="idle"
var idle_phase:float=0
const ASSETS := {"dog": "farm-dog-723730", "cat": "cat-base", "rabbit": "forest-rabbit-ea2da0"}
func setup(owner_world: Node3D, kind: String) -> void:
	world = owner_world
	visual = (load("res://assets/polyfork/%s.glb" % ASSETS[kind]) as PackedScene).instantiate()
	add_child(visual)
	visual.scale = Vector3.ONE * (1.4 if kind == "cat" else 0.9)
	world._apply_vertex_colors(visual)
	collider=preload("res://scripts/life/animal_collision.gd").attach(self,visual)
	for animator: AnimationPlayer in visual.find_children("*", "AnimationPlayer", true, false):
		animation = animator
		for clip: StringName in animator.get_animation_list():
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			clips[str(clip).to_lower()] = clip
		break
func recover() -> void:
	activity.reset(self)
	var offsets: Array[Vector3]=[Vector3(1.5,0,.3),Vector3(-1.5,0,.3),Vector3(0,0,1.6),Vector3(0,0,-1.6)]
	for ring in range(2,5):
		for step in range(12):offsets.append(Vector3(cos(step*TAU/12),0,sin(step*TAU/12))*(ring*.8))
	var found := false
	for offset: Vector3 in offsets:
		var candidate: Vector3=world.player.position+offset
		if not world.terrain_walkable(candidate):continue
		candidate.y=world.terrain_height(candidate.x,candidate.z)+.02
		if preload("res://scripts/life/animal_collision.gd").clear_at(self,collider,candidate,rotation.y):
			position=candidate;found=true;break
	if not found:
		visible=false;collision_layer=0;collision_mask=0;last_place="";recovery_retry=.5
		return
	visible=true;collision_layer=1;collision_mask=3
	last_player=position;last_place=world.last_location;trail.clear()
func _physics_process(delta:float) -> void:
	var before:Vector3=position
	_move_companion(delta)
	if activity.mode=="wait" or absf(activity.look_yaw)>.001 or maxf(activity.hop_pose.front,maxf(activity.hop_pose.hind,activity.hop_pose.compression))>.001:gait_hold=0
	_advance_gait(delta,before)
	if world!=null and world.player.allowed and visible:activity.pose(self,delta)
func _move_companion(delta: float) -> void:
	if world == null or world.player == null: return
	if animation != null: animation.speed_scale = 1 if world.player.allowed else 0
	if not world.player.allowed: return
	recovery_retry=maxf(0,recovery_retry-delta)
	if not visible:
		if recovery_retry<=0:recover()
		return
	if held_for_interaction:
		var offset:Vector3=interaction_wait_target-position;offset.y=0
		velocity=offset.normalized()*minf(2.3,offset.length()/maxf(delta,.001)) if offset.length()>.07 else Vector3.ZERO
		if velocity.length()>.01:
			face(lerp_angle(rotation.y,atan2(offset.x,offset.z),1-exp(-8*delta)));move_and_slide()
			position.y=world.terrain_height(position.x,position.z)+.02
		return
	clock += delta
	petting = maxf(0, petting - delta)
	if world.player.boating:
		activity.reset(self)
		was_boating = true
		collision_layer=0;collision_mask=0
		position = world.player.position + Vector3(0.65, 0.08, 0).rotated(Vector3.UP, world.player.visual.rotation.y)
		rotation.y = world.player.visual.rotation.y
		visual.rotation.y=0
		trail.clear()
		return
	if world.player.bed_stage!="" and world.player.bed_stage!="resting":
		trail.clear();activity.reset(self)
		return
	if was_boating:
		collision_layer=1;collision_mask=3
		recover()
		was_boating = false
	if last_place != world.last_location or position.distance_to(world.player.position) > 12: recover()
	if world.player.home_busy:
		activity.reset(self);_wait_outside_interaction(delta);return
	if world.player.position.distance_to(last_player) > 0.3:
		trail.append(world.player.position)
		last_player = world.player.position
		if trail.size() > 100: trail.pop_front()
	if activity.tick(self,delta):return
	if petting<=0 and (world.player.move_input.length()>.15 or ((world.player.home_busy or world.player.bed_stage in ["approaching_rack","approaching_bed","stepping_clear"]) and (Vector2(world.player.velocity.x,world.player.velocity.z).length()>.1 or world.player.home_move_direction.length()>.1))):
		var toward: Vector3 = position-world.player.position;toward.y=0
		var right: Vector3=world.camera.global_basis.x;right.y=0
		var forward: Vector3=-world.camera.global_basis.z;forward.y=0
		var input: Vector2=world.player.move_input
		var walking := (right.normalized()*input.x-forward.normalized()*input.y).normalized()
		if world.player.home_busy or world.player.bed_stage in ["approaching_rack","approaching_bed","stepping_clear"]:walking=Vector3(world.player.velocity.x,0,world.player.velocity.z).normalized()
		if world.player.home_busy and world.player.home_move_direction.length()>.1:walking=world.player.home_move_direction
		if toward.length()<2.1 and toward.normalized().dot(walking)>.25:
			for aside: Vector3 in [Vector3(-walking.z,0,walking.x),Vector3(walking.z,0,-walking.x),walking]:
				var target := position+aside*.8
				if not world.terrain_walkable(target):continue
				target.y=world.terrain_height(target.x,target.z)+.02
				if not preload("res://scripts/life/animal_collision.gd").clear_at(self,collider,target,rotation.y):continue
				velocity=aside*2.8
				move_and_slide()
				position.y=world.terrain_height(position.x,position.z)+.02
				return
	if petting <= 0 and not trail.is_empty() and position.distance_to(world.player.position) > 1.2:
		var target := trail[0]
		var next := position.move_toward(target, delta * 4.7)
		if world.terrain_walkable(next):
			next.y = world.terrain_height(next.x, next.z) + 0.02
			face(lerp_angle(rotation.y,atan2(target.x-position.x,target.z-position.z),minf(1,delta*8)))
			var previous := position
			velocity=(next-position)/maxf(delta,.001)
			move_and_slide()
			if not world.terrain_walkable(position):position=previous
			position.y=world.terrain_height(position.x,position.z)+.02
		else:
			# Breadcrumbs are recorded from the player's collision-resolved path.
			trail.pop_front()
		if position.distance_to(target) < 0.2 and not trail.is_empty(): trail.pop_front()
	visual.position.y = sin(clock * 5) * 0.015 if petting > 0 else 0.0
func face(heading: float) -> void:
	if preload("res://scripts/life/animal_collision.gd").clear_at(self,collider,position,heading):
		rotation.y=heading;visual.rotation.y=0
func _advance_gait(delta:float,before:Vector3) -> void:
	if animation==null or world==null or not world.player.allowed or not visible:return
	var distance:float=Vector2(position.x-before.x,position.z-before.z).length()
	var grounded:bool=not world.player.boating and distance<.75
	if grounded and distance>.0001:
		gait_hold=.18
		var speed:float=distance/maxf(delta,.001)
		gait_kind="run" if speed>3.0 else "walk"
		gait_phase+=distance/(1.1 if gait_kind=="run" else .65)
	elif gait_hold>0 and grounded:
		gait_hold=maxf(0,gait_hold-delta)
		if gait_hold>0:return
		gait_kind="idle";idle_phase+=delta
	else:gait_kind="idle";idle_phase+=delta
	var clip:StringName=clips.get(gait_kind,clips.get("walk",&""))
	if clip==&"":return
	if animation.current_animation!=clip:animation.play(clip,0)
	var length:float=animation.get_animation(clip).length
	animation.seek(fposmod(idle_phase,length) if gait_kind=="idle" else fposmod(gait_phase,1)*length,true)
	animation.pause()

func _wait_outside_interaction(delta:float) -> void:
	trail.clear()
	var away:Vector3=position-world.player.position;away.y=0
	if away.length()>=2.2:return
	if away.length()<.01:away=Vector3.RIGHT
	away=away.normalized()
	for heading:Vector3 in [away,Vector3(-away.z,0,away.x),Vector3(away.z,0,-away.x)]:
		var next:Vector3=position+heading*minf(2.8*delta,.12)
		if not world.terrain_walkable(next):continue
		next.y=world.terrain_height(next.x,next.z)+.02
		if not preload("res://scripts/life/animal_collision.gd").clear_at(self,collider,next,rotation.y):continue
		velocity=heading*2.8;move_and_slide();position.y=world.terrain_height(position.x,position.z)+.02;return

func reserve_interaction(stand:Vector3) -> void:
	activity.reset(self);held_for_interaction=true;interaction_wait_target=position
	var from:Vector3=world.player.position
	var route:Vector3=stand-from;route.y=0
	var radius:float=maxf(collider.shape.size.x,collider.shape.size.z)*.5+world.player.BODY_RADIUS+.16
	var nearest:Vector3=from+route*clampf((position-from).dot(route)/maxf(.001,route.length_squared()),0,1)
	if position.distance_to(nearest)>radius and position.distance_to(stand)>radius:return
	var best:float=-INF
	for ring:float in [.55,1.1,1.65]:
		for i in range(16):
			var candidate:Vector3=position+Vector3(sin(i*TAU/16),0,cos(i*TAU/16))*ring
			candidate.y=world.terrain_height(candidate.x,candidate.z)+.02
			if not activity.safe_segment(self,position,candidate):continue
			var projected:Vector3=from+route*clampf((candidate-from).dot(route)/maxf(.001,route.length_squared()),0,1)
			var gap:float=candidate.distance_to(projected)
			if candidate.distance_to(stand)<radius:continue
			var score:float=gap-ring*.1
			if score>best:best=score;interaction_wait_target=candidate
func release_interaction() -> void:
	if not held_for_interaction:return
	held_for_interaction=false;velocity=Vector3.ZERO;activity.reset(self)
func _exit_tree() -> void:
	activity.social.stop()
