extends Node3D
## A real two-flight stairwell beside the cutaway rooms. Both floors stay loaded.
const SOUTH_SHIFT := 3.5
const RISE := preload("res://scripts/life/villa_dimensions.gd").RISE
const BASE := 0.675
const FRONT := preload("res://scripts/life/villa_dimensions.gd").STAIR_FRONT
const BACK := preload("res://scripts/life/villa_dimensions.gd").STAIR_BACK
const MID_BACK := BACK-1.45
const MID_CENTER := BACK-.725
const STEP_COUNT := 16
const TREAD := (FRONT-BACK)/STEP_COUNT
const STEP_RISE := RISE/(STEP_COUNT*2.0)
const FLIGHTS := [9.25,12.0]
var sight_surfaces:Array[MeshInstance3D]=[]
var world_ref:Node3D
var entry_gates:Array[StaticBody3D]=[]
static func route(up: bool) -> Array[Vector3]:
 var points:Array[Vector3]=[Vector3(6,BASE+.03,2),Vector3(6,BASE+.03,3),Vector3(FLIGHTS[0],BASE+.03,3),Vector3(FLIGHTS[0],BASE+.03,FRONT),Vector3(FLIGHTS[0],BASE+RISE*.5+.03,BACK),Vector3(FLIGHTS[0],BASE+RISE*.5+.03,MID_CENTER),Vector3(FLIGHTS[1],BASE+RISE*.5+.03,MID_CENTER),Vector3(FLIGHTS[1],BASE+RISE*.5+.03,BACK),Vector3(FLIGHTS[1],BASE+RISE+.03,FRONT),Vector3(FLIGHTS[1],BASE+RISE+.03,3),Vector3(6,BASE+RISE+.03,3),Vector3(6,BASE+RISE+.03,2)]
 if not up:points.reverse()
 return round_corners(points)
# Turn the hard right angles at the stair mouth into an arc, so the actor
# does not pivot on the spot when it switches from the landing to the flight.
static func round_corners(points:Array[Vector3],radius:float=1.05) -> Array[Vector3]:
 if points.size()<3:return points
 var out:Array[Vector3]=[points[0]]
 for i in range(1,points.size()-1):
  var prev:Vector3=points[i-1];var cur:Vector3=points[i];var next:Vector3=points[i+1]
  var a:Vector3=cur-prev;var b:Vector3=next-cur
  if absf(a.y)>.02 or absf(b.y)>.02 or a.length()<.001 or b.length()<.001:
   out.append(cur)
   continue
  a.y=0;b.y=0;a=a.normalized();b=b.normalized()
  var dot:float=clampf(a.dot(b),-1,1)
  if acos(dot)<deg_to_rad(35.0):
   out.append(cur)
   continue
  var cut:float=minf(radius,minf(cur.distance_to(prev),cur.distance_to(next))*.5)
  var p0:Vector3=cur-a*cut;var p1:Vector3=cur+b*cut
  for k in range(1,4):
   var t:float=float(k)/4.0
   var q0:Vector3=p0.lerp(cur,t);var q1:Vector3=cur.lerp(p1,t)
   var p:Vector3=q0.lerp(q1,t);p.y=cur.y
   out.append(p)
  out.append(p1)
 out.append(points[points.size()-1])
 return out
func setup(world: Node3D) -> void:
 world_ref=world
 name="ContinuousVillaStairwell"
 position.z=SOUTH_SHIFT
 var wood=world.material(Color("946e4c"))
 var dark=world.material(Color("36515a"))
 for flight in range(2):
  var x:float=FLIGHTS[flight]
  for i in range(STEP_COUNT):
   var t:float=(i+.5)/STEP_COUNT
   var z:float=lerpf(FRONT,BACK,t) if flight==0 else lerpf(BACK,FRONT,t)
   var y:float=BASE+flight*RISE*.5+(i+1)*STEP_RISE
   var step:MeshInstance3D=world.box(self,Vector3(x,y-(STEP_RISE+.18)*.5,z-SOUTH_SHIFT),Vector3(2.2,STEP_RISE+.18,TREAD),wood)
   step.name="StairTread_%d_%d"%[flight,i]
  var a:=Vector3(x,BASE+flight*RISE*.5,(FRONT if flight==0 else BACK)-SOUTH_SHIFT)
  var b:=Vector3(x,BASE+(flight+1)*RISE*.5,(BACK if flight==0 else FRONT)-SOUTH_SHIFT)
  _ramp(a,b,2.2,wood)
  for side in [-1,1]:
   var edge:=Vector3(side*1.13,0,0)
   _handrail(world,a+edge+Vector3.UP*.95,b+edge+Vector3.UP*.95,dark)
   for i in range(7):
    var p:=a.lerp(b,i/6.0)+edge
    _post(world,p,dark)
 # Protect the outer edges of the turning platform; leave both flight mouths open.
 var mid_y:=BASE+RISE*.5
 var rear:float=MID_BACK-SOUTH_SHIFT
 var back:float=BACK-SOUTH_SHIFT
 _guard(world,Vector3(8.0,mid_y,back),Vector3(8.0,mid_y,rear),dark)
 _guard(world,Vector3(8.0,mid_y,rear),Vector3(13.3,mid_y,rear),dark)
 _guard(world,Vector3(13.3,mid_y,rear),Vector3(13.3,mid_y,back),dark)
 _platform(world,Vector3(10.65,BASE+RISE*.5-.12,(BACK+MID_BACK)*.5-SOUTH_SHIFT),Vector3(5.3,.24,BACK-MID_BACK),wood)
 _platform(world,Vector3(10.65,BASE+RISE-.12,(FRONT+3.5)*.5-SOUTH_SHIFT),Vector3(5.3,.24,3.5-FRONT),wood)
 # Close the 24cm seam between the first flight and the room partition.
 for edge:Vector2 in [Vector2(8.02,.26),Vector2(13.87,1.26)]:
  _platform(world,Vector3(edge.x,(BASE+preload("res://scripts/life/villa_dimensions.gd").TOP)*.5,(MID_BACK+FRONT)*.5-SOUTH_SHIFT),Vector3(edge.y,preload("res://scripts/life/villa_dimensions.gd").TOP-BASE,FRONT-MID_BACK),world.material(Color("e9e4ce")))
 _gate(9.25,BASE);_gate(12.0,BASE+RISE)
func _gate(x:float,y:float) -> void:
 var body:=StaticBody3D.new();body.name="AssistedStairGate";body.collision_layer=32;body.position=Vector3(x,y+.9,FRONT+.3-SOUTH_SHIFT);add_child(body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2.5,1.8,.12);collision.shape=shape;body.add_child(collision);entry_gates.append(body)
func _platform(world: Node3D,p: Vector3,size: Vector3,mat: Material) -> void:
 sight_surfaces.append(world.box(self,p,size,mat))
 var body=StaticBody3D.new();body.position=p;add_child(body)
 var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider)
func _ramp(a: Vector3,b: Vector3,width: float,mat:Material) -> void:
 var points=PackedVector3Array()
 for p: Vector3 in [a,b]:
  for side in [-1,1]:
   points.append(p+Vector3(side*width*.5,0,0));points.append(p+Vector3(side*width*.5,-.25,0))
 var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 for triangle:Array in [[0,4,6],[0,6,2],[1,3,7],[1,7,5],[0,1,5],[0,5,4],[2,6,7],[2,7,3],[0,2,3],[0,3,1],[4,5,7],[4,7,6]]:
  var center:Vector3=(a+b)*.5-Vector3.UP*.125
  var normal:Vector3=(points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]])
  var midpoint:Vector3=(points[triangle[0]]+points[triangle[1]]+points[triangle[2]])/3
  if normal.dot(midpoint-center)<0:triangle=[triangle[0],triangle[2],triangle[1]]
  for index:int in triangle:builder.add_vertex(points[index])
 builder.generate_normals()
 var underside:=MeshInstance3D.new();underside.name="ClosedStairSoffit_"+str(get_child_count());underside.mesh=builder.commit();underside.material_override=mat;add_child(underside)
 var body=StaticBody3D.new();add_child(body)
 var collider=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();shape.points=points;collider.shape=shape;body.add_child(collider)

func _handrail(world:Node3D,a:Vector3,b:Vector3,mat:Material) -> void:
 var rail:=Node3D.new();rail.name="AlignedHandrail_%d"%get_child_count();add_child(rail)
 rail.position=(a+b)*.5
 rail.basis=Basis(Quaternion(Vector3.BACK,(b-a).normalized()))
 sight_surfaces.append(world.box(rail,Vector3.ZERO,Vector3(.06,.07,a.distance_to(b)),mat))
 _rail_collision(rail,Vector3.ZERO,Vector3(.06,.07,a.distance_to(b)))
func _post(world:Node3D,base:Vector3,mat:Material) -> void:
 sight_surfaces.append(world.box(self,base+Vector3.UP*.475,Vector3(.05,.95,.05),mat))
 _rail_collision(self,base+Vector3.UP*.475,Vector3(.05,.95,.05))
func _guard(world:Node3D,a:Vector3,b:Vector3,mat:Material) -> void:
 _handrail(world,a+Vector3.UP*.95,b+Vector3.UP*.95,mat)
 var count:int=ceili(a.distance_to(b)/.6)
 for i in range(count+1):_post(world,a.lerp(b,float(i)/count),mat)
func _rail_collision(parent:Node3D,pos:Vector3,size:Vector3) -> void:
 var body:=StaticBody3D.new();body.name="HandrailCollision";body.position=pos;parent.add_child(body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)

static func can_enter(point:Vector3,floor_index:int) -> bool:
 return point.x>=5.1 and point.x<=13.3 and point.z>=1.0 and point.z<=3.9 and absf(point.y-(BASE+.03+RISE*floor_index))<.8
static func can_start(point:Vector3,direction:Vector3,floor_index:int) -> bool:
 if not can_enter(point,floor_index):return false
 var flight_x:float=9.25 if floor_index==0 else 12.0
 if point.x<flight_x-.8:return direction.x>.35
 return absf(point.x-flight_x)<1.0 and direction.z<-.35
static func surface_at(point:Vector3,reference_y:float) -> float:
 if point.z<=BACK:return BASE+RISE*.5
 if point.z>=FRONT:return BASE+(RISE if reference_y>BASE+RISE*.7 else 0.0)
 for flight in range(2):
  if absf(point.x-FLIGHTS[flight])<1.1:
   var progress:float=(FRONT-point.z) if flight==0 else (point.z-BACK)
   return BASE+flight*RISE*.5+(clampi(floori(progress/TREAD),0,STEP_COUNT-1)+1)*STEP_RISE
 return reference_y-.03
