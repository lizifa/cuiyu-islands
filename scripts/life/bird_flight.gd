extends RefCounted
## Continuous world-space routes. Camera motion never respawns a bird.
var rng:=RandomNumberGenerator.new()
var points:Array[Vector3]=[]
var elapsed:float=0
var duration:float=12
var direction:=Vector3.FORWARD
var mode:="pass"
func setup(actor:Node3D) -> void:
	rng.randomize()
	var angle:float=rng.randf_range(0,TAU)
	actor.position=Vector3(sin(angle)*30,rng.randf_range(7,13),cos(angle)*30)
	direction=(-actor.position*Vector3(1,0,1)).normalized();route(actor.position)
func route(start:Vector3) -> void:
	mode=["pass","circle","glide"][rng.randi_range(0,2)]
	var toward:Vector3=(-start*Vector3(1,0,1)).normalized()
	var heading:Vector3=direction.rotated(Vector3.UP,rng.randf_range(-1.1,1.1))
	if Vector2(start.x,start.z).length()>30:heading=toward.rotated(Vector3.UP,rng.randf_range(-.45,.45))
	var span:float=rng.randf_range(18,36)
	var end:Vector3=start+heading*span;end.y=rng.randf_range(7,14)
	var side:=Vector3(-heading.z,0,heading.x)*rng.randf_range(-8,8)
	points=[start,start+direction*span*.35,start+heading*span*.65+side,end]
	points[1].y=start.y;points[2].y=end.y+rng.randf_range(-1,1)
	duration=rng.randf_range(10,17);elapsed=0
func tick(actor:Node3D,delta:float) -> void:
	elapsed+=delta
	if elapsed>=duration:route(actor.position)
	var t:float=clampf(elapsed/duration,0,1);var u:float=1-t
	actor.position=points[0]*u*u*u+points[1]*3*u*u*t+points[2]*3*u*t*t+points[3]*t*t*t
	var tangent:Vector3=(points[1]-points[0])*3*u*u+(points[2]-points[1])*6*u*t+(points[3]-points[2])*3*t*t
	if tangent.length()>.01:
		direction=tangent.normalized()
		var heading:float=atan2(direction.x,direction.z)
		var turn:float=angle_difference(actor.rotation.y,heading)
		actor.rotation.y=lerp_angle(actor.rotation.y,heading,1-exp(-4*delta))
		actor.rotation.z=lerpf(actor.rotation.z,clampf(-turn,-.3,.3),1-exp(-4*delta))
	for animator:AnimationPlayer in actor.find_children("*","AnimationPlayer",true,false):animator.speed_scale=.25 if mode=="glide" else 1
