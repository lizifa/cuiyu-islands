extends Control
## HUD —— 顶部资源栏 + 动物图鉴提示
## 监听 GameManager.inventory_changed 实时刷新数量。

var _labels: Dictionary = {}   # 资源名 -> Label
var _book_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 顶部资源栏容器
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 14
	bar.offset_left = 16
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_theme_constant_override("separation", 18)
	add_child(bar)

	for name in GameManager.inventory:
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.16, 0.22, 0.78)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		chip.add_theme_stylebox_override("panel", style)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		chip.add_child(hb)

		var icon := Label.new()
		icon.text = _icon_for(name)
		icon.add_theme_font_size_override("font_size", 20)
		hb.add_child(icon)

		var name_label := Label.new()
		name_label.text = name
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1))
		hb.add_child(name_label)

		var count := Label.new()
		count.text = "0"
		count.add_theme_font_size_override("font_size", 16)
		count.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		hb.add_child(count)

		bar.add_child(chip)
		_labels[name] = count

	# 图鉴状态（右下角）
	_book_label = Label.new()
	_book_label.text = "图鉴：0 只"
	_book_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_book_label.offset_left = -220
	_book_label.offset_top = -52
	_book_label.offset_right = -16
	_book_label.offset_bottom = -16
	_book_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_book_label.add_theme_font_size_override("font_size", 18)
	_book_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_book_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_book_label.add_theme_constant_override("outline_size", 6)
	add_child(_book_label)

	GameManager.inventory_changed.connect(_refresh)
	_refresh()

func _icon_for(name: String) -> String:
	match name:
		"木材": return "🌳"
		"野花": return "🌸"
		"浆果": return "🍓"
		"青草": return "🌿"
		"石材": return "🪨"
		"贝壳": return "🐚"
	return "•"

func _refresh() -> void:
	for name in GameManager.inventory:
		if _labels.has(name):
			_labels[name].text = str(GameManager.inventory[name])
	var count: int = GameManager.animal_book.size()
	_book_label.text = "图鉴：%d / %d 只" % [count, 5]
