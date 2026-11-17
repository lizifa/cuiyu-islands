extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.size=Vector2i(2436,1126);view.own_world_3d=true;root.add_child(view)
 var app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app._close_drawers();app.set_process(false);app.set_physics_process(false);app.inactive=false;app.paused=false
 await physics_frame;await physics_frame
 var world:Node3D=app.world;var actor:CharacterBody3D=world.player;actor.set_physics_process(false);world.orbit.set_process(false)
 var site:Dictionary=world.exploration._sites(world.seascape.islands[0])[0]
 actor.position=world.DOCK;world.board_boat(app.state);actor.position=site.berth;actor.allowed=true
 for frame in range(130):actor.rowing_pose.tick(1./60,0)
 app._update_context();check(app.build_action.title=="登岛" and app.context_action.title=="撒网","dock and net actions have separate fixed buttons")
 app.joystick.direction=Vector2.ONE;app.build_action.pressed.emit()
 for frame in range(125):app.boat_session.tick(1./60)
 check(app.joystick.direction==Vector2.ZERO,"landing releases held joystick")
 check(not actor.boating and not app.state.island_visit.is_empty(),"actual landing button dispatches")
 app._sync_overlay_state();app._update_context()
 check(app.build_action.visible and app.build_action.title=="返回船上","thumb-accessible return shortcut appears")
 check(app.task_entries.get_node_or_null("ReturnParkedBoat")!=null,"task list exposes return shortcut")
 app.minimap._process(.2)
 check(app.minimap.center_offset.distance_to(Vector2(world.seascape.islands[0].position.x,world.seascape.islands[0].position.z))<.1,"shore minimap centers visited island")
 world.orbit.motion_enabled=true;world.orbit._process(0)
 check(world.orbit._body_framed(actor),"landing camera contains character")
 var origin:Vector3=actor.position
 var direction:Vector3=world.seascape.islands[0].position-actor.position;direction.y=0;direction=direction.normalized()
 # 沿着沙滩横着走：岛心方向常常就是陡坎，正面爬坡本来就会被碰撞挡住，不能拿它当「能不能走路」的判据。
 var tangent:Vector3=Vector3(-direction.z,0,direction.x)
 actor.allowed=true;actor.manual_world_direction=tangent;actor.set_physics_process(true)
 for frame in range(70):await physics_frame
 actor.manual_world_direction=Vector3.INF;actor.move_input=Vector2.ZERO;actor.set_physics_process(false)
 check(actor.position.distance_to(origin)>1.5 and world.terrain_walkable(actor.position),"real walking works after landing")
 var tree:Node3D=world.seascape.islands[0].near_props[0]
 var start:Vector3=tree.global_position+Vector3.RIGHT*3;start.y=world.terrain_height(start.x,start.z)+.03
 check(world.safe_tree_motion(start,Vector3.LEFT*3).length()<2.9,"visited island tree blocks character motion")
 app.joystick.direction=Vector2.ONE;app.build_action.pressed.emit()
 check(app.joystick.direction==Vector2.ZERO,"return shortcut releases held joystick")
 check(actor.boating and actor.rowing_pose!=null,"auxiliary shortcut returns directly to boat")
 check(actor.position.distance_to(site.berth)<.01,"shortcut restores own berth")
 app.minimap._process(.2)
 check(app.minimap.extent>=600,"sailing map covers archipelago")
 app._update_context();check(app.boat_home_action.title=="返航主岛","boat skill offers home return")
 print("ISLAND SHORTCUT UI: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
