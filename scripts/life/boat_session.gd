extends RefCounted
## Transient net and docking actions. Rewards are committed only when hauling completes.
var app:Node
var phase:=""
var elapsed:=0.0
var soak:=0.0
var stopped:=false
var net:Node3D
var net_origin:=Vector3.ZERO
var cast_origin:=Vector3.ZERO
var dock_site:Dictionary={}
var dock_start:=Vector3.ZERO
var dock_heading:=0.0
func setup(owner_app:Node)->void:app=owner_app
func locked()->bool:return stopped or phase!=""
func busy()->bool:return phase!=""
func cast_or_haul()->void:
 if not app.movement_enabled() or not app.world.player.boating:return
 if phase=="soak":
  phase="haul";elapsed=0
  for index in range(1+int(soak/5)):
   var fish:Node3D=preload("res://scripts/life/fish_catalog.gd").create(preload("res://scripts/life/fish_catalog.gd").SHORE[index%5],app.world)
   net.add_child(fish);fish.position=Vector3((index%2)*.5-.25,.1,(index/2)*.25);fish.rotation.z=PI/2
  return
 if phase!="" or not app.world.player.rowing_pose.ready() or app.world.return_pilot.active:return
 if app.state.capacity()-app.state.load_count()<1:app.state.say("背包已满，先整理鱼获再撒网。");return
 phase="cast";elapsed=0;soak=0;stopped=true;app.sprinting=false;app.world.player.velocity=Vector3.ZERO
 var actor:Node3D=app.world.player
 net_origin=actor.position+Vector3(3.5,0,0).rotated(Vector3.UP,actor.boat_heading)
 net_origin.y=.18
 if not app.world.navigable_water(net_origin):
  reset();app.state.say("这侧离岸太近，请驶向开阔水面再撒网。");return
 cast_origin=actor.position+Vector3.UP*.85+Vector3(.3,0,0).rotated(Vector3.UP,actor.boat_heading)
 net=Node3D.new();net.name="CastFishingNet";app.world.add_child(net);net.position=cast_origin
 var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 for ring in range(1,5):
  var radius:float=ring*.6
  for i in range(32):
   var a:float=i*TAU/32;var b:float=(i+1)*TAU/32
   mesh.surface_add_vertex(Vector3(cos(a)*radius,-.04,sin(a)*radius));mesh.surface_add_vertex(Vector3(cos(b)*radius,-.04,sin(b)*radius))
 for i in range(16):
  var angle:float=i*TAU/16
  mesh.surface_add_vertex(Vector3.ZERO);mesh.surface_add_vertex(Vector3(cos(angle)*2.4,-.04,sin(angle)*2.4))
 mesh.surface_end()
 var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=app.world.material(Color("b9d1c5"));net.add_child(visual)
 for i in range(8):
  var angle:float=i*TAU/8
  app.world.box(net,Vector3(cos(angle)*2.4,.04,sin(angle)*2.4),Vector3(.16,.15,.16),app.world.material(Color("f0bc61")))
 net.scale=Vector3.ONE*.02
func toggle_stop()->void:
 if phase!="":return
 stopped=not stopped;app.sprinting=false;app.world.player.velocity=Vector3.ZERO
func dock()->void:
 if phase!="" or not app.world.player.boating:return
 var point:Dictionary=app.world.nearby_action()
 if point.get("kind") not in ["disembark","remote_land"]:return
 # 靠滩上岸：船本来就贴在岸边，不必再跑两秒靠泊轨迹，直接上岸。
 if point.get("kind")=="remote_land" and str(point.site.get("kind","pier"))=="beach":
  app._act(app._land_on_island.bind(point.site));return
 dock_site=point;dock_start=app.world.player.position;dock_heading=app.world.player.boat_heading
 phase="dock";elapsed=0;stopped=true;app.joystick.reset();app.sprint_action.reset();app.sprinting=false;app.world.return_pilot.cancel();app.world.player.velocity=Vector3.ZERO
func tick(delta:float)->void:
 if not app.world.player.boating:
  if phase!="" or stopped:reset()
  return
 if not app.movement_enabled():return
 if app.world.player.rowing_pose!=null:
  app.world.player.rowing_pose.net_phase=phase if phase in ["cast","soak","haul","recover"] else ""
  app.world.player.rowing_pose.net_time=elapsed
 elapsed+=delta
 if phase=="":return
 if phase=="dock":
  var target:Vector3=dock_site.site.berth if dock_site.kind=="remote_land" else app.world.MOORING
  var heading:float=dock_site.site.heading if dock_site.kind=="remote_land" else 0.0
  var t:float=smoothstep(0,2.0,elapsed)
  var next:Vector3=dock_start.lerp(target,t)
  var turn:float=lerp_angle(dock_heading,heading,t)
  if not app.world.navigable_water(next) or not app.world.boat_heading_is_clear(next,turn):
   reset();app.state.say("码头前有障碍，请调整船的位置后再靠岸。");return
  var actor:CharacterBody3D=app.world.player
  actor.position=next;actor.boat_heading=turn;actor.velocity=Vector3.ZERO
  actor.hull_collider.rotation.y=turn;actor.boat_visual.rotation.y=turn;actor.visual.rotation.y=turn+PI
  if elapsed>=2:
   var point:Dictionary=dock_site;reset()
   if point.kind=="remote_land":app._act(app._land_on_island.bind(point.site))
   else:
    app._act(app.world.disembark_boat);app.joystick.reset();app.sprint_action.reset()
  return
 if phase=="cast":
  var throw_time:float=smoothstep(.6,2.1,elapsed)
  net.position=cast_origin.lerp(net_origin,throw_time)+Vector3.UP*sin(throw_time*PI)*.8
  net.scale=Vector3.ONE*lerpf(.02,1,smoothstep(.6,2.1,elapsed))
  if elapsed>=2.4:phase="soak";elapsed=0
 elif phase=="soak":soak=minf(soak+delta,20)
 elif phase=="haul":
  net.position=net_origin.lerp(app.world.player.position+Vector3.UP*.4,smoothstep(0,3,elapsed))
  net.scale=Vector3.ONE*lerpf(1,.12,smoothstep(0,3,elapsed))
  if elapsed>=3.2:
   var quantity:int=mini(1+int(soak/5),app.state.capacity()-app.state.load_count())
   if quantity>0:app.state.exchange({}, {"鱼":quantity});app.state.log_event("收网完成，鱼获入船：鱼 ×%d。"%quantity)
   else:app.state.log_event("背包已满，已将鱼放回海中。")
   if is_instance_valid(net):net.queue_free()
   net=null;phase="recover";elapsed=0;app._save(false)
 elif phase=="recover" and elapsed>=1.0:reset()
func title()->String:
 match phase:
  "cast":return "撒网中"
  "soak":return "收网"
  "haul":return "收网中"
  "dock":return "靠岸中"
  "recover":return "拿起船桨"
 return "撒网"
func reset()->void:
 phase="";elapsed=0;soak=0;stopped=false;dock_site={}
 if app!=null and app.world.player.rowing_pose!=null:app.world.player.rowing_pose.net_phase=""
 if is_instance_valid(net):net.queue_free()
 net=null
