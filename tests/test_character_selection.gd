extends SceneTree
const Catalog=preload("res://scripts/life/character_catalog.gd")
const State=preload("res://scripts/life/life_state.gd")
var checks:=0
var failed:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);app.set_physics_process(false)
 await process_frame
 var before=app.state.inventory.duplicate(true);var coins=app.state.coins
 app._open_arrival()
 check(app.arrival.character_wheel.values.size()==12,"first entry offers all twelve appearances")
 for id in Catalog.CHARACTERS:
  app.arrival._select_character(id)
  check(app.arrival.character_wheel.get_value()==id,id+" selection highlighted")
  check(app.arrival.preview.get_child(0).get_meta("character_id")==id,id+" 3D preview matches selection")
  check(app.arrival.confirm(),id+" confirmation saves")
  check(app.world.player.visual.get_meta("character_id")==id,id+" actual character matches preview")
  var restored=State.new()
  check(restored.restore(app.state.snapshot()) and restored.profile.character_id==id,id+" survives save restore")
  check(app.state.inventory==before and app.state.coins==coins,id+" preserves progress")
  app._open_arrival()
  check(app.arrival.character_id==id,id+" reopening restores choice")
 app._close_drawers()
 app.queue_free();await process_frame
 print("CHARACTER SELECTION: ",checks," checks, ",failed," failed")
 quit(1 if failed else 0)
