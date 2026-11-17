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
 actor.position=world.DOCK;world.board_boat(app.state);actor.allowed=true;actor.position=Vector3(65,.05,65)
 for frame in range(130):actor.rowing_pose.tick(1./60,0)
 app._sync_overlay_state();app._update_context()
 check(app.context_action.title=="撒网" and app.boat_home_action.visible and app.boat_stop_action.visible,"five sailing skills visible")
 check(not app.build_action.active,"no docking button in open ocean")
 var controls:Array=[app.context_action,app.sprint_action,app.build_action,app.boat_stop_action,app.boat_home_action]
 for small:Control in [app.boat_stop_action,app.boat_home_action]:
  check(not app._camera_can_drag(small.get_global_rect().get_center()),"small boat button does not drag camera")
  for other:Control in controls:
   if other==small:continue
   check(not small.get_global_rect().grow(-2).intersects(other.get_global_rect().grow(-2)),"extra boat skill has its own touch region")
 var count:int=app.state.count("鱼")
 app.context_action.pressed.emit()
 check(app.boat_session.phase=="cast" and app.boat_session.locked(),"cast locks propulsion")
 app.joystick.direction=Vector2.ONE;app.sprinting=true;app._physics_process(.1)
 check(actor.move_input==Vector2.ZERO and not actor.sprint,"held joystick and sprint cannot drag a deployed net")
 for frame in range(150):app.boat_session.tick(1./60);actor.rowing_pose.tick(1./60,0)
 app._update_context()
 check(app.context_action.title=="收网" and not app.sprint_action.active and not app.build_action.active,"net changes action and disables acceleration/docking")
 check(app.state.count("鱼")==count,"cast alone grants no fish")
 var pause_at:float=app.boat_session.soak;app.paused=true;app.boat_session.tick(10);app.paused=false
 check(app.boat_session.soak==pause_at,"paused game freezes net timer")
 app.boat_session.tick(10);app.context_action.pressed.emit()
 check(app.boat_session.phase=="haul","primary button begins haul")
 for frame in range(260):app.boat_session.tick(1./60);actor.rowing_pose.tick(1./60,0)
 check(not app.boat_session.busy() and app.state.count("鱼")>count,"completed haul stores catch")
 var after:int=app.state.count("鱼");app.boat_session.tick(10)
 check(app.state.count("鱼")==after,"catch cannot be duplicated by extra ticks")
 app.boat_stop_action.pressed.emit();check(app.boat_session.stopped,"stop button holds vessel")
 app.boat_stop_action.pressed.emit();check(not app.boat_session.stopped,"continue releases vessel")
 # 鲨鱼贴近：同一个「停船」槽位切成「驱赶鲨鱼」，槽位数量与位置不变
 var shark_node:Node3D=world.sea_giants.sharks[0].node
 actor.position=shark_node.position+Vector3(1.2,0,0);actor.position.y=.05
 app._update_context()
 check(app.boat_stop_action.title=="驱赶鲨鱼","shark threat swaps the stop slot to repel")
 app.boat_stop_action.pressed.emit()
 check(world.sea_giants.repel_cooldown>0.0 and not world.sea_giants.repel_ready(),"repel fires from the slot and goes on cooldown")
 actor.position=Vector3(65,.05,65);app._update_context()
 check(app.boat_stop_action.title!="驱赶鲨鱼","slot returns to stop away from sharks")
 for island:Node3D in world.seascape.islands:
  var site:Dictionary=world.exploration._sites(island)[0]
  check(world.seascape.get_node_or_null("IslandDock_"+str(site.id))!=null,"visible fixed dock "+str(site.id))
  var outward:Vector3=(site.berth-site.land).normalized()
  actor.position=site.berth+outward*20;actor.position.y=.05
  check(world.nearby_action().kind!="remote_land","no premature landing at twenty metres "+str(site.id))
  check(not world.exploration.land(site),"direct landing cannot bypass range check")
  actor.position=site.berth;actor.velocity=Vector3(4,0,0)
  check(not world.exploration.land(site),"fast moving boat cannot teleport to land")
  app._update_context();app.build_action.pressed.emit()
  check(actor.boating and app.boat_session.phase=="dock","docking starts with boat still afloat")
  for frame in range(125):app.boat_session.tick(1./60)
  check(not actor.boating and app.state.island_visit.id==site.id,"align stop then land "+str(site.id))
  app._return_to_parked_boat()
  for frame in range(130):actor.rowing_pose.tick(1./60,0)
 actor.position=Vector3(65,.05,65);app.boat_session.cast_or_haul();app.boat_session.reset()
 check(app.boat_session.net==null and app.boat_session.phase=="" and not app.boat_session.locked(),"reset cleans deployed equipment and locks")
 print("BOAT SKILLS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
