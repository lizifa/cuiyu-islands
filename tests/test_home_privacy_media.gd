extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app._close_drawers();app.paused=false;app.inactive=false;app.set_process(false);app.set_physics_process(false)
 var d=app.world.Villa.Dimensions
 app.state.location="villa";app.state.home_floor=1;app.state.player_position=[6,d.UPPER_FLOOR+.03,2];app.world.sync(app.state)
 await physics_frame;await physics_frame
 var actor:CharacterBody3D=app.world.player;actor.set_physics_process(false);actor.allowed=true
 var room:Node3D=app.world.villa_room;var suite:Node3D=room.get_node("UpstairsRooms")
 suite._physics_process(1)
 check(suite.door_slide<.01,"bathroom stays closed at stair landing")
 var pane:MeshInstance3D=suite.door.get_child(0)
 check(pane.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"bathroom privacy door is opaque")
 for destination:Vector3 in [Vector3(3.95,7,-4.9),Vector3(5.7,7,-4.7),Vector3(7,7,-2.5)]:
  var hit:Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(6,8.1,2),destination,1,[actor.get_rid()]))
  check(not hit.is_empty(),"landing cannot see bathroom fixture directly "+str(destination))
 var media:Node=room.get_node("HomeComputer")
 check(not media.enabled,"computer starts off")
 var point:Dictionary=app.world.find_interaction("villa_computer");check(not point.is_empty(),"computer interaction exists")
 actor.position=point.pos;app._update_context();check(app.context_action.title=="打开电脑","near computer shows power action")
 check(app._toggle_computer() and media.enabled and media.player.is_playing(),"computer powers on real video playback")
 check(media.target_screen.material_override==media.screen_material,"monitor displays video texture")
 app._update_context();check(app.context_action.title=="关闭电脑","computer action updates when on")
 check(app._toggle_computer() and not media.player.is_playing(),"computer power off stops decoding")
 var door:Node3D=room.get_node("SensorGlassEntrance")
 check(door.width>=2.8,"upstairs glass entrance is widened")
 actor.position=Vector3(3.2,d.UPPER_FLOOR+.03,17);door._physics_process(1)
 check(door.openness>.99,"upstairs sensor door opens on approach")
 var glass:MeshInstance3D=door.leaves[0].get_child(0)
 check(glass.material_override.shader.resource_path.ends_with("privacy_glass.gdshader"),"sensor door uses inside-transparent privacy glass")
 actor.position=Vector3(0,d.UPPER_FLOOR+.03,8);door._physics_process(1)
 check(door.openness<.01,"sensor door closes after leaving")
 app.state.home_floor=0;app.world.sync(app.state)
 var lower:Node3D=app.world.villa_room.get_node("SensorGlassEntrance")
 check(lower.width>=3.2,"ground floor entrance widened")
 actor.position=Vector3(0,.705,16.5);lower._physics_process(1)
 check(lower.openness>.99,"ground floor sensor door opens on approach")
 print("HOME PRIVACY MEDIA: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
