extends RefCounted
## Stable input basis for each gesture; rear alignment is optional cinematic behavior.
const TURN_DELAY:=.25
const TURN_SPEED:=deg_to_rad(85)
var follow_requested:=false
var travel_heading:float=INF
var moving_time:float=0
var manual_grace:float=0
var revision:int=-1
var input_revision:int=-1
var input_axis:=Vector2.ZERO
var input_heading:=Vector3.ZERO
var input_active:=false
var input_right:=Vector3.RIGHT
var input_forward:=Vector3.FORWARD
func map_input(world:Node3D,axis:Vector2) -> Vector3:
 if axis.length()<.08:
  input_active=false;input_axis=Vector2.ZERO;return Vector3.INF
 # 相机正在被脚本摆位（进房/出房、上楼梯、锻炼特写、钓鱼摇臂）或人物此刻不能走时，
 # 直接交还「每帧现算」的相机相对方向：否则手感会在运镜那一瞬被冻住，镜头摆回身
 # 后仍在按老方向走，看起来像非得先斜着走（差 90 度）才肯正常走。
 if world.orbit.view_transition>0.0 or world.orbit.activity_key!="" or world.home_camera.owner_key!="" or world.player.working or not world.player.fishing_stage.is_empty() or world.player.sofa_seated or world.player.bed_stage!="" or world.player.stair_active:
  input_active=false;input_axis=Vector2.ZERO;return Vector3.INF
 var normalized:Vector2=axis.normalized()
 if world.orbit.first_person or not input_active or input_revision!=world.orbit.manual_revision:
  input_right=world.camera.global_basis.x;input_right.y=0;input_right=input_right.normalized()
  input_forward=-world.camera.global_basis.z;input_forward.y=0;input_forward=input_forward.normalized()
  input_active=true;input_revision=world.orbit.manual_revision
 input_heading=(input_right*axis.x-input_forward*axis.y).normalized()
 input_axis=normalized
 return input_heading*minf(axis.length(),1)
func tick(world:Node3D,delta:float) -> void:
 if world.orbit.comfort_mode:return
 var orbit:Node=world.orbit;var actor:CharacterBody3D=world.player
 if revision<0:revision=orbit.manual_revision
 if revision!=orbit.manual_revision:revision=orbit.manual_revision;manual_grace=1.5
 manual_grace=maxf(0,manual_grace-delta)
 if not follow_requested or not actor.allowed or actor.boating or actor.stair_active or actor.sofa_seated or actor.bed_stage!="" or actor.home_busy or actor.pet_stage!="" or actor.working or actor.fishing_stage!="" or world.home_camera.owner_key!="" or orbit.observing_sun or orbit.rotation_mode or manual_grace>0:
  moving_time=0;return
 var direction:Vector3=actor.velocity;direction.y=0
 if actor.manual_world_direction.is_finite():direction=actor.manual_world_direction
 if direction.length()<.15:moving_time=0;travel_heading=INF;return
 var heading:float=atan2(direction.x,direction.z)
 if is_finite(travel_heading) and absf(angle_difference(travel_heading,heading))>deg_to_rad(35):moving_time=0
 travel_heading=heading
 moving_time+=delta
 if moving_time<TURN_DELAY:return
 var wanted:float=atan2(direction.x,direction.z)+PI
 if world.navigation_state.location=="villa":wanted-=world.indoor_camera.retained_angle
 var turn:float=angle_difference(orbit.target_yaw,wanted)
 if absf(turn)<deg_to_rad(10):return
 orbit.target_yaw+=clampf(turn,-TURN_SPEED*delta,TURN_SPEED*delta)
func reset() -> void:
 follow_requested=false;travel_heading=INF;moving_time=0;manual_grace=0;revision=-1;input_revision=-1;input_active=false;input_axis=Vector2.ZERO
