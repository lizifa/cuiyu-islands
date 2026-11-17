extends Node3D
const Catalog=preload("res://scripts/life/fish_catalog.gd")
const REST:=Vector3(-1.15,.88,18.35)
var mouth:=REST
var rings:Array[MeshInstance3D]=[]
var body:MeshInstance3D
var label:Label3D
var world:Node3D
var shown_key:int=-1
var catch_visuals:Array[Node3D]=[]
func setup(owner_world:Node3D) -> void:
	world=owner_world;name="FishKeepNet";world.fish_keeper=self
	var material:StandardMaterial3D=world.material(Color("78a7ad55"));material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	body=MeshInstance3D.new();body.material_override=material;add_child(body)
	for i in range(5):
		var ring:=TorusMesh.new();ring.inner_radius=.34;ring.outer_radius=.37;ring.rings=16;ring.ring_segments=6
		var mesh:=MeshInstance3D.new();mesh.name="KeepNetRing";mesh.mesh=ring;mesh.material_override=world.material(Color("6e9690"));add_child(mesh);rings.append(mesh)
	label=Label3D.new();label.name="KeepNetCount";label.font=load("res://assets/fonts/NotoSansSC.ttf");label.font_size=32;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)
	redraw()
func centers() -> Array[Vector3]:
	return [mouth,Vector3(-1.15,maxf(.73,mouth.y*.6),18.22),Vector3(-1.15,.15,18.6),Vector3(-1.15,-.4,18.6),Vector3(-1.15,-.95,18.6)]
func point_at(t:float) -> Vector3:
	var points:Array[Vector3]=centers();var value:float=clampf(t,0,.999)*4;var index:int=int(value)
	return points[index].lerp(points[index+1],fmod(value,1))
func set_mouth(point:Vector3) -> void:
	if mouth.distance_to(point)<.001:return
	mouth=point;redraw()
func redraw() -> void:
	var points:Array[Vector3]=centers();var geometry:=ImmediateMesh.new();geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(5):rings[i].position=points[i]
	for level in range(4):
		for i in range(16):
			var a:=Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*.35;var b:=Vector3(cos((i+1)*TAU/16),0,sin((i+1)*TAU/16))*.35
			for point:Vector3 in [points[level]+a,points[level]+b,points[level+1]+b,points[level]+a,points[level+1]+b,points[level+1]+a]:geometry.surface_add_vertex(point)
	geometry.surface_end();body.mesh=geometry
func sync(state:RefCounted) -> void:
	visible=world.player!=null and not world.player.fishing_stage.is_empty()
	label.position=mouth+Vector3.UP*.45;label.text="鱼护 · %d 条"%state.fish_keep.size();label.visible=not world.orbit.first_person and world.player.position.distance_to(REST)<8
	var key:int=hash(state.fish_keep)
	if key==shown_key:return
	shown_key=key
	for fish:Node3D in catch_visuals:fish.queue_free()
	catch_visuals.clear()
	for i in range(mini(3,state.fish_keep.size())):
		var fish:Node3D=Catalog.create(state.fish_keep[i].species,world);fish.scale=Vector3.ONE*.25;fish.position=Vector3(-1.15,-.22-i*.2,18.6);fish.rotation.y=i*2.1;add_child(fish);catch_visuals.append(fish)
