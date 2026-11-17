extends SceneTree
var app: Node
var view: SubViewport
var passed := 0
var failed := 0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func frames(n: int) -> void:
 for i in range(n):app.inactive=false;await physics_frame
func _initialize():call_deferred("run")
func run():
 view=SubViewport.new();view.size=Vector2i(1280,720);view.own_world_3d=true;root.add_child(view)
 app=load("res://scenes/life_main.tscn").instantiate();view.add_child(app);app.set_process(false)
 await frames(3)
 var stick=app.joystick
 check(not stick.is_engaged(),"stick starts idle with faint outer ring")
 for axis:Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
  stick._set_point(stick.get_global_rect().get_center()+axis*90)
  var points:PackedVector2Array=stick.direction_marker()
  var base:Vector2=(points[1]+points[2])*.5
  check((points[0]-base).normalized().dot(axis)>.99,"triangle follows movement direction "+str(axis))
 var touch=InputEventScreenTouch.new();touch.position=stick.get_global_rect().get_center();touch.index=7;touch.pressed=true;stick._input(touch)
 check(stick.is_engaged(),"pressing strengthens outer ring")
 touch.pressed=false;stick._input(touch)
 check(not stick.is_engaged() and stick.direction==Vector2.ZERO,"release returns faint ring and clears movement")
 var original:Rect2=app.minimap.get_global_rect()
 check(app.minimap.position.x==-8,"compact map moved toward safe left edge")
 touch=InputEventScreenTouch.new();touch.position=original.get_center();touch.index=1;touch.pressed=true
 app.minimap._gui_input(touch);await frames(2);app._layout_mobile()
 check(app.map_drawer.visible and not app.minimap.visible,"native tap expands map")
 check(app.map_drawer.find_children("*","Button",true,false).is_empty(),"expanded map has no dedicated close button")
 touch.position=app.large_map.get_global_rect().get_center();app.large_map._gui_input(touch);await frames(2)
 check(not app.map_drawer.visible and app.minimap.visible,"tapping large map restores compact map")
 check(app.minimap.get_global_rect()==original,"compact map restores exact original placement")
 var duplicate=InputEventMouseButton.new();duplicate.device=InputEvent.DEVICE_ID_EMULATION;duplicate.button_index=MOUSE_BUTTON_LEFT;duplicate.pressed=true
 app.minimap._gui_input(duplicate)
 check(not app.map_drawer.visible,"emulated mouse cannot reopen map after touch")
 for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
  view.size=dimensions;app.test_safe_override=Vector4(50,8,50,28);await frames(2);app._layout_mobile();await frames(2)
  app._open_map();await frames(2)
  check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(app.map_drawer.get_global_rect()),"large map stays inside screen "+str(dimensions))
  app._close_drawers();await frames(2)
  check(app.minimap.get_global_rect().position.x>=50,"map stays outside notch "+str(dimensions))
 app.state.location="villa";app.state.home_floor=0;app.state.player_position=[5.3,.705,-4.8];app.world.sync(app.state);await frames(3)
 var room=app.world.villa_room
 check(room.has_node("CoffeeTeaSet"),"tea cups decorate coffee table")
 check(room.has_node("DiningFruitBowl"),"fruit bowl decorates dining table")
 check(room.has_node("StudyBookcase/BookcaseObstacle"),"full bookcase has solid body")
 check(app.world.player.position.z>-4.0,"older saves recover outside new solid bookcase")
 var chairs=room.find_children("DiningChair*","Node3D",false,false)
 check(chairs.size()==4,"four dining chairs stay together")
 for chair:Node3D in chairs:
  var inward:Vector3=room.DINING_CENTER-chair.position;inward.y=0
  check(chair.basis.z.normalized().dot(inward.normalized())>.8,"chair seat faces dining table")
 print("HOME DETAILS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
