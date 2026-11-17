extends SceneTree
## Run extract_mixamo_life.py first. Existing normalized Kenney rig remains unchanged.
func _initialize() -> void:
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/cuiyu_mixamo_life.json"))
 var model=load("res://assets/kenney-protagonists/protagonist.scn").instantiate()
 var rig:Skeleton3D=model.find_child("Skeleton3D",true,false)
 var library:=AnimationLibrary.new()
 var aliases:Dictionary={"Chest":"Spine1","UpperChest":"Spine2","LeftToes":"LeftToeBase","RightToes":"RightToeBase"}
 for name:String in data:
  var spec:Dictionary=data[name]
  var clip:=Animation.new();clip.length=float(spec.length)
  for bone in rig.get_bone_count():
   var track:int=clip.add_track(Animation.TYPE_ROTATION_3D)
   clip.track_set_path(track,NodePath("Root/Skeleton3D:"+rig.get_bone_name(bone)))
  for frame in spec.frames.size():
   var global_rotations:Array[Quaternion]=[]
   for bone in rig.get_bone_count():
    var parent:int=rig.get_bone_parent(bone)
    var key:String=aliases.get(str(rig.get_bone_name(bone)),str(rig.get_bone_name(bone)))
    var rotation:Quaternion=global_rotations[parent] if parent>=0 else Quaternion.IDENTITY
    if spec.frames[frame].has(key):
     var q:Array=spec.frames[frame][key];rotation=Quaternion(q[0],q[1],q[2],q[3]).normalized()
    global_rotations.append(rotation)
    var local:Quaternion=global_rotations[parent].inverse()*rotation if parent>=0 else rotation
    clip.rotation_track_insert_key(bone,minf(float(frame)/float(spec.fps),clip.length),local)
  library.add_animation(name,clip)
 var result:int=ResourceSaver.save(library,"res://assets/mixamo-life/life_actions.tres")
 model.free();print("Mixamo life library: ",result);quit(result)
