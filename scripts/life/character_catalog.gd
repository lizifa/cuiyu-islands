extends RefCounted
## Kenney Animated Characters 三包共十二套外观，全部开放且不按性别分组。
const DEFAULT := "skater_coral"
const CHARACTERS := {
 "skater_coral": {"label":"红衣滑手", "skin":"skaterMaleA"},
 "skater_heart": {"label":"绿心滑手", "skin":"skaterFemaleA"},
 "cyborg": {"label":"机械旅人", "skin":"cyborgFemaleA"},
 "street": {"label":"白衣旅人", "skin":"criminalMaleA"},
 "survivor_sand": {"label":"沙裤旅人", "skin":"survivorFemaleA", "pack":"kenney-survivors"},
 "survivor_trail": {"label":"远行旅人", "skin":"survivorMaleB", "pack":"kenney-survivors"},
 "zombie_skull": {"label":"骷髅衫僵尸", "skin":"zombieA", "pack":"kenney-survivors"},
 "zombie_earth": {"label":"灰衫僵尸", "skin":"zombieC", "pack":"kenney-survivors"},
 "retro_shorts": {"label":"复古短裤", "skin":"humanFemaleA", "pack":"kenney-retro"},
 "retro_denim": {"label":"复古牛仔", "skin":"humanMaleA", "pack":"kenney-retro"},
 "zombie_mint": {"label":"薄荷绿僵尸", "skin":"zombieFemaleA", "pack":"kenney-retro"},
 "zombie_plaid": {"label":"格纹衫僵尸", "skin":"zombieMaleA", "pack":"kenney-retro"},
}
static func resolve(value: String) -> String:
 if value == "female":return "skater_heart"
 if CHARACTERS.has(value):return value
 return DEFAULT
static func from_profile(profile: Dictionary) -> String:
 return resolve(str(profile.get("character_id",profile.get("gender",DEFAULT))))
static func texture_path(value: String) -> String:
 var entry:Dictionary=CHARACTERS[resolve(value)]
 return "res://assets/%s/Skins/%s.png" % [entry.get("pack","kenney-protagonists"),entry.skin]
static func make(value: String) -> Node3D:
 var id=resolve(value)
 var model=(load("res://assets/kenney-protagonists/protagonist.scn") as PackedScene).instantiate() as Node3D
 model.set_meta("character_id",id)
 for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  var material=StandardMaterial3D.new()
  material.albedo_texture=load(texture_path(id))
  material.roughness=1.0
  mesh.material_override=material
 return model
