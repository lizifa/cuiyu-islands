extends Node3D
## Camera-local hands and held objects. Animation never moves the camera.
const LAYER:=128
var world:Node3D
var palms:Array[Node3D]=[]
var arms:Array[MeshInstance3D]=[]
var forearms:Array[MeshInstance3D]=[]
var cloth:Node3D
var cup:Node3D
var throw_from:=Vector3.INF
var bottle:Node3D
var spoon:Node3D
var food:MeshInstance3D
var axe:Node3D
var right_grip:=Vector3(.23,-.28,-.62)
var left_grip:=Vector3(-.18,-.3,-.64)
func setup(owner_world:Node3D) -> void:
 world=owner_world;name="FirstPersonHands"
 for side:int in [-1,1]:
  arms.append(_cylinder(self,.065,Color("526b60")))
  forearms.append(_cylinder(self,.048,Color("d3a17c")))
  var palm:=Node3D.new();add_child(palm);palms.append(palm)
  _box(palm,Vector3.ZERO,Vector3(.09,.055,.13),Color("d3a17c"))
  for i in range(4):
   var finger:=_cylinder(palm,.012,Color("d3a17c"));_segment(finger,Vector3((i-1.5)*.021,0,-.055),Vector3((i-1.5)*.021,-.008,-.13+absf(i-1.5)*.012))
  var thumb:=_cylinder(palm,.016,Color("d3a17c"));_segment(thumb,Vector3(side*-.045,0,.02),Vector3(side*-.075,-.01,-.045))
 bottle=Node3D.new();add_child(bottle);bottle.name="FirstPersonBottle"
 var body:=_cylinder(bottle,.055,Color("c7944c"));_segment(body,Vector3(0,-.11,0),Vector3(0,.11,0))
 var neck:=_cylinder(bottle,.026,Color("d9c58f"));_segment(neck,Vector3(0,.11,0),Vector3(0,.19,0))
 _box(bottle,Vector3(0,.2,0),Vector3(.06,.035,.06),Color("e7eadf"))
 cloth=Node3D.new();add_child(cloth);cloth.name="HeldFoldedCloak"
 for i in range(3):_box(cloth,Vector3(0,-i*.035,i*.015),Vector3(.3-i*.025,.055,.16),Color("a99565"))
 cup=Node3D.new();add_child(cup);cup.name="FirstPersonWaterCup"
 var cup_body:=_cylinder(cup,.065,Color("e5dfc7"));_segment(cup_body,Vector3(0,-.07,0),Vector3(0,.07,0))
 _box(cup,Vector3(.075,0,0),Vector3(.045,.09,.04),Color("e5dfc7"))
 spoon=Node3D.new();add_child(spoon);spoon.name="FirstPersonSpoon"
 var shaft:=_cylinder(spoon,.014,Color("9e7549"));_segment(shaft,Vector3.ZERO,Vector3(0,.36,-.12))
 _box(spoon,Vector3(0,.38,-.12),Vector3(.08,.035,.12),Color("9e7549"))
 food=MeshInstance3D.new();var fruit:=SphereMesh.new();fruit.radius=.075;fruit.height=.15;fruit.radial_segments=12;fruit.rings=6;food.mesh=fruit;food.layers=LAYER;food.material_override=world.material(Color("c27c43"));food.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(food)
 axe=Node3D.new();add_child(axe);axe.name="FirstPersonWorkTool"
 var handle:=_cylinder(axe,.025,Color("916c44"));_segment(handle,Vector3(0,-.15,0),Vector3(0,.5,0))
 _box(axe,Vector3(.1,.43,0),Vector3(.27,.2,.055),Color("aebbb6"))
 hide()
func _box(parent:Node3D,at:Vector3,size:Vector3,color:Color) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.position=at;mesh.layers=LAYER;mesh.material_override=world.material(color);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);return mesh
func _cylinder(parent:Node3D,radius:float,color:Color) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.height=1;shape.top_radius=radius*.85;shape.bottom_radius=radius;shape.radial_segments=8;mesh.mesh=shape;mesh.layers=LAYER;mesh.material_override=world.material(color);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);return mesh
func _segment(mesh:MeshInstance3D,a:Vector3,b:Vector3) -> void:
 var offset:Vector3=b-a;mesh.position=(a+b)*.5;mesh.basis=Basis(Quaternion(Vector3.UP,offset.normalized()));mesh.scale.y=offset.length()
func update_pose(app:Node,actor:Node3D,clock:float) -> void:
 var fishing:Node=app.get("fishing_session")
 var routine:Node=app.get("home_routine")
 var phase:String=str(routine.phase) if routine!=null else ""
 var active_fishing:bool=fishing!=null and fishing.active
 var carrying:bool=routine!=null and routine.gesture!=null and is_instance_valid(routine.gesture.prop)
 visible=active_fishing or carrying or actor.home_busy or actor.working or actor.pet_stage!="" or actor.boating or actor.seated_eat_time>=0 or actor.bed_stage in ["undressing","hanging_cloak","taking_cloak","dressing","removing_shoes","putting_shoes","boarding","getting_off"]
 bottle.hide();cup.hide();cloth.hide();spoon.hide();axe.hide();food.hide()
 if phase!="discarding":throw_from=Vector3.INF
 if not visible:return
 right_grip=Vector3(.23,-.28,-.62);left_grip=Vector3(-.18,-.31,-.65)
 if active_fishing:
  var t:float=fishing.elapsed
  if fishing.stage=="casting":right_grip+=Vector3(0,sin(clampf(t/1.2,0,1)*PI)*.18,-sin(clampf(t/1.2,0,1)*PI)*.15)
  elif fishing.stage=="reeling":
   left_grip=right_grip+Vector3(-.15,sin(fishing.reel_angle)*.035,-.04+cos(fishing.reel_angle)*.035)
  elif fishing.stage=="landing":left_grip=Vector3(-.28,-.36,-.85)
  elif fishing.stage=="storing":
   left_grip=Vector3(-.08,-.25,-.85);right_grip=left_grip+Vector3(.17,.06,-.02)
  elif fishing.stage=="chumming":left_grip=Vector3(-.23,-.24,-.7)+Vector3(0,sin(t*PI)*.08,-sin(t*PI)*.25)
 elif actor.working:
  right_grip+=Vector3(0,sin(actor.work_elapsed*5)*.18,-maxf(0,sin(actor.work_elapsed*5))*.14)
  axe.show();axe.position=right_grip;axe.rotation.z=-.25;axe.rotation.x=sin(actor.work_elapsed*5)*.55
 elif actor.pet_stage!="":
  right_grip=Vector3(.1,-.42,-.85)
  if actor.pet_stage=="crouch":
   var head:Vector3=actor._pet_head_position()+Vector3(0,.02,0)
   right_grip=right_grip.lerp(to_local(head)+Vector3(sin(clock*4)*.045,0,0),smoothstep(0,.65,float(actor.pet_elapsed)))
 elif actor.bed_stage!="":
  right_grip=Vector3(.13,-.22,-.58);left_grip=Vector3(-.13,-.22,-.58)
  if actor.bed_stage in ["undressing","taking_cloak","dressing"]:cloth.show();cloth.position=(right_grip+left_grip)*.5+Vector3(0,-.12,0)
 elif actor.seated_eat_time>=0:
  var bite:float=smoothstep(0,.7,float(actor.seated_eat_time))*(1-smoothstep(1.7,2.3,float(actor.seated_eat_time)))
  right_grip=right_grip.lerp(Vector3(.04,-.19,-.32),bite)
  food.show();food.position=right_grip+Vector3(0,.035,-.025)
 elif actor.boating:
  right_grip=Vector3(.25,-.28,-.7);left_grip=Vector3(-.25,-.28,-.7)
 elif phase in ["cooking_setup","cooking"]:
  right_grip=Vector3(.18+sin(clock*2)*.07,-.3,-.72+cos(clock*2)*.07)
  spoon.show();spoon.position=right_grip;spoon.rotation.x=-PI*.5
 else:
  var sip:float=0
  if phase in ["water","drinking"]:sip=smoothstep(2.6,3.7,float(routine.elapsed))*(1-smoothstep(4.6,5.8,float(routine.elapsed)))
  if phase in ["approach_fridge","to_bin","taking","retreating","closing","fridge","turning_drink","water","drinking","filling","turning_water","discarding"]:
   bottle.show();left_grip=Vector3(-.16,-.29,-.58).lerp(Vector3(-.045,-.19,-.32),sip)
   bottle.position=left_grip+Vector3(0,.025,0);bottle.rotation=Vector3(sip*1.35,0,0)
   if phase in ["filling","turning_water","water"]:
    bottle.hide();cup.show();cup.position=left_grip+Vector3(0,.025,0);cup.rotation.x=sip*1.1
   if phase=="discarding" and routine.elapsed>=.65:
    if not throw_from.is_finite():throw_from=bottle.global_position
    var t:float=smoothstep(.65,1.25,float(routine.elapsed))
    bottle.global_position=throw_from.lerp(Vector3(-7,1.43,-3.2),t)+Vector3.UP*sin(t*PI)*.18
    bottle.global_basis=Basis.from_euler(Vector3(t*.4,0,t*.6))
  if phase=="waving":right_grip=Vector3(.15,-.3,-.6).lerp(Vector3(.16+sin(float(routine.elapsed)*12)*.06,.02,-.4),smoothstep(0,.25,float(routine.elapsed))*(1-smoothstep(1.65,2,float(routine.elapsed))))
  if phase in ["opening","closing","taking","discarding"]:right_grip=Vector3(.15,-.14,-.8)
  if actor.seated_eat_time>=0:right_grip=Vector3(.17,-.3,-.6).lerp(Vector3(.04,-.08,-.3),sin(clampf(actor.seated_eat_time/2.3,0,1)*PI))
 for i in range(2):
  var side:float=-1 if i==0 else 1
  var grip:Vector3=left_grip if i==0 else right_grip
  var elbow:=Vector3(side*.34,-.4,-.3)
  _segment(arms[i],Vector3(side*.43,-.48,.05),elbow)
  _segment(forearms[i],elbow,grip+Vector3(0,0,.04))
  palms[i].position=grip
func right_world() -> Vector3:return to_global(right_grip)
func left_world() -> Vector3:return to_global(left_grip)
