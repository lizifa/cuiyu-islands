extends SceneTree
var app: Node
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n: int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func steer(direction: Vector3) -> void:
 var right: Vector3=app.world.camera.global_basis.x;var forward: Vector3=-app.world.camera.global_basis.z
 right.y=0;forward.y=0
 app.joystick.direction=Vector2(direction.dot(right.normalized()),-direction.dot(forward.normalized()))
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=8;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 await frames(3)
 var actor: CharacterBody3D=app.world.player
 var query := PhysicsShapeQueryParameters3D.new()
 var shape := CapsuleShape3D.new();shape.radius=.38;shape.height=1.66
 query.shape=shape;query.collision_mask=1
 for kind: String in ["dog","cat","rabbit"]:
  app.state.profile.pet=kind;app.world.sync(app.state);await frames(3)
  var pet: CharacterBody3D=app.world.companion
  pet.set_physics_process(false);pet.position=Vector3(0,.7,3.2);pet.rotation.y=0
  actor.position=Vector3(0,.7,6.5);actor.velocity=Vector3.ZERO
  steer(Vector3(0,0,-1))
  var clear := true
  for i in range(45):
   await frames(1)
   query.transform=Transform3D(Basis.IDENTITY,actor.position+Vector3.UP*.85)
   for hit: Dictionary in app.world.get_world_3d().direct_space_state.intersect_shape(query,16):
    if hit.collider==pet:clear=false
  app.joystick.reset()
  check(clear and actor.position.z>pet.position.z+.5,"actual walking cannot pass through stationary "+kind)
  actor.position=Vector3(0,.7,3.2);actor.velocity=Vector3.ZERO
  pet.position=Vector3(0,.7,6.5);pet.trail.clear();pet.trail.append(actor.position);pet.last_player=actor.position;pet.last_place=app.world.last_location;pet.petting=0
  pet.set_physics_process(true);clear=true
  for i in range(60):
   await frames(1)
   query.transform=Transform3D(Basis.IDENTITY,actor.position+Vector3.UP*.85)
   for hit: Dictionary in app.world.get_world_3d().direct_space_state.intersect_shape(query,16):
    if hit.collider==pet:clear=false
  check(clear,"following "+kind+" cannot move through player")
 for animal: Node3D in app.world.forest.actors:
  if animal.get_meta("mode")=="land":check(animal is CharacterBody3D and animal.collision_layer==1 and animal.find_child("AnimalBodyCollider",true,false)!=null,"woodland animal has real solid body")
 app.queue_free();await process_frame
 print("ANIMAL OBSTACLES: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
