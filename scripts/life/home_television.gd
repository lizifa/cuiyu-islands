extends Node
## Decode only while the television is on and its room is active.
const VIDEO_PATH="res://assets/videos/home-tv.ogv"
var target_screen:MeshInstance3D
var active_floor:=0
var room:Node3D
var player:VideoStreamPlayer
var enabled:=false
var user_paused:=false
var volume_db:float=-12
var screen_material:StandardMaterial3D
func setup(owner_room:Node3D,display:MeshInstance3D=null,floor_index:int=0) -> void:
 target_screen=display;active_floor=floor_index
 room=owner_room
 player=VideoStreamPlayer.new();player.name="TelevisionVideo";player.loop=true;player.hide();add_child(player)
 player.volume_db=volume_db
 screen_material=StandardMaterial3D.new();screen_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
func set_enabled(value:bool) -> void:
 enabled=value
 if not value:
  player.stop();_screen().material_override=room.palette.dark;return
 if player.stream==null:player.stream=load(VIDEO_PATH)
 player.play();player.paused=user_paused
 screen_material.albedo_texture=player.get_video_texture();_screen().material_override=screen_material
func toggle_pause() -> void:
 user_paused=not user_paused
func set_volume(value:float) -> void:
 volume_db=clampf(value,-40,0);player.volume_db=volume_db
func _process(_delta:float) -> void:
 if not enabled or room==null:return
 var world:Node3D=room.world
 var state:RefCounted=world.navigation_state
 player.paused=user_paused or state==null or state.location!="villa" or state.home_floor!=active_floor or not world.player.allowed

func _screen() -> MeshInstance3D:
 return target_screen if is_instance_valid(target_screen) else room.tv_screen
