extends Node3D
var lights:Array[Light3D]=[]
var shades:Array[StandardMaterial3D]=[]
var world:Node3D
var night:float=0
func setup(owner_world:Node3D) -> void:
	world=owner_world;name="ShoreLights";world.shore_lights=self
	for point:Vector3 in [Vector3(-.45,.65,7),Vector3(-.45,.65,10.5),Vector3(3.8,.65,13),Vector3(3.8,.65,17.5)]:lamp(point,.8,false)
	lamp(Vector3(2.0,.65,5.3),2.5,true)
	# 这盏高灯原来正好顶在钓鱼机位的视线里，坐下钓鱼时屏幕右下会怼上一个巨大的黄色灯罩。
	lamp(Vector3(-3.45,.65,12.3),2.6,true)
	var work:=SpotLight3D.new();work.name="FishingWorkLight";work.light_color=Color("ffe7bb");work.spot_range=8;work.spot_angle=55;work.shadow_enabled=false
	add_child(work);work.position=Vector3(-2.65,2.7,15.5);work.look_at(Vector3(-1,.3,18.5));lights.append(work)
	world.box(self,Vector3(-2.85,1.7,15.5),Vector3(.09,2.1,.09),world.material(Color("486269")))
	world.box(self,work.position,Vector3(.28,.16,.24),world.material(Color("e8d4ab")))
func lamp(point:Vector3,height:float,real_light:bool) -> void:
	world.box(self,point+Vector3.UP*height*.5,Vector3(.09,height,.09),world.material(Color("486269")))
	world._solid(point+Vector3.UP*height*.5,Vector3(.09,height,.09))
	var material:StandardMaterial3D=world.material(Color("ffe4ad"));material.emission_enabled=true;material.emission=Color("ffcb80").srgb_to_linear();shades.append(material)
	# 灯罩缩小一点并补上碰撞体：以前没有碰撞体，镜头抬高时会直接钻进灯罩里，
	# 屏幕上就是一整块「巨大的黄色方块」。
	world.box(self,point+Vector3.UP*height,Vector3(.19,.2,.19),material)
	world._solid(point+Vector3.UP*height,Vector3(.19,.2,.19))
	if real_light:
		var light:=OmniLight3D.new();light.name="ShoreLamp";light.omni_range=7;light.light_color=Color("ffdda4");light.shadow_enabled=false;light.position=point+Vector3.UP*height;add_child(light);lights.append(light)
func sync(state:RefCounted) -> void:
	night=1-smoothstep(.12,.5,state.daylight())
	visible=state.location=="island"
	world.water_shader.set_shader_parameter("dock_light_strength",night if visible else 0.0)
	for lamp:Light3D in lights:lamp.light_energy=night*(1.8 if lamp is SpotLight3D else 1.2)
	for material:StandardMaterial3D in shades:material.emission_energy_multiplier=night*1.8
