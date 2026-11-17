extends Node3D
var room:Node3D
var leaves:Array[AnimatableBody3D]=[]
var width:=3.2
var openness:=0.0
func setup(owner_room:Node3D,at:Vector3,door_width:float) -> void:
 room=owner_room;position=at;width=door_width;name="SensorGlassEntrance"
 var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/privacy_glass.gdshader")
 for side:int in [-1,1]:
  var leaf:=AnimatableBody3D.new();leaf.sync_to_physics=false;leaf.name="GlassLeafLeft" if side<0 else "GlassLeafRight";leaf.collision_layer=1;add_child(leaf);leaves.append(leaf)
  room.world.box(leaf,Vector3.ZERO,Vector3(width*.5,3.0,.055),mat)
  for x:float in [-width*.25,width*.25]:room.world.box(leaf,Vector3(x,0,0),Vector3(.045,3.0,.08),room.palette.metal)
  var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(width*.5,3.0,.055);collision.shape=box;leaf.add_child(collision)
 _place()
func _place() -> void:
 for i in range(2):leaves[i].position.x=(-1 if i==0 else 1)*(width*.25+openness*(width*.5+.12))
func _physics_process(delta:float) -> void:
 if room==null or room.world.player==null or not room.world.player.allowed:return
 var p:Vector3=to_local(room.world.player.global_position)
 var near:bool=absf(p.x)<width*.5+1 and absf(p.z)<3.0 and absf(p.y)<2.2
 openness=move_toward(openness,1.0 if near else 0.0,delta*1.5);_place()
