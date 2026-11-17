extends SceneTree
const Catalog=preload("res://scripts/life/character_catalog.gd")
const State=preload("res://scripts/life/life_state.gd")
var failed:=0
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 for id in Catalog.CHARACTERS:
  var model=Catalog.make(id);root.add_child(model)
  var skeleton:Skeleton3D=model.find_child("Skeleton3D",true,false)
  var animator:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
  check(skeleton!=null and animator!=null,id+" rig and animation exist")
  for bone in ["Hips","Head","LeftHand","RightHand","LeftFoot","RightFoot","LeftArm","RightArm","LeftForeArm","RightForeArm"]:
   check(skeleton.find_bone(bone)>=0,id+" bone "+bone)
  check(skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin.y>1.2,id+" normalized Y-up")
  for clip in ["Idle","Walk","Run"]:
   check(animator.has_animation(clip),id+" clip "+clip)
   animator.play(clip);animator.advance(.25)
   var head=skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
   check(head.origin.is_finite() and head.origin.y>1.0,id+" animated head remains upright")
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   check(mesh.material_override.albedo_texture.resource_path.ends_with(Catalog.CHARACTERS[id].skin+".png"),id+" correct skin")
  model.free()
 for gender in ["male","female"]:
  var state=State.new();state.coins=321
  var snapshot=state.snapshot();snapshot.profile.erase("character_id");snapshot.profile.gender=gender;snapshot.profile.confirmed=true
  var restored=State.new()
  check(restored.restore(snapshot),"legacy profile migrates "+gender)
  check(restored.coins==321 and restored.profile.character_id==Catalog.resolve(gender) and not restored.profile.has("gender"),"legacy progress preserved "+gender)
 var state=State.new();state.profile.character_id="cyborg"
 var restored=State.new();check(restored.restore(state.snapshot()) and restored.profile.character_id=="cyborg","new selection survives save")
 var bad=state.snapshot();bad.profile.character_id="unknown";check(not restored.restore(bad),"invalid character rejected")
 print("PROTAGONISTS: ",checks," checks, ",failed," failed")
 quit(1 if failed else 0)
