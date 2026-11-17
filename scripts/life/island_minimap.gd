extends Control
signal expanded
var app: Node
var land: ImageTexture
var cached_place := ""
var cached_floor := -1
var center_offset:=Vector2.ZERO
var extent := 27.0
var player_pos := Vector3.ZERO
var heading := 0.0
var pet_pos := Vector3.ZERO
var elapsed := 0.0
var view_polygon := PackedVector2Array()
var view_center := Vector3.ZERO
var observing := false
const RANGE := 44.0
var label_rects: Array[Rect2] = []
func setup(owner_app: Node) -> void:
	app = owner_app
	clip_contents=true
	name = "IslandMinimap"
	custom_minimum_size = Vector2(152, 152)
	size = Vector2(152, 152)
	mouse_filter = Control.MOUSE_FILTER_STOP
	app.safe_root.add_child(self)
	tooltip_text = "小地图 · 点击展开"
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		expanded.emit(); accept_event()
func _process(delta: float) -> void:
	if app.world.player == null: return
	elapsed += delta
	if elapsed < 0.12: return
	elapsed = 0
	var exploring:Node3D=app.world.exploration.active_island
	var wanted_center:Vector2=Vector2(1.76,6.1) if app.state.location=="villa" else (Vector2(exploring.position.x,exploring.position.z) if exploring!=null else Vector2.ZERO)
	var wanted_extent: float=(22.0 if app.state.home_floor==1 else 16.0) if app.state.location=="villa" else (620.0 if app.world.player.boating else (maxf(exploring.spec.radii.x,exploring.spec.radii.y)*1.5 if exploring!=null else RANGE))
	if cached_place != app.state.location or cached_floor != app.state.home_floor or extent!=wanted_extent or center_offset!=wanted_center:
		cached_place = app.state.location
		cached_floor = app.state.home_floor
		extent = wanted_extent
		center_offset=wanted_center
		var resolution:int=192 if app.world.player.boating else 96
		var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
		image.fill(Color("194c5a"))
		for x in range(resolution):
			for y in range(resolution):
				var pos := Vector3((x / float(resolution-1) * 2 - 1) * extent+center_offset.x, 0, (y / float(resolution-1) * 2 - 1) * extent+center_offset.y)
				var height: float = app.world.island_ground_height(pos) if cached_place == "island" else (0.7 if Vector2(pos.x,pos.z).length() < 7 else -1.0)
				if cached_place == "villa": height = 0.7 if (pos.x> -10.98 and pos.x<14.5 and pos.z> -6.1 and pos.z<18.3) or (cached_floor==1 and app.world.Villa.Dimensions.BALCONY_RECT.has_point(Vector2(pos.x,pos.z))) else -1.0
				if is_finite(height) and height > 0.05:
					image.set_pixel(x,y,Color("c4a77c") if cached_place == "villa" else Color("71955e").lerp(Color("b7bd87"),clampf(height / 4,0,1)))
		land = ImageTexture.create_from_image(image)
	player_pos = app.world.player.position
	heading = atan2(-app.world.camera.basis.z.x,-app.world.camera.basis.z.z) if app.world.orbit.first_person else app.world.player.visual.rotation.y
	if app.world.companion != null: pet_pos = app.world.companion.position
	_update_view()
	queue_redraw()
func _update_view() -> void:
	var camera: Camera3D=app.world.camera
	if app.world.orbit.first_person:
		var forward:Vector3=-camera.basis.z;forward.y=0;forward=forward.normalized()
		var reach:float=8 if app.state.location=="villa" else 18
		var left:Vector3=forward.rotated(Vector3.UP,deg_to_rad(44))*reach
		var right:Vector3=forward.rotated(Vector3.UP,deg_to_rad(-44))*reach
		var cone:=PackedVector2Array([project(player_pos),project(player_pos+left),project(player_pos+right)])
		var frame:=PackedVector2Array([Vector2(8,8),Vector2(size.x-8,8),size-Vector2(8,8),Vector2(8,size.y-8)])
		var clipped:Array[PackedVector2Array]=Geometry2D.intersect_polygons(cone,frame)
		view_polygon=clipped[0] if not clipped.is_empty() else PackedVector2Array()
		observing=false;view_center=camera.position;return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var polygon := PackedVector2Array()
	var down := 0
	var plane_height: float=app.world.player.position.y
	for corner: Vector2 in [Vector2.ZERO,Vector2(viewport_size.x,0),viewport_size,Vector2(0,viewport_size.y)]:
		var origin := camera.project_ray_origin(corner)
		var ray := camera.project_ray_normal(corner)
		var point: Vector3
		if ray.y<-.02:
			down+=1
			point=origin+ray*minf(120,maxf(0,(plane_height-origin.y)/ray.y))
		else:point=origin+Vector3(ray.x,0,ray.z).normalized()*120
		polygon.append(project(point))
	view_center=app.world.orbit.view_focus
	observing=app.world.orbit.is_away()
	view_polygon.clear()
	if down==0:return
	var clipped := Geometry2D.intersect_polygons(polygon,PackedVector2Array([Vector2(8,8),Vector2(size.x-8,8),size-Vector2(8,8),Vector2(8,size.y-8)]))
	if not clipped.is_empty():view_polygon=clipped[0]
func project(pos: Vector3) -> Vector2:
	return Vector2(8,8) + ((Vector2(pos.x,pos.z)-center_offset) / (extent * 2) + Vector2.ONE * 0.5) * (size - Vector2(16,16))
func _label(text: String, at: Vector2, font_size: int, color: Color, align_left: bool = true) -> void:
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var base := at if align_left else at - Vector2(text_size.x, 0)
	# Try a few offsets so island names never stack on each other.
	for offset: Vector2 in [Vector2(0, 0), Vector2(0, -12), Vector2(0, 12), Vector2(0, -24), Vector2(0, 22), Vector2(10, -12), Vector2(-10, 12)]:
		var origin := base + offset
		var box := Rect2(origin, text_size + Vector2(2, 2))
		if box.position.x < 2 or box.position.x + box.size.x > size.x - 2: continue
		if box.position.y < 2 or box.position.y + box.size.y > size.y - 2: continue
		var clear := true
		for used: Rect2 in label_rects:
			if used.intersects(box): clear = false; break
		if not clear: continue
		label_rects.append(box)
		draw_string(font, origin + Vector2(0, text_size.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		return

func _draw() -> void:
	label_rects.clear()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("132f3de6")
	style.border_color = Color("c6ba82aa")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	if land != null: draw_texture_rect(land,Rect2(Vector2(8,8),size-Vector2(16,16)),false)
	if app == null: return
	if cached_place == "island":
		for point: Vector3 in app.world.forest.tree_positions: draw_circle(project(point),1.4,Color("315d3e"))
		draw_rect(Rect2(project(Vector3(-2.5,0,-1.7))-Vector2(3,3),Vector2(6,6)),Color("f4cd8d"))
		draw_rect(Rect2(project(Vector3(11,0,-6))-Vector2(7,6),Vector2(14,12)),Color("ebd6a6"))
		_label("别墅",project(Vector3(11,0,-6))+Vector2(-13,8),11,Color("fff0bd"))
		_label("营地",project(Vector3(-2.5,0,-1.7))+Vector2(-11,6),10,Color("f4cd8d"))
		draw_line(project(Vector3(3,0,5)),project(app.world.DOCK),Color("d7b38a"),2)
		var berth:Vector3=app.world.exploration.vector(app.state.island_visit.berth) if not app.state.island_visit.is_empty() else app.world.MOORING
		draw_circle(project(berth),4,Color("efb454"))
		for island:Node3D in app.world.seascape.islands:
			var docks:Array=app.world.exploration._sites(island)
			if not docks.is_empty():
				var dock:Vector2=project(docks[0].berth)
				draw_rect(Rect2(dock-Vector2(2,2),Vector2(4,4)),Color("efb454"))
				if extent<150:_label("码头",dock+Vector2(5,-8),11,Color("ffe6aa"))
			var marker:Vector2=project(island.position)
			draw_circle(marker,3,Color("f2d9a0"));_label(app.world.exploration.NAMES[island.spec.id],marker+Vector2(4,-10),10,Color("f4edcc"))
	elif cached_place == "villa":
		for point: Dictionary in app.world.interaction_points: draw_circle(project(point.pos),3,Color("f7e8bf"))
	else:
		for x in [-4,0,4]: draw_rect(Rect2(project(Vector3(x,0,-1))-Vector2(3,3),Vector2(6,6)),Color("f4cd8d"))
	if app.world.companion != null: draw_circle(project(pet_pos),2.5,Color("e3bde8"))
	if app.auto_task != null and app.auto_task.running and not app.auto_task.point.is_empty():
		draw_arc(project(app.auto_task.point.pos),5,0,TAU,20,Color("f9e774"),2)
	if view_polygon.size()>=3:
		draw_colored_polygon(view_polygon,Color("a6e9f211"))
		var outline:=view_polygon.duplicate();outline.append(view_polygon[0])
		draw_polyline(outline,Color("c4eef4b3"),1.5,true)
	if observing:
		var center:=project(view_center).clamp(Vector2(12,12),size-Vector2(12,12))
		draw_arc(center,4,0,TAU,16,Color("84e2f3"),2,true)
		draw_line(center-Vector2(6,0),center+Vector2(6,0),Color("84e2f3"),1)
		draw_line(center-Vector2(0,6),center+Vector2(0,6),Color("84e2f3"),1)
	var player := project(player_pos).clamp(Vector2(10,10),size-Vector2(10,10))
	var forward := Vector2(sin(heading),cos(heading))
	draw_colored_polygon(PackedVector2Array([player+forward*7,player-forward*4+forward.orthogonal()*4,player-forward*4-forward.orthogonal()*4]),Color("fff5d5"))
	draw_string(get_theme_default_font(),Vector2(size.x/2-5,20),"北",HORIZONTAL_ALIGNMENT_CENTER,14,12,Color.WHITE)
