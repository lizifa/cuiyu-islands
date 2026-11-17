extends Node
## One movement owner; commands execute once after physical approach and smooth facing.
var app: Node
var active := false
var executing := false
var stage := ""
var point: Dictionary = {}
var anchor: Marker3D
var path: Array[Vector3] = []
var stand := Vector3.ZERO
var target := Vector3.ZERO
var callback := Callable()
var context := ""
var stalled := 0.0
var previous := Vector3.ZERO
var before_view: Dictionary = {}
var camera_revision := -1
var task_revision := -1
var task_view_key := ""
var body_query: PhysicsShapeQueryParameters3D
var tree_query: PhysicsShapeQueryParameters3D
func view_snapshot() -> Dictionary:
 var orbit: Node=app.world.orbit
 return {"yaw":orbit.target_yaw,"pitch":orbit.target_pitch,"distance":orbit.target_distance if orbit.target_distance>0 else orbit.distance}
func context_key() -> String:
 return "%s:%d:%s:%s"%[app.state.location,app.state.home_floor,str(app.state.profile),str(app.state.buildings)]
func cancel(message: String="") -> void:
 if is_instance_valid(app.world.companion):app.world.companion.release_interaction()
 if active and app.world.player.working:app.world.player.cancel_work()
 active=false;stage="";path.clear();callback=Callable()
 if not message.is_empty():app.state.say(message)
func request(value: Dictionary, action: Callable) -> bool:
 if active:return false
 if app.world.player.boating or not is_instance_valid(value.get("anchor")):return false
 if not app.world.player.fishing_stage.is_empty() or app.world.player.sofa_seated:return false
 app.auto_task.stop("")
 if not app.world.player.pet_stage.is_empty():app.world.player.cancel_pet()
 path.clear()
 point=value.duplicate();anchor=value.anchor;callback=action
 context=context_key();camera_revision=app.world.orbit.manual_revision
 before_view=view_snapshot();target=anchor.facing.global_position
 if point.kind=="shore_fish" and is_instance_valid(app.world.companion):
  _prepare_queries()
  var saved_excludes:Array[RID]=body_query.exclude.duplicate()
  var clearance_excludes:Array[RID]=saved_excludes.duplicate();clearance_excludes.append(app.world.companion.get_rid());body_query.exclude=clearance_excludes
  var clear:bool=_clear(anchor.global_position);body_query.exclude=saved_excludes
  if not clear:callback=Callable();return app.state.say("操作位置被挡住了，请绕到物体前方再试。")
  app.world.companion.reserve_interaction(anchor.global_position)
  active=true;stage="pet_clear";stalled=0
  app.state.say("伙伴正在让出通道，随后自动就位垂钓。")
  return true
 _prepare_queries()
 if _transition_ready():
  _complete();return true
 if not _route():callback=Callable();return app.state.say("操作位置被挡住了，请绕到物体前方再试。")
 point["stand"]=stand
 active=true;stage="approach";stalled=0;previous=app.world.player.position
 app.state.say("正在走到%s的操作位置，摇杆可随时接管。"%str(point.title))
 return true
func _prepare_queries() -> void:
 if body_query==null:
  body_query=PhysicsShapeQueryParameters3D.new();tree_query=PhysicsShapeQueryParameters3D.new()
  var body_shape := CylinderShape3D.new();body_shape.radius=app.world.player.BODY_RADIUS+.03;body_shape.height=1.6
  var tree_shape := CylinderShape3D.new();tree_shape.radius=app.world.player.TREE_RADIUS+.03;tree_shape.height=app.world.player.TREE_HEIGHT
  body_query.shape=body_shape;body_query.collision_mask=1
  tree_query.shape=tree_shape;tree_query.collision_mask=8
 var excludes: Array[RID]=[]
 if is_instance_valid(app.world.companion) and point.kind!="shore_fish":excludes.append(app.world.companion.get_rid())
 if app.state.location=="island":
  for body: StaticBody3D in app.world.forest.find_children("*","StaticBody3D",true,false):
   for child: Node in body.get_children():
    if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:excludes.append(body.get_rid())
 body_query.exclude=excludes;tree_query.exclude=excludes
func _clear(pos: Vector3, trees_only: bool=false) -> bool:
 var query := tree_query if trees_only else body_query
 var height: float=query.shape.height
 query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*(height*.5+.06))
 return app.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _transition_ready() -> bool:
 var actor:CharacterBody3D=app.world.player
 if point.kind not in ["villa_entry","boat"]:return false
 if not app.world.transition_in_range(point.kind):return false
 return _clear(actor.position) and _clear(actor.position,true)
func _route() -> bool:
 var actor: CharacterBody3D=app.world.player
 var candidates: Array[Vector3]=[]
 var desired: Vector3=anchor.global_position
 if anchor.radial:
  var radius: float=maxf(float(point.get("min_range",.8))+.23,1.0)
  var starting: Vector3=actor.position-target
  var angle := atan2(starting.x,starting.z)
  for i in range(16):candidates.append(target+Vector3(sin(angle+i*TAU/16),0,cos(angle+i*TAU/16))*radius)
 else:
  candidates.append(desired)
  if not anchor.exact_stand:
   for i in range(8):candidates.append(desired+Vector3(sin(i*TAU/8),0,cos(i*TAU/8))*.25)
 var valid: Array[Vector3]=[]
 for pos: Vector3 in candidates:
  if not app.world.terrain_walkable(pos):continue
  pos.y=app.world.terrain_height(pos.x,pos.z)+.03
  if _clear(pos) and (app.state.location!="island" or _clear(pos,true)):valid.append(pos)
 if valid.is_empty():return false
 # 站在能碰到它的距离内：就用脚下这一格当站位，原地转身即可，不再往标定点挪。
 # 以前不管离得多近都要先走到 anchor 那一个点（±0.2 米），走完才允许转向，
 # 观感就是「点了交互还得先绕一段路」。
 # 只在房屋内部套用「原地就能用」：岛上的钓鱼/船只/柴堆仍要走到位再操作，
 # 那些玩的正是站位；房子里的器材、沙发、床、灶台不必再绕那半步路。
 if app.state.location=="villa" and point.kind not in ["villa_entry","boat","shore_fish","捕鱼"] and not anchor.exact_stand:
  var here: Vector3=actor.position
  here.y=app.world.terrain_height(here.x,here.z)+.03
  var reach: float=float(point.get("range",1.4))
  if Vector2(here.x-point.pos.x,here.z-point.pos.z).length()<=reach and app.world.terrain_walkable(here) and _clear(here) and (app.state.location!="island" or _clear(here,true)):
   path.clear();stand=here;return true
 # Already at a safe anchor: turning still remains a separate smooth stage.
 for pos: Vector3 in valid:
  if Vector2(pos.x-actor.position.x,pos.z-actor.position.z).length()<anchor.arrival_radius:
   stand=pos;return true
 var grid: AStarGrid2D
 var heights: Dictionary
 var step := .3
 if app.state.location=="island" and point.kind!="shore_fish":
  app.auto_task._build_graph();grid=app.auto_task.grid;heights=app.auto_task.heights;step=app.auto_task.STEP
 else:
  if point.kind=="shore_fish":step=.15
  grid=AStarGrid2D.new();grid.region=Rect2i(-23,83,52,48) if point.kind=="shore_fish" else (Rect2i(-36,-19,84,99) if app.state.location=="villa" else Rect2i(-26,-19,53,79));grid.cell_size=Vector2.ONE*step
  grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update();heights={}
  for x in range(grid.region.position.x,grid.region.end.x):
   for z in range(grid.region.position.y,grid.region.end.y):
    var id:=Vector2i(x,z);var pos:=Vector3(x*step,0,z*step)
    if not app.world.terrain_walkable(pos):grid.set_point_solid(id);continue
    pos.y=app.world.terrain_height(pos.x,pos.z);heights[id]=pos.y
    if not _clear(pos):grid.set_point_solid(id)
 var start:=Vector2i(roundi(actor.position.x/step),roundi(actor.position.z/step))
 if not grid.is_in_boundsv(start):return false
 grid.set_point_solid(start,false)
 var best: Array[Vector2i]=[]
 for pos: Vector3 in valid:
  var goal:=Vector2i(roundi(pos.x/step),roundi(pos.z/step))
  if anchor.exact_stand and grid.is_in_boundsv(goal) and grid.is_point_solid(goal):
   var closest:float=INF;var replacement:=goal
   for dx in range(-1,2):
    for dz in range(-1,2):
     var neighbor:Vector2i=goal+Vector2i(dx,dz)
     if not grid.is_in_boundsv(neighbor) or grid.is_point_solid(neighbor):continue
     var gap:float=Vector2(neighbor.x*step-pos.x,neighbor.y*step-pos.z).length()
     if gap<closest:closest=gap;replacement=neighbor
   goal=replacement
  if not grid.is_in_boundsv(goal) or grid.is_point_solid(goal):continue
  var route:=grid.get_id_path(start,goal)
  if not route.is_empty() and (best.is_empty() or route.size()<best.size()):best=route;stand=pos
 if best.is_empty():return false
 for cell: Vector2i in (best.slice(1) if point.kind in ["villa_entry","boat"] else best):
  if heights.has(cell):path.append(Vector3(cell.x*step,heights[cell]+.03,cell.y*step))
 path.append(stand)
 return true
func recommend(value: Dictionary, revision: int) -> void:
 if app.world.orbit.comfort_mode:return
 if app.state.location=="villa":return
 if app.world.orbit.manual_revision!=revision or not is_instance_valid(value.get("anchor")):return
 var spec: Dictionary=value.anchor.view_spec()
 if value.anchor.radial:
  var actual: Vector3=app.world.player.position-value.pos
  var preferred: Vector3=value.anchor.global_position-value.pos
  spec.yaw+=atan2(actual.x,actual.z)-atan2(preferred.x,preferred.z)
 var orbit: Node=app.world.orbit
 orbit.clear_observation(false,false);orbit.view_transition=1.2
 orbit.target_yaw=spec.yaw;orbit.target_pitch=spec.pitch;orbit.target_distance=spec.distance
func begin_task_view() -> void:
 task_revision=app.world.orbit.manual_revision;task_view_key=""
func align_task(value: Dictionary, delta: float) -> bool:
 if value.kind in ["villa_entry","boat"]:return true
 var destination: Vector3=value.pos
 var actor: CharacterBody3D=app.world.player
 var direction:=destination-actor.position;direction.y=0
 if direction.length_squared()>.001:
  var heading:=atan2(direction.x,direction.z)
  actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,heading,1-exp(-8*delta))
  if absf(angle_difference(actor.visual.rotation.y,heading))>.035:return false
 var key:=str(value.kind)+str(value.pos)
 if key!=task_view_key:
  task_view_key=key
  recommend(value,task_revision)
 return true
func tick(delta: float, manual: Vector2) -> Vector2:
 if manual.length()>.12:
  if active:cancel("已手动接管，就位已取消。")
  return manual
 if not active:return Vector2.ZERO
 if context_key()!=context or not is_instance_valid(anchor):cancel("目标已变化，请重新选择交互。");return Vector2.ZERO
 if not app.movement_enabled():return Vector2.ZERO
 var actor: CharacterBody3D=app.world.player
 if point.kind in ["villa_entry","boat"] and _transition_ready():
  actor.velocity=Vector3.ZERO;_complete();return Vector2.ZERO
 if stage=="pet_clear":
  stalled+=delta
  var pet:Node3D=app.world.companion
  if is_instance_valid(pet) and pet.position.distance_to(pet.interaction_wait_target)>.1 and stalled<2.5:return Vector2.ZERO
  if is_instance_valid(pet):pet.interaction_wait_target=pet.position
  _prepare_queries()
  if not _route():cancel("钓位通道受阻，请稍作移动后重新交互。");return Vector2.ZERO
  point["stand"]=stand;stage="approach";stalled=0;previous=actor.position
 if stage=="approach":
  if not path.is_empty():
   var offset:=path[0]-actor.position;offset.y=0
   if offset.length()<minf(.16,anchor.arrival_radius):path.pop_front();stalled=0;return Vector2.ZERO
   if actor.position.distance_to(previous)<delta*.08:stalled+=delta
   else:stalled=0
   previous=actor.position
   if stalled>2.0:cancel("前方受阻，请手动绕开后重新交互。");return Vector2.ZERO
   var right: Vector3=app.world.camera.global_basis.x;right.y=0
   var forward: Vector3=-app.world.camera.global_basis.z;forward.y=0
   var direction:=offset.normalized()
   return Vector2(direction.dot(right.normalized()),-direction.dot(forward.normalized()))*minf(1,offset.length()/maxf(delta*actor.WALK_SPEED,.001))
  if Vector2(actor.position.x-stand.x,actor.position.z-stand.z).length()>.35:cancel("未能到达安全站位，请重新交互。");return Vector2.ZERO
  if point.kind in ["villa_entry","boat"]:
   actor.velocity=Vector3.ZERO;_complete();return Vector2.ZERO
  stage="facing"
 if stage=="facing":
  var toward:=target-actor.position;toward.y=0
  var heading:=atan2(toward.x,toward.z)
  actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,heading,1-exp(-8*delta))
  if absf(angle_difference(actor.visual.rotation.y,heading))>.035:return Vector2.ZERO
  recommend(point,camera_revision)
  if point.kind in ["伐木","拾石","采纤维"]:
   if not actor.start_work(point.kind,point.pos):cancel("人物正在进行其他动作。");return Vector2.ZERO
   stage="perform";return Vector2.ZERO
  _complete()
 elif stage=="perform":
  if actor.work_done:actor.cancel_work();_complete()
 return Vector2.ZERO
func _complete() -> void:
 if is_instance_valid(app.world.companion):app.world.companion.release_interaction()
 var action:=callback
 active=false;stage="";path.clear();callback=Callable();executing=true
 if action.is_valid():action.call()
 executing=false
