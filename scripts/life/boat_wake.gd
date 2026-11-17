extends Node3D
## Bounded world-space foam pool: emission follows real travelled distance, not input.
const LIMIT:=96
const LIFE:=3.2
var world:Node3D
var foam:MultiMeshInstance3D
var particles:Array[Dictionary]=[]
var last_position:=Vector3.INF
var last_stern:=Vector3.INF
var last_yaw:=0.0
var distance_bank:=0.0
var next_slot:=0
var emission_count:=0
var boost:=0.0
var boost_events:=0
var boost_spray:GPUParticles3D
var boost_clock:=0.0
func setup(owner_world:Node3D) -> void:
 world=owner_world;name="BoatWake"
 foam=MultiMeshInstance3D.new();foam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(foam)
 var mesh:=PlaneMesh.new();mesh.size=Vector2.ONE
 var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/boat_foam.gdshader");mat.render_priority=2;mesh.material=mat
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=mesh;multi.instance_count=LIMIT;multi.custom_aabb=AABB(Vector3(-90,-2,-90),Vector3(180,5,180));foam.multimesh=multi
 for i in range(LIMIT):particles.append({"age":LIFE});multi.set_instance_color(i,Color(1,1,1,0));multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
 _build_boost_spray()
func _build_boost_spray() -> void:
 boost_spray=GPUParticles3D.new();boost_spray.name="SternSpray"
 boost_spray.amount=96;boost_spray.lifetime=1.15;boost_spray.emitting=false
 boost_spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(boost_spray)
 var process:=ParticleProcessMaterial.new()
 process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
 process.emission_box_extents=Vector3(.75,.10,.45)
 process.direction=Vector3(0,1.35,-1);process.spread=38
 process.initial_velocity_min=3.2;process.initial_velocity_max=6.4
 process.gravity=Vector3(0,-6.0,0)
 process.scale_min=.7;process.scale_max=1.9
 boost_spray.process_material=process
 var drop:=SphereMesh.new();drop.radius=.06;drop.height=.12;drop.radial_segments=6;drop.rings=3
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(0.86,0.95,0.94,0.9)
 drop.material=mat;boost_spray.draw_pass_1=drop
func burst(at:Vector3,strength:float) -> void:
 # 外部冲击（鲨鱼撞船等）也掀起一片白浪。
 for i in range(6):
  var dir:=Vector3(randf_range(-1,1),0,randf_range(-1,1))
  if dir.length()<.01:dir=Vector3.FORWARD
  _emit(at-dir.normalized()*.35,dir.normalized(),strength,1.2)
 boost_events+=1
func clear() -> void:
 last_position=Vector3.INF;last_stern=Vector3.INF;distance_bank=0
 if not foam.visible:return
 foam.visible=false
 for i in range(LIMIT):particles[i].age=LIFE;foam.multimesh.set_instance_color(i,Color(1,1,1,0))
func _physics_process(delta:float) -> void:
 if world==null or world.player==null or world.navigation_state==null:return
 if world.navigation_state.location!="island":clear();return
 if not world.player.allowed:return
 if not world.player.boating and not foam.visible:last_position=Vector3.INF;last_stern=Vector3.INF;return
 tick(delta,world.player.position,world.player.boating,world.player.boat_heading)
func tick(delta:float,at:Vector3,boating:bool,hull_yaw:float=NAN) -> void:
 if delta<=0:return
 var motion:Vector3=at-last_position if last_position.is_finite() else Vector3.ZERO;motion.y=0
 var travelled:float=motion.length()
 var angle:float=hull_yaw if is_finite(hull_yaw) else (atan2(motion.x,motion.z) if travelled>.001 else last_yaw)
 var heading:=Vector3(sin(angle),0,cos(angle))
 var stern:Vector3=at-heading*1.45
 var wake_speed:=0.0
 if boating and last_stern.is_finite() and travelled>.001 and travelled<2.0:
  # Sideways motion during a hull turn is not forward propulsion. Avoid fans
  # and reverse jets while the visible boat catches up with the input heading.
  var alignment:float=maxf(0,motion.normalized().dot(heading))
  var forward_distance:float=travelled*alignment
  var speed:float=forward_distance/delta
  wake_speed=speed
  if alignment>.25 and speed>.15:
   distance_bank+=forward_distance
   var spacing:float=lerpf(.42,.24,clampf((speed-3)/4,0,1))
   while distance_bank>=spacing:
    distance_bank-=spacing
    var fraction:float=clampf(1-distance_bank/maxf(forward_distance,.001),0,1)
    var center:Vector3=last_stern.lerp(stern,fraction)
    var emission_yaw:float=lerp_angle(last_yaw,angle,fraction)
    var emission_direction:=Vector3(sin(emission_yaw),0,cos(emission_yaw))
    _emit(center,emission_direction,speed)
  else:distance_bank=0
 else:distance_bank=0
 var target_boost:float=0.0
 if boating and wake_speed>4.8:target_boost=clampf((wake_speed-4.8)/2.2,0,1)
 boost=move_toward(boost,target_boost,delta*(3.0 if target_boost>boost else 2.0))
 if target_boost>0.0:
  boost_clock-=delta
  if boost_clock<=0.0:
   boost_clock=.085
   _emit(stern,heading,wake_speed,1.0+boost*1.4)
   boost_events+=1
 if is_instance_valid(boost_spray):
  boost_spray.emitting=boost>0.12
  boost_spray.amount_ratio=clampf(boost,.18,1.0)
  boost_spray.position=stern+Vector3.UP*.10
 if boating:foam.multimesh.custom_aabb=AABB(Vector3(at.x-40,-2,at.z-40),Vector3(80,5,80))
 last_position=at if boating else Vector3.INF
 last_stern=stern if boating else Vector3.INF;last_yaw=angle
 var alive:=0
 for i in range(LIMIT):
  var p:Dictionary=particles[i]
  if p.age>=LIFE:continue
  p.age+=delta
  if p.age<LIFE:alive+=1
  var age:float=clampf(p.age/LIFE,0,1)
  foam.multimesh.set_instance_transform(i,_foam_transform(p))
  var alpha:float=(1-age)*(1-age)*clampf((.28+p.speed*.055)*(1.0+p.get("wash",0.0)*.5),0,.9)
  foam.multimesh.set_instance_color(i,Color(1,1,1,alpha))
 foam.visible=alive>0
func _emit(center:Vector3,heading:Vector3,speed:float,wash:float=0.0) -> void:
 particles[next_slot]={"age":0.0,"center":center,"forward":heading,"speed":speed,"wash":wash}
 next_slot=(next_slot+1)%LIMIT;emission_count+=1

func _foam_transform(p:Dictionary) -> Transform3D:
 var wash:float=p.get("wash",0.0)
 var width:float=(.38+p.speed*.04)*(1.0+wash*.9)
 var length:float=(2.1+p.speed*.18)*(1.0+wash*.5)
 var point:Vector3=p.center;point.y=-.225
 var basis:=Basis(Vector3.UP,atan2(p.forward.x,p.forward.z))*Basis.from_scale(Vector3(width,1,length))
 return Transform3D(basis,point)
