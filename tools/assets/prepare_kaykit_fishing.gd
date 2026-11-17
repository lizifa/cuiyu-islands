extends SceneTree
## Bake seven CC0 KayKit clips onto the existing normalized Kenney skeleton.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var source=load("res://assets/kaykit-fishing/tools.glb").instantiate();root.add_child(source)
 var src:Skeleton3D=source.find_child("Skeleton3D",true,false)
 var ap:AnimationPlayer=source.find_child("AnimationPlayer",true,false)
 var target=load("res://assets/kenney-protagonists/protagonist.scn").instantiate()
 var rig:Skeleton3D=target.find_child("Skeleton3D",true,false)
 var mapping:Dictionary={"Hips":"hips","Spine":"spine","Chest":"chest","UpperChest":"chest","Neck":"chest","Head":"head","LeftArm":"upperarm.l","LeftForeArm":"lowerarm.l","LeftHand":"hand.l","RightArm":"upperarm.r","RightForeArm":"lowerarm.r","RightHand":"hand.r"}
 var library:=AnimationLibrary.new()
 for name:String in ["Fishing_Cast","Fishing_Idle","Fishing_Bite","Fishing_Tug","Fishing_Reeling","Fishing_Struggling","Fishing_Catch"]:
  var original:Animation=ap.get_animation(name)
  var baked:=Animation.new();baked.length=original.length
  for bone in rig.get_bone_count():
   var track:int=baked.add_track(Animation.TYPE_ROTATION_3D)
   baked.track_set_path(track,NodePath("Root/Skeleton3D:"+rig.get_bone_name(bone)))
  for frame in range(int(ceil(original.length*30))+1):
   var time:float=minf(frame/30.0,original.length)
   src.reset_bone_poses()
   for track in original.get_track_count():
    var path:NodePath=original.track_get_path(track)
    if path.get_subname_count()==0:continue
    var bone:int=src.find_bone(path.get_subname(0))
    if bone<0:continue
    match original.track_get_type(track):
     Animation.TYPE_POSITION_3D:src.set_bone_pose_position(bone,original.position_track_interpolate(track,time))
     Animation.TYPE_ROTATION_3D:src.set_bone_pose_rotation(bone,original.rotation_track_interpolate(track,time))
     Animation.TYPE_SCALE_3D:src.set_bone_pose_scale(bone,original.scale_track_interpolate(track,time))
   src.force_update_all_bone_transforms()
   var globals:Array[Quaternion]=[]
   for bone in rig.get_bone_count():
    var parent:int=rig.get_bone_parent(bone)
    var rotation:Quaternion=globals[parent] if parent>=0 else Quaternion.IDENTITY
    var source_bone:int=src.find_bone(mapping.get(str(rig.get_bone_name(bone)),""))
    if source_bone>=0:
     rotation=src.get_bone_global_pose(source_bone).basis.get_rotation_quaternion()*src.get_bone_global_rest(source_bone).basis.get_rotation_quaternion().inverse()
    globals.append(rotation.normalized())
    var local:Quaternion=globals[parent].inverse()*rotation if parent>=0 else rotation
    baked.rotation_track_insert_key(bone,time,local.normalized())
  library.add_animation(name,baked)
  print(name," baked ",baked.length)
 var result:int=ResourceSaver.save(library,"res://assets/kaykit-fishing/fishing_actions.tres")
 target.free();source.free();quit(result)
