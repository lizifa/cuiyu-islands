extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/life/life_state.gd").new()
 var w=load("res://scripts/life/life_world.gd").new();root.add_child(w);w.sync(s)
 await physics_frame
 var rig=w.orbit
 var original: int=rig.manual_revision
 var yaw: float=rig.target_yaw;var pitch: float=rig.target_pitch
 for i in range(20):rig.pan_drag(Vector2(1,0) if i%2==0 else Vector2(-1,0))
 check(rig.manual_revision==original and rig.target_pan==Vector3.ZERO,"long hold jitter does not move camera")
 check(rig.target_yaw==yaw and rig.target_pitch==pitch,"normal observation never changes orientation")
 var wall=StaticBody3D.new();wall.position=Vector3(50,3,56);w.add_child(wall)
 var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(6,6,.5);collider.shape=shape;wall.add_child(collider)
 await physics_frame;await physics_frame
 var focus=Vector3(50,1,50);var desired=Vector3(50,7,65)
 var blocked: Vector3=w.safe_camera_position(focus,desired)
 check(blocked.distance_to(desired)>3,"obstacle clips camera safely")
 wall.collision_layer=0;await physics_frame
 var released: Vector3=w.safe_camera_position(focus,desired)
 check(released.distance_to(blocked)<.1,"clearing obstacle cannot snap immediately to full distance")
 for i in range(240):w.safe_camera_position(focus,desired)
 check(w.camera_clearance>.9,"camera returns outward after hysteresis delay")
 wall.collision_layer=1;await physics_frame
 var overlapping: Vector3=w.safe_camera_position(Vector3(50,2,56),Vector3(50,8,70))
 check(overlapping.is_finite() and overlapping.y>=.8,"overlapping observation focus recovers to clear air")
 check(s.inventory["木材"]==0,"camera safety changes no resources")
 print("CAMERA STABILITY: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
