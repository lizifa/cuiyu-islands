extends Control
## StoryDialog —— 开局剧情字幕
## 逐句打字显示，点击/空格/回车逐行推进，全部播完发出 finished 信号。

signal finished

@export var text_lines: Array[String] = []
@export var char_delay: float = 0.03   # 每字间隔秒

var _label: RichTextLabel
var _hint: Label
var _line_idx: int = 0
var _char_idx: int = 0
var _timer: float = 0.0
var _typing: bool = false
var _all_done: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 挡住下面交互，避免剧情中误操作

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_top = -220
	box.offset_left = 120
	box.offset_right = -120
	box.offset_bottom = -40
	add_child(box)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.22, 0.85)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	box.add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.custom_minimum_size = Vector2(0, 120)
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 24)
	_label.add_theme_color_override("default_color", Color.WHITE)
	box.add_child(_label)

	_hint = Label.new()
	_hint.text = "点击 或 按空格 继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_hint.modulate.a = 0.6
	box.add_child(_hint)

	if text_lines.is_empty():
		_emit_finish()
		return
	_start_next_line()

func _start_next_line() -> void:
	if _line_idx >= text_lines.size():
		_emit_finish()
		return
	_label.text = ""
	_char_idx = 0
	_typing = true
	_hint.text = ""

func _process(delta: float) -> void:
	if not _typing:
		return
	_timer += delta
	while _timer >= char_delay and _char_idx < text_lines[_line_idx].length():
		_char_idx += 1
		_timer -= char_delay
		_label.text = text_lines[_line_idx].substr(0, _char_idx)
	if _char_idx >= text_lines[_line_idx].length():
		_typing = false
		_hint.text = "点击 或 按空格 继续"

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventKey):
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventKey and not event.pressed:
		return
	# 仅处理主键/空格/回车
	var ok := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		ok = true
	elif event is InputEventKey:
		var k: Key = event.physical_keycode
		if k == KEY_SPACE or k == KEY_ENTER:
			ok = true
	if not ok:
		return
	if _typing:
		# 快进整行
		_label.text = text_lines[_line_idx]
		_char_idx = text_lines[_line_idx].length()
		_typing = false
		_hint.text = "点击 或 按空格 继续"
	else:
		_line_idx += 1
		_start_next_line()

func _emit_finish() -> void:
	_all_done = true
	finished.emit()
	queue_free()
