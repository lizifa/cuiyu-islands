extends Button
## A compact, non-camera-driving way home. Uses the existing safe walking task.
var app:Node
var elapsed:=0.0
var distance_to_home:=0.0
var bearing:=0.0
func setup(owner_app:Node) -> void:
 app=owner_app;name="HomeNavigation";focus_mode=Control.FOCUS_NONE
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 offset_left=-150;offset_right=150;offset_top=82;offset_bottom=146
 add_theme_font_size_override("font_size",17)
 add_theme_stylebox_override("normal",app.crisp_panel(Color("0d2630e0"),14))
 add_theme_stylebox_override("hover",app.crisp_panel(Color("12343fe8"),14))
 add_theme_stylebox_override("pressed",app.crisp_panel(Color("0a1e26f0"),14))
 tooltip_text="箭头指向别墅入口；点击自动步行回家，推摇杆可接管。"
 pressed.connect(go_home)
 refresh()
func direction_symbol() -> String:
 var angle:float=rad_to_deg(bearing)
 if absf(angle)<=15:return "↑"
 if absf(angle)<=65:return "↗" if angle>0 else "↖"
 if absf(angle)<=115:return "→" if angle>0 else "←"
 return "↷" if angle>0 else "↶"
func refresh() -> void:
 if app==null or app.world.player==null:return
 var actor:Node3D=app.world.player
 visible=app.state.location=="island" and app.movement_enabled() and actor.fishing_stage=="" and actor.pet_stage=="" and not actor.working
 if not visible:return
 var offset:Vector3=app.world.Villa.ENTRY-actor.position;offset.y=0
 distance_to_home=offset.length()
 var forward:Vector3=-app.world.camera.global_basis.z;forward.y=0;forward=forward.normalized()
 var right:Vector3=app.world.camera.global_basis.x;right.y=0;right=right.normalized()
 bearing=atan2(offset.dot(right),offset.dot(forward))
 disabled=actor.boating or app.interaction_director.active
 var suffix:String="先靠岸" if actor.boating else ("取消回家" if app.auto_task.running and app.auto_task.job=="villa" else ("进入别墅" if distance_to_home<=2 else "点击回家"))
 text="%s  别墅 · %d米  · %s"%[direction_symbol(),ceili(distance_to_home),suffix]
func _process(delta:float) -> void:
 elapsed+=delta
 if elapsed>=.1:elapsed=0;refresh()
func go_home() -> void:
 refresh()
 if not visible or disabled:return
 if app.auto_task.running and app.auto_task.job=="villa":
  app.auto_task.stop("已取消回家，可继续自由走动。")
 elif distance_to_home<=2:app._act(app.world.enter_villa.bind(app.state))
 else:app._start_task("villa")
 refresh()
