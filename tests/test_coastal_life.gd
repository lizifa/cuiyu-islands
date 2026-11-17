extends SceneTree
const Catalog=preload("res://scripts/life/fish_catalog.gd")
var app:Node
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(count:int) -> void:
 for i in range(count):app.inactive=false;await physics_frame
func _initialize():
 if "--test-mode" not in OS.get_cmdline_user_args():quit(1);return
 call_deferred("run")
func run():
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false);await frames(4)
 app.world.forest.set_process(false)
 var birds:Array=app.world.forest.actors.filter(func(actor):return actor.get_meta("mode")=="air")
 check(birds.size()==3,"three animated birds remain in scene")
 var original:Vector3=birds[0].position
 check(birds[1].position.distance_to(original)>1,"birds begin from different bearings")
 var continuous:=true;var heights:=true;var modes:Dictionary={}
 for actor:Node3D in birds:
  var flight:RefCounted=actor.get_meta("flight");flight.rng.seed=123
  for i in range(1800):
   var before:Vector3=actor.position;flight.tick(actor,1.0/30);modes[flight.mode]=true
   continuous=continuous and actor.position.distance_to(before)<.6
   heights=heights and actor.position.y>5 and actor.position.y<16
 check(continuous and heights,"route changes keep position and height continuous")
 check(modes.size()>=2,"birds mix flying and gliding routes")
 var lighting:Node3D=app.world.shore_lights
 app.state.minute=12*60;app.world.sync(app.state)
 check(lighting.night<.01 and lighting.lights.all(func(light):return light.light_energy<.01),"daylight turns shore lights off")
 app.state.minute=23*60;app.world.sync(app.state)
 check(float(app.world.water_shader.get_shader_parameter("dock_light_strength"))>.95,"unshaded water receives a local fishing-light pool")
 check(lighting.night>.95 and lighting.lights.size()==3 and lighting.lights.all(func(light):return light.light_energy>1 and not light.shadow_enabled),"night lights cover shore and fishing without shadow cost")
 for id:String in Catalog.DATA:
  var fish:Node3D=Catalog.create(id,app.world);root.add_child(fish)
  check(fish.has_node("Tail") and fish.get_child(0).mesh.get_surface_count()==1,"distinct fish has compact body and moving tail "+id)
  Catalog.animate(fish,.1);var angle:float=fish.get_node("Tail").rotation.y;Catalog.animate(fish,.3)
  check(absf(angle-fish.get_node("Tail").rotation.y)>.01,"tail swims "+id);fish.queue_free()
 var pet:CharacterBody3D=app.world.companion
 pet.position=Vector3(0,.7,3.2)
 check(is_equal_approx(pet.activity.roam_radius(pet),6),"dog has wider outdoor exploration radius")
 pet.position=Vector3(-1,.68,16.1)
 check(pet.activity.roam_radius(pet)<3,"fishing platform keeps dog in a safe smaller area")
 pet.position=Vector3(-1,.68,17.1)
 check(pet.activity.safe_ground(pet,pet.position),"real deck support is not rejected by duplicated edge margins")
 pet.position=Vector3(-2.5,.68,17.5)
 check(not pet.activity.safe_ground(pet,pet.position),"unsupported body footprint still rejects the sea edge")
 app.world.player.position=Vector3(-1,.68,16.1);app.world.player.fishing_stage="waiting"
 pet.position=Vector3(1,.68,14.5);pet.activity.reset(pet);pet.activity.still_time=3;pet.activity.last_owner=app.world.player.position
 pet.activity.tick(pet,.05)
 check(pet.activity.mode!="follow","idle fishing companion can play from its safe waiting spot")
 app.world.player.fishing_stage=""
 print("COASTAL LIFE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
