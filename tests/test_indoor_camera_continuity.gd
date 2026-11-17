extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 var state=load("res://scripts/life/life_state.gd").new();state.location="villa"
 var world=load("res://scripts/life/life_world.gd").new();view.add_child(world);world.sync(state)
 world.set_process(false);world.orbit.set_process(false);world.player.set_physics_process(false)
 await physics_frame;await physics_frame
 for floor_index:int in [0,1]:
  state.home_floor=floor_index;world.sync(state)
  for hz:int in [30,60]:
   var rig:Node=world.orbit;rig.yaw=0;rig.target_yaw=0;rig.pitch=world.indoor_camera.COMFORT_PITCH;rig.target_pitch=rig.pitch;rig.motion_reset=true
   world.indoor_camera.reset()
   var old:=Vector3.INF;var old_basis:=Basis.IDENTITY;var motion_ok:=true;var rotation_ok:=true;var enclosed:=true
   var first:=Vector3.ZERO
   for i in range(hz*6):
    world.player.position=Vector3(-2,.705+floor_index*VillaDimensions.RISE,6+float(i)/hz)
    rig.focus=world.player.position+Vector3.UP*1.45
    world._process(1./hz);rig._process(1./hz)
    var camera:Camera3D=world.camera
    if i==0:first=camera.position
    if old.is_finite():
     if old.distance_to(camera.position)>3.5/hz+.002:motion_ok=false
     if old_basis.get_rotation_quaternion().angle_to(camera.basis.get_rotation_quaternion())>rig.ANGULAR_SPEED/hz+.001:rotation_ok=false
    if camera.position.y>=.675+floor_index*VillaDimensions.RISE+VillaDimensions.CLEAR_HEIGHT-.2:enclosed=false
    old=camera.position;old_basis=camera.basis
   check(motion_ok,"room follow obeys the translation budget at %d fps"%hz)
   check(rotation_ok,"room follow obeys the angular budget at %d fps"%hz)
   check(enclosed,"camera stays below the ceiling for the complete walk")
   print("FOLLOW ",floor_index," ",hz," first ",first," last ",old)
   check(old.distance_to(first)>3,"camera follows the actor without freezing at an obstacle")
   check(world.camera.cull_mask==1048575,"continuous follow retains real roof and walls")
 print("INDOOR CAMERA CONTINUITY: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
