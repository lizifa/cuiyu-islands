extends Button
func _ready()->void:
 name="ModalClose";text="";tooltip_text="关闭";custom_minimum_size=Vector2(48,48);mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 resized.connect(queue_redraw)
 mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
func _draw()->void:
 var center:Vector2=size*.5;var radius:=8.0
 var color:=Color("fff4df")
 draw_line(center-Vector2(radius,radius),center+Vector2(radius,radius),color,2.5,true)
 draw_line(center+Vector2(-radius,radius),center+Vector2(radius,-radius),color,2.5,true)
