extends SceneTree
## 从轴向已转换的 GLB 烘焙统一米制、Y-up、骨骼全局静置轴，供生活动作复用。
const BASE = "res://assets/kenney-protagonists/"
const UNIT = 2.2 / 3.764686
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var model = load(BASE + "character.glb").instantiate()
 root.add_child(model)
 var skeleton:Skeleton3D=model.find_child("Skeleton3D",true,false)
 var rests:Array[Transform3D]=[]
 for i in skeleton.get_bone_count():rests.append(skeleton.get_bone_global_rest(i))
 var animations=AnimationLibrary.new()
 for spec in [["idle.glb","Idle"],["run.glb","Run"]]:
  var source=load(BASE+spec[0]).instantiate()
  root.add_child(source)
  var src_skeleton:Skeleton3D=source.find_child("Skeleton3D",true,false)
  var ap:AnimationPlayer=source.find_child("AnimationPlayer",true,false)
  for clip in ap.get_animation_list():
   if not str(clip).ends_with(spec[1]):continue
   var original:Animation=ap.get_animation(clip)
   var baked=Animation.new();baked.length=original.length;baked.loop_mode=Animation.LOOP_LINEAR
   for i in skeleton.get_bone_count():
    for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
     var track=baked.add_track(type);baked.track_set_path(track,NodePath("Root/Skeleton3D:"+skeleton.get_bone_name(i)))
   for sample in range(int(ceil(original.length*30))+1):
    var time=minf(sample/30.0,original.length)
    for track in original.get_track_count():
     var path=original.track_get_path(track)
     if path.get_subname_count()==0:continue
     var bone=src_skeleton.find_bone(path.get_subname(0))
     if bone<0:continue
     match original.track_get_type(track):
      Animation.TYPE_POSITION_3D:src_skeleton.set_bone_pose_position(bone,original.position_track_interpolate(track,time))
      Animation.TYPE_ROTATION_3D:src_skeleton.set_bone_pose_rotation(bone,original.rotation_track_interpolate(track,time))
      Animation.TYPE_SCALE_3D:src_skeleton.set_bone_pose_scale(bone,original.scale_track_interpolate(track,time))
    src_skeleton.force_update_all_bone_transforms()
    var globals:Array[Transform3D]=[]
    for i in skeleton.get_bone_count():
     var pose=src_skeleton.get_bone_global_pose(src_skeleton.find_bone(skeleton.get_bone_name(i)))
     globals.append(Transform3D(pose.basis*rests[i].basis.inverse(),pose.origin*UNIT))
    for i in skeleton.get_bone_count():
     var local=globals[i];var parent=skeleton.get_bone_parent(i)
     if parent>=0:local=globals[parent].affine_inverse()*local
     baked.position_track_insert_key(i*3,time,local.origin)
     baked.rotation_track_insert_key(i*3+1,time,local.basis.get_rotation_quaternion())
     baked.scale_track_insert_key(i*3+2,time,local.basis.get_scale())
   animations.add_animation(spec[1],baked)
  source.free()
 # 可控步行使用相同骨架的跑步循环，减速播放；不伪称素材有独立 Walk 动画。
 var walk=animations.get_animation("Run").duplicate()
 walk.length*=1.6
 for track in walk.get_track_count():
  for key in range(walk.track_get_key_count(track)-1,-1,-1):walk.track_set_key_time(track,key,walk.track_get_key_time(track,key)*1.6)
 animations.add_animation("Walk",walk)
 for i in skeleton.get_bone_count():
  var parent=skeleton.get_bone_parent(i)
  var position=rests[i].origin*UNIT
  if parent>=0:position-=rests[parent].origin*UNIT
  skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,position))
  skeleton.set_bone_pose_position(i,position);skeleton.set_bone_pose_rotation(i,Quaternion.IDENTITY);skeleton.set_bone_pose_scale(i,Vector3.ONE)
 for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  var geometry=ArrayMesh.new()
  for surface in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for i in vertices.size():vertices[i]*=UNIT
   arrays[Mesh.ARRAY_VERTEX]=vertices
   geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   geometry.surface_set_material(surface,StandardMaterial3D.new())
  mesh.mesh=geometry
  var skin=mesh.skin.duplicate()
  for bind in skin.get_bind_count():
   var bone=skin.get_bind_bone(bind)
   if skin.get_bind_name(bind)!=&"":bone=skeleton.find_bone(skin.get_bind_name(bind))
   skin.set_bind_pose(bind,Transform3D(Basis.IDENTITY,-rests[bone].origin*UNIT))
  mesh.skin=skin
 var player=AnimationPlayer.new();player.name="AnimationPlayer";model.add_child(player);player.owner=model
 player.add_animation_library("",animations)
 var scene=PackedScene.new();scene.pack(model)
 var result=ResourceSaver.save(scene,BASE+"protagonist.scn")
 print("Protagonists bake: ",result)
 model.free();quit(result)
