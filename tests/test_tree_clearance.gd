extends SceneTree
var app: Node
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
 if ok: passed+=1
 else: failed+=1;push_error(message)
func frames(count: int) -> void:
 for i in range(count): app.inactive=false;await physics_frame
func steer(direction: Vector3) -> void:
 var right: Vector3=app.world.camera.global_basis.x
 var forward: Vector3=-app.world.camera.global_basis.z
 right.y=0;forward.y=0
 app.joystick.direction=Vector2(direction.dot(right.normalized()),-direction.dot(forward.normalized()))
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=8;Engine.physics_ticks_per_second=120
 app=load("res://scenes/life_main.tscn").instantiate();root.add_child(app);app.set_process(false)
 await frames(3)
 var world: Node3D=app.world
 var actor: CharacterBody3D=world.player
 var ground := StaticBody3D.new()
 var collider := CollisionShape3D.new();var floor_shape := BoxShape3D.new()
 floor_shape.size=Vector3(20,.2,20);collider.shape=floor_shape;ground.add_child(collider)
 world.add_child(ground);ground.position=Vector3(40,19.9,40)
 actor.terrain_height=func(_x,_z):return 20.0
 actor.terrain_walkable=func(_p):return true
 var query := PhysicsShapeQueryParameters3D.new()
 var shape := CylinderShape3D.new();shape.radius=actor.TREE_RADIUS-.01;shape.height=actor.TREE_HEIGHT-.02
 query.shape=shape;query.collision_mask=8
 for id: String in ["broadleaf-oak-997c22","broad-canopy-shade-tree-e7c4a2","ornamental-front-yard-tree-c6781a","young-pine-0d7695","birch-tree-181b33"]:
  for size_value: float in [.65,1.05]:
   var tree: Node3D=load("res://assets/polyfork/"+id+".glb").instantiate()
   world.add_child(tree);tree.position=Vector3(40,20,40);tree.scale=Vector3.ONE*size_value;tree.rotation.y=.73
   world._apply_vertex_colors(tree)
   preload("res://scripts/life/prop_collision.gd").tree(tree,id)
   await frames(2)
   check(tree.find_child("TreeObstacle",true,false).get_child_count()>=2,"scaled tree has head-height segmented geometry: "+id)
   for direction_id in range(8):
    var direction := Vector3(cos(direction_id*TAU/8),0,sin(direction_id*TAU/8))
    actor.position=tree.position+direction*(float(tree.get_meta("solid_radius"))+1.3)+Vector3.UP*.03
    actor.velocity=Vector3.ZERO;steer(-direction)
    var clear := true
    for step in range(35):
     await frames(1)
     query.transform=Transform3D(Basis.IDENTITY,actor.position+Vector3.UP*(actor.TREE_HEIGHT*.5+.02))
     if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false
    check(clear,"head/shoulders stay outside tree for every moving frame: %s scale %.2f direction %d"%[id,size_value,direction_id])
    app.joystick.reset()
   actor.position=tree.position+Vector3(0,.03,float(tree.get_meta("solid_radius"))+actor.TREE_RADIUS+.3)
   actor.velocity=Vector3.ZERO
   var work_clear: bool = actor.start_work("伐木",tree.position)
   var joint_query := PhysicsShapeQueryParameters3D.new()
   var joint_shape := SphereShape3D.new();joint_shape.radius=.1
   joint_query.shape=joint_shape;joint_query.collision_mask=8
   for step in range(32):
    await frames(1)
    if actor.pose_skeleton==null:work_clear=false;continue
    for bone_name: String in ["Head","Spine","RightArm","RightForeArm","RightHand"]:
     var bone: int=actor._bone(bone_name)
     if bone<0:work_clear=false;continue
     var joint: Vector3=(actor.pose_skeleton.global_transform*actor.pose_skeleton.get_bone_global_pose(bone)).origin
     joint_query.transform=Transform3D(Basis.IDENTITY,joint)
     if not world.get_world_3d().direct_space_state.intersect_shape(joint_query,1).is_empty():work_clear=false
   check(work_clear,"actual chopping head, torso and arm joints remain outside wood: %s %.2f"%[id,size_value])
   actor.cancel_work()
   tree.hide();tree.get_node("TreeObstacle").collision_layer=0;await frames(1)
 var nearby_tree: Node3D=world.forest.trees[0]
 world.forest.reveal_player(nearby_tree.position+Vector3(0,3,5),nearby_tree.position+Vector3.UP)
 var leaf_faded := false
 var bark_solid := true
 for mesh: MeshInstance3D in nearby_tree.find_children("*","MeshInstance3D",true,false):
  var leaf_surfaces: Array=mesh.get_meta("foliage_surfaces",[])
  for surface in range(mesh.mesh.get_surface_count()):
   var material: StandardMaterial3D=mesh.get_active_material(surface)
   if surface in leaf_surfaces:leaf_faded=leaf_faded or material.albedo_color.a<.3
   else:bark_solid=bark_solid and material.albedo_color.a==1
 check(leaf_faded,"nearby foliage fades independently")
 check(bark_solid,"tree bark stays opaque while nearby leaves fade")
 actor.terrain_height=world.terrain_height;actor.terrain_walkable=world.terrain_walkable
 actor.position=Vector3(0,.7,3.2);actor.velocity=Vector3.ZERO
 for point: Dictionary in world.interaction_points:
  if point.kind=="伐木":check(point.min_range>=actor.TREE_RADIUS+.3 and point.range>point.min_range+.5,"all chopping points reserve an animation approach ring")
 app.queue_free();await process_frame
 print("TREE CLEARANCE: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
