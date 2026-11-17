extends SceneTree
const State = preload("res://scripts/life/life_state.gd")
var s = State.new()
var failed := 0
var steps := 0

func check(ok: bool, message: String) -> void:
	steps += 1
	if not ok:
		failed += 1
		push_error("PLAYTHROUGH: %s; %s" % [message, s.last_message])

func care() -> void:
	if s.thirst < 50: s.drink()
	if s.hunger < 50:
		if s.count("浆果") == 0:
			if s.location == "island":
				if s.energy < 10: s.rest(false)
				s.labor("采果")
			else:
				s.eat()
		if s.count("浆果") > 0: s.eat()
	if s.energy < 25: s.rest(false)

func gather(kind: String, item: String, target: int) -> void:
	for i in range(60):
		if s.count(item) >= target: return
		care()
		check(s.labor(kind), "labor " + kind)
	check(false, "resource target was unreachable")

func business_hours(workday: bool = false) -> void:
	for i in range(80):
		if s.hour() >= 8 and s.hour() < 15 and (not workday or not s.weekend()): return
		check(s.rest(false), "wait safely for business")
	check(false, "opening hours unreachable")

func _initialize() -> void:
	# No inventory/date/coin fixtures: all progress below is earned via production actions.
	gather("伐木", "木材", 3)
	gather("拾石", "石材", 2)
	check(s.craft("篝火") and s.claim(), "first milestone")
	gather("伐木", "木材", 8)
	gather("采纤维", "纤维", 6)
	check(s.craft("庇护所"), "home")
	while s.hour() >= 6 and s.hour() < 18:
		s.rest(false)
	check(s.rest(true) and s.claim(), "first night and home milestone")
	gather("伐木", "木材", 24)
	gather("拾石", "石材", 4)
	gather("采纤维", "纤维", 8)
	for stage: String in State.HOUSE_STAGES:
		care()
		check(s.craft(stage), "build own house " + stage)
	check(s.claim(), "house milestone")
	gather("伐木", "木材", 4)
	gather("采纤维", "纤维", 2)
	check(s.buildings.has("小船") and s.craft("菜地"), "boat and farm")
	gather("捕鱼", "鲜鱼", 18)
	for i in range(8):
		care()
		check(s.craft("鱼干"), "preserve trade goods")
	for i in range(80):
		care()
		if s.travel("town"): break
		s.rest(false)
	check(s.location == "town" and s.claim(), "first real journey")
	business_hours(true)
	check(s.sell("鱼干", 1) and s.barter() and s.claim(), "sell barter and trade milestone")
	check(s.accept_order() and s.deliver_order(), "earned delivery")
	check(s.buy("船舱"), "buy cargo from earned money")
	check(s.travel("island") and s.plant() and s.claim(), "return and invest in planting")
	check(s.city_unlocked(), "city unlocked without fixtures")
	for i in range(80):
		care()
		if s.travel("city"): break
		s.rest(false)
	check(s.location == "city", "real city visit")
	print("EARNED PLAYTHROUGH: %d checks, %d failures; %s; coins=%d" % [steps, failed, s.date_text(), s.coins])
	quit(1 if failed else 0)
