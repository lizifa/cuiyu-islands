extends RefCounted
## Friendly land animals may greet and play; neither participant loses collisions.
const Collision=preload("res://scripts/life/animal_collision.gd")
var partner:CharacterBody3D
var goal:=Vector3.ZERO
var center:=Vector3.ZERO
var radius:float=1
var bearing:float=0
var elapsed:float=0
var playing:=false
func stop() -> void:
	if is_instance_valid(partner):
		partner.remove_meta("pet_play");animate(partner,"walk")
	partner=null;playing=false;elapsed=0
func begin(pet:CharacterBody3D) -> bool:
	stop()
	if pet.world.last_location!="island" or not pet.world.forest.visible:return false
	var candidates:Array[Node3D]=[]
	for animal:Node3D in pet.world.forest.actors:
		if animal is CharacterBody3D and animal.get_meta("mode","")=="land" and not animal.has_meta("pet_play") and animal.is_visible_in_tree() and animal.position.distance_to(pet.position)<3.5 and animal.position.distance_to(pet.world.player.position)<pet.activity.roam_radius(pet):candidates.append(animal)
	candidates.sort_custom(func(a,b):return a.position.distance_squared_to(pet.position)<b.position.distance_squared_to(pet.position))
	for animal:CharacterBody3D in candidates:
		var shape:CollisionShape3D=animal.get_meta("animal_shape")
		var spacing:float=(maxf(pet.collider.shape.size.x,pet.collider.shape.size.z)+maxf(shape.shape.size.x,shape.shape.size.z))*.5+.4
		var toward:Vector3=pet.position-animal.position
		var angle:float=atan2(toward.x,toward.z)
		for i in range(12):
			var point:Vector3=animal.position+Vector3(sin(angle+i*TAU/12),0,cos(angle+i*TAU/12))*spacing
			point.y=pet.world.terrain_height(point.x,point.z)+.02
			if Vector2(point.x-pet.world.player.position.x,point.z-pet.world.player.position.z).length()>pet.activity.roam_radius(pet):continue
			if not pet.activity.safe_segment(pet,pet.position,point):continue
			partner=animal;goal=point
			partner.set_meta("pet_play",{"pet":pet,"goal":partner.position,"face":pet.position})
			return true
	return false
func tick(pet:CharacterBody3D,delta:float) -> bool:
	if not is_instance_valid(partner) or not partner.is_visible_in_tree() or not partner.has_meta("pet_play"):stop();return false
	if partner.position.distance_to(pet.world.player.position)>pet.activity.roam_radius(pet)+.4 or pet.world.last_location!="island":stop();return false
	var greeting:Dictionary=partner.get_meta("pet_play");greeting.face=pet.position
	if not playing and pet.position.distance_to(goal)<.18:
		playing=true;elapsed=0;center=(pet.position+partner.position)*.5
		radius=Vector2(pet.position.x-center.x,pet.position.z-center.z).length()
		bearing=atan2(pet.position.x-center.x,pet.position.z-center.z)
	if playing:
		elapsed+=delta
		var angle:float=bearing+sin(maxf(0,elapsed-.8)*1.2)*.3
		var offset:=Vector3(sin(angle),0,cos(angle))*radius
		goal=center+offset;goal.y=pet.world.terrain_height(goal.x,goal.z)+.02
		var other:Vector3=center-offset;other.y=pet.world.terrain_height(other.x,other.z)+.02
		var play:Dictionary=partner.get_meta("pet_play");play.goal=other;play.face=pet.position
		if Vector2(goal.x-pet.world.player.position.x,goal.z-pet.world.player.position.z).length()>pet.activity.roam_radius(pet):return false
	var next:Vector3=pet.position.move_toward(goal,delta*.9)
	var moving:bool=next.distance_to(pet.position)>.002
	var face:Vector3=goal-pet.position if moving and not playing else partner.position-pet.position
	if not pet.activity.safe_segment(pet,pet.position,next,atan2(face.x,face.z)):return false
	pet.face(lerp_angle(pet.rotation.y,atan2(face.x,face.z),1-exp(-7*delta)))
	pet.velocity=(next-pet.position)/maxf(delta,.001);pet.move_and_slide()
	pet.position.y=pet.world.terrain_height(pet.position.x,pet.position.z)+.02
	return true
static func animate(animal:Node3D,kind:String) -> void:
	for player:AnimationPlayer in animal.find_children("*","AnimationPlayer",true,false):
		for clip:StringName in player.get_animation_list():
			if str(clip).to_lower().ends_with(kind):
				if player.current_animation!=clip:player.play(clip,.18)
				return
static func tick_animal(world:Node3D,animal:CharacterBody3D,delta:float) -> bool:
	if not animal.has_meta("pet_play"):return false
	var play:Dictionary=animal.get_meta("pet_play")
	var pet:Node=play.pet
	if not is_instance_valid(pet) or not pet.visible or pet.activity.mode!="social":
		animal.remove_meta("pet_play");animate(animal,"walk");return false
	var goal:Vector3=play.goal
	var offset:Vector3=goal-animal.position;offset.y=0
	var next:Vector3=animal.position+offset.limit_length(delta*.7)
	var shape:CollisionShape3D=animal.get_meta("animal_shape")
	var heading:float=atan2(offset.x,offset.z) if offset.length()>.04 else atan2(play.face.x-animal.position.x,play.face.z-animal.position.z)
	if world.terrain_walkable(next) and absf(world.terrain_height(next.x,next.z)-animal.position.y)<.18 and Collision.clear_at(animal,shape,next,heading):
		animal.velocity=(next-animal.position)/maxf(delta,.001);animal.move_and_slide()
		animal.position.y=world.terrain_height(animal.position.x,animal.position.z)+.02
	if Collision.clear_at(animal,shape,animal.position,heading):animal.rotation.y=lerp_angle(animal.rotation.y,heading,1-exp(-6*delta))
	animate(animal,"walk" if offset.length()>.04 else "idle")
	return true
