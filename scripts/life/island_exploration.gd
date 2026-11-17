extends RefCounted
## Connects horizon terrain to the same playable sea, preserving a safe shore/boat pair.
const SEA_RADIUS:=600.0
const NAMES:={"twin_hills":"双丘林岛","crescent_bay":"弯月沙湾","rocky_reef":"礁岩小岛","forest_cape":"长岬林岛"}
var world:Node3D
var active_island:Node3D
var sites:Dictionary={}
var dry_cache:Dictionary={}
var cached_position:=Vector3.INF
var cached_landing:Dictionary={}
func setup(owner_world:Node3D) -> void:
 world=owner_world

func find(id:String) -> Node3D:
 for island:Node3D in world.seascape.islands:
  if island.spec.id==id:return island
 return null
func land_height(p:Vector3) -> float:
 var highest:float=-INF
 for island:Node3D in world.seascape.islands:
  if Vector2(p.x-island.position.x,p.z-island.position.z).length()>maxf(island.spec.radii.x,island.spec.radii.y)*1.5:continue
  var local:Vector3=island.to_local(p);var height:float=island.surface_height_at(Vector2(local.x,local.z))
  if is_finite(height):highest=maxf(highest,height+island.global_position.y)
 return highest
func mesh_ground(island:Node3D, at:Vector3) -> float:
 # 解析高度和实际网格能差 0.3 米，落地/桥脚一律用撞到岛体的射线，脚下才是看得见的那层地。
 var from:Vector3=at+Vector3(0,40,0)
 var to:Vector3=at+Vector3(0,-12,0)
 var query:=PhysicsRayQueryParameters3D.create(from,to,17)
 var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
 if hit:return float(hit.position.y)
 var local:Vector3=island.to_local(at)
 var fallback:float=island.surface_height_at(Vector2(local.x,local.z))
 return fallback if is_finite(fallback) else at.y
func island_at(p:Vector3) -> Node3D:
 for island:Node3D in world.seascape.islands:
  if Vector2(p.x-island.position.x,p.z-island.position.z).length()>maxf(island.spec.radii.x,island.spec.radii.y)*1.5:continue
  var local:Vector3=island.to_local(p);var h:float=island.surface_height_at(Vector2(local.x,local.z))
  if is_finite(h) and h>.12:return island
 return null
func walkable(p:Vector3) -> bool:
 var h:float=land_height(p)
 if not is_finite(h) or h<.12:return false
 for offset:Vector3 in [Vector3(.4,0,0),Vector3(-.4,0,0),Vector3(0,0,.4),Vector3(0,0,-.4)]:
  var next:float=land_height(p+offset)
  if not is_finite(next) or absf(next-h)>.4:return false
 return true
func standable(p:Vector3) -> bool:
 # 岛上能不能站：只要求是这座岛的干地；陡坡交给真实碰撞体去挡，不再用解析坡度把整片山坡判成禁区。
 var h:float=land_height(p)
 return is_finite(h) and h>=.10
func activate(island:Node3D) -> void:
 if active_island==island:return
 if is_instance_valid(active_island):active_island.set_explorable(false)
 active_island=island
 if active_island!=null:active_island.set_explorable(true)
func sync(state:RefCounted) -> void:
 for entry:Node3D in world.seascape.islands:_sites(entry)
 var island:Node3D=island_at(world.player.position) if state.location=="island" and not world.player.boating else null
 activate(island)
 if state.location=="island" and not state.island_visit.is_empty() and not world.player.boating:
  var expected:Node3D=find(state.island_visit.id)
  var valid:bool=expected!=null and island==expected and island_at(vector(state.island_visit.landing))==expected and world.navigable_water(vector(state.island_visit.berth))
  if not valid:
   state.island_visit={};world.player.position=world.DOCK;state.player_position=array(world.DOCK);activate(null)
   if world.companion!=null:world.companion.recover()
   state.log_event("停船位置不可用，已安全回到主岛码头。")
 position_parked_boat(state)
func position_parked_boat(state:RefCounted) -> void:
 if not is_instance_valid(world.own_boat):return
 var berth:Vector3=world.MOORING;var angle:=0.0
 if not state.island_visit.is_empty():berth=vector(state.island_visit.berth);angle=float(state.island_visit.heading)
 world.own_boat.position=berth-Vector3.UP*.62;world.own_boat.rotation=Vector3(0,angle,0);world.own_boat.visible=not world.player.boating
static func vector(value:Array) -> Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
static func array(value:Vector3) -> Array:return [value.x,value.y,value.z]
func _dry_vertices(island:Node3D) -> Array:
 var id:String=island.spec.id
 if dry_cache.has(id):return dry_cache[id]
 var pool:Array=[]
 var terrain:MeshInstance3D=island.get_node_or_null("NaturalIslandTerrain")
 if terrain!=null and terrain.mesh!=null:
  for surface in range(terrain.mesh.get_surface_count()):
   var arrays:Array=terrain.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for vertex:Vector3 in vertices:
    if vertex.y>=.17 and vertex.y<=.72:pool.append(vertex)
 dry_cache[id]=pool
 return pool
func _sites(island:Node3D) -> Array:
 var id:String=island.spec.id
 if sites.has(id):return sites[id]
 var candidates:Array=[]
 # 统一码头方位：主岛的木码头在岛的南侧，所有远岛也把码头放在同一方位附近（±36°），
 # 这样每座岛的登岛口都长在同一个位置、朝向一致，玩家不用每座岛重新找码头。
 var preferred:float=PI/2.0
 var angles:Array=[]
 for index in range(9):angles.append(preferred+float(index-4)*deg_to_rad(9.0))
 for index in range(48):angles.append(index*TAU/48)
 for angle:float in angles:
  var direction:=Vector2(cos(angle),sin(angle))
  var coast:float=island.shoreline(angle)
  var land:=Vector3.INF
  # 沿这个方向从内往外走，找这条射线上最后一块干沙（height_at 与岛体网格同源，取到的点一定在地形上）。
  var best_ratio:float=-1.0
  var best_height:float=0.0
  for step in range(120):
   var ratio:float=.50+step*.005
   var flat:Vector2=direction*island.spec.radii*(coast*ratio)
   var height:float=island.height_at(flat)
   if not is_finite(height):break
   if height<.17:break
   best_ratio=ratio;best_height=height
  if best_ratio<0.0:continue
  # 从水线往回退约 1.8 米，落在干沙上，栈桥才有沙滩可压。
  var inland:float=maxf(.0,best_ratio-.045)
  var flat:Vector2=direction*island.spec.radii*(coast*inland)
  var height:float=island.height_at(flat)
  if not is_finite(height) or height<.15:continue
  var at:Vector3=island.to_global(Vector3(flat.x,height,flat.y))
  at.y=land_height(at)+.03
  # 必须能被 island_at 认成这座岛的干地，且身边没有树石（否则落地会被碰撞推开半米）。
  if walkable(at) and island_at(at)==island:
   var lp:Vector3=island.to_local(at)
   var blocked:=false
   for item:Vector3 in island.tree_positions:
    if Vector2(item.x-lp.x,item.z-lp.z).length()<1.7:blocked=true;break
   if not blocked:
    for item:Transform3D in island.rock_instances:
     if Vector2(item.origin.x-lp.x,item.origin.z-lp.z).length()<1.9:blocked=true;break
   if not blocked:land=at
  if not land.is_finite():continue
  var outward:Vector3=(land-island.global_position);outward.y=0;outward=outward.normalized()
  var heading:float=atan2(outward.x,outward.z)
  var beach:Vector3=land
  # 桥脚要顶到草地边上，不能悬在水面上：从沙滩点往内陆找连续 3 米的岛面平台（>=1.0）。
  var inward:Vector3=-outward
  var shore:Vector3=beach-outward*4.0
  for step in range(0,18):
   var base:Vector3=beach+inward*float(step)
   var solid:=true
   for ahead in range(3):
    var probe:Vector3=beach+inward*float(step+ahead)
    var lp2:Vector3=island.to_local(probe)
    var h2:float=island.surface_height_at(Vector2(lp2.x,lp2.z))
    if not is_finite(h2) or h2<1.0:solid=false;break
   if solid:shore=base;break
  # 甲板从 shore 往内陆铺 4 米，落点再往内挪，人才会站在桥后的干沙/草地而不是桥板上。
  shore.y=mesh_ground(island,shore)
  var standing:Vector3=shore
  for offset:float in [5.4,4.6,3.8,3.0,2.2,1.6]:
   var candidate:Vector3=shore+inward*offset
   var lp3:Vector3=island.to_local(candidate)
   candidate.y=mesh_ground(island,candidate)+.06
   var clear:=walkable(candidate) and island_at(candidate)==island
   if clear:
    for item:Vector3 in island.tree_positions:
     if Vector2(item.x-lp3.x,item.z-lp3.z).length()<3.2:clear=false;break
   if clear:
    for item:Transform3D in island.rock_instances:
     if Vector2(item.origin.x-lp3.x,item.origin.z-lp3.z).length()<3.4:clear=false;break
   if clear:standing=candidate;break
  land=standing
  # 泊位跟着桥尾走：桥 14 米，泊位在桥尾外 1 米起找深水。
  for step in range(24):
   var middle:Vector3=shore+outward*(13.5+step*.5);middle.y=.05
   if not world.navigable_water(middle) or not world.boat_heading_is_clear(middle,heading):continue
   var water:Vector3=middle
   # 给这块岸打分：周围干沙越多、离主岛越近越好，避免挑到水里孤立的小沙包。
   var dry:float=0.0
   var local_land:Vector3=island.to_local(beach)
   for gap:float in [1.6,3.2]:
    for probe in range(12):
     var a:float=probe*TAU/12
     var h:float=island.surface_height_at(Vector2(local_land.x+cos(a)*gap,local_land.z+sin(a)*gap))
     if is_finite(h) and h>=.12:dry+=1.0
   candidates.append({"id":id,"land":land,"shore":shore,"beach":beach,"berth":water,"heading":heading,"dry":dry,"preferred":absf(angle_difference(angle,preferred))<deg_to_rad(37.0)});break
 # One permanent harbour: 优先岸上干沙连续的地方（水里的孤立沙包不算），再比离主岛远近。
 candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
  # 同一个方位的候选优先：所有远岛的码头都落在岛的南侧，和主岛一致。
  if bool(a.get("preferred",false))!=bool(b.get("preferred",false)):return bool(a.get("preferred",false))
  if absf(float(a.dry)-float(b.dry))>1.0:return float(a.dry)>float(b.dry)
  return a.berth.length_squared()<b.berth.length_squared())
 if not candidates.is_empty():
  candidates=[candidates[0]]
  _build_dock(candidates[0])
 sites[id]=candidates
 return candidates
func landing_candidate() -> Dictionary:
 if world.player==null or not world.player.boating:return {}
 var position:Vector3=world.player.position
 for island:Node3D in world.seascape.islands:
  for site:Dictionary in _sites(island):
   # 泊位在桥尾外侧 15 米，登岛提示放宽到 12 米，让船在港区范围内就能触发（真正的落点判定仍在 land()）。
   if Vector2(position.x-site.berth.x,position.z-site.berth.z).length()<=12.0:return site
  # 码头之外也能直接靠滩：船贴到干沙 5 米内就允许上岸，不用非得开到桥尾。
  var beach:=_beach_site(island,position)
  if not beach.is_empty():return beach
 return {}
## 就近找一块能站的干沙：以船所在方位为中心左右扫一圈，落点必须高于水线、可站、且离船不超过 5.4 米。
var _beach_probe:Dictionary={}
func _beach_site(island:Node3D, boat:Vector3) -> Dictionary:
 var key:String=island.spec.id
 var now:int=Time.get_ticks_msec()
 if _beach_probe.has(key):
  var entry:Dictionary=_beach_probe[key]
  if now-int(entry.t)<250 and (entry.pos as Vector3).distance_to(boat)<1.5:return entry.site
 var site:Dictionary=_probe_beach(island,boat)
 _beach_probe[key]={"t":now,"pos":boat,"site":site}
 return site
func _probe_beach(island:Node3D, boat:Vector3) -> Dictionary:
 var local:Vector3=island.to_local(boat)
 var reach:float=maxf(island.spec.radii.x,island.spec.radii.y)
 if Vector2(local.x,local.z).length()>reach+9.0:return {}
 var bearing:=atan2(local.x,local.z)
 for sweep in range(-4,5):
  var angle:float=bearing+float(sweep)*deg_to_rad(9.0)
  var direction:=Vector2(sin(angle),cos(angle))
  var coast:float=island.shoreline(angle)
  var best_ratio:float=-1.0
  for step in range(70):
   var ratio:float=.55+step*.006
   var flat:Vector2=direction*island.spec.radii*(coast*ratio)
   var height:float=island.height_at(flat)
   if not is_finite(height):break
   if height<.17:break
   best_ratio=ratio
  if best_ratio<0.0:continue
  var point2:Vector2=direction*island.spec.radii*(coast*maxf(0.0,best_ratio-.05))
  var h:float=island.height_at(point2)
  if not is_finite(h) or h<.15:continue
  var at:Vector3=island.to_global(Vector3(point2.x,h,point2.y))
  at.y=land_height(at)+.03
  if not walkable(at) or island_at(at)!=island:continue
  if Vector2(boat.x-at.x,boat.z-at.z).length()>5.4:continue
  var lp:Vector3=island.to_local(at)
  var blocked:=false
  for item:Vector3 in island.tree_positions:
   if Vector2(item.x-lp.x,item.z-lp.z).length()<1.7:blocked=true;break
  if blocked:continue
  return {"id":island.spec.id,"kind":"beach","land":at,"shore":at,"beach":at,"berth":boat,"heading":atan2(boat.x-at.x,boat.z-at.z),"dry":1.0}
 return {}

func _build_dock(site:Dictionary) -> void:
 # 和主岛一模一样：同一个 build_pier 构件（三块甲板 + 四排立柱 + 走人碰撞），只是摆放的位置随岛走。
 var dock:=Node3D.new();dock.name="IslandDock_"+str(site.id);world.seascape.add_child(dock)
 var outward:Vector3=(site.berth-site.land);outward.y=0;outward=outward.normalized()
 var heading:float=atan2(outward.x,outward.z)
 var shore:Vector3=site.get("shore",site.land-outward*2.0)
 # 桥面高度必须贴着这块岛的实地，否则沙滩高一米、桥就埋进沙里（看起来像被水淹了）。
 var island_node:Node3D=find(str(site.id))
 shore.y=maxf(.35,(mesh_ground(island_node,shore) if island_node!=null else shore.y)+.02)
 world.build_pier(dock,shore,heading,world.material(Color("b68b57")))
 var label:=Label3D.new();label.text=NAMES[site.id]+" · 码头";label.font_size=48;label.pixel_size=.018
 label.position=site.berth+outward*1.2+Vector3.UP*1.7;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;dock.add_child(label)
 var marker:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.8;ring.outer_radius=1.0;marker.mesh=ring
 marker.material_override=world.material(Color("e5c87c"));marker.position=Vector3(site.berth.x,0.02,site.berth.z);dock.add_child(marker)
func land(site:Dictionary) -> bool:
 if not world.player.boating or site.is_empty():return false
 var island:Node3D=find(site.id)
 if island==null:return false
 if str(site.get("kind","pier"))=="beach":
  # 靠滩：船已经贴到岸边 4.6 米内、并且基本停稳，就可以直接上岸。
  if world.player.position.distance_to(site.berth)>4.6 or world.player.velocity.length()>1.2:return false
 else:
  var fixed:Array=_sites(island)
  if fixed.is_empty() or site.berth.distance_to(fixed[0].berth)>.05 or world.player.position.distance_to(site.berth)>4.6 or world.player.velocity.length()>1.2:return false
 var state:RefCounted=world.navigation_state
 state.island_visit={"id":site.id,"landing":array(site.land),"berth":array(site.berth),"heading":site.heading}
 world._set_boating(false);activate(island)
 world.player.position=site.land;world.player.velocity=Vector3.ZERO;world.player.move_input=Vector2.ZERO;world.player.manual_world_direction=Vector3.INF
 world.player.visual.rotation.y=atan2(island.position.x-site.land.x,island.position.z-site.land.z)
 state.player_position=array(site.land);position_parked_boat(state);world.walk_camera.reset()
 world.orbit.room_key="";world.orbit.pivot=Vector3.INF
 if world.companion!=null:world.companion.recover()
 state.log_event("登上"+NAMES[site.id]+"。可自由探索，点击「返回船上」随时回到停船处。")
 cached_position=Vector3.INF
 return true
func return_to_boat() -> bool:
 var state:RefCounted=world.navigation_state
 if state.location!="island" or state.island_visit.is_empty() or world.player.boating:return false
 var visit:Dictionary=state.island_visit
 var berth:Vector3=vector(visit.berth)
 if not world.navigable_water(berth) or not world.boat_heading_is_clear(berth,float(visit.heading)):return state.say("停船处暂有障碍，请稍等后再上船。")
 world.player.cancel_pet();world.player.cancel_work()
 activate(null);world._set_boating(true)
 world.player.position=berth;world.player.boat_heading=float(visit.heading);world.player.hull_collider.rotation.y=world.player.boat_heading
 world.player.visual.rotation.y=world.player.boat_heading+PI;world.player.boat_visual.rotation.y=world.player.boat_heading
 if world.player.rowing_pose!=null:
  world.player.rowing_pose.start_yaw=world.player.boat_heading+PI;world.player.rowing_pose.tick(0,0)
 world.player.move_input=Vector2.ZERO;world.player.manual_world_direction=Vector3.INF;world.walk_camera.reset()
 world.orbit.room_key="";world.orbit.pivot=Vector3.INF
 state.log_event("已回到自己的船上，坐稳取桨后可继续航行或返航主岛。")
 cached_position=Vector3.INF
 return true
func view_landmark(p:Vector3) -> Vector3:
 var island:Node3D=island_at(p)
 return island.global_position if island!=null else world.Villa.ENTRY
