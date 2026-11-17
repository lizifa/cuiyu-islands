extends RefCounted
## Local idle play has lower priority than following, interaction and safe ground.
const Collision=preload("res://scripts/life/animal_collision.gd")
const FOLLOW_DISTANCE:=4.2
const ROAM_RADIUS:=3.2
var social=preload("res://scripts/life/pet_social.gd").new()
var hop_pose=preload("res://scripts/life/pet_hop.gd").new()
var rng:=RandomNumberGenerator.new()
var move_speed:float=0
var look_yaw:float=0
var wag_time:float=0
var mode:="follow"
var elapsed:float=0
var duration:float=0
var still_time:float=0
var last_owner:=Vector3.INF
var target:=Vector3.ZERO
var history:Array[Vector3]=[]
func _init() -> void:rng.randomize()
func roam_radius(pet:CharacterBody3D) -> float:
	if pet.world.last_location!="island":return 2.8
	if preload("res://scripts/life/fishing_platform.gd").within_reach(pet.position):return 2.2
	return 6.0 if pet.world.navigation_state.profile.pet=="dog" else ROAM_RADIUS
func reset(pet:CharacterBody3D) -> void:
	social.stop()
	move_speed=0;look_yaw=0;mode="follow";elapsed=0;duration=0;still_time=0;history.clear();last_owner=Vector3.INF
	hop_pose.reset(pet)
func _follow(pet:CharacterBody3D) -> void:
	social.stop()
	if not history.is_empty():
		var toward:Vector3=pet.position-pet.world.player.position;toward.y=0
		var approach:Vector3=pet.world.player.position+toward.normalized()*1.5
		if safe_segment(pet,pet.position,approach):pet.trail.clear();pet.trail.append(approach)
		else:history.reverse();history.append_array(pet.trail);pet.trail=history.duplicate()
		history.clear()
	if pet.trail.is_empty() and pet.position.distance_to(pet.world.player.position)>1.2:pet.trail.append(pet.world.player.position)
	mode="follow";elapsed=0;duration=0
func tick(pet:CharacterBody3D,delta:float) -> bool:
	var owner:CharacterBody3D=pet.world.player
	if owner.working:
		still_time=0;_follow(pet);return false
	var moving:bool=last_owner!=Vector3.INF and owner.position.distance_to(last_owner)>.003
	last_owner=owner.position
	moving=moving or owner.move_input.length()>.15
	still_time=0 if moving else still_time+delta
	var distance:float=Vector2(pet.position.x-owner.position.x,pet.position.z-owner.position.z).length()
	if moving or distance>roam_radius(pet)+1.2 or absf(pet.position.y-owner.position.y)>.8:
		pet.petting=0 if distance>roam_radius(pet)+1.2 else pet.petting
		_follow(pet);return false
	if pet.petting>0 or still_time<.8:
		if pet.petting>0:hop_pose.reset(pet)
		_follow(pet);return false
	if mode=="follow":
		if distance>1.8 and (owner.fishing_stage=="" or distance>roam_radius(pet)+.5):return false
		pet.trail.clear();history.append(pet.position)
		choose(pet)
	elapsed+=delta
	if elapsed>=duration:choose(pet)
	pet.velocity=Vector3.ZERO
	if mode=="social":
		if not social.tick(pet,delta):choose(pet,"wait")
		return true
	if mode in ["walk","run"]:
		if pet.position.distance_to(target)<.15:
			choose(pet,"wait");return true
		var speed:float=(3.8 if mode=="run" else 1.05) if pet.world.navigation_state.profile.pet=="dog" else (3.4 if mode=="run" else .85)
		var desired:float=minf(speed,sqrt(10*pet.position.distance_to(target)))
		move_speed=move_toward(move_speed,desired,delta*5)
		var next:Vector3=pet.position.move_toward(target,delta*move_speed)
		if not safe_segment(pet,pet.position,next):choose(pet,"wait");return true
		pet.face(lerp_angle(pet.rotation.y,atan2(target.x-pet.position.x,target.z-pet.position.z),minf(1,delta*8)))
		var before:Vector3=pet.position
		pet.velocity=(next-before)/maxf(delta,.001);pet.move_and_slide()
		if not safe_ground(pet,pet.position):pet.position=before;choose(pet,"wait")
		pet.position.y=pet.world.terrain_height(pet.position.x,pet.position.z)+.02
		if history.is_empty() or history[-1].distance_to(pet.position)>.35:
			for i in range(maxi(0,history.size()-2)):
				if history[i].distance_to(pet.position)<.4:history.resize(i+1);break
			history.append(pet.position)
			if history.size()>96:history.pop_front()
	return true
func choose(pet:CharacterBody3D,requested:String="") -> void:
	social.stop()
	elapsed=0;pet.visual.position.y=0
	mode=requested
	if mode=="" and rng.randf()<.5 and social.begin(pet):mode="social"
	if mode=="social":
		if not is_instance_valid(social.partner) and not social.begin(pet):mode="wait"
		else:duration=rng.randf_range(5.5,8);return
	if mode=="":
		var roll:float=rng.randf()
		mode=("wait" if roll<.06 else ("walk" if roll<.42 else ("run" if roll<.9 else "hop"))) if pet.world.navigation_state.profile.pet=="dog" else ("wait" if roll<.32 else ("walk" if roll<.7 else ("run" if roll<.88 else "hop")))
	duration=(rng.randf_range(.35,.8) if pet.world.navigation_state.profile.pet=="dog" else rng.randf_range(.6,1.4)) if mode=="wait" else rng.randf_range(1.8,4.2)
	if mode=="hop":
		if not safe_jump(pet):mode="wait";return
		duration=1.05;pet.gait_hold=0
	if mode in ["walk","run"]:
		for attempt in range(12):
			var angle:float=rng.randf_range(0,TAU)
			var candidate:Vector3=pet.world.player.position+Vector3(sin(angle),0,cos(angle))*rng.randf_range(1.4,roam_radius(pet))
			candidate.y=pet.world.terrain_height(candidate.x,candidate.z)+.02
			if candidate.distance_to(pet.position)>.6 and safe_segment(pet,pet.position,candidate):target=candidate;return
		# A nearby safe stroll is preferable to repeated failed long targets.
		if pet.world.navigation_state.profile.pet=="dog":
			for i in range(12):
				var candidate:Vector3=pet.position+Vector3(sin(i*TAU/12),0,cos(i*TAU/12))*rng.randf_range(.55,1.1)
				candidate.y=pet.world.terrain_height(candidate.x,candidate.z)+.02
				if candidate.distance_to(pet.world.player.position)<=roam_radius(pet) and safe_segment(pet,pet.position,candidate):target=candidate;mode="walk";return
		mode="wait"
func safe_ground(pet:CharacterBody3D,point:Vector3) -> bool:
	if not pet.world.terrain_walkable(point):return false
	var height:float=pet.world.terrain_height(point.x,point.z)
	if absf(height-pet.position.y)>.18:return false
	# Keep the complete body footprint away from the pier and sea edge.
	var radius:float=maxf(pet.collider.shape.size.x,pet.collider.shape.size.z)*.5
	for offset:Vector3 in [Vector3(radius,0,0),Vector3(-radius,0,0),Vector3(0,0,radius),Vector3(0,0,-radius)]:
		if pet.world.last_location!="island" and not pet.world.terrain_walkable(point+offset):return false
		if absf(pet.world.terrain_height(point.x+offset.x,point.z+offset.z)-height)>.12:return false
	return true
func safe_segment(pet:CharacterBody3D,start:Vector3,end:Vector3,heading_hint:float=INF) -> bool:
	var count:int=maxi(1,ceili(start.distance_to(end)/.2))
	var heading:float=heading_hint if heading_hint!=INF else (pet.rotation.y if start.distance_squared_to(end)<.000001 else atan2(end.x-start.x,end.z-start.z))
	for i in range(1,count+1):
		var point:Vector3=start.lerp(end,float(i)/count)
		if not safe_ground(pet,point):return false
		point.y=pet.world.terrain_height(point.x,point.z)+.02
		if not Collision.clear_at(pet,pet.collider,point,heading):return false
	return true
func safe_jump(pet:CharacterBody3D) -> bool:
	if not safe_ground(pet,pet.position):return false
	for rise:float in [.12,.24,.4]:
		if not Collision.clear_at(pet,pet.collider,pet.position+Vector3.UP*rise,pet.rotation.y):return false
	return true
func pose(pet:CharacterBody3D,delta:float) -> void:
	wag_time+=delta
	hop_pose.apply(pet,clampf(elapsed/duration,0,1) if mode=="hop" else -1.0,delta)
	var goal:float=0
	if mode=="wait" and pet.petting<=0 and pet.world.navigation_state.profile.pet=="dog":
		var toward:Vector3=pet.world.player.position-pet.position
		goal=clampf(angle_difference(pet.rotation.y,atan2(toward.x,toward.z)),-.65,.65)
	look_yaw=lerpf(look_yaw,goal,1-exp(-5*delta))
	if absf(look_yaw)>.001:
		var rig:Skeleton3D=pet.visual.find_children("*","Skeleton3D",true,false)[0]
		for bone:String in ["Neck","Head"]:
			var index:int=rig.find_bone(bone)
			if index>=0:rig.set_bone_pose_rotation(index,rig.get_bone_pose_rotation(index)*Quaternion(Vector3.UP,look_yaw*.5))

	if pet.world.navigation_state.profile.pet=="dog" and mode!="hop":
		var rig:Skeleton3D=pet.visual.find_children("*","Skeleton3D",true,false)[0]
		for bone:String in ["Tail","TailTip"]:
			var index:int=rig.find_bone(bone)
			if index>=0:rig.set_bone_pose_rotation(index,Quaternion((rig.get_bone_global_pose(index).basis.inverse()*Vector3.UP).normalized(),sin(wag_time*10+(0 if bone=="Tail" else .7))*.25))
