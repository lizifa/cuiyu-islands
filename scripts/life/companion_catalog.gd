extends RefCounted
const NAMES={"dog":"小狗","cat":"小猫","rabbit":"兔子","cloud":"小云朵","ghost":"小幽灵","none":"独自启程"}
const FLOATING=["cloud","ghost"]
const GROUND={"dog":"farm-dog-723730","cat":"cat-base","rabbit":"forest-rabbit-ea2da0"}
static func make_visual(kind:String,world:Node3D) -> Node3D:
 if kind in FLOATING:
  var model:Node3D
  if kind=="cloud":model=_cloud()
  else:
   model=Node3D.new();model.name="GhostVisual"
   var source=(load("res://assets/cc0-companions/ghost.glb") as PackedScene).instantiate() as Node3D
   model.add_child(source)
   var bounds=_bounds(source,Transform3D.IDENTITY)
   var size:float=.65/maxf(bounds.size.y,.001)
   source.scale=Vector3.ONE*size;source.position=Vector3(-(bounds.position.x+bounds.size.x*.5),-bounds.position.y,-(bounds.position.z+bounds.size.z*.5))*size
  var head=Marker3D.new();head.name="CompanionHead";head.position=Vector3(0,.28 if kind=="cloud" else .45,0);model.add_child(head)
  return model
 var model=(load("res://assets/polyfork/%s.glb" % GROUND[kind]) as PackedScene).instantiate() as Node3D
 model.scale=Vector3.ONE*(1.4 if kind=="cat" else .9);world._apply_vertex_colors(model)
 return model
static func _cloud() -> Node3D:
 var root=Node3D.new();root.name="CloudVisual"
 var white=StandardMaterial3D.new();white.albedo_color=Color("edf7ff");white.roughness=.85
 for data in [[Vector3(-.24,.14,0),Vector3(.45,.28,.34)],[Vector3(0,.23,0),Vector3(.5,.44,.42)],[Vector3(.26,.15,0),Vector3(.42,.3,.34)]]:
  var mesh=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radial_segments=16;sphere.rings=8;mesh.mesh=sphere;mesh.scale=data[1];mesh.position=data[0];mesh.material_override=white;root.add_child(mesh)
 var ink=StandardMaterial3D.new();ink.albedo_color=Color("233c51")
 for x:float in [-.09,.09]:
  var eye=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.025;sphere.height=.05;sphere.radial_segments=8;sphere.rings=4;eye.mesh=sphere;eye.position=Vector3(x,.25,.21);eye.material_override=ink;root.add_child(eye)
 return root
static func _bounds(node:Node,parent:Transform3D) -> AABB:
 var transform=parent*(node.transform if node is Node3D else Transform3D.IDENTITY)
 var result=AABB();var has_bounds=false
 if node is MeshInstance3D:
  result=transform*node.get_aabb();has_bounds=true
 for child in node.get_children():
  var bounds=_bounds(child,transform)
  if bounds.size.length_squared()<.000001:continue
  result=result.merge(bounds) if has_bounds else bounds;has_bounds=true
 return result
