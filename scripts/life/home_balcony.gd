extends Node3D
var rocker:Node3D
const ROCKER_AT:=Vector3(-3.0,5.925,22.2)
const D=preload("res://scripts/life/villa_dimensions.gd")
func setup(world:Node3D) -> void:
 name="AccessibleUpperBalcony"
 var wood:Material=world.material(Color("c6b38f"));var rail:Material=world.material(Color("668382"))
 _make_rocker(world,wood)
 var bounds:Rect2=D.BALCONY_RECT
 _solid(world,Vector3(bounds.get_center().x,D.UPPER_FLOOR-.12,bounds.get_center().y),Vector3(bounds.size.x,.24,bounds.size.y),wood,"BalconyDeck")
 for x:float in [bounds.position.x,bounds.end.x]:
  _solid(world,Vector3(x,D.UPPER_FLOOR+.53,bounds.get_center().y),Vector3(.1,1.06,bounds.size.y),rail,"BalconySideGuard")
 _solid(world,Vector3(bounds.get_center().x,D.UPPER_FLOOR+.53,bounds.end.y),Vector3(bounds.size.x,1.06,.1),rail,"BalconySeaGuard")
 for x:float in [bounds.position.x+.2,bounds.end.x-.2]:
  world.box(self,Vector3(x,(D.UPPER_FLOOR+D.BASE)*.5,bounds.end.y-.2),Vector3(.28,D.UPPER_FLOOR-D.BASE,.28),wood)
func _solid(world:Node3D,at:Vector3,size:Vector3,mat:Material,id:String) -> void:
 var visual_material:Material=mat
 if id.contains("Guard"):
  var glass:StandardMaterial3D=mat.duplicate();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(.55,.77,.76,.23);visual_material=glass
  world.box(self,at+Vector3.UP*.52,Vector3(size.x,.07,size.z),mat)
 var mesh:MeshInstance3D=world.box(self,at,size,visual_material);mesh.name=id
 var body:=StaticBody3D.new();body.name=id+"Collision";body.position=at;body.collision_layer=17;add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)

func _make_rocker(world:Node3D,wood:Material) -> void:
 var base:=Node3D.new();base.name="RockingChair";base.position=ROCKER_AT;add_child(base)
 rocker=Node3D.new();rocker.name="RockingSeat";rocker.position.y=.7;base.add_child(rocker)
 var cushion:Material=world.material(Color("d8d3b8"))
 world.box(rocker,Vector3(0,.14,.12),Vector3(1.05,.22,1.15),cushion)
 var back:MeshInstance3D=world.box(rocker,Vector3(0,.65,-.68),Vector3(1.05,1.3,.18),cushion);back.rotation.x=-.65
 var legs:MeshInstance3D=world.box(rocker,Vector3(0,-.02,.98),Vector3(1.05,.18,.95),cushion);legs.rotation.x=.24
 for side:float in [-.62,.62]:
  world.box(rocker,Vector3(side,.38,.15),Vector3(.11,.1,1.1),wood)
  for z:float in [-.25,.55]:world.box(rocker,Vector3(side,.08,z),Vector3(.09,.6,.09),wood)
  for i in range(10):
   var z:float=-1.3+i*.28;var runner:MeshInstance3D=world.box(base,Vector3(side,.12+z*z*.16,z),Vector3(.12,.12,.31),wood);runner.rotation.x=-atan(z*.32)
 _solid(world,ROCKER_AT+Vector3(0,.55,.1),Vector3(1.4,1.1,2.8),wood,"RockerBody")
 var collider_visual:Node3D=get_node("RockerBody");collider_visual.hide()
func set_rock(time:float,amount:float=1.0) -> void:
 if is_instance_valid(rocker):rocker.rotation.x=sin(time*.85)*.035*amount
