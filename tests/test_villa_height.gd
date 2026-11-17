extends SceneTree
const Dimensions=preload("res://scripts/life/villa_dimensions.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 var state=load("res://scripts/life/life_state.gd").new();state.location="villa";state.home_floor=1
 state.player_position=[0,4.955,8] # Deliberately use the previous release's upstairs height.
 var world=load("res://scripts/life/life_world.gd").new();view.add_child(world);world.sync(state)
 world.set_process(false);world.orbit.set_process(false);world.player.set_physics_process(false)
 await physics_frame;await physics_frame
 check(is_equal_approx(world.player.position.y,Dimensions.UPPER_FLOOR+.03),"old upstairs save is grounded on the raised second floor")
 check(is_equal_approx(Dimensions.CLEAR_HEIGHT,4.8),"each floor has 4.8 metres clear height")
 check(is_equal_approx(Dimensions.RISE,5.25),"floor separation includes the original slab allowance")
 var shell:Node3D=world.props.get_node("VillaInteriorEnvelope")
 var lowest_trim:=INF
 for mesh:MeshInstance3D in shell.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh is BoxMesh and is_equal_approx(mesh.mesh.size.y,.18) and mesh.position.y<Dimensions.UPPER_FLOOR:
   lowest_trim=minf(lowest_trim,mesh.position.y-mesh.mesh.size.y*.5-Dimensions.BASE)
 check(lowest_trim>4.5,"ceiling border retains more than 4.5 metres below it")
 var Stairs=load("res://scripts/life/villa_stairwell.gd")
 check(Stairs.STEP_COUNT==16,"each flight has sixteen steps")
 check(Stairs.STEP_RISE<.17 and Stairs.TREAD>=.249,"raised house preserves a natural riser and tread proportion")
 check(rad_to_deg(atan2(Stairs.STEP_RISE,Stairs.TREAD))<35,"stairs remain below a thirty-five degree slope")
 var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 var head_query:=PhysicsShapeQueryParameters3D.new();var head:=SphereShape3D.new();head.radius=.18;head_query.shape=head;head_query.collision_mask=17;head_query.exclude=[world.player.get_rid()]
 for point:Vector3 in Stairs.route(true):
  head_query.transform.origin=point+Vector3.UP*2.35
  check(space.intersect_shape(head_query,1).is_empty(),"stair route leaves standing headroom "+str(point))
 var scale_before:Vector3=world.player.visual.scale
 state.home_floor=0;world.sync(state);world.player.position=Vector3(0,.705,8)
 world.orbit.focus=world.player.position+Vector3.UP*1.45;world.orbit.yaw=0;world.orbit.target_yaw=0;world.orbit.pitch=world.indoor_camera.COMFORT_PITCH;world.orbit.target_pitch=world.orbit.pitch
 world.indoor_camera.reset();world._process(1./60);world.orbit._process(1./60)
 var camera:Camera3D=world.camera
 var old_edge:=Vector3(0,Dimensions.BASE+3.8,1)
 var new_edge:=Vector3(0,Dimensions.CEILING,1)
 check(camera.is_position_in_frustum(old_edge) and camera.is_position_in_frustum(new_edge),"standing camera can see the old and new upper-wall reference heights")
 var extra_pixels:float=camera.unproject_position(old_edge).y-camera.unproject_position(new_edge).y
 check(extra_pixels>35,"added wall height is visibly separated on a phone viewport: "+str(extra_pixels))
 check(camera.position.y<Dimensions.BASE+3.0,"camera stays near the actor instead of rising with the roof")
 check(world.player.visual.scale.is_equal_approx(scale_before),"character scale stays unchanged")
 check(world.camera.cull_mask==1048575,"roof and walls remain rendered")
 print("VILLA HEIGHT: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
