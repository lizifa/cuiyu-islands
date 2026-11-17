extends Node3D
const POINT := Vector3(-1,0.68,16.1)
const SEAT := Vector3(-1,.68,16.45)
const FLOAT := Vector3(-1,-0.16,36.1)
static func within_reach(point:Vector3) -> bool:
	return point.x>=-3.4 and point.x<=2.65 and point.z>=12.6 and point.z<=18.4 and absf(point.y-.68)<1.2
func setup(world: Node3D) -> void:
	name = "ShoreFishingPlatform"
	var lighting=preload("res://scripts/life/shore_lights.gd").new();add_child(lighting);lighting.setup(world)
	var wood: Material = world.material(Color("987149"))
	var dark: Material = world.material(Color("5b4939"))
	world.box(self,Vector3(0,0.5,15.5),Vector3(6,0.3,5),wood)
	world._solid(Vector3(0,0.5,15.5),Vector3(6,0.3,5))
	var seams := MultiMeshInstance3D.new()
	var seam_instances := MultiMesh.new()
	seam_instances.transform_format=MultiMesh.TRANSFORM_3D
	var seam_mesh := BoxMesh.new()
	seam_mesh.size=Vector3(.015,.012,5)
	seam_mesh.material=dark
	seam_instances.mesh=seam_mesh
	seam_instances.instance_count=30
	for i in range(30): seam_instances.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3((i-14.5)*.2,.66,15.5)))
	seams.multimesh=seam_instances
	add_child(seams)
	for x in [-2.85,2.85]:
		for z in [13.2,17.8]:
			world.box(self,Vector3(x,-.15,z),Vector3(.2,1.6,.2),dark)
			world.box(self,Vector3(x,1.15,z),Vector3(.12,1,.12),wood)
	# Rails keep the sea edge solid; fishing opening faces open water.
	for data: Array in [[Vector3(-2.85,1.25,15.5),Vector3(.1,.15,4.8)], [Vector3(1.225,1.25,17.85),Vector3(3.25,.15,.1)], [Vector3(-2.4,1.25,17.85),Vector3(.9,.15,.1)], [Vector3(2.85,1.25,17.7),Vector3(.1,.15,.3)]]:
		world.box(self,data[0],data[1],wood)
		world._solid(data[0],data[1])
	# One stool marks the fishing position; equipment appears only while in use.
	preload("res://scripts/life/fishing_gear.gd").setup(world,self,SEAT)
	world.fishing_sign=null
