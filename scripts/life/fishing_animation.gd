extends RefCounted
## Upper-body clips share the session clock; existing feet, rod and net IK stay authoritative.
const LIBRARY=preload("res://assets/kaykit-fishing/fishing_actions.tres")
var current_clip:=""
var previous:Array[Quaternion]=[]
var last:Array[Quaternion]=[]
var transition_start:float=0
func clear() -> void:
 current_clip="";previous.clear();last.clear()
func clip_for(stage:String,load:float,pulling:bool) -> String:
 match stage:
  "ready","charging","waiting","standing":return "Fishing_Idle"
  "casting":return "Fishing_Cast"
  "bite":return "Fishing_Bite"
  "hooking":return "Fishing_Tug"
  "reeling":return "Fishing_Struggling" if load>.82 or not pulling else "Fishing_Reeling"
  "net_ready":return "Fishing_Catch"
 return ""
func apply(actor:Node3D,stage:String,clock:float,load:float,pulling:bool) -> bool:
 var name:String=clip_for(stage,load,pulling)
 if name.is_empty():clear();return false
 var rig:Skeleton3D=actor.pose_skeleton
 var clip:Animation=LIBRARY.get_animation(name)
 var time:float=clock*clip.length if stage=="casting" else clock
 if name!=current_clip:
  previous=last.duplicate();transition_start=time;current_clip=name
 if time<transition_start:transition_start=time
 var blend:float=smoothstep(0,.18,time-transition_start)
 # A repeated cast has its own clock even when the same clip was active before.
 var sample:float=fposmod(time,clip.length) if stage in ["ready","charging","waiting","standing","reeling"] else minf(time,clip.length)
 last.resize(rig.get_bone_count())
 for bone in rig.get_bone_count():last[bone]=rig.get_bone_pose_rotation(bone)
 for track in clip.get_track_count():
  var key:String=str(clip.track_get_path(track).get_subname(0))
  if not (key in ["Spine","Chest","UpperChest","Neck","Head"] or "Arm" in key or "Shoulder" in key or "Hand" in key):continue
  var bone:int=rig.find_bone(key)
  if bone<0:continue
  var start:Quaternion=previous[bone] if previous.size()==rig.get_bone_count() else actor.pose_rotations[bone]
  var rotation:Quaternion=clip.rotation_track_interpolate(track,sample)
  last[bone]=start.slerp(rotation,blend)
  rig.set_bone_pose_rotation(bone,last[bone])
 rig.force_update_all_bone_transforms()
 return true
