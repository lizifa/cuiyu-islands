extends RefCounted
## One owner for indoor action framing; ordinary walking always returns to a wide view.
const WIDE_RADIUS:=7.8
const WIDE_HEIGHT:=3.45
const WIDE_FOV:=80.0
var owner_key:=""
var subject:=Vector3.ZERO
var radius:float=WIDE_RADIUS
var height:float=WIDE_HEIGHT
var fov:float=WIDE_FOV
var target_radius:float=WIDE_RADIUS
var target_height:float=WIDE_HEIGHT
var target_fov:float=WIDE_FOV
var saved_view:Dictionary={}
func begin(world:Node3D,key:String,focus:Vector3,yaw:float,distance:float=3.6,elevation:float=2.45,lens:float=70) -> void:
 if owner_key=="":saved_view={"yaw":world.orbit.target_yaw,"pitch":world.orbit.target_pitch,"distance":world.orbit.target_distance}
 owner_key=key
 if world.orbit.first_person:
  subject=focus
  return
 if world.orbit.comfort_mode:
  subject=world.player.position+Vector3.UP
  target_radius=WIDE_RADIUS;target_height=WIDE_HEIGHT;target_fov=WIDE_FOV
  return
 subject=focus;target_radius=distance;target_height=elevation;target_fov=lens
 world.orbit.clear_observation(false,false);world.orbit.target_yaw=yaw-world.indoor_camera.retained_angle;world.orbit.view_transition=1.2
func release(world:Node3D,key:String="") -> void:
 if key!="" and owner_key!=key:return
 if owner_key=="":return
 owner_key="";target_radius=WIDE_RADIUS;target_height=WIDE_HEIGHT;target_fov=WIDE_FOV
 if not world.orbit.comfort_mode and not saved_view.is_empty():
  world.orbit.target_yaw=saved_view.yaw;world.orbit.target_pitch=saved_view.pitch;world.orbit.target_distance=saved_view.distance
 world.orbit.view_transition=1.2;saved_view.clear()
func tick(delta:float) -> void:
 var blend:float=1-exp(-3.2*delta)
 radius=lerpf(radius,target_radius,blend);height=lerpf(height,target_height,blend);fov=lerpf(fov,target_fov,blend)
func reset() -> void:
 owner_key="";saved_view.clear();radius=WIDE_RADIUS;height=WIDE_HEIGHT;fov=WIDE_FOV;target_radius=radius;target_height=height;target_fov=fov

func drink(world:Node3D,actor:Node3D,heading:float,side:String) -> void:
 var forward:=Vector3(sin(heading),0,cos(heading))
 var lateral:=Vector3(cos(heading),0,-sin(heading))*(-1 if side=="Left" else 1)
 var bearing:Vector3=(forward+lateral*.65).normalized()
 var head:Vector3=actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(actor._bone("Head")).origin
 var floor_y:float=world.Villa.Dimensions.BASE+world.navigation_state.home_floor*world.Villa.Dimensions.RISE
 begin(world,"household",head-Vector3.UP*.12,atan2(bearing.x,bearing.z),2.35,head.y-floor_y+.18,58)
func sofa(world:Node3D) -> void:
 var seat:Vector3=world.Villa.SOFA_SEAT
 var screen:Vector3=world.villa_room.tv_screen.global_position
 var focus:Vector3=(seat+Vector3.UP*1.0).lerp(screen,.4)
 begin(world,"sofa",focus,1.20,5.7,2.15,50)
