extends RefCounted
## One permanent stool; handheld tools are created by the fishing session.
static func mesh(world: Node3D, parent: Node3D, geometry: Mesh, color: String, pos: Vector3, name_value: String) -> MeshInstance3D:
 var node := MeshInstance3D.new();node.mesh=geometry;node.material_override=world.material(Color(color));node.position=pos;node.name=name_value;parent.add_child(node);return node
static func cylinder(world: Node3D,parent: Node3D,radius: float,height: float,color: String,pos: Vector3,name_value: String) -> MeshInstance3D:
 var shape := CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=10
 return mesh(world,parent,shape,color,pos,name_value)
static func net(world: Node3D,parent: Node3D) -> Node3D:
 var tool := Node3D.new();tool.name="LandingNet";parent.add_child(tool)
 cylinder(world,tool,.028,2.4,"536e76",Vector3(0,1.2,0),"NetHandle")
 var head:=Node3D.new();head.name="NetHead";head.position.y=2.4;tool.add_child(head)
 var ring := TorusMesh.new();ring.inner_radius=.47;ring.outer_radius=.5;ring.rings=16;ring.ring_segments=6
 mesh(world,head,ring,"536e76",Vector3.ZERO,"NetHoop")
 var strands := ImmediateMesh.new();strands.surface_begin(Mesh.PRIMITIVE_LINES)
 for i in range(12):
  var angle := i*TAU/12
  strands.surface_add_vertex(Vector3(cos(angle)*.48,0,sin(angle)*.48));strands.surface_add_vertex(Vector3(cos(angle)*.12,-.65,sin(angle)*.12))
 for level in range(1,4):
  var y := -.65+level*.1625;var radius := .12+level*.09
  for i in range(16):
   for point in [i,i+1]:strands.surface_add_vertex(Vector3(cos(point*TAU/16)*radius,y,sin(point*TAU/16)*radius))
 strands.surface_end();mesh(world,head,strands,"b7c7ab",Vector3.ZERO,"NetMesh")
 var bag:=CylinderMesh.new();bag.top_radius=.48;bag.bottom_radius=.12;bag.height=.65;bag.radial_segments=16
 var fabric:=mesh(world,head,bag,"70959c33",Vector3(0,-.325,0),"NetBag")
 fabric.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 fabric.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
 return tool
static func setup(world: Node3D,parent: Node3D,seat: Vector3) -> void:
 var kit := Node3D.new();kit.name="ShoreFishingKit";parent.add_child(kit)
 cylinder(world,kit,.29,.12,"496e65",seat+Vector3.UP*.43,"FishingStoolSeat")
 world._solid(seat+Vector3.UP*.24,Vector3(.5,.48,.5))
 for x in [-.19,.19]:
  for z in [-.19,.19]:cylinder(world,kit,.025,.35,"6d6452",seat+Vector3(x,.18,z),"StoolLeg")
 # Keep the storage controller for the catch animation, without idle scenery clutter.
 var keep=preload("res://scripts/life/fish_keep_net.gd").new();kit.add_child(keep);keep.setup(world);keep.hide()
