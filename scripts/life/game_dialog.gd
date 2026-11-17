extends Control
## Shared in-canvas dialog: one top close icon; footer only contains a real confirmation.
signal confirmed
signal canceled
var app:Node
var title:=""
var dialog_text:=""
var window:PanelContainer
var title_label:Label
var body:Label
var ok:Button
var close:Button
func setup(owner_app:Node,action:bool=true)->void:
 app=owner_app;name="GameDialog";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var shade:=ColorRect.new();shade.color=Color("07191d99");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
 window=PanelContainer.new();window.name="ModalWindow";window.add_theme_stylebox_override("panel",app.panel(Color("142e35fa")));add_child(window)
 var rows:=VBoxContainer.new();rows.add_theme_constant_override("separation",12);window.add_child(rows)
 var header:=HBoxContainer.new();rows.add_child(header)
 title_label=app.label("",22,Color("f3d99d"));title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title_label)
 close=app.modal_close(header,func():hide();canceled.emit();app._sync_overlay_state())
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;rows.add_child(scroll)
 body=app.label("",17);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 ok=app.button(rows,"确认",func():hide();confirmed.emit();app._sync_overlay_state());ok.name="ModalConfirm";ok.visible=action
 hide()
 resized.connect(_layout)
func _layout()->void:
 if app!=null and window!=null:app.layout_modal(window)
func get_ok_button()->Button:return ok
func get_cancel_button()->Button:return close
func get_label()->Label:return body
func popup_centered()->void:
 title_label.text=title;body.text=dialog_text;_layout();show();move_to_front();close.grab_focus();app._sync_overlay_state()
func _unhandled_key_input(event:InputEvent)->void:
 if visible and event.is_action_pressed("ui_cancel"):
  hide();canceled.emit();app._sync_overlay_state();get_viewport().set_input_as_handled()
