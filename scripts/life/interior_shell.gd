extends Node3D
## Opaque indoor envelope shared by the two floors and the enclosed stair hall.
const BOUNDS := preload("res://scripts/life/villa_dimensions.gd").BOUNDS
const BASE := .675
const Dimensions=preload("res://scripts/life/villa_dimensions.gd")
const TOP := Dimensions.TOP
var upper_visuals:Array[Node3D]=[]
func setup(world:Node3D) -> void:
 name="VillaInteriorEnvelope"
 var plaster:Material=world.material(Color("e9e4ce"))
 var floor_mat:Material=world.material(Color("c4a77c"))
 var ceiling:Material=world.material(Color("e9e4d5"))
 _panel(world,Vector3(-11.08,(TOP+BASE-.16)*.5,6.1),Vector3(.2,TOP-BASE+.16,24.6),plaster,true)
 _panel(world,Vector3(14.6,(TOP+BASE-.16)*.5,6.1),Vector3(.2,TOP-BASE+.16,24.6),plaster,true)
 _panel(world,Vector3(1.76,(TOP+BASE-.16)*.5,-6.2),Vector3(25.68,TOP-BASE+.16,.2),plaster,true)
 for floor_index in range(2):
  var floor_y:float=BASE+floor_index*Dimensions.RISE
  var center_x:float=0 if floor_index==0 else Dimensions.BALCONY_DOOR_X
  var width:float=3.2 if floor_index==0 else Dimensions.BALCONY_DOOR_WIDTH
  var left:float=center_x-width*.5;var right:float=center_x+width*.5
  for span:Vector2 in [Vector2(-11.08,left),Vector2(right,14.6)]:
   # The second-floor glazed bay also remains transparent from the interior.
   var spans:Array[Vector2]=[span]
   if floor_index==1 and span.x<1.25 and span.y>1.25:spans=[Vector2(span.x,1.25),Vector2(1.25,span.y)]
   elif floor_index==1 and span.x<7.75 and span.y>7.75:spans=[Vector2(span.x,7.75),Vector2(7.75,span.y)]
   for piece:Vector2 in spans:
    var material:Material=plaster
    if floor_index==1 and piece.x>=1.25 and piece.y<=7.75:
     var glass:=ShaderMaterial.new();glass.shader=preload("res://shaders/privacy_glass.gdshader");material=glass
    _panel(world,Vector3((piece.x+piece.y)*.5,floor_y+Dimensions.CLEAR_HEIGHT*.5,18.4),Vector3(piece.y-piece.x,Dimensions.CLEAR_HEIGHT,.2),material,true)
  _panel(world,Vector3(center_x,floor_y+(Dimensions.DOOR_HEIGHT+Dimensions.CLEAR_HEIGHT)*.5,18.4),Vector3(width,Dimensions.CLEAR_HEIGHT-Dimensions.DOOR_HEIGHT,.2),plaster,true)
 _panel(world,Vector3(1.76,TOP+.06,6.1),Vector3(25.68,.12,24.6),ceiling,true)
 # Ceiling borders and restrained light panels give the closed rooms a visible finish.
 for floor_index in range(2):
  var y:float=Dimensions.CEILING+floor_index*Dimensions.RISE-.12
  var cream:Material=world.material(Color("e7dfcd"))
  for x:float in [Dimensions.MAIN_LEFT+.32,Dimensions.MAIN_RIGHT-.32]:_panel(world,Vector3(x,y,6.1),Vector3(.48,.18,23.8),cream)
  for z:float in [-5.5,17.7]:_panel(world,Vector3(Dimensions.MAIN_CENTER_X,y,z),Vector3(Dimensions.MAIN_WIDTH-.4,.18,.48),cream)
  for z:float in [0,8,15]:
   world.box(self,Vector3(-2,y+.015,z),Vector3(1.2,.06,.8),world.material(Color("fff1cc")))
 # Main rooms have a first-floor ceiling; the stairwell remains open vertically.
 _panel(world,Vector3(Dimensions.MAIN_CENTER_X,Dimensions.CEILING+.05,6.1),Vector3(Dimensions.MAIN_WIDTH,.1,24.4),ceiling,true)
 _panel(world,Vector3(1.76,BASE-.23,6.1),Vector3(25.68,.36,24.6),floor_mat)
 _panel(world,Vector3(11.25,BASE-.18,6.1),Vector3(6.5,.36,24.4),floor_mat)
 upper_visuals.append(_panel(world,Vector3(11.25,Dimensions.UPPER_FLOOR-.18,(Dimensions.NORTH+Dimensions.STAIR_OPENING_NORTH)*.5),Vector3(6.5,.36,Dimensions.STAIR_OPENING_NORTH-Dimensions.NORTH),floor_mat,false,1))
 upper_visuals.append(_panel(world,Vector3(11.25,Dimensions.UPPER_FLOOR-.18,10.95),Vector3(6.5,.36,14.9),floor_mat,false,1))
 upper_visuals.append(_panel(world,Vector3(13.975,Dimensions.UPPER_FLOOR-.18,(Dimensions.STAIR_OPENING_NORTH+3.4)*.5),Vector3(1.05,.36,3.4-Dimensions.STAIR_OPENING_NORTH),floor_mat,false,1))
 # Guard rails make the upper stair opening legible, leaving the top-flight entrance clear.
 var rail_mat:Material=world.material(Color("36515a"))
 _rail(world,Vector3(10.7,Dimensions.UPPER_FLOOR+.5,Dimensions.STAIR_OPENING_NORTH+.05),Vector3(5.4,1,.07),rail_mat)
 _rail(world,Vector3(9.25,Dimensions.UPPER_FLOOR+.5,Dimensions.STAIR_FRONT+.05),Vector3(2.5,1,.07),rail_mat)
 _rail(world,Vector3(13.4,Dimensions.UPPER_FLOOR+.5,(Dimensions.STAIR_OPENING_NORTH+Dimensions.STAIR_FRONT+.05)*.5),Vector3(.07,1,Dimensions.STAIR_FRONT+.05-Dimensions.STAIR_OPENING_NORTH),rail_mat)
 # The room owns two automatic glass leaves; the outer envelope shares their opening.
 for x:float in [-1.64,1.64]:world.box(self,Vector3(x,BASE+Dimensions.DOOR_HEIGHT*.5,18.23),Vector3(.08,Dimensions.DOOR_HEIGHT,.12),world.material(Color("946e4c")))
 world.box(self,Vector3(0,BASE+Dimensions.DOOR_HEIGHT+.04,18.23),Vector3(3.36,.08,.12),world.material(Color("946e4c")))
 for y:float in [2.8,2.8+Dimensions.RISE]:
  var light:=OmniLight3D.new();light.position=Vector3(10.5,y,1);light.light_color=Color("fff0d3");light.light_energy=.5;light.omni_range=5;add_child(light)
func _panel(world:Node3D,pos:Vector3,size:Vector3,mat:Material,cutaway:bool=false,floor_index:int=-1) -> MeshInstance3D:
 var visual:MeshInstance3D=world.box(self,pos,size,mat)
 if cutaway:visual.layers=2
 var body:=StaticBody3D.new();body.name="InteriorBoundary";body.collision_layer=17;body.set_meta("camera_cutaway",cutaway);body.set_meta("camera_floor",floor_index);add_child(body);body.position=pos
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider)
 return visual

func set_upper_visible(value:bool) -> void:
 for visual:Node3D in upper_visuals:visual.visible=value

func _rail(world:Node3D,pos:Vector3,size:Vector3,mat:Material) -> void:
 var visual_root:=Node3D.new();visual_root.name="UpperFloorGuard";add_child(visual_root);upper_visuals.append(visual_root)
 var along_x:bool=size.x>size.z
 var length:float=maxf(size.x,size.z)
 world.box(visual_root,pos+Vector3.UP*.46,Vector3(size.x,.08,size.z),mat)
 var count:int=ceili(length/.65)
 for i in range(count+1):
  var offset:float=lerpf(-length*.5,length*.5,float(i)/count)
  world.box(visual_root,pos+(Vector3(offset,0,0) if along_x else Vector3(0,0,offset)),Vector3(.06,1,.06),mat)
 var body:=StaticBody3D.new();body.position=pos;body.collision_layer=17;body.set_meta("camera_floor",1);add_child(body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)

