extends RefCounted
## Shared timeline for the left hand, net hoop and caught fish.
const DURATION:=3.4
const CATCH_TIME:=1.85
static func pose(origin:Vector3,time:float) -> Dictionary:
	var reach:float=smoothstep(0,.55,time)
	var dip:float=smoothstep(.55,1.35,time)
	var sweep:float=smoothstep(1.35,CATCH_TIME,time)
	var lift:float=smoothstep(CATCH_TIME,3.15,time)
	var hand:Vector3=origin+Vector3(-.2,1.25,.32).lerp(Vector3(-.2,.75,.6),dip).lerp(Vector3(-.2,1.2,.3),lift)
	var hoop:Vector3=origin+Vector3(-.55,1.75,.65).lerp(Vector3(-.55,-.9,2.1),dip).lerp(Vector3(-.6,-.9,2.45),sweep).lerp(Vector3(-.55,.55,2),lift)
	var fish:Vector3=origin+Vector3(-.6,-.74,2.35)
	if time<CATCH_TIME:fish+=Vector3(sin(time*7)*.05,0,cos(time*5)*.04)
	else:fish=hoop-Vector3.UP*.27
	return {"hand":hand,"hoop":hoop,"fish":fish,"reach":reach,"lean":dip*(1-lift),"caught":time>=CATCH_TIME}
static func place_net(tool:Node3D,hand:Vector3,hoop:Vector3) -> void:
	var direction:Vector3=hoop-hand
	var length:float=maxf(.1,direction.length())
	tool.position=hand;tool.basis=Basis(Quaternion(Vector3.UP,direction.normalized()))
	var handle:MeshInstance3D=tool.get_node("NetHandle")
	handle.position.y=length*.5;handle.scale.y=length/2.4
	var head:Node3D=tool.get_node("NetHead")
	head.position=Vector3(0,length,0)
	# Keep the hoop open upwards and the bag hanging down throughout the scoop.
	head.global_basis=Basis.IDENTITY
