extends Node3D
## Deterministic natural islands for the horizon, without homestead/game-state clones.
const SECTORS:=64
const RINGS:=14
const LAND_SPECIES:=["forest-rabbit-ea2da0","forest-deer-fe648d","red-fox-5c3bc0"]
## 每座岛自己的生物池：陆地 / 空中 / 近海分开，彼此不串门。
## 资源库里只有兔子、鹿、狐狸、海鸥、三种鱼和礁鲨，缺的种类用程序化低模补上（crab/lizard）。
const CREATURE_SETS:={
 "twin_hills":{"land":["forest-rabbit-ea2da0","red-fox-5c3bc0"],"air":["herring-gull-base"],"sea":["reef-fish-base"]},
 "crescent_bay":{"land":["crab-base","lizard-base"],"air":[],"sea":["flame-angelfish-ce502b"]},
 "rocky_reef":{"land":["lizard-base","herring-gull-base"],"air":["herring-gull-base"],"sea":["reef-shark-base","reef-fish-base"]},
 "forest_cape":{"land":["forest-deer-fe648d","forest-rabbit-ea2da0"],"air":["herring-gull-base"],"sea":["flame-angelfish-ce502b","reef-fish-base"]},
}
const PROCEDURAL:=["crab-base","lizard-base"]
const FISH=preload("res://scripts/life/fish_catalog.gd")
static var prototypes:Dictionary={}
var world:Node3D
var spec:Dictionary
var noise:=FastNoiseLite.new()
var rng:=RandomNumberGenerator.new()
var columns:Dictionary={}
var tree_positions:Array[Vector3]=[]
var terrain:MeshInstance3D
var wildlife:Array[Dictionary]=[]
var near_props:Array[Node3D]=[]
var far_batches:Array[MultiMeshInstance3D]=[]
var tree_instances:Array[Dictionary]=[]
var rock_instances:Array[Transform3D]=[]
var tree_count:=0
var elapsed:=0.0
var lod_time:=0.0
var nearby:=false
func setup(owner_world:Node3D,definition:Dictionary) -> void:
 world=owner_world;spec=definition.duplicate(true);name="DistantIsland_"+str(spec.id)
 position=spec.at;rotation.y=spec.yaw;rng.seed=int(spec.seed)
 noise.seed=int(spec.seed);noise.frequency=.05;noise.fractal_octaves=3
 set_meta("island_kind",spec.kind);set_meta("island_size",spec.radii)
 _terrain();_vegetation();_wildlife()
func shoreline(angle:float) -> float:
 var coast:float=1+.11*sin(angle*3+spec.seed*.01)+.07*cos(angle*5-spec.seed*.03)
 coast+=noise.get_noise_2d(cos(angle)*40,sin(angle)*40)*.10
 # 四座岛各留一个能一眼认出来的轮廓特征：弯月沙湾的月牙缺口、长岬林岛的细长岬角、礁岩小岛的锯齿轮廓。
 if spec.kind=="bay":coast-=.52*exp(-pow(angle_difference(angle,.25),2)/.24)
 elif spec.kind=="cape":coast+=.28*pow(maxf(0,cos(angle-2.2)),6)
 elif spec.kind=="reef":coast+=.18*sin(angle*7)
 return maxf(.43,coast)
func height_at(p:Vector2) -> float:
 var normalized:Vector2=p/spec.radii
 var ratio:float=normalized.length()/shoreline(atan2(normalized.y,normalized.x))
 if ratio>1.09:return -INF
 # 抬成主岛那样的平整岛面，再用陡坎在岸边快速入水，保证泊位仍是深水。
 var shore:float=lerpf(1.25,-1.35,smoothstep(.90,1.04,ratio))
 var slope:float=1-smoothstep(.25,.90,ratio)
 var hill:float=exp(-((normalized-Vector2(-.25,-.18)).length_squared())*4)
 hill+=.68*exp(-((normalized-Vector2(.35,.22)).length_squared())*8)
 if spec.kind=="reef":hill=.25*hill
 return shore+slope*(hill*float(spec.height)+noise.get_noise_2d(p.x,p.y)*1.3)
func _point(ring:int,sector:int) -> Vector3:
 var angle:float=sector*TAU/SECTORS
 var ratio:float=ring/float(RINGS)*1.08
 var flat:Vector2=Vector2(cos(angle),sin(angle))*spec.radii*shoreline(angle)*ratio
 return Vector3(flat.x,height_at(flat),flat.y)
func _terrain() -> void:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for ring in range(RINGS):
  for sector in range(SECTORS):
   var a:Vector3=_point(ring,sector);var b:Vector3=_point(ring+1,sector);var c:Vector3=_point(ring+1,sector+1);var d:Vector3=_point(ring,sector+1)
   if not columns.has(sector):columns[sector]=[]
   columns[sector].append([a,c,b]);_triangle(tool,a,c,b)
   if ring>0:columns[sector].append([a,d,c]);_triangle(tool,a,d,c)
 var mat:StandardMaterial3D=world.material(Color.WHITE);mat.vertex_color_use_as_albedo=true;mat.roughness=1
 # 岛体三角形是按「法线朝上」拼的，Godot 的正面是顺时针，导致整座岛被背面剔除、只能看见下面的海面。
 # 这里关掉剔除（顶点法线本来就朝上，光照仍然正确），岛面才会真正显示出来。
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 terrain=MeshInstance3D.new();terrain.name="NaturalIslandTerrain";terrain.mesh=tool.commit();terrain.material_override=mat;terrain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(terrain)
 terrain.create_trimesh_collision()
 for body:StaticBody3D in terrain.find_children("*","StaticBody3D",true,false):body.collision_layer=17
func _triangle(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
 var normal:Vector3=(b-a).cross(c-a).normalized()
 if normal.y<0:var swap:=b;b=c;c=swap;normal=-normal
 var center:Vector3=(a+b+c)/3
 var flat:Vector2=Vector2(center.x,center.z)/spec.radii
 var ratio:float=flat.length()/shoreline(atan2(flat.y,flat.x))
 # 用主岛地面的同一套颜色（forest_scene 的 e5f2cf / e4c58f），远岛才会看起来和主岛是同一个世界。
 var grass:Color=Color("e5f2cf").lerp(Color("b9d49a"),clampf(center.y/20,0,1))
 var color:Color=grass.lerp(Color("a4a28b"),1-smoothstep(.55,.88,normal.y))
 color=color.lerp(Color("e4c58f"),smoothstep(.72,.90,ratio))
 for point:Vector3 in [a,b,c]:tool.set_color(color.srgb_to_linear());tool.set_normal(normal);tool.add_vertex(point)
func surface_height_at(p:Vector2) -> float:
 var normalized:Vector2=p/spec.radii
 var sector:int=posmod(floori(fposmod(atan2(normalized.y,normalized.x),TAU)/TAU*SECTORS),SECTORS)
 for triangle:Array in columns.get(sector,[]):
  var a:Vector3=triangle[0];var b:Vector3=triangle[1];var c:Vector3=triangle[2]
  var denominator:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
  if absf(denominator)<.000001:continue
  var u:float=((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.y-c.z))/denominator
  var v:float=((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.y-c.z))/denominator
  if minf(u,minf(v,1-u-v))>=-.0001:return u*a.y+v*b.y+(1-u-v)*c.y
 return -INF
func _land_point() -> Vector3:
 for attempt in range(150):
  var p:Vector2=Vector2(rng.randf_range(-.76,.76),rng.randf_range(-.76,.76))*spec.radii
  var height:float=surface_height_at(p)
  if not is_finite(height) or height<.65:continue
  var neighbor:float=surface_height_at(p+Vector2(1,0))
  if not is_finite(neighbor) or absf(neighbor-height)>1:continue
  return Vector3(p.x,height,p.y)
 return Vector3(0,surface_height_at(Vector2.ZERO),0)
func _prototype(id:String) -> Array:
 if prototypes.has(id):return prototypes[id]
 var source:Node3D=load("res://assets/polyfork/%s.glb"%id).instantiate();add_child(source);source.hide();world._apply_vertex_colors(source)
 var meshes:Array=[]
 for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
  var materials:Array[Material]=[]
  for surface in range(mesh.mesh.get_surface_count()):materials.append(mesh.get_active_material(surface))
  meshes.append({"mesh":mesh.mesh,"transform":source.global_transform.affine_inverse()*mesh.global_transform,"materials":materials})
 source.free();prototypes[id]=meshes
 return meshes
func _batch(id:String,transforms:Array[Transform3D]) -> void:
 for part:Dictionary in _prototype(id):
  var node:=MultiMeshInstance3D.new();node.name="IslandScenery_"+id;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=part.mesh;multi.instance_count=transforms.size()
  for index in range(transforms.size()):multi.set_instance_transform(index,transforms[index]*part.transform)
  node.multimesh=multi
  # The imported palette is shared by every instance, including multi-surface GLBs.
  var mesh_copy:Mesh=multi.mesh.duplicate()
  for surface in range(part.materials.size()):mesh_copy.surface_set_material(surface,part.materials[surface])
  multi.mesh=mesh_copy;add_child(node);far_batches.append(node)
## 每座远岛的码头统一摆在南侧（见 island_exploration._sites），所以从沙滩到岛心要留一条
## 一样宽的「码头大道」：x 方向 ±3.4 米内不长树、不放石头，四座岛的登岛路径长得一样。
func _blocks_dock_lane(p:Vector3) -> bool:
 return absf(p.x)<3.4 and p.z>-.2
func _vegetation() -> void:
 var species:Array[String]=["broad-canopy-shade-tree-e7c4a2","birch-tree-181b33","young-pine-0d7695"]
 var grouped:Dictionary={}
 for id:String in species:grouped[id]=[]
 for index in range(int(spec.trees)):
  var p:Vector3=_land_point()
  for attempt in range(60):
   if not _blocks_dock_lane(p) and tree_positions.all(func(other):return Vector2(other.x-p.x,other.z-p.z).length()>2.5):break
   p=_land_point()
  tree_positions.append(p)
  var size:float=rng.randf_range(.60,.95)
  var id:String=species[index%species.size()];var placement:=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size),p)
  grouped[id].append(placement);tree_instances.append({"id":id,"transform":placement});tree_count+=1
 for id:String in species:
  var transforms:Array[Transform3D]=[];transforms.assign(grouped[id]);_batch(id,transforms)
 var rocks:Array[Transform3D]=[]
 for index in range(10):
  var spot:Vector3=_land_point()
  for attempt in range(20):
   if not _blocks_dock_lane(spot):break
   spot=_land_point()
  rocks.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(.8,2.2)),spot))
 rock_instances=rocks;_batch("medium-rock-e08405",rocks)
func _animal(id:String,mode:String,index:int) -> void:
 var actor:=Node3D.new();actor.name="IslandWildlife_"+id;actor.set_meta("species",id);actor.set_meta("mode",mode);add_child(actor)
 var visual:Node3D=_procedural(id) if id in PROCEDURAL else (FISH.create(id,world) if FISH.DATA.has(id) else load("res://assets/polyfork/%s.glb"%id).instantiate())
 actor.add_child(visual);visual.scale=Vector3.ONE*.85
 if not FISH.DATA.has(id):world._apply_vertex_colors(visual)
 for mesh:MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var animations:Array[AnimationPlayer]=[]
 for animation:AnimationPlayer in visual.find_children("*","AnimationPlayer",true,false):
  animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var desired:String="walk" if mode=="land" else ("fly" if mode=="air" else "swim")
  for clip:StringName in animation.get_animation_list():
   if str(clip).to_lower().ends_with(desired):animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animation.play(clip);animation.advance(0);break
  animations.append(animation)
 var origin:Vector3=_land_point()
 if mode=="land":
  for attempt in range(60):
   if tree_positions.all(func(tree):return Vector2(tree.x-origin.x,tree.z-origin.z).length()>2):break
   origin=_land_point()
 var data:Dictionary={"node":actor,"visual":visual,"id":id,"mode":mode,"index":index,"origin":origin,"phase":rng.randf_range(0,TAU),"animations":animations}
 wildlife.append(data);_move_animal(data,0)
## 资源库缺的种类：寄居蟹、沙滩蜥蜴用简单几何体拼，风格和低模岛一致。
func _procedural(id:String) -> Node3D:
 var root:=Node3D.new()
 var shell:=StandardMaterial3D.new()
 var limb:=StandardMaterial3D.new()
 if id=="crab-base":
  shell.albedo_color=Color("c4552f");limb.albedo_color=Color("8a3a20")
  _body(root,Vector3(.30,.12,.24),shell,Vector3(0,.10,0))
  for side:float in [-1.0,1.0]:
   for leg in range(3):
    _body(root,Vector3(.24,.05,.05),limb,Vector3(side*.20,.06,-.10+leg*.10),side*.25)
   _body(root,Vector3(.10,.06,.16),limb,Vector3(side*.22,.12,.16),side*.5)
 elif id=="lizard-base":
  shell.albedo_color=Color("6f8f4a");limb.albedo_color=Color("55703a")
  _body(root,Vector3(.16,.13,.42),shell,Vector3(0,.11,0))
  _body(root,Vector3(.11,.10,.16),shell,Vector3(0,.12,.26))
  for side:float in [-1.0,1.0]:
   for offset:float in [-.12,.12]:
    _body(root,Vector3(.18,.05,.05),limb,Vector3(side*.14,.05,offset),side*.4)
  _body(root,Vector3(.06,.06,.34),limb,Vector3(0,.11,-.30))
 else:
  _body(root,Vector3(.22,.12,.22),shell,Vector3.ZERO)
 return root

func _body(parent:Node3D,size:Vector3,material:StandardMaterial3D,at:Vector3,roll:=0.0) -> void:
 var part:=MeshInstance3D.new()
 var mesh:=BoxMesh.new();mesh.size=size
 part.mesh=mesh;part.material_override=material
 part.position=at;part.rotation.z=roll
 parent.add_child(part)

func creature_pool() -> Dictionary:
 return CREATURE_SETS.get(String(spec.id),CREATURE_SETS["twin_hills"])

func _wildlife() -> void:
 var pool:Dictionary=creature_pool()
 for id:String in pool.land:_animal(id,"land",wildlife.size())
 for id:String in pool.air:_animal(id,"air",wildlife.size())
 for id:String in pool.sea:_animal(id,"sea",wildlife.size())
func _move_animal(data:Dictionary,time:float) -> void:
 var angle:float=time*(.16 if data.mode=="land" else .10)+float(data.phase)
 var at:Vector3=data.origin
 if data.mode=="land":
  at+=Vector3(cos(angle)*.65,0,sin(angle)*.5);at.y=surface_height_at(Vector2(at.x,at.z));data.node.rotation.y=atan2(-sin(angle)*.65,cos(angle)*.5)
 elif data.mode=="air":
  at=Vector3(cos(angle)*spec.radii.x*.6,float(spec.height)+7+sin(angle*2),sin(angle)*spec.radii.y*.6);data.node.rotation.y=-angle
 else:
  var coast:float=shoreline(angle)*(1.26+float(int(data.index)%3)*.06)
  at=Vector3(cos(angle)*spec.radii.x*coast,-.65,sin(angle)*spec.radii.y*coast)
  if data.id=="reef-shark-base":at.y=-.40
  else:at.y+=pow(maxf(0,sin(time*.5+float(data.phase))),18)*.7
  data.node.rotation.y=-angle
 if not is_finite(at.y):at.y=float(data.origin.y)
 if data.mode=="land" and not near_props.is_empty() and to_global(at).distance_to(world.player.position)<1.25:return
 data.node.position=at
func _process(delta:float) -> void:
 if world==null or world.player==null or world.navigation_state==null:return
 if not world.player.allowed:return
 lod_time-=delta
 if lod_time<=0:
  nearby=world.navigation_state.location=="island" and world.camera.global_position.distance_to(global_position)<220
  lod_time=.35
 if not nearby:return
 elapsed+=delta
 for data:Dictionary in wildlife:
  _move_animal(data,elapsed)
  for animation:AnimationPlayer in data.animations:animation.advance(delta*.65)
  if FISH.DATA.has(data.id):FISH.animate(data.visual,elapsed+float(data.phase))

func set_explorable(enabled:bool) -> void:
 for batch:MultiMeshInstance3D in far_batches:batch.visible=not enabled
 if enabled and near_props.is_empty():
  for item:Dictionary in tree_instances:
   var tree:Node3D=load("res://assets/polyfork/%s.glb"%item.id).instantiate();world.forest.add_child(tree);tree.global_transform=global_transform*item.transform;world._apply_vertex_colors(tree)
   preload("res://scripts/life/prop_collision.gd").tree(tree,item.id);world.forest.extra_trees.append(tree);near_props.append(tree)
  for placement:Transform3D in rock_instances:
   var rock:Node3D=load("res://assets/polyfork/medium-rock-e08405.glb").instantiate();world.forest.add_child(rock);rock.global_transform=global_transform*placement;world._apply_vertex_colors(rock);preload("res://scripts/life/prop_collision.gd").convex(rock);near_props.append(rock)
 elif not enabled:
  for prop:Node3D in near_props:
   if not is_instance_valid(prop):continue
   world.forest.extra_trees.erase(prop);world.forest.faded.erase(prop.get_instance_id());world.clear_visual_materials(prop);prop.queue_free()
  near_props.clear()
 for data:Dictionary in wildlife:
  if data.mode!="land":continue
  var body:StaticBody3D=data.node.get_node_or_null("WildlifeObstacle")
  if enabled and body==null:
   body=StaticBody3D.new();body.name="WildlifeObstacle";data.node.add_child(body)
   var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.5 if data.id=="forest-deer-fe648d" else .28;shape.height=1.2 if data.id=="forest-deer-fe648d" else .5;collision.shape=shape;collision.position.y=shape.height*.5;body.add_child(collision)
  if body!=null:body.collision_layer=1 if enabled else 0
