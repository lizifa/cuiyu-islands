extends Node3D
## A separate equipment zone, leaving the dining route and front door clear.
var room:Node3D
func setup(owner_room:Node3D) -> void:
 room=owner_room;name="HomeGym"
 room.world.box(self,Vector3(-7.3,.698,11.8),Vector3(6,.03,7),room.world.material(Color("d8c5a5")))
 var treadmill:=_root("Treadmill",Vector3(-9,.72,10.1))
 _box(treadmill,Vector3(0,.12,0),Vector3(1.0,.24,2.0),"metal")
 _box(treadmill,Vector3(0,.255,0),Vector3(.78,.035,1.7),"dark")
 for x:float in [-.45,.45]:_box(treadmill,Vector3(x,.82,-.65),Vector3(.055,1.4,.055),"metal")
 _box(treadmill,Vector3(0,1.44,-.65),Vector3(.95,.12,.38),"dark")
 _box(treadmill,Vector3(0,1.51,-.65),Vector3(.48,.025,.24),"glass")
 _solid(treadmill)
 var bike:=_root("ExerciseBike",Vector3(-6.7,.72,10.3))
 for z:float in [-.57,.57]:
  var wheel:MeshInstance3D=room._cylinder(bike,Vector3(0,.3,z),.28,.12,room.palette.dark);wheel.rotation.z=PI/2
  _box(bike,Vector3(0,.055,z),Vector3(.85,.1,.18),"metal")
 _beam(bike,Vector3(0,.23,-.57),Vector3(0,.8,.25),.07,"metal")
 _beam(bike,Vector3(0,.23,.57),Vector3(0,.8,.25),.07,"metal")
 _box(bike,Vector3(0,.84,.24),Vector3(.4,.12,.3),"dark")
 _box(bike,Vector3(0,.76,-.56),Vector3(.055,1.0,.055),"metal")
 _box(bike,Vector3(0,1.27,-.56),Vector3(.68,.055,.055),"dark")
 for side in range(2):_box(bike,Vector3(-.22 if side==0 else .22,.4,0),Vector3(.15,.045,.18),"dark").name="Pedal%d"%side
 _solid(bike)
 var rack:=_root("DumbbellRack",Vector3(-9,.72,14))
 # 架面原来做到离地 0.98 米（世界 1.70），比角色头顶（约 1.86 世界、离地 1.16）还高一截：
 # 人弯腰也够不到，拿起动作只能是伸手抓空气。横杆压到离地 0.56 米，哑铃落在 0.645 米腰高。
 for x:float in [-1.1,1.1]:_box(rack,Vector3(x,.30,0),Vector3(.07,.60,.24),"metal")
 _box(rack,Vector3(0,.56,0),Vector3(2.3,.07,.45),"metal")
 for x:float in [-.8,-.27,.27,.8]:
  _box(rack,Vector3(x,.645,0),Vector3(.055,.055,.27),"cream")
  for z:float in [-.16,.16]:
   var weight:MeshInstance3D=room._cylinder(rack,Vector3(x,.645,z),.10,.07,room.palette.dark);weight.rotation.x=PI/2
 _solid(rack)
 var mat:=_root("YogaMat",Vector3(-5.3,.735,14))
 _box(mat,Vector3.ZERO,Vector3(.95,.025,2.1),"rug");_solid(mat)
 for spec:Array in [["treadmill","跑步机锻炼",treadmill,Vector3(-9,.705,11.65)],["bike","骑健身车",bike,Vector3(-5.5,.705,10.4)],["weights","哑铃训练",rack,Vector3(-7.4,.705,12.1)],["yoga","瑜伽伸展",mat,Vector3(-5.3,.705,12.5)]]:
  # 哑铃是站桩动作：站位直接落在"训练位"，练完就停在这，取消/再开始不会先退再上前。
  var reach:float=2.6 if spec[0]=="weights" else 1.9
  room.points.append({"kind":"gym_"+spec[0],"title":spec[1],"pos":spec[2].global_position,"range":reach,"owner":self,"object":spec[2],"equipment":spec[2],"stand":room.to_global(spec[3]),"facing":spec[2].global_position})
func _root(id:String,pos:Vector3) -> Node3D:
 var node:=Node3D.new();node.name=id;node.position=pos;add_child(node);return node
func _box(parent:Node3D,pos:Vector3,size:Vector3,key:String) -> MeshInstance3D:
 return room.world.box(parent,pos,size,room.palette[key])
func _beam(parent:Node3D,a:Vector3,b:Vector3,width:float,key:String) -> void:
 var mesh:MeshInstance3D=room.world.box(parent,(a+b)*.5,Vector3(width,width,a.distance_to(b)),room.palette[key])
 mesh.basis=Basis(Quaternion(Vector3.BACK,(b-a).normalized()))
func _solid(node:Node3D) -> void:
 preload("res://scripts/life/prop_collision.gd").convex(node)
