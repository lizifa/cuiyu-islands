extends RefCounted
## Two-bone leg IK keeps feet planted while the pelvis sits or crouches.
static func leg(actor:Node3D,index:int,target_world:Vector3,weight:float) -> void:
 var side:String="Left" if index==0 else "Right"
 var upper:int=actor._bone(side+"UpLeg");var lower:int=actor._bone(side+"Leg");var foot:int=actor._bone(side+"Foot")
 if mini(upper,mini(lower,foot))<0:return
 var skeleton:Skeleton3D=actor.pose_skeleton
 var a:Transform3D=skeleton.get_bone_global_pose(upper);var b:Transform3D=skeleton.get_bone_global_pose(lower);var c:Transform3D=skeleton.get_bone_global_pose(foot)
 var original_a:=a;var original_b:=b;var original_c:=c
 var target:Vector3=skeleton.to_local(target_world)
 var l1:float=a.origin.distance_to(b.origin);var l2:float=b.origin.distance_to(c.origin)
 var direction:Vector3=(target-a.origin).normalized();var distance:float=clampf(target.distance_to(a.origin),.02,l1+l2-.003)
 var along:float=(l1*l1-l2*l2+distance*distance)/(2*distance)
 var forward:Vector3=skeleton.global_basis.inverse()*actor.visual.global_basis.z.normalized()
 var pole:Vector3=forward-direction*forward.dot(direction)
 if pole.length()<.05:pole=Vector3.UP-direction*Vector3.UP.dot(direction)
 var knee:Vector3=a.origin+direction*along+pole.normalized()*sqrt(maxf(0,l1*l1-along*along))
 a.basis=Basis(Quaternion((b.origin-a.origin).normalized(),(knee-a.origin).normalized()))*a.basis
 b.basis=Basis(Quaternion((c.origin-b.origin).normalized(),(a.origin+direction*distance-knee).normalized()))*b.basis;b.origin=knee
 c.origin=a.origin+direction*distance
 c.basis=skeleton.global_basis.orthonormalized().inverse()*actor.visual.global_basis.orthonormalized()
 skeleton.set_bone_global_pose_override(upper,original_a.interpolate_with(a,weight),1,true)
 skeleton.set_bone_global_pose_override(lower,original_b.interpolate_with(b,weight),1,true)
 skeleton.set_bone_global_pose_override(foot,original_c.interpolate_with(c,weight),1,true)
