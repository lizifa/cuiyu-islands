extends SceneTree
var passed:=0
var failed:=0
var app:Node
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func step(dt:float=1./60) -> void:
 app.inactive=false;app.world.player.allowed=true;app.world._process(dt);app.world.orbit._process(dt)
func _initialize():call_deferred("run")
func run():
 var viewport:=SubViewport.new();viewport.size=Vector2i(2436,1126);viewport.own_world_3d=true;root.add_child(viewport)
 app=load("res://scenes/life_main.tscn").instantiate();viewport.add_child(app);app.world.orbit.set_first_person(true);app.set_process(false);app.set_physics_process(false)
 app._close_drawers();app.paused=false;app.inactive=false
 var world:Node=app.world;var actor:Node=world.player;var rig:Node=world.orbit;var camera:Camera3D=world.camera
 world.set_process(false);rig.set_process(false);actor.set_physics_process(false);app.fishing_session.set_physics_process(false)
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[0,.705,8];world.sync(app.state)
 await physics_frame;await physics_frame
 for i in range(120):step()
 check(rig.first_person,"explicit first-person mode is selected")
 check(camera.position.distance_to(actor.position+Vector3.UP*1.85)<.01,"camera is at stable eye level")
 check(camera.keep_aspect==Camera3D.KEEP_WIDTH and is_equal_approx(camera.fov,88),"horizontal FOV is fixed, without ultrawide distortion")
 app._layout_mobile()
 check(is_equal_approx(camera.fov,88),"HUD relayout never restores the old third-person FOV")
 var edge:Vector3=camera.project_ray_normal(Vector2(0,viewport.size.y*.5))
 check(absf(rad_to_deg(edge.angle_to(-camera.basis.z))-44)<.1,"horizontal view spans eighty-eight degrees")
 check((camera.cull_mask&256)==0 and (camera.cull_mask&2)!=0,"own body is hidden while complete walls and ceilings remain visible")
 var hidden:=true
 for mesh:MeshInstance3D in actor.visual.find_children("*","MeshInstance3D",true,false):hidden=hidden and mesh.layers==256
 check(hidden,"head, hat and cloak cannot cover the player's view")
 var original:Transform3D=camera.transform
 for i in range(120):step()
 check(camera.transform.is_equal_approx(original),"standing still has no breathing sway or camera bob")
 rig.mouse_dragging=true;rig.gesture_drag(Vector2(170,-70));step(.05)
 check(rig.yaw<0 and rig.pitch<0,"rightward and upward gestures look right and up")
 rig.cancel_drag();var stopped:=Vector2(rig.yaw,rig.pitch)
 for i in range(20):step()
 check(Vector2(rig.yaw,rig.pitch).distance_to(stopped)<.0001,"releasing look stops immediately")
 rig.target_pitch=99;for i in range(120):step()
 check(rig.pitch<=deg_to_rad(65)+.001,"vertical view is clamped")
 rig.pitch=0;rig.target_pitch=0;rig.yaw=0;rig.target_yaw=0;step()
 var north:Vector3=world.walk_camera.map_input(world,Vector2.UP)
 rig.yaw=-PI*.5;rig.target_yaw=rig.yaw;step()
 var east:Vector3=world.walk_camera.map_input(world,Vector2.UP)
 check(north.dot(Vector3.FORWARD)>.99 and east.dot(Vector3.RIGHT)>.99,"held forward movement uses the current look direction")
 var frozen:Transform3D=camera.transform;rig.motion_enabled=false;actor.position.x+=.2;rig.gesture_drag(Vector2(70,30));step()
 check(camera.transform.is_equal_approx(frozen),"pause freezes the camera")
 rig.motion_enabled=true;rig.cancel_drag();actor.position=Vector3(-1.15,.705,-2.6);rig.pitch=0;rig.target_pitch=0
 for i in range(120):step()
 camera.look_at(Vector3(-1.5,1.8,-4.7))
 var point:Dictionary=world.nearby_action()
 check(point.get("kind","")=="villa_fridge","gaze picks the fridge from its object bounds")
 camera.look_at(camera.position+Vector3.BACK)
 check(world.nearby_action().get("kind","")!="villa_fridge","turning away clears the fridge prompt")
 actor.position=Vector3(-1.15,.705,-2.6);step();camera.look_at(Vector3(-1.5,1.8,-4.7))
 var wall:=StaticBody3D.new();world.add_child(wall);wall.position=Vector3(-1.2,2,-3.4)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,3,.12);shape.shape=box;wall.add_child(shape)
 await physics_frame;await physics_frame
 check(world.nearby_action().get("kind","")!="villa_fridge","a solid wall blocks the interaction prompt")
 wall.queue_free();await physics_frame
 actor.position=world.Villa.SOFA_STAND;step()
 check(app.sofa_session.begin(),"sofa rest still starts")
 for i in range(120):step()
 check(absf(camera.position.y-actor.position.y-1.18)<.02,"sitting lowers the eye level smoothly")
 app.sofa_session.finish()
 var chair:Node3D=world.villa_room.find_children("DiningChair*","Node3D",false,false)[0]
 actor.position=chair.global_position+Vector3(.5,0,0);actor.position.y=.705
 check(app.sofa_session.begin_dining(),"dining chair is usable in first person")
 app.state.inventory["浆果"]=4;app.sofa_session.begin_eating();actor.seated_eat_time=.9;step()
 check(rig.activity=="dining" and rig.auto_point.distance_to(world.villa_room.get_node("DiningTable").global_position+Vector3.UP*.8)<.001,"dining assist faces the table rather than the television")
 check(rig.hands.food.visible and app.sofa_session.food_prop.layers==256,"eating shows one first-person food prop without the hidden body duplicate")
 app.sofa_session.finish()
 var old_water:Array[Node]=world.forest.find_children("water","MeshInstance3D",true,false)
 check(not old_water.is_empty() and old_water.all(func(mesh):return not mesh.visible) and world.forest.get_node_or_null("RiverUnderPromenade")==null,"neither imported nor rebuilt legacy water can cover the eye above the island")
 app.state.location="island";app.state.player_position=[-1,.68,16.45];world.sync(app.state)
 await physics_frame;await physics_frame
 for i in range(120):step()
 var session:Node=app.fishing_session
 actor.position=world.FishingPlatform.SEAT+Vector3(-.8,0,-.6)
 check(session.begin() and session.stage=="ready","first-person fishing waits for a deliberate cast")
 var entry:Vector3=actor.position
 session._physics_process(1./60)
 check(session.active and actor.position.distance_to(entry)<=actor.WALK_SPEED/60+.001,"entering from the side does not cancel or teleport the fisher")
 for i in range(60):session._physics_process(1./60)
 check(session.active and actor.position.distance_to(session.origin)<.001,"ready phase settles at the actual fishing position")
 for i in range(180):step()
 check(rig.hands.visible and not camera.is_position_behind(rig.hands.right_world()),"fishing hands are visible in front of the eye")
 check(session.active,"fishing remains active before input")
 session.interact();app.context_action.held=true
 session._physics_process(.9);step()
 check(session.stage=="charging" and session.cast_power>.5,"holding builds cast power")
 app.context_action.held=false;session._physics_process(.02);step()
 check(session.stage=="casting" and session.cast_target.z>session.origin.z+20,"release casts the line farther with power")
 session._physics_process(1.3);step()
 check(session.stage=="waiting","cast transitions to waiting without a camera cut")
 for i in range(120):step()
 check(absf(camera.position.y-actor.position.y-1.2)<.02,"waiting uses seated first-person eye height")
 session.fish_roll=0;session._set_stage("bite");session.interact();session._physics_process(.8);session._physics_process(.5);step()
 check(session.big_fish and session.stage=="reeling","big fish still requires standing and hooking")
 for i in range(120):step()
 check(absf(camera.position.y-actor.position.y-1.85)<.02,"a big fish raises the eye smoothly")
 check(session.rod.global_position.distance_to(rig.hands.right_world())<.001,"sea rod is held by the visible first-person hand")
 check(session.bend_load>.3,"the original tension-driven rod curve remains active")
 session._set_stage("landing");session._physics_process(2.0);step()
 check(session.net_tool.visible,"landing presents the real landing net")
 session._physics_process(2.0);step()
 check(session.stage=="storing" and app.state.pending_fish.size()>0,"catch enters pending storage exactly once")
 session._physics_process(session.Storage.DURATION+.1);step()
 check(session.stage=="result" and app.state.pending_fish.is_empty() and app.state.fish_keep.size()>0,"fish is placed into the keep net")
 session.cancel(false);step()
 check(not rig.hands.visible,"leaving fishing clears the held-equipment view")
 check(camera.cull_mask==(1048575&~256),"outdoors keeps the correct first-person render mask")
 var inventory:Dictionary=app.state.inventory.duplicate(true)
 for hz:int in [30,60]:
  var safe:=true;var budget:=true;var eye:=true
  rig.mouse_dragging=true
  for i in range(hz*8):
   var previous_basis:Basis=camera.basis
   rig.gesture_drag(Vector2(180 if i%2==0 else -170,220 if i%3==0 else -100))
   step(1./hz)
   if not camera.position.is_finite() or absf(camera.basis.x.y)>.001 or rig.pitch<deg_to_rad(-75)-.001 or rig.pitch>deg_to_rad(65)+.001:safe=false
   if previous_basis.get_rotation_quaternion().angle_to(camera.basis.get_rotation_quaternion())>rig.LOOK_SPEED/hz+.002:budget=false
   if absf(camera.position.y-actor.position.y-1.85)>.02:eye=false
  check(safe and eye,"rapid look never rolls, changes eye height or inverts at %d fps"%hz)
  check(budget,"rapid look obeys the angular budget at %d fps"%hz)
  rig.cancel_drag();var heading:Vector2=Vector2(rig.yaw,rig.pitch)
  for i in range(10):step(1./hz)
  check(Vector2(rig.yaw,rig.pitch).distance_to(heading)<.001,"rapid look stops on release at %d fps"%hz)
 check(inventory==app.state.inventory,"look stress never consumes resources")
 print("FIRST PERSON: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
