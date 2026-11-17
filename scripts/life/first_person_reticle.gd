extends Control
var app:Node
var caption:Label
var available:=false
func setup(owner_app:Node) -> void:
 app=owner_app;name="FirstPersonReticle";mouse_filter=Control.MOUSE_FILTER_IGNORE;visible=app.world.orbit.first_person
 caption=Label.new();caption.position=Vector2(-140,22);caption.size=Vector2(280,30);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption.add_theme_font_size_override("font_size",17);caption.add_theme_color_override("font_outline_color",Color("173338"));caption.add_theme_constant_override("outline_size",5);add_child(caption)
func _process(_delta:float) -> void:
 if app==null:return
 visible=app.world.orbit.first_person and app.movement_enabled() and app.world.player.bed_stage!="resting"
 position=app.safe_root.get_global_transform_with_canvas().affine_inverse()*(get_viewport_rect().size*.5)
 var actor:Node=app.world.player
 var ready:bool=visible and (app.home_routine==null or app.home_routine.phase=="") and not actor.home_busy and not actor.sofa_seated and not actor.stair_active and actor.bed_stage=="" and actor.fishing_stage==""
 var point:Dictionary=app.world.nearby_action() if ready else {}
 available=not point.is_empty();caption.text=str(point.get("title",""))
 if app.fishing_session.active:caption.text="";available=false
 queue_redraw()
func _draw() -> void:
 var color:=Color("f6d990") if available else Color("f4f4df99")
 draw_circle(Vector2.ZERO,2,color)
 for axis:Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:draw_line(axis*7,axis*11,color,1.5,true)
