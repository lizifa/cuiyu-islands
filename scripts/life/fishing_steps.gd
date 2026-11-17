extends RefCounted
## Keep the model's actual left/right stance; advance one planted foot at a time.
var stance:Array[Transform3D]=[]
func capture(actor:Node3D) -> void:
	stance.clear()
	for side:String in ["Left","Right"]:
		var foot:int=actor._bone(side+"Foot")
		var transform:Transform3D=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(foot)
		transform.origin-=actor.position;stance.append(transform)
func apply(actor:Node3D,origin:Vector3,time:float) -> void:
	if stance.size()!=2:return
	var first:int=0 if stance[0].origin.z<stance[1].origin.z else 1
	for side:int in range(2):
		var start:float=2.2 if side==first else 2.62
		var finish:float=2.68 if side==first else 3.1
		var phase:float=smoothstep(start,finish,time)
		var point:Vector3=origin+stance[side].origin+Vector3(0,sin(phase*PI)*.075,.65*phase)
		actor.grounded_pose.leg(actor,side,point,1)
		var foot:int=actor._bone(("Left" if side==0 else "Right")+"Foot")
		var pose:Transform3D=actor.pose_skeleton.get_bone_global_pose(foot)
		pose.basis=actor.pose_skeleton.global_basis.inverse()*stance[side].basis
		actor.pose_skeleton.set_bone_global_pose_override(foot,pose,1,true)
