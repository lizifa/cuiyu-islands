extends RefCounted
## Original lightweight stylized fish, shared by the sea and the catch presentation.
const DATA:Dictionary={
	"bass":{"name":"海鲈鱼","body":Vector3(.22,.34,.88),"color":"91a9a0","fin":"607a78"},
	"bream":{"name":"鲷鱼","body":Vector3(.2,.48,.7),"color":"d59782","fin":"b45c58"},
	"grouper":{"name":"石斑鱼","body":Vector3(.32,.38,.86),"color":"857951","fin":"62573d"},
	"pomfret":{"name":"银鲳","body":Vector3(.11,.5,.64),"color":"b4cad1","fin":"7299a5"},
	"croaker":{"name":"黄花鱼","body":Vector3(.17,.29,.86),"color":"d9b94e","fin":"9d7938"},
	"mackerel":{"name":"马鲛鱼","body":Vector3(.15,.24,1.05),"color":"5b9fa8","fin":"35576d"},
	"tuna":{"name":"金枪鱼","body":Vector3(.26,.36,1.08),"color":"5483a1","fin":"dec65a"},
	"billfish":{"name":"旗鱼","body":Vector3(.17,.27,1.18),"color":"5876a3","fin":"3b526f"}}
const SHORE:Array[String]=["bass","bream","grouper","pomfret","croaker"]
const DEEP:Array[String]=["mackerel","tuna","billfish"]
static var cache:Dictionary={}
## 分岛鱼种：在哪座岛下竿就只会上那座岛水域的鱼，和岛上的近海生物池对应。
const ISLAND_POOLS:Dictionary={
	"twin_hills":["bass","grouper","mackerel"],
	"crescent_bay":["bream","pomfret","croaker"],
	"rocky_reef":["grouper","croaker","tuna"],
	"forest_cape":["bass","mackerel","pomfret"],
}
static func island_pool(island:String) -> Array:
	if ISLAND_POOLS.has(island):return ISLAND_POOLS[island]
	return SHORE
static func catch_id(big:bool,roll:float,deep:bool=false,island:String="") -> String:
	var pool:Array
	if deep:pool=DEEP
	elif not island.is_empty():pool=island_pool(island)
	elif big:pool=["bass","bream","grouper"]
	else:pool=SHORE
	if pool.is_empty():pool=SHORE
	return pool[mini(pool.size()-1,int(clampf(roll,0,.99999)*pool.size()))]
static func add_shape(tool:SurfaceTool,shape:Mesh,transform:Transform3D,color:Color) -> void:
	var arrays:Array=shape.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in range(indices.size() if not indices.is_empty() else vertices.size()):
		var index:int=indices[i] if not indices.is_empty() else i
		tool.set_color(color);tool.set_normal((transform.basis.inverse().transposed()*normals[index]).normalized());tool.add_vertex(transform*vertices[index])
static func fin(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
	var normal:Vector3=(b-a).cross(c-a).normalized()
	for point:Vector3 in [a,b,c]:tool.set_color(color);tool.set_normal(normal);tool.add_vertex(point)
	for point:Vector3 in [c,b,a]:tool.set_color(color);tool.set_normal(-normal);tool.add_vertex(point)
static func create(id:String,world:Node3D) -> Node3D:
	var spec:Dictionary=DATA[id];var dimensions:Vector3=spec.body
	if not cache.has(id):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6
		add_shape(tool,sphere,Transform3D(Basis.IDENTITY.scaled(dimensions),Vector3.ZERO),Color(spec.color))
		var length:float=dimensions.z;var height:float=dimensions.y
		fin(tool,Vector3(0,height*.25,length*.2),Vector3(0,height*(1.5 if id=="billfish" else .9),-length*.1),Vector3(0,height*.2,-length*.36),Color(spec.fin))
		for side:float in [-1,1]:
			fin(tool,Vector3(side*dimensions.x*.35,0,length*.18),Vector3(side*dimensions.x*1.3,-height*.28,-length*.12),Vector3(side*dimensions.x*.3,-height*.15,-length*.25),Color(spec.fin))
			add_shape(tool,sphere,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.055),Vector3(side*dimensions.x*.43,height*.13,length*.28)),Color("182f3a"))
		if id=="billfish":
			var nose:=CylinderMesh.new();nose.top_radius=.003;nose.bottom_radius=.025;nose.height=.35;nose.radial_segments=6
			add_shape(tool,nose,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,length*.5+.12)),Color(spec.fin))
		if id in ["grouper","mackerel","tuna"]:
			for i in range(5):
				for side:float in [-1,1]:add_shape(tool,sphere,Transform3D(Basis.IDENTITY.scaled(Vector3(.012,.045,.035)),Vector3(side*dimensions.x*.48,.03,(i-2)*length*.12)),Color(spec.fin))
		cache[id]=tool.commit()
	var root:=Node3D.new();root.name="Fish_"+id;root.set_meta("fish_species",id)
	var body:=MeshInstance3D.new();body.mesh=cache[id];root.add_child(body)
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.65;body.material_override=material
	var tail:=Node3D.new();tail.name="Tail";tail.position.z=-dimensions.z*.43;root.add_child(tail)
	var tail_tool:=SurfaceTool.new();tail_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	fin(tail_tool,Vector3.ZERO,Vector3(0,dimensions.y*.65,-dimensions.z*.25),Vector3(0,-dimensions.y*.65,-dimensions.z*.25),Color(spec.fin))
	var tail_mesh:=MeshInstance3D.new();tail_mesh.mesh=tail_tool.commit();tail_mesh.material_override=material;tail.add_child(tail_mesh)
	return root
static func animate(fish:Node3D,time:float,fast:bool=false) -> void:
	var tail:Node3D=fish.get_node_or_null("Tail")
	if tail!=null:tail.rotation.y=sin(time*(13 if fast else 7))*(.45 if fast else .25)
