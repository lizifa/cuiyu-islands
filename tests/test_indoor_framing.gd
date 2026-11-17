extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 var app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app._close_drawers();app.paused=false
 app.set_process(false);app.set_physics_process(false);app.world.set_process(false);app.world.orbit.set_process(false);app.world.player.set_physics_process(false)
 var actor:Node3D=app.world.player;var rig:Node=app.world.orbit;var camera:Camera3D=app.world.camera
 for floor_index:int in ([] if OS.get_cmdline_user_args().has("--walk-only") else [0,1]):
  for spot:Vector2 in [Vector2(6,2),Vector2(0,8),Vector2(6.9,3)]:
   app.state.location="villa";app.state.home_floor=floor_index;app.state.player_position=[spot.x,.705+floor_index*5.25,spot.y];app.world.sync(app.state)
   actor.position=Vector3(spot.x,.705+floor_index*5.25,spot.y);actor.velocity=Vector3.ZERO
   await physics_frame;await process_frame;await physics_frame
   for heading:float in [0,PI*.5,PI,-PI*.5]:
    actor.visual.rotation.y=heading;rig.room_key="";rig.pivot=Vector3.INF
    for i in range(90):rig.motion_enabled=true;rig._process(1./60)
    var label:String="floor %d spot %s heading %.2f"%[floor_index,spot,heading]
    check(rig._body_framed(actor),"full body fits on indoor entry "+label)
    check(camera.position.y<app.world.Villa.Dimensions.CEILING+floor_index*5.25-.2,"camera remains below its own floor ceiling "+label)
    var hit:Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,actor.position+Vector3.UP*1.5,17,[actor.get_rid()]))
    check(hit.is_empty(),"entry view is not a wall surface "+label+" "+str(hit.get("position","")))
 # Reproduce walking toward a wall after a valid spawn, rather than only testing teleports.
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[0,.705,8];app.world.sync(app.state)
 actor.position=Vector3(0,.705,8);actor.velocity=Vector3.ZERO
 await physics_frame;await process_frame;await physics_frame
 rig.room_key="";actor.visual.rotation.y=0
 for i in range(90):rig.motion_enabled=true;rig._process(1./60)
 var clipped:=0
 for i in range(345):
  actor.position.x+=.02
  rig.motion_enabled=true;rig._process(1./60)
  if not rig._body_framed(actor):
   clipped+=1
   if i%30==0:print("WALK CLIP ",i," actor ",actor.position," camera ",camera.position," heading ",rig.stable_yaw," requested ",rig.requested_yaw," body ",rig.framing_skeleton.global_transform*rig.framing_skeleton.get_bone_global_pose(rig.framing_bones.Head).origin)
 check(clipped==0,"walking toward the east wall keeps a full-body view: "+str(clipped))
 var manual_clipped:=0
 rig.mouse_dragging=true
 for i in range(120):
  rig.gesture_drag(Vector2(160 if i%2==0 else -150,160 if i%3==0 else -90))
  rig._process(1./60)
  if not rig._body_framed(actor):manual_clipped+=1
 rig.cancel_drag()
 check(manual_clipped==0,"rapid indoor look preserves the full body near a wall: "+str(manual_clipped))
 print("INDOOR FRAMING: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
