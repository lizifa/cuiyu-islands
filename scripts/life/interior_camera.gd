extends RefCounted
## Prefer requested heading, but find an indoor viewing side before squeezing against a wall.
var stair_band := -1
var last := Vector3.INF
var retained_angle := 0.0
var last_actor:=Vector3.INF
var stair_yaw:=0.0
var following_stairs:=false
var stair_weight:float=0
var landing_hold:float=0
const Dimensions=preload("res://scripts/life/villa_dimensions.gd")
const MOVE_SPEED := 8.0
const VIEW_FOV := 80.0
const COMFORT_FOV := 78.0
const COMFORT_RADIUS := 5.4
const COMFORT_PITCH := deg_to_rad(12)
const FOLLOW_DISTANCE := 9.0
const VIEW_RADIUS := 7.8
const AREA := Rect2(-10.38,-5.5,24.28,23.2)
func reset() -> void:
 stair_band=-1
 last=Vector3.INF;retained_angle=0;last_actor=Vector3.INF;following_stairs=false;stair_weight=0;landing_hold=0
func resolve(world:Node3D,focus:Vector3,_desired:Vector3,frame_delta:float=-1.0) -> Vector3:
 var actor:Node3D=world.player
 if world.orbit.comfort_mode or actor.stair_active:
  return _enclosed(world,focus,frame_delta)
 if last_actor.is_finite() and last_actor.distance_to(actor.position)>3:reset()
 last_actor=actor.position
 var dt:float=clampf(frame_delta if frame_delta>=0 else world.get_process_delta_time(),1.0/120,.05)
 if actor.stair_active:
  var heading:float=actor.visual.global_rotation.y
  if not following_stairs:stair_yaw=heading
  else:stair_yaw=lerp_angle(stair_yaw,heading,1-exp(-7*dt))
 if actor.stair_active:stair_weight=1;landing_hold=.65
 elif following_stairs:landing_hold=.65
 elif landing_hold>0:landing_hold=maxf(0,landing_hold-dt)
 else:stair_weight=move_toward(stair_weight,0,dt/.95)
 following_stairs=actor.stair_active
 var floor_y:float=Dimensions.BASE+world.navigation_state.home_floor*Dimensions.RISE
 if actor.stair_active:floor_y=actor.position.y
 var height:float=minf(Dimensions.TOP-.5,floor_y+world.home_camera.height)
 var center:=focus
 center.x=clampf(center.x,AREA.position.x,AREA.end.x);center.z=clampf(center.z,AREA.position.y,AREA.end.y)
 var radius:float=world.home_camera.radius
 var best:=Vector3(center.x,height,center.z) if not last.is_finite() else last
 var best_score:float=INF
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=clearance_radius(world);query.shape=sphere;query.collision_mask=17;query.exclude=[actor.get_rid()]
 var initializing:bool=not last.is_finite()
 var previous_angle:float=retained_angle
 var best_angle:float=retained_angle
 # Select a viewing side only on entry/reset. Ordinary collision never changes sides.
 var offsets:Array[float]=[retained_angle,0,PI/6,-PI/6,PI/3,-PI/3,PI/2,-PI/2,PI*2/3,-PI*2/3,PI*5/6,-PI*5/6,PI]
 if not initializing:offsets.clear();offsets.append(retained_angle)
 for offset:float in offsets:
  var angle:float=world.orbit.yaw+offset
  var candidate:=center+Vector3(sin(angle)*radius,0,cos(angle)*radius);candidate.y=height
  if initializing and not AREA.has_point(Vector2(candidate.x,candidate.z)):continue
  candidate.x=clampf(candidate.x,AREA.position.x,AREA.end.x);candidate.z=clampf(candidate.z,AREA.position.y,AREA.end.y)
  if actor.stair_active or stair_weight>0:
   var forward:=Vector3(sin(stair_yaw),0,cos(stair_yaw))
   var rear:Vector3=actor.position+Vector3.UP*1.9-forward*2.0
   rear.x=clampf(rear.x,AREA.position.x,AREA.end.x);rear.z=clampf(rear.z,-2.3,AREA.end.y)
   if rear.y>Dimensions.CEILING-.2 and actor.position.x>7.7:rear.x=maxf(rear.x,8.4)
   candidate=candidate.lerp(rear,stair_weight);height=candidate.y
  # Retract at a fixed heading instead of jumping to the opposite side of the room.
  if not initializing:
   var anchor:=Vector3(center.x,height,center.z)
   query.transform=Transform3D(Basis.IDENTITY,anchor);query.motion=Vector3.ZERO
   if space.intersect_shape(query,1).is_empty():candidate=anchor+_sweep(space,query,anchor,candidate-anchor)
  query.transform=Transform3D(Basis.IDENTITY,candidate)
  if not space.intersect_shape(query,1).is_empty():continue
  query.transform.origin=center;query.motion=candidate-center
  var fraction:=1.0
  if space.intersect_shape(query,1).is_empty():
   var hit:PackedFloat32Array=space.cast_motion(query)
   if hit.size()>0:fraction=hit[0]
  if actor.stair_active and fraction<.99:
   var visible:Vector3=center+(candidate-center)*maxf(0,fraction-.02)
   query.transform.origin=visible;query.motion=Vector3.ZERO
   if visible.distance_to(center)>.45 and space.intersect_shape(query,1).is_empty():candidate=visible
  query.motion=Vector3.ZERO
  var score:float=(1-fraction)*30+absf(angle_difference(offset,previous_angle))*.55+absf(offset)*.08
  if fraction<.25:score+=40
  if score<best_score:
   best_score=score;best=candidate;best_angle=offset
  # A clear retained heading is the lowest possible score; avoid re-testing every side each frame.
  if fraction>.999 and absf(angle_difference(offset,previous_angle))<.001:break
 retained_angle=best_angle
 if initializing:last=best
 else:
  # Sweep the entire path, not merely the destination. Never snap when a lerp is blocked.
  var motion:Vector3=((best-last)*(1-exp(-5*dt))).limit_length(MOVE_SPEED*dt)
  var safe:Vector3=_sweep(space,query,last,motion)
  last+=safe
  var remainder:Vector3=motion-safe
  # Sliding components let the camera round a doorway or stair ceiling at bounded speed.
  for axis:Vector3 in [Vector3(remainder.x,0,0),Vector3(0,0,remainder.z),Vector3(0,remainder.y,0)]:
   last+=_sweep(space,query,last,axis)
 last.x=clampf(last.x,AREA.position.x,AREA.end.x);last.z=clampf(last.z,AREA.position.y,AREA.end.y)
 last.y=clampf(last.y,.675+(1.35 if world.home_camera.owner_key!="" else 1.9),Dimensions.TOP-.5)
 return last
func _sweep(space:PhysicsDirectSpaceState3D,query:PhysicsShapeQueryParameters3D,origin:Vector3,motion:Vector3) -> Vector3:
 if motion.length_squared()<.00000001:return Vector3.ZERO
 query.transform=Transform3D(Basis.IDENTITY,origin);query.motion=Vector3.ZERO
 if not space.intersect_shape(query,1).is_empty():return Vector3.ZERO
 query.motion=motion
 var hit:PackedFloat32Array=space.cast_motion(query)
 query.motion=Vector3.ZERO
 var fraction:float=hit[0] if hit.size()>0 else 1.0
 return motion*maxf(0,fraction-(.02/motion.length() if fraction<1 else 0))

static func clearance_radius(world:Node3D) -> float:
 var size:Vector2=world.camera.get_viewport().get_visible_rect().size
 var aspect:float=size.x/maxf(size.y,1)
 var half_height:float=world.camera.near*tan(deg_to_rad(VIEW_FOV)*.5)
 return maxf(.16,sqrt(half_height*half_height*(1+aspect*aspect)+world.camera.near*world.camera.near)+.015)

static func lens(world:Node3D) -> float:
 return COMFORT_FOV if world.orbit.comfort_mode else VIEW_FOV

static func bound_focus(point:Vector3) -> Vector3:
 return Vector3(clampf(point.x,Dimensions.WEST+.5,Dimensions.EAST-.5),point.y,clampf(point.z,Dimensions.NORTH+.5,Dimensions.SOUTH-.5))

func _enclosed(world:Node3D,focus:Vector3,frame_delta:float) -> Vector3:
 var actor:CharacterBody3D=world.player
 var dt:float=clampf(frame_delta if frame_delta>=0 else world.orbit.frame_delta,1./120,.05)
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new()
 sphere.radius=clearance_radius(world);query.shape=sphere;query.collision_mask=17;query.exclude=[actor.get_rid()]
 var anchor:Vector3=focus
 query.transform.origin=anchor
 if not space.intersect_shape(query,1).is_empty():anchor=actor.position+Vector3.UP*1.45
 var angle:float=clampf(world.orbit.pitch,deg_to_rad(5),deg_to_rad(20))
 var heading:float=world.orbit.yaw
 var radius:float=COMFORT_RADIUS
 if not world.orbit.comfort_mode and actor.stair_active:
  var rear_heading:float=actor.visual.global_rotation.y+PI
  stair_yaw=lerp_angle(stair_yaw,rear_heading,1-exp(-7*dt)) if following_stairs else rear_heading
  heading=stair_yaw;radius=2.2
 var desired:Vector3=anchor+Vector3(sin(heading)*radius,radius*tan(angle),cos(heading)*radius)
 if actor.stair_active and ((actor.position.z>1.5 and anchor.x<10) or (anchor.x<7.8 and actor.stair_path.size()>2)):desired.z=minf(desired.z,3.0)
 desired.x=clampf(desired.x,Dimensions.WEST+.4,Dimensions.EAST-.4)
 desired.z=clampf(desired.z,Dimensions.NORTH+.4,Dimensions.SOUTH-.4)
 var roof:float=Dimensions.TOP
 if actor.position.x<7.7 and actor.position.y<Dimensions.BASE+Dimensions.RISE*.5:roof=Dimensions.CEILING
 desired.y=minf(desired.y,roof-sphere.radius-.08)
 # Retract along the line of sight. Never remove structural walls or ceilings.
 var goal:Vector3=anchor+_sweep(space,query,anchor,desired-anchor)
 if last.is_finite():
  var upper:float=Dimensions.UPPER_FLOOR
  var opening:bool=last.x>8.5 and last.x<10.0 and last.z<1.4 and last.z> -2.3
  var rising:bool=last.y<upper+.4 and goal.y>upper+.4
  var falling:bool=last.y>upper-.4 and (goal.y<upper-.4 or (actor.stair_active and world.stair_target_floor==0 and actor.position.y<upper-1 and goal.y<upper+.8))
  var transfer:bool=(last.y<upper+.4 and goal.y>upper+.4) or (last.y>upper-.4 and goal.y<upper-.4)
  var to_hall:bool=anchor.x>7.8 or transfer
  var cross_wall:bool=(last.x<8.0 and to_hall) or (last.x>7.6 and not to_hall)
  if rising and last.x>8.0:
   goal=Vector3(last.x,upper+.75,last.z) if opening else _opening_waypoint(last)
  elif cross_wall:
   var from_room:bool=to_hall
   var near_x:float=7.1 if from_room else 8.6
   var far_x:float=8.6 if from_room else 7.1
   goal=Vector3(near_x if absf(last.z-2.5)>.3 else far_x,last.y,2.5)
  elif falling and last.x>8.0:
   goal=Vector3(last.x,upper-.75,last.z) if opening else _opening_waypoint(last)
  # Keep a horizontal stand-off on the flights. A taller stairwell must
  # never put the lens directly over the actor's head at a floor transition.
  var separation:Vector3=last-actor.position;separation.y=0
  if actor.stair_active and actor.position.x>8 and actor.position.z<1.5 and separation.length()<2.0:
   var away:Vector3=separation.normalized() if separation.length()>.1 else Vector3.BACK
   goal=actor.position+away*2.6;goal.y=last.y
  # Recover tiny contact overlaps instead of freezing forever on a slab edge.
  query.transform.origin=last;query.motion=Vector3.ZERO
  if not space.intersect_shape(query,1).is_empty():
   for offset:Vector3 in [Vector3.DOWN*.04,Vector3.UP*.04,Vector3.FORWARD*.04,Vector3.BACK*.04,Vector3.LEFT*.04,Vector3.RIGHT*.04]:
    query.transform.origin=last+offset
    if space.intersect_shape(query,1).is_empty():last+=offset;break
 if not last.is_finite() or not last_actor.is_finite() or actor.position.distance_to(last_actor)>3:
  last=goal
 else:
  var motion:Vector3=((goal-last)*(1-exp(-5*dt))).limit_length(3.5*dt)
  var accepted:Vector3=_sweep(space,query,last,motion)
  last+=accepted
  var remainder:Vector3=motion-accepted
  for axis:Vector3 in [Vector3(remainder.x,0,0),Vector3(0,0,remainder.z),Vector3(0,remainder.y,0)]:last+=_sweep(space,query,last,axis)
 last_actor=actor.position;stair_weight=0;following_stairs=actor.stair_active;retained_angle=0
 return last

func _opening_waypoint(point:Vector3) -> Vector3:
 # Cross the rails above the lower ends, never through the narrow centre gap.
 if point.x>10.9 and point.z>-.6:return Vector3(12,point.y,-.8)
 return Vector3(9.25,point.y,-.8)
