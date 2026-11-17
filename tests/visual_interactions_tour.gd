extends "res://tests/visual_scene_tour.gd"
func run() -> void:
 output="/tmp/qgyh-visual-interactions"
 DirAccess.make_dir_recursive_absolute(output)
 app=load("res://scenes/life_main.tscn").instantiate();app.test_mode=true;root.add_child(app)
 app._close_drawers();app.paused=false
 app.state.buildings["小船"]=true
 await place("island",app.world.DOCK,app.world.MOORING+Vector3(0,1,10))
 assert(app.world.board_boat(app.state),"boat boarding")
 await capture("boat-first-person");app.world._set_boating(false)
 await place("island",Vector3(0,.7,3.2),Vector3(0,1.2,0))
 if app.world.companion!=null:
  app.world.companion.position=app.world.player.position+Vector3(1,0,0)
  assert(app.world.pet_companion(app.state),"pet interaction")
  await frames(45);await capture("pet-crouch");app.world.player.cancel_pet()
 await place("villa",Vector3(-5.9,.705,-3.3),Vector3(-5.9,1.5,-4.3))
 assert(app.home_routine.begin_sink("water"),"water interaction")
 await frames(90);await capture("water-cup");app.home_routine.cancel()
 app.state.inventory["鲜鱼"]=4
 await place("villa",Vector3(-3.4,.705,-3.3),Vector3(-3.4,1.4,-4.4))
 assert(app.home_routine.begin_sink("cooking"),"cooking interaction")
 await frames(60);await capture("cooking-pot");app.home_routine.cancel()
 var dining:Dictionary=app.world.find_interaction("villa_eat")
 print("DINING POINT: ",dining)
 if not dining.is_empty():
  await place("villa",dining.pos,Vector3(2,1.4,0))
  assert(app.sofa_session.begin_dining(),"dining interaction")
  app.sofa_session.begin_eating();await frames(25);await capture("dining-food");app.sofa_session.finish()
 await place("island",Vector3(0,.7,3.2),Vector3(0,2,-8))
 app._open_tasks();await capture("task-panel");app._close_drawers()
 app._open_map();await capture("large-map");app._open_map();app._close_drawers()
 app._update_context();await capture("playable-test-state")
 print("VISUAL INTERACTIONS COMPLETE: ",records.size()," checkpoints")
