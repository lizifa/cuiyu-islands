extends Node3D
var world:Node3D
var hinge:AnimatableBody3D
var opened:=false
var angle:=0.0
var bottles:Array[Node3D]=[]
func setup(owner_world:Node3D) -> void:
 world=owner_world;name="HomeFridge"
 var white:Material=world.material(Color("e9efed"));var inside:Material=world.material(Color("cddcde"));var dark:Material=world.material(Color("44565d"))
 _box(Vector3(0,.08,0),Vector3(1.25,.16,1.05),white)
 _box(Vector3(0,2.54,0),Vector3(1.25,.12,1.05),white)
 _box(Vector3(0,1.3,-.47),Vector3(1.25,2.6,.11),white)
 for x:float in [-.58,.58]:_box(Vector3(x,1.3,0),Vector3(.09,2.6,1.05),white)
 for y:float in [.7,1.4,2.1]:_box(Vector3(0,y,.02),Vector3(1.07,.045,.9),inside)
 for i in range(6):
  var bottle:=Node3D.new();bottle.position=Vector3(-.28+(i%3)*.28,.73+(i/3)*.7,.32);add_child(bottle)
  _bottle(bottle,world.material(Color("dba453") if i%2==0 else Color("7eae6b")));bottles.append(bottle)
 hinge=AnimatableBody3D.new();hinge.sync_to_physics=false;hinge.name="FridgeDoor";hinge.position=Vector3(-.625,0,.54);add_child(hinge)
 world.box(hinge,Vector3(.625,1.3,0),Vector3(1.25,2.6,.1),white)
 world.box(hinge,Vector3(1.12,1.5,.08),Vector3(.045,.6,.05),dark)
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.25,2.6,.1);collider.shape=shape;collider.position=Vector3(.625,1.3,0);hinge.add_child(collider)
 var light:=OmniLight3D.new();light.position=Vector3(0,2.1,.25);light.omni_range=2;light.light_energy=.25;light.light_color=Color("e2f8ff");add_child(light)
func _box(pos:Vector3,size:Vector3,mat:Material) -> void:
 world.box(self,pos,size,mat)
 var body:=StaticBody3D.new();body.position=pos;add_child(body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
func _bottle(parent:Node3D,mat:Material) -> void:
 var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.055;shape.bottom_radius=.07;shape.height=.3;shape.radial_segments=10;mesh.mesh=shape;mesh.position.y=.15;mesh.material_override=mat;parent.add_child(mesh)
 var cap:=MeshInstance3D.new();var top:=CylinderMesh.new();top.top_radius=.035;top.bottom_radius=.035;top.height=.06;cap.mesh=top;cap.position.y=.32;cap.material_override=world.material(Color("eee3c6"));parent.add_child(cap)
func show_stock(count:int) -> void:
 for i in range(bottles.size()):bottles[i].visible=i<count
func _physics_process(delta:float) -> void:
 if world.player==null or not world.player.allowed:return
 if opened and world.player.position.distance_to(global_position)>3:opened=false
 var target:float=deg_to_rad(-105) if opened else 0.0
 angle=move_toward(angle,target,delta*2.5)
 hinge.rotation.y=angle
