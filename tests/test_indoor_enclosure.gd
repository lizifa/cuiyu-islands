extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var state=load("res://scripts/life/life_state.gd").new()
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.orbit.comfort_mode=false # Optional sealed-camera mode keeps physical enclosure coverage.
 state.location="villa";state.home_floor=1;state.player_position=[0,(VillaDimensions.UPPER_FLOOR+.03),1];world.sync(state)
 world.set_process(false);world.orbit.set_process(false);world.player.set_physics_process(false)
 await physics_frame;await physics_frame
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 var rack:Node3D=world.villa_room.get_node("BedroomCoatRack")
 check(rack.get_node("Approach").global_position.distance_to(Vector3(-2.95,(VillaDimensions.UPPER_FLOOR+.03),-2.75))<.02,"coat rack approach clear of bed and wardrobe")
 var old_span:float=2*sqrt(3.4*3.4+1.8*1.8)*tan(deg_to_rad(55)*.5)
 var new_span:float=2*sqrt(5.2*5.2+1.9*1.9)*tan(deg_to_rad(world.indoor_camera.VIEW_FOV)*.5)
 check(new_span>old_span*1.9,"wide indoor framing covers at least 1.9 times previous vertical span")
 check(rack.find_children("*","StaticBody3D",true,false).size()>0,"coat rack has physical collision")
 for floor_index in range(2):
  state.home_floor=floor_index;world.sync(state);await physics_frame;await physics_frame
  for point:Vector2 in [Vector2(0,1),Vector2(-6.8,-4.8),Vector2(6.8,-4.8),Vector2(-6.8,4.8),Vector2(6.8,4.8),Vector2(9.6,3.7),Vector2(-3,-2.75),Vector2(1.1,-1.2)]:
   world.player.position=Vector3(point.x,.705+floor_index*VillaDimensions.RISE,point.y)
   for heading:float in [0.,PI/2,PI,-PI/2]:
    world.orbit.yaw=heading;world.indoor_camera.reset()
    var focus:Vector3=world.player.position+Vector3.UP
    var pos:Vector3=world.safe_camera_position(focus,focus+Vector3(0,8,12))
    check(pos.x> -10.98 and pos.x<14.5 and pos.z> -6.1 and pos.z<18.3 and pos.y>.675 and pos.y<VillaDimensions.TOP,"camera remains inside shell")
    world.camera.position=pos;world.camera.look_at(focus);world.camera.fov=world.indoor_camera.VIEW_FOV
    var rays_closed:=true
    for x:float in [0.,.25,.5,.75,1.]:
     for y:float in [0.,.25,.5,.75,1.]:
      var size:Vector2=world.camera.get_viewport().get_visible_rect().size
      var pixel:=Vector2(x,y)*size
      var direction:Vector3=world.camera.project_ray_normal(pixel)
      var q:=PhysicsRayQueryParameters3D.create(pos,pos+direction*100,16)
      if space.intersect_ray(q).is_empty():
       rays_closed=false;print("OPEN_RAY ",pos," direction ",direction," pixel ",pixel)
    check(rays_closed,"viewport fully enclosed on floor %d at %s heading %.2f"%[floor_index,point,heading])
    var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.15;query.shape=sphere;query.transform.origin=pos;query.collision_mask=17;query.exclude=[world.player.get_rid()]
    check(space.intersect_shape(query,1).is_empty(),"camera avoids walls and furniture")
 world.player.stair_active=true
 for step:Vector3 in load("res://scripts/life/villa_stairwell.gd").route(true):
  world.player.position=step;world.indoor_camera.reset()
  var camera_position:Vector3=world.safe_camera_position(step+Vector3.UP,step+Vector3(0,8,12))
  check(camera_position.x> -10.98 and camera_position.x<14.5 and camera_position.z> -6.1 and camera_position.z<18.3 and camera_position.y<VillaDimensions.TOP,"stair camera stays indoors")
 world.player.stair_active=false
 check(world.terrain_walkable(Vector3(9.5,4.95,3.8)),"enclosed upper landing is walkable")
 check(not world.terrain_walkable(Vector3(9.5,4.95,0)),"cannot walk into stair opening")
 print("INDOOR ENCLOSURE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
