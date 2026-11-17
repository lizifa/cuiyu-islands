extends Node
## GameManager —— 全局游戏总控（Autoload 单例）
## 负责：开局剧情、背包数据、HUD 同步、引导气泡。

signal story_finished
signal inventory_changed

# ---- 开局剧情文本（逐句播放） ----
var story_lines: Array[String] = [
	"海风裹着咸甜的花香，把你送到了这片蓝海中央。",
	"你顺着海浪漂流，落在了这座宁静的小岛——初心岛。",
	"狐狸抬眼望向你，兔子停下啃食青草，彩鹦鹉落在枝头轻轻鸣叫。",
	"四面八方，无数翠绿小岛散落在大海之上，等待你的到访。",
	"收集草木，搭建营地，修好岸边的小船，去探索翠屿群岛的秘密吧。",
]

# ---- 引导提示（剧情结束后依次弹出） ----
var guide_tips: Array[String] = [
	"欢迎来到初心岛！这里是你的新家。",
	"左键点击 花草/原木/浆果，可以采集资源。",
	"靠近小动物投喂食物，可以和它们交朋友哦。",
	"点击海面，小木船就会载你驶向远方的小岛。",
	"WASD 平移镜头，滚轮缩放，Q/E 旋转视角。",
]

# ---- 背包数据（资源名 -> 数量） ----
var inventory: Dictionary = {
	"木材": 0, "野花": 0, "浆果": 0, "青草": 0, "石材": 0, "贝壳": 0,
}

# ---- 已解锁的动物图鉴 ----
var animal_book: Dictionary = {}   # 动物名 -> true

var story_ui: Node = null
var guide_ui: Node = null

func _ready() -> void:
	if ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/life_main.tscn":
		return
	# 延迟一下再弹开场剧情，等场景稳定
	await get_tree().create_timer(0.8).timeout
	_play_story()

## 播放开局剧情
func _play_story() -> void:
	var dialog = load("res://scenes/ui/story_dialog.tscn").instantiate()
	dialog.text_lines = story_lines
	get_tree().current_scene.add_child(dialog)
	dialog.finished.connect(_on_story_end)

func _on_story_end() -> void:
	story_finished.emit()
	# 依次展示引导气泡
	_show_guides()

func _show_guides() -> void:
	for i in guide_tips.size():
		await get_tree().create_timer(1.2).timeout
		var bubble = load("res://scenes/ui/guide_bubble.tscn").instantiate()
		bubble.tip_text = guide_tips[i]
		bubble.lifetime = 2.6
		get_tree().current_scene.add_child(bubble)

## 采集/获得资源
func add_resource(item_name: String, amount: int = 1) -> void:
	if not inventory.has(item_name):
		inventory[item_name] = 0
	inventory[item_name] += amount
	inventory_changed.emit()

## 记录图鉴解锁
func unlock_animal(animal_name: String) -> void:
	animal_book[animal_name] = true

## 投喂动物（返回是否成功成为朋友）
func feed_animal() -> bool:
	# 由 animal_npc 内部调用 add_resource 的回礼逻辑
	return true
