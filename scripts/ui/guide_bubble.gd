extends Control
## GuideBubble —— 引导气泡
## 屏幕下方弹出提示，停留 lifetime 秒后淡出消失。

@export var tip_text: String = ""
@export var lifetime: float = 2.6

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -70
	offset_left = 260
	offset_right = -260
	offset_bottom = -20
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.18, 0.25, 0.88)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = tip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(label)

	# 淡入
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(lifetime)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
