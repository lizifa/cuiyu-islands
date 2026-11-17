extends Node
func _ready() -> void:
 var tree:=get_tree()
 tree.set_script(load("res://tests/visual_scene_tour.gd"))
 tree.call_deferred("run")
