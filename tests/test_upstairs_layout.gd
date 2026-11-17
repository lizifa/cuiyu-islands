extends SceneTree
const VillaDimensions=preload("res://scripts/life/villa_dimensions.gd")
var passed := 0
var failed := 0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 Engine.time_scale=6;Engine.physics_ticks_per_second=120
 var state=load("res://scripts/life/life_state.gd").new();state.location="villa";state.home_floor=1;state.player_position=[0,(VillaDimensions.UPPER_FLOOR+.03),3]
 var world=load("res://scripts/life/life_world.gd").new();root.add_child(world);world.sync(state)
 await physics_frame;await physics_frame
 var room=world.villa_room;var suite=room.get_node("UpstairsRooms")
 var beds=0;var sofas=0
 for node:Node in room.find_children("*","Node3D",true,false):
  if node.scene_file_path.ends_with("bed-6e10e8.glb"):beds+=1
  if node.scene_file_path.ends_with("sofa-9c0e7e.glb"):sofas+=1
 check(beds==1,"only one bed upstairs")
 check(sofas==0,"no sofa in lower hall")
 var bed:Node3D=room.get_node("MasterBed");var bounds=AABB();var first=true
 for mesh:MeshInstance3D in bed.find_children("*","MeshInstance3D",true,false):
  var a:AABB=mesh.global_transform*mesh.mesh.get_aabb();bounds=a if first else bounds.merge(a);first=false
 check(absf(bounds.position.z+5.69)<.03,"headboard against north wall")
 check(room.has_node("BedroomWardrobe") and room.has_node("BedroomGreenRug"),"wardrobe and green bedroom rug")
 var desk:Node3D=room.get_node("ComputerDesk")
 check(desk.has_node("Keyboard") and desk.has_node("DesktopSpeaker"),"desk has keyboard and small speaker")
 var monitor:Node3D=desk.get_node("SmallBorderlessMonitor")
 var panel:MeshInstance3D=monitor.get_child(0)
 check(panel.mesh.size.x<=1 and panel.mesh.size.x<3.2*.4,"small monitor occupies less than forty percent of desk")
 check(room.has_node("ComputerGamingChair"),"black gaming chair")
 check(room.has_node("BathroomTub") and room.has_node("BathroomVanity") and room.has_node("BathroomToilet"),"all three bathroom fixtures")
 check(room.get_node("BathroomTub").position==Vector3(5.7,.7,-4.7) and room.get_node("BathroomVanity").position==Vector3(7,1.2,-2.5),"existing bath and vanity positions retained")
 check(room.get_node("FullBathroomBlueMat").mesh.size.z>4.8,"blue mat fills bathroom")
 var query=PhysicsShapeQueryParameters3D.new();var shape=CylinderShape3D.new();shape.radius=.4;shape.height=1.68;query.shape=shape;query.collision_mask=1;query.exclude=[world.player.get_rid()]
 if world.companion!=null:query.exclude.append(world.companion.get_rid());world.companion.set_physics_process(false);world.companion.position=Vector3(0,(VillaDimensions.UPPER_FLOOR+.03),4.5)
 for x:float in [-6.5,-3,0,3,6]:
  for z:float in [.6,1.5,2.5,3.5,4.6]:
   query.transform=Transform3D(Basis.IDENTITY,Vector3(x,(VillaDimensions.UPPER_FLOOR+.895),z))
   check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"empty southern passage %s %s"%[x,z])
 for p:Vector3 in [Vector3(-7.15,(VillaDimensions.UPPER_FLOOR+.895),-3.5),Vector3(-3.0,(VillaDimensions.UPPER_FLOOR+.895),-3.6),Vector3(-4.8,(VillaDimensions.UPPER_FLOOR+.895),-1.8),Vector3(1.1,(VillaDimensions.UPPER_FLOOR+.895),-1.7)]:
  query.transform=Transform3D(Basis.IDENTITY,p)
  check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"bedside/withdrawn chair clearance %s"%p)
 check(is_equal_approx(world.find_interaction("villa_stairs").pos.z,2.6),"stairs connect to lower right hallway")
 world.player.position=Vector3(5,(VillaDimensions.UPPER_FLOOR+.03),.5)
 for i in range(30):await physics_frame
 check(suite.door_slide>1.2,"bathroom sliding door opens before arrival")
 world.player.position=Vector3(0,(VillaDimensions.UPPER_FLOOR+.03),3)
 for i in range(30):await physics_frame
 check(suite.door_slide<.01,"bathroom door closes after leaving")
 var door_query=PhysicsShapeQueryParameters3D.new();var slab=BoxShape3D.new();slab.size=Vector3(1.14,2.1,.05);door_query.shape=slab;door_query.collision_mask=1;door_query.exclude=[suite.door.get_rid(),world.player.get_rid()]
 if world.companion!=null:door_query.exclude.append(world.companion.get_rid())
 for shift:float in [0,.25,.5,.75,1.,1.25]:
  door_query.transform=Transform3D(Basis.IDENTITY,room.to_global(suite.door_origin+Vector3(shift,0,0)))
  check(world.get_world_3d().direct_space_state.intersect_shape(door_query,1).is_empty(),"door travel clears bathroom fixtures")
 print("UPSTAIRS LAYOUT: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
