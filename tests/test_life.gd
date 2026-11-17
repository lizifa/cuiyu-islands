extends SceneTree
const State = preload("res://scripts/life/life_state.gd")
var passed := 0
var failed := 0
func check(value: bool, description: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	var s = State.new()
	check(s.weekday() == 0 and s.season() == 0 and s.hour() == 8, "spring Monday start")
	check(s.daylight() == 1, "daylight")
	var initial: Dictionary = s.snapshot()
	check(not s.craft("篝火") and s.inventory == initial.inventory, "failed craft atomic")
	check(s.labor("伐木") and s.count("木材") == 4, "labor gives actual resources")
	check(s.labor("拾石") and s.craft("篝火"), "gather then build")
	check(s.claim(), "quest reward")
	var coins: int = s.coins
	check(not s.claim() and s.coins == coins, "no duplicate milestone reward")
	check(s.labor("采纤维") and s.labor("采纤维"), "fiber collection")
	check(s.labor("伐木") and s.labor("伐木"), "shelter materials")
	check(s.craft("庇护所"), "shelter built")
	s.minute = 20 * 60
	check(s.rest(true) and s.hour() == 6 and s.day() == 1, "sleep to dawn")
	check(s.flags.has("slept") and s.claimed.has("fire") and s.claim(), "home milestone after sleep")
	check(s.buildings.has("小船") and not s.RECIPES.has("小船"), "boat is ready without a repair recipe")
	var before_house: Dictionary = s.inventory.duplicate()
	check(not s.craft("屋顶") and s.inventory == before_house, "house stages cannot skip or consume materials")
	s.inventory["木材"] = 24
	s.inventory["石材"] = 4
	s.inventory["纤维"] = 8
	for stage: String in State.HOUSE_STAGES:
		check(s.craft(stage), "house stage " + stage)
	check(s.buildings.has("木屋") and s.claim(), "finished house milestone")
	check(not s.craft("地基"), "house stages cannot charge twice")
	check(s.buildings.has("小船"), "boat remains ready after house construction")
	s.minute = 2 * 1440 + 8 * 60
	s.energy = 100
	for i in range(6): s.labor("捕鱼")
	check(s.count("鲜鱼") == 18, "fish production")
	for i in range(8): s.craft("鱼干")
	check(s.count("鱼干") == 8 and s.count("鲜鱼") == 2, "processed and retained food")
	s.minute = 4 * 1440 + 8 * 60
	s.energy = 100
	s.drink()
	s.hunger = 100
	check(s.travel("town"), "travel town")
	check(s.claim(), "first town visit milestone")
	check(s.sell("鱼干", 1), "sale")
	check(s.barter() and s.count("种子") == 1, "barter")
	var stock: int = s.count("鱼干")
	check(not s.barter() and s.count("鱼干") == stock, "daily barter cannot repeat")
	check(s.claim(), "trade milestone")
	check(s.accept_order() and s.order.due == 9, "Friday order due Wednesday skips weekend")
	check(s.deliver_order() and s.flags.has("order_done"), "first order paid")
	check(not s.deliver_order(), "order payout idempotent")
	check(s.coins >= 120 and s.buy("船舱"), "labor income buys cargo upgrade")
	check(s.travel("island"), "return island")
	s.inventory["木材"] = 4
	s.inventory["纤维"] = 2
	check(s.craft("菜地") and s.plant(), "plant barter seeds")
	check(s.city_unlocked() and s.claim(), "city progression unlock")
	var ready: float = s.crop_ready
	s.advance(1440, true)
	check(s.minute >= ready and s.harvest() and s.count("蔬菜") == 6, "sleep progresses crops")
	check(not s.harvest(), "crop harvested once")
	s.minute = 5 * 1440 + 9 * 60
	s.location = "town"
	check(s.weekend() and not s.accept_order(), "weekend no work orders")
	check(s.sell("鲜鱼", 1), "weekend market remains open")
	s.minute = 5 * 1440 + 20 * 60
	check(not s.sell("鲜鱼", 1), "night market closed")
	check(s.rest(true) and s.weekday() == 6, "weekend sleep")
	s.minute = 13 * 1440 + 23 * 60
	s.advance(120, true)
	check(s.season() == 1 and s.weekday() == 0 and s.day() == 14, "season transition preserves weekdays")
	s.minute = 55 * 1440 + 23 * 60
	s.advance(120, true)
	check(s.season() == 0 and s.day() == 56 and s.weekday() == 0, "new year")
	s.minute = 18 * 60
	check(s.daylight() == 0, "spring sunset")
	s.minute = 14 * 1440 + 18 * 60
	check(s.daylight() == 1, "summer longer day")
	s.minute = 42 * 1440 + 18 * 60
	check(s.daylight() == 0, "winter early night")
	s.minute = 8 * 60
	s.location = "town"
	s.demand = 0
	s.inventory["木材"] = 1
	var before: int = s.coins
	check(s.sell("木材") and s.coins > before, "floor-price fallback")
	s.inventory["鱼干"] = 0
	before = s.coins
	check(not s.sell("鱼干", -1) and s.coins == before, "reject negative sale")
	s.inventory["木材"] = 80
	s.inventory["种子"] = 0
	s.inventory["鱼干"] = 0
	var inv_before: Dictionary = s.inventory.duplicate()
	check(not s.barter() and s.inventory == inv_before, "failed barter atomic")
	var saved := s.snapshot()
	var restored = State.new()
	check(restored.restore(saved) and restored.snapshot() == saved, "state roundtrip")
	var invalid := saved.duplicate(true)
	invalid.inventory["木材"] = -1
	check(not restored.restore(invalid) and restored.snapshot() == saved, "invalid restore does not partially mutate")
	var path := "user://test_life.json"
	check(s.save_game(path) == OK, "write real save")
	s.coins += 5
	check(s.save_game(path) == OK, "write backup")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("corrupted")
	f.close()
	check(restored.load_game(path) and restored.coins == int(saved.coins), "recover corrupt save from backup")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("LIFE TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
