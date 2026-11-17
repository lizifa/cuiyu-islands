extends RefCounted
## Soft take-off and landing, with front/hind legs folding at different times.
var height:float=0
var front:float=0
var hind:float=0
var compression:float=0
static func smoother(value:float) -> float:
	var t:float=clampf(value,0,1)
	return t*t*t*(t*(t*6-15)+10)
static func sample(time:float) -> Dictionary:
	var t:float=clampf(time,0,1)
	var air:float=clampf((t-.2)/.58,0,1)
	var arc:float=64*pow(air*(1-air),3)
	var preparation:float=smoother(t/.2)*(1-smoother((t-.2)/.14))
	var landing:float=smoother((t-.7)/.13)*(1-smoother((t-.83)/.17))
	return {"height":arc,"front":smoother((t-.14)/.22)*(1-smoother((t-.55)/.25)),"hind":smoother((t-.24)/.2)*(1-smoother((t-.65)/.25)),"compress":maxf(preparation,landing)}
func reset(pet:CharacterBody3D) -> void:
	height=0;front=0;hind=0;compression=0;pet.visual.position.y=0
func apply(pet:CharacterBody3D,time:float,delta:float) -> void:
	var pose:Dictionary=sample(time) if time>=0 else {"height":0,"front":0,"hind":0,"compress":0}
	var blend:float=1-exp(-20*delta)
	height=lerpf(height,pose.height*(.32 if pet.world.navigation_state.profile.pet=="cat" else .26),blend)
	front=lerpf(front,pose.front,blend);hind=lerpf(hind,pose.hind,blend);compression=lerpf(compression,pose.compress,blend)
	pet.visual.position.y=height
	if maxf(front,maxf(hind,compression))<.001:return
	var rig:Skeleton3D=pet.visual.find_children("*","Skeleton3D",true,false)[0]
	var hips:int=rig.find_bone("Hips")
	if hips>=0:rig.set_bone_pose_position(hips,rig.get_bone_pose_position(hips)-Vector3.UP*(.025*compression/rig.global_basis.get_scale().y))
	for side:String in ["Left","Right"]:
		for part:String in ["FrontUpLeg","FrontElbow","HindUpLeg","HindLeg"]:
			var index:int=rig.find_bone(side+part)
			if index<0:continue
			var fold:float=front if part.begins_with("Front") else hind
			var bend:float=(-.36 if part.ends_with("UpLeg") else .58)*fold
			rig.set_bone_pose_rotation(index,rig.get_bone_pose_rotation(index)*Quaternion(Vector3.RIGHT,bend))
