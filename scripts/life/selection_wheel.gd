extends Control
## 三行滚轮：中央位置定义选择；触摸、鼠标拖动、滚轮和键盘共用同一状态。
signal selected(value:String)
const ROW_HEIGHT:=48.0
var values:Array[String]=[]
var captions:Array[String]=[]
var selected_index:=0
var scroll_position:=0.0
var velocity:=0.0
var touch_index:=-1
var mouse_dragging:=false
var last_y:=0.0
var last_time:=0
var pressed_y:=0.0
var dragged:=false
var background:StyleBoxFlat
var highlight:StyleBoxFlat
func _ready() -> void:
 custom_minimum_size=Vector2(240,ROW_HEIGHT*3)
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL
 background=StyleBoxFlat.new();background.bg_color=Color("173d43");background.set_corner_radius_all(12)
 highlight=StyleBoxFlat.new();highlight.bg_color=Color("52694b");highlight.border_color=Color("e2c58b");highlight.set_border_width_all(1);highlight.set_corner_radius_all(8)
 visibility_changed.connect(func():
  if not is_visible_in_tree():settle())
func configure(options:Dictionary) -> void:
 values.clear();captions.clear()
 for key in options:values.append(str(key));captions.append(str(options[key]))
 selected_index=0;scroll_position=0;velocity=0;queue_redraw()
func get_value() -> String:return values[selected_index] if not values.is_empty() else ""
func set_value(value:String,notify:bool=false) -> void:
 var index=values.find(value)
 if index<0:return
 touch_index=-1;mouse_dragging=false;velocity=0
 _scroll(float(index),notify)
func settle() -> void:
 touch_index=-1;mouse_dragging=false;velocity=0
 _scroll(roundf(scroll_position))
func _scroll(value:float,notify:bool=true) -> void:
 if values.is_empty():return
 scroll_position=clampf(value,0,values.size()-1)
 var index=clampi(roundi(scroll_position),0,values.size()-1)
 var changed=index!=selected_index;selected_index=index
 queue_redraw()
 if changed and notify:selected.emit(get_value())
func _process(delta:float) -> void:
 if not is_visible_in_tree() or touch_index>=0 or mouse_dragging:return
 if absf(velocity)>.25:
  var next=scroll_position+velocity*minf(delta,.05)
  _scroll(next)
  velocity=0.0 if next<=0 or next>=values.size()-1 else velocity*exp(-9*delta)
 else:
  velocity=0
  var target=roundf(scroll_position)
  _scroll(lerpf(scroll_position,target,1-exp(-18*delta)))
  if absf(scroll_position-target)<.002:_scroll(target)
func _draw() -> void:
 if background==null:return
 draw_style_box(background,Rect2(Vector2.ZERO,size))
 var middle=size.y*.5
 draw_style_box(highlight,Rect2(8,middle-ROW_HEIGHT*.5,maxf(0,size.x-16),ROW_HEIGHT))
 var font=get_theme_default_font()
 for i in values.size():
  var distance=float(i)-scroll_position
  var center=middle+distance*ROW_HEIGHT
  if center < -ROW_HEIGHT*.5 or center > size.y+ROW_HEIGHT*.5:continue
  var amount=clampf(1-absf(distance)*.5,.12,1)
  var font_size=22 if i==selected_index else 17
  var color=Color("fff0c8") if i==selected_index else Color("c5d2cc")
  color.a=amount
  var text=captions[i];var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  draw_string(font,Vector2((size.x-width)*.5,center+(font.get_ascent(font_size)-font.get_descent(font_size))*.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
 if has_focus():draw_rect(Rect2(Vector2.ONE*2,size-Vector2.ONE*4),Color("d8c08b"),false,1)
func _begin(y:float) -> void:
 last_y=y;pressed_y=y;last_time=Time.get_ticks_usec();velocity=0;dragged=false;grab_focus()
func _drag(y:float) -> void:
 var now=Time.get_ticks_usec()
 var scale_y=maxf(.001,get_global_transform().get_scale().y)
 var difference=(y-last_y)/scale_y
 if absf(y-pressed_y)>5:dragged=true
 var elapsed=maxf(.008,float(now-last_time)/1000000.0)
 velocity=clampf(lerpf(velocity,-difference/ROW_HEIGHT/elapsed,.5),-18,18)
 _scroll(scroll_position-difference/ROW_HEIGHT)
 last_y=y;last_time=now
func _release(y:float) -> void:
 if not dragged:
  var local_y=(y-get_global_rect().position.y)/maxf(.001,get_global_transform().get_scale().y)
  _scroll(roundf(scroll_position)+roundf((local_y-size.y*.5)/ROW_HEIGHT));velocity=0
 elif Time.get_ticks_usec()-last_time>100000:velocity=0
 touch_index=-1;mouse_dragging=false
func _contains(point:Vector2) -> bool:
 if not get_global_rect().has_point(point):return false
 var ancestor=get_parent()
 while ancestor!=null:
  if ancestor is Control and (ancestor.clip_contents or ancestor is ScrollContainer):
   if not ancestor.get_global_rect().has_point(point):return false
  ancestor=ancestor.get_parent()
 return true
func _input(event:InputEvent) -> void:
 if not is_visible_in_tree() or values.is_empty():return
 if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==InputEvent.DEVICE_ID_EMULATION:return
 if event is InputEventScreenTouch:
  if event.pressed and _contains(event.position):
   if touch_index<0 and not mouse_dragging:touch_index=event.index;_begin(event.position.y)
   get_viewport().set_input_as_handled()
  elif not event.pressed and event.index==touch_index:
   _release(event.position.y);get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index==touch_index:
  _drag(event.position.y);get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed and touch_index<0 and _contains(event.position):
    mouse_dragging=true;_begin(event.position.y);get_viewport().set_input_as_handled()
   elif not event.pressed and mouse_dragging:_release(event.position.y);get_viewport().set_input_as_handled()
  elif event.pressed and _contains(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   velocity=0;_scroll(roundf(scroll_position)+(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1));get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and mouse_dragging:
  _drag(event.position.y);get_viewport().set_input_as_handled()
func _gui_input(event:InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode in [KEY_UP,KEY_DOWN,KEY_HOME,KEY_END]:
  velocity=0
  match event.keycode:
   KEY_UP:_scroll(roundf(scroll_position)-1)
   KEY_DOWN:_scroll(roundf(scroll_position)+1)
   KEY_HOME:_scroll(0)
   KEY_END:_scroll(values.size()-1)
  accept_event()
func _notification(what:int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:settle()
 if what==NOTIFICATION_RESIZED:queue_redraw()
