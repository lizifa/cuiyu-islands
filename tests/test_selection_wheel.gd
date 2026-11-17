extends SceneTree
const Wheel=preload("res://scripts/life/selection_wheel.gd")
var passed:=0
var failed:=0
var notifications:Array[String]=[]
func check(ok:bool,message:String):
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var wheel=Wheel.new();root.add_child(wheel);wheel.position=Vector2(20,20);wheel.size=Vector2(300,144)
 wheel.configure({"a":"甲","b":"乙","c":"丙","d":"丁","e":"戊"})
 wheel.selected.connect(func(value):notifications.append(value))
 wheel.set_value("c")
 check(wheel.get_value()=="c" and notifications.is_empty(),"restoring selection is silent")
 var press=InputEventScreenTouch.new();press.position=Vector2(160,92);press.index=2;press.pressed=true;wheel._input(press)
 var drag=InputEventScreenDrag.new();drag.index=2;drag.position=Vector2(160,40);wheel._input(drag)
 check(wheel.get_value()=="d","drag position selects nearest central row")
 var duplicate=InputEventMouseMotion.new();duplicate.device=InputEvent.DEVICE_ID_EMULATION;duplicate.position=Vector2(160,40);duplicate.relative=Vector2(0,-48);duplicate.button_mask=MOUSE_BUTTON_MASK_LEFT
 var position=wheel.scroll_position;wheel._input(duplicate)
 check(is_equal_approx(position,wheel.scroll_position),"emulated mouse does not duplicate touch")
 var other=InputEventScreenDrag.new();other.index=4;other.position=Vector2(160,-200);wheel._input(other)
 check(is_equal_approx(position,wheel.scroll_position),"other finger cannot hijack drag")
 press.pressed=false;press.position=drag.position;wheel._input(press)
 for i in 180:wheel._process(1./60)
 check(absf(wheel.scroll_position-roundf(wheel.scroll_position))<.002 and wheel.touch_index==-1,"release coasts and snaps to a row")
 check(not notifications.is_empty(),"scroll emits selection changes")
 wheel._scroll(-100);check(wheel.get_value()=="a","first item is selectable and bounded")
 wheel._scroll(100);check(wheel.get_value()=="e","last item is selectable and bounded")
 wheel.set_value("c");wheel._scroll(2.4);wheel.settle();check(wheel.get_value()=="c" and is_equal_approx(wheel.scroll_position,2),"confirm settles current center rather than previous saved value")
 wheel._scroll(2.7);wheel._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(wheel.get_value()=="d" and wheel.velocity==0,"focus loss ends gesture safely")
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_HOME;wheel._gui_input(key)
 check(wheel.get_value()=="a","keyboard selects first row")
 var clip=Control.new();clip.clip_contents=true;clip.position=Vector2(0,0);clip.size=Vector2(300,60);root.add_child(clip)
 root.remove_child(wheel);clip.add_child(wheel);wheel.position=Vector2.ZERO
 check(not wheel._contains(Vector2(100,90)),"clipped rows cannot steal taps from confirmation or other fields")
 wheel.queue_free();clip.queue_free();await process_frame
 print("SELECTION WHEEL: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)
