extends Node3D
## Three furnished northern rooms; the southern half stays an empty connecting hall.
var room: Node3D
var door: AnimatableBody3D
const Dimensions=preload("res://scripts/life/villa_dimensions.gd")
var door_origin := Vector3(4.95,Dimensions.BASE+Dimensions.DOOR_HEIGHT*.5,-.6)
var door_slide := 0.0
func setup(owner_room: Node3D) -> void:
 room=owner_room;name="UpstairsRooms"
 room.block(Vector3(-1,Dimensions.WALL_CENTER,-2.7),Vector3(.18,Dimensions.CLEAR_HEIGHT,5.6),"plaster",true).name="BedroomPartition"
 room.block(Vector3(3.5,Dimensions.WALL_CENTER,-3.25),Vector3(.18,Dimensions.CLEAR_HEIGHT,5.1),"plaster",true).name="BathroomPartition"
 _bedroom();_coat_rack();_computer();_bathroom()
func _bedroom() -> void:
 room.block(Vector3(-4.8,.69,-3),Vector3(5.2,.025,5.3),"rug").name="BedroomGreenRug"
 var bed:Node3D=room.furniture("bed-6e10e8",room.BED_CENTER,0,1.45,Vector2.ZERO);bed.name="MasterBed"
 _fit_bed_height(bed)
 preload("res://scripts/life/prop_collision.gd").convex(bed)
 for x:float in [-6.45,-3.15]:room.block(Vector3(x,1,-5.12),Vector3(.55,.6,.55),"teak",true)
 room.block(Vector3(-6.45,1.52,-5.12),Vector3(.045,.44,.045),"metal")
 # 床头灯：灯罩 + 一盏点光源，默认关着，技能里可以开/关。
 var lamp_shade:MeshInstance3D=room._cylinder(room,Vector3(-6.45,1.8,-5.12),.2,.25,room.palette.cream,.14)
 lamp_shade.name="BedsideLampShade"
 var lamp:=OmniLight3D.new();lamp.name="BedsideLampLight";room.add_child(lamp)
 lamp.position=Vector3(-6.45,1.72,-5.05);lamp.light_color=Color("ffd7a0");lamp.light_energy=1.6
 lamp.omni_range=4.4;lamp.omni_attenuation=1.4;lamp.shadow_enabled=false;lamp.visible=false
 room.set_meta("bedside_lamp_on",false)
 # 被子/枕头记住原始摆法，起床后可以「整理床铺」把它们拉回原位。
 for part_name:String in ["duvet","pillows"]:
  var part:Node3D=bed.find_child(part_name,true,false)
  if part!=null:
   part.set_meta("rest_position",part.position);part.set_meta("rest_rotation",part.rotation)
 room.set_meta("bed_tidy",true)
 room.point("villa_sleep","床上休息",room.BED_STAND,1.6)
 var wardrobe:=Node3D.new();wardrobe.name="BedroomWardrobe";room.add_child(wardrobe);wardrobe.position=Vector3(-1.75,.7,-4.8)
 _box(wardrobe,Vector3(0,1.2,0),Vector3(1.3,2.4,.8),room.palette.teak)
 for x:float in [-.32,.32]:
  _box(wardrobe,Vector3(x,1.2,.407),Vector3(.62,2.3,.035),room.palette.teak)
  _box(wardrobe,Vector3(x*.18,1.2,.44),Vector3(.035,.22,.035),room.palette.metal)
 _solid(wardrobe,Vector3(0,1.2,0),Vector3(1.3,2.4,.85))
 room.point("villa_storage","整理衣柜",Vector3(-1.8,.7,-3.6),1.3)
func _coat_rack() -> void:
 var rack:=Node3D.new();rack.name="BedroomCoatRack";room.add_child(rack);rack.position=Vector3(-1.95,.7,-2.75)
 room._cylinder(rack,Vector3(0,.025,0),.24,.05,room.palette.teak)
 room._cylinder(rack,Vector3(0,1.075,0),.045,2.15,room.palette.teak)
 _box(rack,Vector3(0,1.65,0),Vector3(.62,.055,.055),room.palette.teak)
 for x:float in [-.25,.25]:room._cylinder(rack,Vector3(x,1.72,0),.035,.16,room.palette.teak)
 var stand:=Marker3D.new();stand.name="Approach";rack.add_child(stand);stand.position=Vector3(-1,.005,0)
 var hook:=Marker3D.new();hook.name="Hook";rack.add_child(hook);hook.position=Vector3(-.25,1.65,0)
 var body:=StaticBody3D.new();rack.add_child(body)
 var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.24;shape.height=2.15;collider.shape=shape;collider.position.y=1.075;body.add_child(collider)
func _computer() -> void:
 var desk:=Node3D.new();desk.name="ComputerDesk";room.add_child(desk);desk.position=Vector3(.8,.7,-4.1)
 _box(desk,Vector3(0,.8,0),Vector3(3.2,.12,1),room.palette.teak)
 _box(desk,Vector3(-1.2,.39,0),Vector3(.65,.78,.94),room.palette.teak)
 for y:float in [.2,.43,.66]:_box(desk,Vector3(-1.2,y,.48),Vector3(.25,.025,.035),room.palette.metal)
 _solid(desk,Vector3(0,.4,0),Vector3(3.2,.8,1))
 # Open shelves are built into the right pedestal.
 for x:float in [.9,1.55]:_box(desk,Vector3(x,.39,0),Vector3(.055,.78,.95),room.palette.teak)
 for y:float in [.04,.29,.54,.76]:_box(desk,Vector3(1.225,y,0),Vector3(.65,.045,.95),room.palette.teak)
 for shelf in range(3):
  for i in range(5):_box(desk,Vector3(.99+i*.115,.15+shelf*.245,.33),Vector3(.08,.18,.25),[room.palette.rug,room.palette.cream,room.palette.green][i%3])
 var display:=Node3D.new();display.name="SmallBorderlessMonitor";desk.add_child(display)
 _box(display,Vector3(0,1.21,-.28),Vector3(.8,.45,.025),room.palette.dark)
 var screen:=MeshInstance3D.new();screen.name="ComputerScreen";var quad:=QuadMesh.new();quad.size=Vector2(.77,.42);screen.mesh=quad;display.add_child(screen);screen.position=Vector3(0,1.21,-.261);screen.material_override=room.palette.dark
 var media=preload("res://scripts/life/home_television.gd").new();media.name="HomeComputer";room.add_child(media);media.setup(room,screen,1)
 room.point("villa_computer","打开电脑",Vector3(.8,.705,-1.0),1.7)
 _box(display,Vector3(0,.93,-.28),Vector3(.04,.16,.04),room.palette.dark)
 _box(display,Vector3(0,.875,-.23),Vector3(.34,.03,.2),room.palette.dark)
 var keyboard:=Node3D.new();keyboard.name="Keyboard";desk.add_child(keyboard)
 _box(keyboard,Vector3(0,.875,.18),Vector3(.64,.025,.23),room.palette.dark)
 var keys:=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
 var key:=BoxMesh.new();key.size=Vector3(.045,.012,.045);key.material=room.palette.metal;multi.mesh=key;multi.instance_count=30
 for i in range(30):multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-.27+(i%10)*.06,.895,.12+floori(i/10.)*.06)))
 keys.multimesh=multi;keyboard.add_child(keys)
 var speaker:=Node3D.new();speaker.name="DesktopSpeaker";desk.add_child(speaker)
 _box(speaker,Vector3(-1.25,1.0,-.28),Vector3(.2,.3,.18),room.palette.dark)
 for y:float in [.94,1.07]:
  var cone:MeshInstance3D=room._cylinder(speaker,Vector3(-1.25,y,-.185),.04,.008,room.palette.metal)
  cone.rotation.x=PI/2
 _gaming_chair()
func _gaming_chair() -> void:
 var black:Material=room.world.material(Color("20262a"))
 var root:=Node3D.new();root.name="ComputerGamingChair";room.add_child(root);root.position=Vector3(.8,.7,-2.7)
 _box(root,Vector3(0,.46,0),Vector3(.62,.12,.58),black)
 _box(root,Vector3(0,.96,.25),Vector3(.6,.9,.13),black)
 _box(root,Vector3(0,1.43,.25),Vector3(.38,.2,.15),black)
 _box(root,Vector3(0,.23,0),Vector3(.08,.46,.08),room.palette.metal)
 for side in [-1,1]:_box(root,Vector3(side*.37,.7,.03),Vector3(.08,.08,.5),black)
 for i in range(5):
  var angle:=i*TAU/5
  var leg:MeshInstance3D=_box(root,Vector3(sin(angle)*.19,.08,cos(angle)*.19),Vector3(.06,.045,.4),room.palette.metal)
  leg.rotation.y=angle
  room._cylinder(root,Vector3(sin(angle)*.37,.045,cos(angle)*.37),.045,.06,black)
 _solid(root,Vector3(0,.75,.06),Vector3(.8,1.5,.75))
func _bathroom() -> void:
 var blue:Material=room.world.material(Color("4d91ad"))
 var mat:MeshInstance3D=room.world.box(room,Vector3(5.65,.69,-3.245),Vector3(4.08,.025,4.89),blue);mat.name="FullBathroomBlueMat"
 room.furniture("bath-fad968",Vector3(5.7,.7,-4.7),PI/2,1.25,Vector2(2.2,1)).name="BathroomTub"
 room.block(Vector3(7,1.2,-2.5),Vector3(.7,1,1),"cream",true).name="BathroomVanity"
 room._cylinder(room,Vector3(7,1.75,-2.5),.29,.12,room.palette.cream,.32)
 room._cylinder(room,Vector3(7,1.815,-2.5),.25,.005,blue)
 room.block(Vector3(7.28,1.87,-2.5),Vector3(.04,.25,.04),"metal")
 room.block(Vector3(7.18,2.0,-2.5),Vector3(.22,.04,.04),"metal")
 room.block(Vector3(7.55,1.95,-2.5),Vector3(.04,1,1),"glass").name="BathroomMirror"
 var toilet:=Node3D.new();toilet.name="BathroomToilet";room.add_child(toilet);toilet.position=Vector3(3.95,.7,-4.9)
 _box(toilet,Vector3(0,.65,-.15),Vector3(.45,.6,.24),room.palette.cream)
 room._cylinder(toilet,Vector3(0,.24,.18),.21,.48,room.palette.cream,.27)
 var seat:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.16;ring.outer_radius=.28;ring.rings=12;ring.ring_segments=16
 seat.mesh=ring;seat.material_override=room.palette.cream;toilet.add_child(seat);seat.position=Vector3(0,.49,.18);seat.scale=Vector3(1,.35,1.15)
 room._cylinder(toilet,Vector3(0,.48,.18),.15,.003,room.palette.glass)
 _box(toilet,Vector3(0,.96,-.15),Vector3(.1,.025,.06),room.palette.metal)
 _solid(toilet,Vector3(0,.45,.05),Vector3(.58,.9,.85))
 room.point("villa_bath","洗个热水澡",Vector3(5,.7,-2.5),1.3)
 # Pocket-style sliding entrance stays out of the fixtures' footprints.
 room.block(Vector3(4.95,Dimensions.BASE+(Dimensions.DOOR_HEIGHT+Dimensions.CLEAR_HEIGHT)*.5,-.8),Vector3(1.32,Dimensions.CLEAR_HEIGHT-Dimensions.DOOR_HEIGHT,.12),"plaster",true).name="BathroomDoorLintel"
 for spec:Vector2 in [Vector2(3.9,.8),Vector2(6.7,2.2)]:room.block(Vector3(spec.x,Dimensions.WALL_CENTER,-.8),Vector3(spec.y,Dimensions.CLEAR_HEIGHT,.12),"plaster",true)
 for x:float in [4.32,5.58]:room.block(Vector3(x,Dimensions.BASE+Dimensions.DOOR_HEIGHT*.5,-.69),Vector3(.06,Dimensions.DOOR_HEIGHT,.1),"dark")
 room.block(Vector3(4.95,Dimensions.BASE+Dimensions.DOOR_HEIGHT+.03,-.69),Vector3(1.32,.06,.1),"dark")
 room.block(Vector3(5.575,Dimensions.BASE+Dimensions.DOOR_HEIGHT+.03,-.56),Vector3(2.5,.04,.06),"dark")
 door=AnimatableBody3D.new();door.name="BathroomSlidingDoor";room.add_child(door);door.position=door_origin;door.sync_to_physics=false
 var glass:StandardMaterial3D=room.palette.teak.duplicate() # Opaque privacy door, closed from the landing.
 _box(door,Vector3.ZERO,Vector3(1.14,Dimensions.DOOR_HEIGHT,.05),glass)
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.14,Dimensions.DOOR_HEIGHT,.05);collider.shape=shape;door.add_child(collider)
func _box(parent:Node3D,pos:Vector3,size:Vector3,mat:Material) -> MeshInstance3D:
 return room.world.box(parent,pos,size,mat)
func _solid(parent:Node3D,pos:Vector3,size:Vector3) -> void:
 var body:=StaticBody3D.new();parent.add_child(body);body.position=pos
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider)
func _physics_process(delta:float) -> void:
 if door==null or room.world.player==null or not room.world.player.allowed:return
 var local:Vector3=room.to_local(room.world.player.global_position)
 var near:bool=absf(local.y-.7)<1.5 and (Vector2(local.x-door_origin.x,local.z-door_origin.z).length()<1.25 or (local.x>3.5 and local.z<-.8))
 var pet:Node3D=room.world.companion
 if pet!=null and pet.visible:
  var p:Vector3=room.to_local(pet.global_position)
  near=near or (absf(p.y-.7)<1.5 and Vector2(p.x-door_origin.x,p.z-door_origin.z).length()<1.8)
 door_slide=move_toward(door_slide,1.25 if near else 0,delta*1.8)
 door.position=door_origin+Vector3(door_slide,0,0)

func _fit_bed_height(bed:Node3D) -> void:
 # Bake the height correction into owned meshes so static collision keeps unit scaling.
 var squash:=Basis.from_scale(Vector3(1,.65,1))
 for mesh:MeshInstance3D in bed.find_children("*","MeshInstance3D",true,false):
  var relative:Transform3D=bed.global_transform.affine_inverse()*mesh.global_transform
  var transform:Basis=relative.basis.inverse()*squash*relative.basis
  var normal_transform:Basis=transform.inverse().transposed()
  var original:Mesh=mesh.mesh;var fitted:=ArrayMesh.new()
  for surface in range(original.get_surface_count()):
   var arrays:Array=original.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in range(vertices.size()):
    vertices[i]=relative.affine_inverse()*(squash*(relative*vertices[i]))
    if not normals.is_empty():normals[i]=(normal_transform*normals[i]).normalized()
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
   fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   fitted.surface_set_material(surface,mesh.get_active_material(surface))
  mesh.mesh=fitted
