extends RefCounted
## Authoritative, engine-scene-independent life simulation. Minutes are game minutes.
const SEASONS := ["春", "夏", "秋", "冬"]
const WEEKDAYS := ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
const ITEMS := ["木材", "石材", "纤维", "浆果", "鲜鱼", "鱼干", "种子", "蔬菜", "家具", "饵料", "饮料", "空饮料瓶"]
const RECIPES := {
	"饵料": {"浆果": 1},
	"篝火": {"木材": 3, "石材": 2}, "庇护所": {"木材": 8, "纤维": 6},
	"地基": {"木材": 6, "石材": 4}, "墙体": {"木材": 8, "纤维": 2},
	"屋顶": {"木材": 6, "纤维": 4}, "木门与床": {"木材": 4, "纤维": 2},
	"鱼干": {"鲜鱼": 2},
	"菜地": {"木材": 4, "纤维": 2}, "家具": {"木材": 6, "纤维": 2},
	"保暖衣": {"纤维": 8}, "储水桶": {"木材": 6}, "遮阴棚": {"木材": 4, "纤维": 4}}
const DAILY_TARGETS := {"wood": 12, "stone": 8, "fiber": 8}
const HOUSE_STAGES := ["地基", "墙体", "屋顶", "木门与床"]
const BASE_PRICES := {"木材": 2, "石材": 2, "纤维": 2, "浆果": 3, "鲜鱼": 6, "鱼干": 15, "蔬菜": 10, "家具": 35}
const QUESTS := [
	{"id": "fire", "name": "第一缕炊烟", "hint": "采木与拾石，建造篝火", "reward": 10},
	{"id": "home", "name": "日落有处归", "hint": "建庇护所，睡过一个夜晚", "reward": 20},
	{"id": "house", "name": "亲手建成的家", "hint": "地基 → 墙体 → 屋顶 → 木门与床，完成自己的木屋", "reward": 30},
	{"id": "boat", "name": "带着手艺赶集", "hint": "驾驶小船，带货前往小镇", "reward": 20},
	{"id": "trade", "name": "靠劳动过日子", "hint": "完成一次出售和一次鱼干换种子", "reward": 30},
	{"id": "city", "name": "城里的第一位熟客", "hint": "建菜地，完成小镇订单，升级船舱", "reward": 40}]
var minute: float = 480.0
var inventory: Dictionary = {}
var fish_keep:Array=[]
var pending_fish:Dictionary={}
var fish_catches:Dictionary={}
var home_drinks:int=6
var buildings: Dictionary = {"小船":true}
var claimed: Dictionary = {}
var flags: Dictionary = {}
var coins: int = 0
var energy: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var health: float = 100.0
var location: String = "island"
var home_floor: int = 0
var island_visit:Dictionary={}
var player_position: Array = [0.0, 0.7, 3.2]
var profile: Dictionary = {"name": "晴屿旅人", "character_id": "skater_coral", "pet": "dog", "pet_name": "小麦", "confirmed": false}
var daily: Dictionary = {"day": 0, "counts": {}}
var demand: int = 12
var market_day: int = 0
var sales: int = 0
var order: Dictionary = {}
var crop_ready: float = -1.0
var income: int = 0
var spending: int = 0
var week_income: int = 0
var week_spending: int = 0
var journal: Array = []
var last_message: String = "你独自来到晴屿。眼前没有房子，先拾木石、搭个落脚处，再一砖一木建自己的家。"
var save_error: String = ""

func _init() -> void:
	for item: String in ITEMS:
		inventory[item] = 0
	inventory["浆果"] = 4

func day() -> int:
	return int(minute / 1440.0)

func hour() -> float:
	return fmod(minute, 1440.0) / 60.0

func weekday() -> int:
	return day() % 7

func weekend() -> bool:
	return weekday() >= 5

func season() -> int:
	return int(day() / 14.0) % 4

func weather(for_day: int = -1) -> String:
	var d: int = day() if for_day < 0 else for_day
	var s := int(d / 14.0) % 4
	if d % 5 == 3:
		return ["春雨", "雷雨", "大风", "冷雨"][s]
	return ["晴", "晴热", "晴", "海雾"][s]

func daylight() -> float:
	var rise: float = [6.0, 5.0, 6.0, 7.0][season()]
	var setting: float = [18.0, 20.0, 18.0, 17.0][season()]
	return clampf(minf((hour() - rise) / 1.0, (setting - hour()) / 1.0), 0.0, 1.0)

func date_text() -> String:
	return "第%d年 · %s季第%d日 · %s  %02d:%02d" % [int(day() / 56.0) + 1, SEASONS[season()], day() % 14 + 1, WEEKDAYS[weekday()], int(hour()), int(minute) % 60]

func count(item: String) -> int:
	return int(inventory.get(item, 0))

func capacity() -> int:
	return 120 if buildings.has("船舱") else 80

func load_count() -> int:
	var total := 0
	for value: Variant in inventory.values():
		total += int(value)
	return total+kept_portions()+(int(pending_fish.get("portions",0)))

func has_materials(cost: Dictionary) -> bool:
	for item: String in cost:
		if count(item) < int(cost[item]):
			return false
	return true

func can_exchange(cost: Dictionary, gain: Dictionary) -> bool:
	if not has_materials(cost):
		return false
	var total := load_count()
	for n: Variant in cost.values():
		total -= int(n)
	for n: Variant in gain.values():
		total += int(n)
	return total <= capacity()

func exchange(cost: Dictionary, gain: Dictionary) -> void:
	for item: String in cost:
		inventory[item] = count(item) - int(cost[item])
	for item: String in gain:
		inventory[item] = count(item) + int(gain[item])

func say(message: String) -> bool:
	last_message = message
	return false

func log_event(message: String) -> void:
	last_message = message
	journal.push_front("%s  %s" % [date_text(), message])
	if journal.size() > 24:
		journal.resize(24)

func advance(minutes: float, sleeping: bool = false, relaxing: bool = false) -> void:
	# At most one game minute per step: day/season/market boundaries never skipped.
	var remaining := minutes
	while remaining > 0.001:
		var step := minf(remaining, 1.0)
		var old_day := day()
		if not sleeping:
			var night_rate := 5.0 if hour() >= 22.0 or hour() < 6.0 else 3.0
			if season() == 3 and not buildings.has("保暖衣") and location == "island":
				night_rate *= 1.25
			if not relaxing: energy = maxf(0, energy - step * night_rate / 60.0)
			hunger = maxf(0, hunger - step / 30.0)
			var water_rate := 1.25 if season() == 1 and not buildings.has("遮阴棚") else 1.0
			thirst = maxf(0, thirst - step * water_rate / 20.0)
			if hunger <= 0 or thirst <= 0:
				health = maxf(1, health - step / 5.0)
		minute += step
		remaining -= step
		if day() != old_day:
			_on_day_started()

func _on_day_started() -> void:
	flags.erase("villa_bath")
	ensure_daily()
	demand = 12
	market_day = day()
	if weekday() == 5:
		log_event("周末到了。本周收入 %d，支出 %d，结余 %d 贝币。安心休息吧。" % [week_income, week_spending, week_income - week_spending])
	if weekday() == 0:
		week_income = 0
		week_spending = 0
	if day() % 14 == 0:
		log_event("进入%s季。基础食水全年可得，查看换季准备。" % SEASONS[season()])

func labor(kind: String) -> bool:
	if location != "island":
		return say("先返岛，才可以在自己的岛上劳动。")
	if energy < 10 and kind!="捕鱼":
		return say("今天累了，先短休或回屋睡觉。")
	var item := "木材"
	var amount := 4
	var duration := 45
	match kind:
		"拾石": item = "石材"
		"采纤维": item = "纤维"
		"采果":
			item = "浆果"
			amount = 4 if season() != 3 else 2
		"捕鱼":
			item = "鲜鱼"
			amount = 4 if season() == 1 else 3
			duration = 60
			if buildings.has("好鱼竿"): amount += 1
		"伐木": pass
		_: return say("未知的劳动。")
	if not can_exchange({}, {item: amount}):
		return say("行囊已满，请加工、出售或先使用一些物品。")
	advance(duration,false,kind=="捕鱼")
	exchange({}, {item: amount})
	ensure_daily()
	var task_id: String = {"伐木": "wood", "拾石": "stone", "采纤维": "fiber"}.get(kind, "")
	if not task_id.is_empty(): daily.counts[task_id] = mini(int(DAILY_TARGETS[task_id]), daily_count(task_id) + amount)
	if kind!="捕鱼":energy = maxf(0, energy - 5)
	flags["labor"] = true
	log_event("%s，获得 %s ×%d。%s" % [kind, item, amount, "天色晚了，记得回家。" if daylight() < 0.3 else "辛苦有了收获。"])
	return true

func craft(recipe: String) -> bool:
	if location not in ["island", "villa"]: return say("要回自己的工坊制作。")
	if location == "villa" and (recipe != "鱼干" or home_floor != 0): return say("请到一楼厨房制作鱼干，其他施工要到岛上工坊进行。")
	if not RECIPES.has(recipe): return say("没有这个配方。")
	if recipe=="饵料":
		if not can_exchange({"浆果":1},{"饵料":3}):return say("制作3份饵料需要1份浆果和背包空间。")
		exchange({"浆果":1},{"饵料":3})
		advance(5,false,true)
		log_event("用浆果拌好饵料 ×3，不消耗精力。")
		return true
	if buildings.has(recipe): return say("已经建好了。")
	if recipe in HOUSE_STAGES:
		var stage := HOUSE_STAGES.find(recipe)
		if stage > 0 and not buildings.has(HOUSE_STAGES[stage - 1]): return say("先完成%s，再建%s。" % [HOUSE_STAGES[stage - 1], recipe])
	if recipe == "鱼干" and not buildings.has("篝火") and location != "villa": return say("需要先建造篝火。")
	var gain: Dictionary = {recipe: 1} if recipe in ["鱼干", "家具"] else {}
	var cost: Dictionary = RECIPES[recipe]
	if not can_exchange(cost, gain): return say("材料不足或行囊空间不足，未扣除材料。")
	if energy < 5: return say("先休息，再做手工。")
	exchange(cost, gain)
	if gain.is_empty(): buildings[recipe] = true
	if recipe == "木门与床": buildings["木屋"] = true
	advance(30)
	energy = maxf(0, energy - 3)
	log_event("完成%s。家和手艺都在慢慢变好。" % recipe)
	return true

func eat() -> bool:
	for item: String in ["浆果", "蔬菜", "鱼干", "鲜鱼"]:
		if count(item) > 0:
			inventory[item] = count(item) - 1
			hunger = minf(100, hunger + 35)
			health = minf(100, health + 10)
			advance(10)
			log_event("吃了一份%s，坐下来好好吃饭。" % item)
			return true
	return say("没有食物。岛上采果免费，小镇码头有应急热粥。")

func drink() -> bool:
	thirst = minf(100, thirst + 50)
	advance(10)
	log_event("补充饮水。岛上泉水与镇上码头饮水始终免费。")
	return true

func rest(overnight: bool) -> bool:
	if overnight and location == "island" and not (buildings.has("庇护所") or buildings.has("木屋")):
		return say("先搭庇护所；现在也可免费短休。")
	if overnight and hour() >= 6 and hour() < 18:
		return say("现在还是白天，可短休两小时；18:00 后能睡到明早。")
	var duration := 120.0
	if overnight:
		duration = fposmod(360.0 - fmod(minute, 1440), 1440.0)
		if duration < 1: duration = 1440
	advance(duration, true)
	energy = minf(100, energy + (duration / 360.0 * 100.0 if overnight else 20.0))
	health = minf(100, health + 20)
	if overnight: flags["slept"] = true
	log_event("%s 明日预报：%s。" % ["一夜好眠，新的一天开始了。" if overnight else "歇了两小时，不必把日子过得太急。", weather(day() + 1)])
	return true

func travel(destination: String) -> bool:
	if location == "villa": return say("先走出别墅，再去码头出航。")
	if destination not in ["island", "town", "city"]: return say("未知航线。")
	if destination == location: return say("已经在这里了。")
	if destination == "city" and not city_unlocked(): return say("城市航线需要菜地、完成一次小镇订单及升级船舱。")
	if destination != "island" and weather() in ["雷雨", "大风"]: return say("今天风浪大，先在家加工休息；返岛航线始终可用。")
	if destination != "island" and (hunger < 20 or thirst < 20): return say("出海前先吃饭喝水，避免半路挨饿。")
	advance(120 if destination == "city" or location == "city" else 60)
	island_visit={}
	location = destination
	player_position = [0.0, 0.7, 3.2]
	if destination == "town": flags["visited_town"] = true
	log_event("抵达%s。%s" % [place_name(), "集市 08:00—18:00 营业，晚了可免费借宿。" if destination != "island" else "回家了，卸货吃饭吧。"])
	return true

func place_name() -> String:
	if location=="island" and not island_visit.is_empty():return {"twin_hills":"双丘林岛","crescent_bay":"弯月沙湾","rocky_reef":"礁岩小岛","forest_cape":"长岬林岛"}.get(island_visit.id,"小岛")+" · 探索"
	return {"island": "晴屿 · 自家小岛", "town": "青湾镇 · 港口集市", "city": "临海城 · 贸易街", "villa": "晴屿别墅 · %s" % ("一层" if home_floor == 0 else "二层")}.get(location, "小岛")

func market_open() -> bool:
	return location in ["town", "city"] and hour() >= 8 and hour() < 18

func price(item: String) -> int:
	var base := float(BASE_PRICES.get(item, 0))
	var multiplier := 1.0
	if (season() == 3 and item in ["木材", "鱼干"]) or (season() == 1 and item == "鲜鱼") or (season() == 0 and item == "蔬菜"):
		multiplier = 1.2
	if location == "city" and item in ["家具", "鱼干"]: multiplier *= 1.15
	return maxi(1, int(round(base * multiplier)))

func credit(amount: int) -> void:
	coins += amount
	income += amount
	week_income += amount

func debit(amount: int) -> void:
	coins -= amount
	spending += amount
	week_spending += amount

func sell(item: String, amount: int = 1) -> bool:
	if not market_open(): return say("请在镇上或城市的 08:00—18:00 交易。")
	if not BASE_PRICES.has(item) or amount <= 0 or count(item) < amount: return say("货物不足或不能出售。")
	var revenue := 0
	for i in range(amount):
		revenue += price(item) if i < demand else maxi(1, int(price(item) * 0.6))
	inventory[item] = count(item) - amount
	demand = maxi(0, demand - amount)
	credit(revenue)
	sales += amount
	flags["sold"] = true
	log_event("出售 %s ×%d，收入 %d 贝币。" % [item, amount, revenue])
	return true

func barter() -> bool:
	if not market_open(): return say("换物摊 08:00—18:00 营业。")
	if flags.has("barter_%d" % day()): return say("今日种子换物已完成，明日再来。")
	if not can_exchange({"鱼干": 4}, {"种子": 1}): return say("需要 4 份鱼干，并留出种子空间；未扣货。")
	exchange({"鱼干": 4}, {"种子": 1})
	flags["bartered"] = true
	flags["barter_%d" % day()] = true
	log_event("4 份鱼干换回一袋种子。没带钱也能做买卖。")
	return true

func buy(product: String) -> bool:
	if not market_open(): return say("商店现在休息，早上 08:00 再来。")
	var costs := {"种子": 40, "好鱼竿": 80, "船舱": 120}
	if not costs.has(product): return say("没有这件商品。")
	if product != "种子" and buildings.has(product): return say("已经拥有了。")
	var cost := int(costs[product])
	if coins < cost: return say("贝币不足。可先出售或以物易物，不需要充值。")
	if product == "种子" and not can_exchange({}, {"种子": 1}): return say("行囊已满。")
	debit(cost)
	if product == "种子": exchange({}, {"种子": 1})
	else: buildings[product] = true
	log_event("买下%s，花费 %d 贝币。这是劳动换来的改善。" % [product, cost])
	return true

func plant() -> bool:
	if location != "island" or not buildings.has("菜地"): return say("先在岛上建菜地。")
	if crop_ready >= 0: return say("菜地里已经有作物了。")
	if count("种子") < 1: return say("需要一袋种子，可去镇上换物或购买。")
	inventory["种子"] -= 1
	crop_ready = minute + (2880 if season() == 3 else 1440)
	advance(20)
	log_event("种下蔬菜，%s后成熟；周末不照料也不会枯死。" % ["两个游戏日" if season() == 3 else "一个游戏日"])
	return true

func harvest() -> bool:
	if location != "island" or crop_ready < 0 or minute < crop_ready: return say("作物还未成熟，或这里没有菜地。")
	if not can_exchange({}, {"蔬菜": 6}): return say("行囊已满，成熟蔬菜会等你。")
	exchange({}, {"蔬菜": 6})
	crop_ready = -1
	log_event("收获 6 份蔬菜，可以自用、售卖或备货。")
	return true

func workdays_left(due_day: int) -> int:
	var result := 0
	for d in range(day() + 1, due_day + 1):
		if d % 7 < 5: result += 1
	return result

func accept_order() -> bool:
	if not market_open(): return say("先在营业时间去订单板。")
	if weekend(): return say("双休不发生产订单，逛集市或休息吧。")
	if not order.is_empty(): return say("先交付或取消现有订单。")
	if flags.has("order_%d" % day()): return say("今天的订单已经交付，下个工作日再来。")
	var due := day()
	var remaining := 3
	while remaining > 0:
		due += 1
		if due % 7 < 5: remaining -= 1
	order = {"item": "家具" if location == "city" else "鱼干", "amount": 2 if location == "city" else 3, "reward": 100 if location == "city" else 60, "due": due, "place": location, "first": not flags.has("order_done")}
	log_event("接下订单：%s ×%d，报酬 %d；%s。" % [order.item, order.amount, order.reward, "首单无期限" if order.first else "3 个工作日内交货，周末不扣天数"])
	return true

func deliver_order() -> bool:
	if order.is_empty(): return say("还没有订单。")
	if not market_open() or weekend(): return say("订单交付在工作日 08:00—18:00，周末先休息。")
	if location != order.place: return say("请到接单地点交货。")
	if not order.first and day() > int(order.due): return say("订单已过期，可免费取消；货物仍属于你。")
	var cost := {str(order.item): int(order.amount)}
	if not has_materials(cost): return say("交货材料不足。")
	exchange(cost, {})
	credit(int(order.reward))
	flags["order_done"] = true
	flags["order_%d" % day()] = true
	order = {}
	log_event("交货成功，熟客记住了你的手艺。")
	return true

func city_unlocked() -> bool:
	return buildings.has("菜地") and buildings.has("船舱") and flags.has("order_done")

func quest_done(id: String) -> bool:
	match id:
		"fire": return buildings.has("篝火")
		"home": return (buildings.has("庇护所") or buildings.has("木屋")) and flags.has("slept")
		"house": return buildings.has("木屋")
		"boat": return buildings.has("小船") and flags.has("visited_town")
		"trade": return flags.has("sold") and flags.has("bartered")
		"city": return city_unlocked()
	return false

func current_quest() -> Dictionary:
	for quest: Dictionary in QUESTS:
		if not claimed.has(quest.id): return quest
	return {}

func claim() -> bool:
	var quest := current_quest()
	if quest.is_empty(): return say("主线切片已完成，继续过自己的日子吧。")
	if not quest_done(quest.id): return say(quest.hint)
	claimed[quest.id] = true
	# Quest stipends are tracked separately from labor revenue.
	coins += int(quest.reward)
	log_event("完成「%s」，获得一次性安家补助 %d 贝币。" % [quest.name, quest.reward])
	return true

func snapshot() -> Dictionary:
	var result := {"version": 1}
	for key: String in ["minute", "player_position", "island_visit", "profile", "daily", "home_drinks", "fish_keep", "pending_fish", "fish_catches", "inventory", "buildings", "claimed", "flags", "coins", "energy", "hunger", "thirst", "health", "location", "home_floor", "demand", "market_day", "sales", "order", "crop_ready", "income", "spending", "week_income", "week_spending", "journal"]:
		result[key] = get(key)
	return result.duplicate(true)

static func valid_island_visit(value:Variant) -> bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.get("id") not in ["twin_hills","crescent_bay","rocky_reef","forest_cape"]:return false
	for key:String in ["landing","berth"]:
		if not value.get(key) is Array or value[key].size()!=3:return false
		for number:Variant in value[key]:
			if not (number is int or number is float) or not is_finite(float(number)):return false
		if Vector2(value[key][0],value[key][2]).length()>600 or absf(value[key][1])>100:return false
	if absf(float(value.berth[1])-.05)>.1 or float(value.landing[1])<.12 or float(value.landing[1])>50:return false
	if Vector2(value.berth[0]-value.landing[0],value.berth[2]-value.landing[2]).length()>25:return false
	if not (value.get("heading") is int or value.get("heading") is float) or not is_finite(float(value.heading)):return false
	return true

func restore(data: Dictionary) -> bool:
	data = data.duplicate(true)
	if not data.has("island_visit"):data.island_visit={}
	if not valid_island_visit(data.island_visit):return false
	if not data.has("fish_keep"):data.fish_keep=[]
	if not data.has("pending_fish"):data.pending_fish={}
	if not data.has("fish_catches"):data.fish_catches={}
	if not data.fish_keep is Array or data.fish_keep.size()>80 or not data.pending_fish is Dictionary or not data.fish_catches is Dictionary:return false
	for fish:Variant in data.fish_keep:
		if not valid_fish(fish):return false
	if not data.pending_fish.is_empty() and not valid_fish(data.pending_fish):return false
	for id:Variant in data.fish_catches:
		if id not in preload("res://scripts/life/fish_catalog.gd").DATA or not (data.fish_catches[id] is int or data.fish_catches[id] is float) or not is_finite(float(data.fish_catches[id])) or data.fish_catches[id]<0 or floorf(float(data.fish_catches[id]))!=data.fish_catches[id]:return false
	if data.get("inventory") is Dictionary:
		for item:String in ["饵料","饮料","空饮料瓶"]:
			if not data.inventory.has(item):data.inventory[item]=0
	if not data.has("home_drinks"):data.home_drinks=6
	if not (data.home_drinks is int or data.home_drinks is float) or not is_finite(float(data.home_drinks)) or data.home_drinks<0 or data.home_drinks>6 or float(data.home_drinks)!=floorf(float(data.home_drinks)):return false
	data.home_drinks=int(data.home_drinks)
	if not data.has("home_floor"): data["home_floor"] = 0
	var stored_floor: Variant = data.home_floor
	if not (stored_floor is int or stored_floor is float) or not is_finite(float(stored_floor)) or float(stored_floor) not in [0.0,1.0]: return false
	data.home_floor = int(stored_floor)
	if not data.has("daily"):
		var old_minute: Variant = data.get("minute", 480)
		var old_day := 0
		if (old_minute is int or old_minute is float) and is_finite(float(old_minute)) and float(old_minute) >= 0: old_day = int(float(old_minute) / 1440.0)
		data["daily"] = {"day": old_day, "counts": {}}
	if not valid_daily(data.daily): return false
	if not data.has("profile"): data["profile"] = {"name": "晴屿旅人", "character_id": "skater_coral", "pet": "dog", "pet_name": "小麦", "confirmed": false}
	# 旧版男女选择映射到新外观，保留同一份存档的其他状态。
	if data.profile is Dictionary and not data.profile.has("character_id") and data.profile.get("gender") in ["male", "female"]:
		data.profile = data.profile.duplicate(true)
		data.profile["character_id"] = preload("res://scripts/life/character_catalog.gd").from_profile(data.profile)
		data.profile.erase("gender")
	if not valid_profile(data.profile): return false
	if not data.has("player_position"): data["player_position"] = [0.0, 0.7, 3.2]
	if not data.player_position is Array or data.player_position.size() != 3: return false
	for value: Variant in data.player_position:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if Vector2(float(data.player_position[0]), float(data.player_position[2])).length() > 600.0: return false
	# 存档落在离岸很远又没记录登陆点时，不整份作废：把出生点挪回主岛码头，
	# 玩家最多损失一个位置，不会因为一次异常坐标丢掉整份存档。
	if data.get("location")=="island" and Vector2(float(data.player_position[0]),float(data.player_position[2])).length()>80 and data.island_visit.is_empty():
		data["player_position"] = [3.0, 0.7, 17.0]
	if not (data.get("version") is int or data.get("version") is float): return false
	if int(data.version) != 1: return false
	var defaults := snapshot()
	for key: String in defaults:
		if not data.has(key): return false
	for key: String in ["inventory", "buildings", "claimed", "flags", "order"]:
		if not data[key] is Dictionary: return false
	for key: String in ["minute", "coins", "energy", "hunger", "thirst", "health", "demand", "market_day", "sales", "crop_ready", "income", "spending", "week_income", "week_spending"]:
		if not (data[key] is int or data[key] is float) or not is_finite(float(data[key])): return false
	if data.location not in ["island", "town", "city", "villa"] or not data.journal is Array: return false
	for entry: Variant in data.journal:
		if not entry is String: return false
	for category: String in ["buildings", "claimed", "flags"]:
		for key: Variant in data[category]:
			if not key is String or not data[category][key] is bool: return false
	if data.minute < 0 or data.minute > 100000000 or data.coins < 0: return false
	for item: String in ITEMS:
		if not data.inventory.has(item) or not (data.inventory[item] is int or data.inventory[item] is float): return false
		if data.inventory[item] < 0 or data.inventory[item] > 10000: return false
	if not data.order.is_empty():
		for key: String in ["item", "amount", "reward", "due", "place", "first"]:
			if not data.order.has(key): return false
		if not data.order.first is bool: return false
		if data.order.item not in ["鱼干", "家具"] or data.order.place not in ["town", "city"]: return false
		for key: String in ["amount", "reward", "due"]:
			if not (data.order[key] is int or data.order[key] is float) or data.order[key] < 0: return false
	for key: String in defaults:
		if key != "version": set(key, data[key])
	buildings["小船"]=true # Existing saves also receive a ready boat, without a material cost.
	for item: String in ITEMS: inventory[item] = int(inventory[item])
	for key: String in ["coins", "demand", "market_day", "sales", "income", "spending", "week_income", "week_spending"]:
		set(key, int(get(key)))
	for key: String in ["energy", "hunger", "thirst", "health"]: set(key, clampf(float(get(key)), 0, 100))
	return true

func save_game(path: String = "user://life.json") -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return write_error
	if FileAccess.file_exists(path):
		# Only promote a validated previous save into the backup.
		var previous: Variant = parse_save(path)
		var check := get_script().new() as RefCounted
		if previous is Dictionary and check.restore(previous):
			var copy_error := DirAccess.copy_absolute(path, path + ".bak")
			if copy_error != OK: return copy_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_game(path: String = "user://life.json") -> bool:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var raw: Variant = parse_save(candidate)
		if raw is Dictionary and restore(raw):
			last_message = "读档成功。离开期间世界停在原来的时间。" if candidate == path else "主存档异常，已恢复上一次备份。"
			return true
	return false

func parse_save(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

static func valid_profile(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["name", "character_id", "pet", "pet_name"]:
		if not value.has(key) or not value[key] is String: return false
	return value.get("confirmed") is bool and preload("res://scripts/life/character_catalog.gd").CHARACTERS.has(value.character_id) and preload("res://scripts/life/companion_catalog.gd").NAMES.has(value.pet) and value.name.strip_edges().length() > 0 and value.name.length() <= 24 and value.pet_name.length() <= 24

func ensure_daily() -> void:
	if int(daily.day) != day(): daily = {"day": day(), "counts": {}}

func daily_count(id: String) -> int:
	ensure_daily()
	return int(daily.counts.get(id, 0))

func daily_done(id: String) -> bool:
	return DAILY_TARGETS.has(id) and daily_count(id) >= int(DAILY_TARGETS[id])

static func valid_daily(value: Variant) -> bool:
	if not value is Dictionary or not value.get("counts") is Dictionary: return false
	var day_value: Variant = value.get("day")
	if not (day_value is int or day_value is float) or not is_finite(float(day_value)) or day_value < 0 or day_value > 100000: return false
	for id: Variant in value.counts:
		if id not in DAILY_TARGETS: return false
		var amount: Variant = value.counts[id]
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount < 0 or amount > int(DAILY_TARGETS[id]): return false
	return true

func bathe_at_home() -> bool:
	if location != "villa" or home_floor != 1: return say("请到别墅二楼浴室。")
	if flags.get("villa_bath", false): return say("今天已经洗过澡了，好好休息吧。")
	advance(20)
	health = minf(100, health + 5)
	energy = minf(100, energy + 5)
	flags["villa_bath"] = true
	log_event("洗了个热水澡，换上干净衣服，家的感觉真好。")
	return true

func start_shore_fishing() -> bool:
	if location != "island": return say("先到岛上的钓鱼台。")
	if weather() in ["雷雨","大风"]: return say("风浪太大，等天气平稳再垂钓。")
	if not can_exchange({}, {"鲜鱼":1}): return say("背包已满，先整理出放鱼的空间。")
	advance(20,false,true)
	log_event("抛竿垂钓：花费20分钟，不消耗精力，留意浮漂。")
	return true
func land_shore_fish(amount: int = 1) -> bool:
	if amount not in [1,2]:return false
	if location != "island": return say("已经离开钓台，鱼已放回海里。")
	if not can_exchange({}, {"鲜鱼":amount}): return say("背包已满，鱼已放回海里。")
	exchange({}, {"鲜鱼":amount})
	flags["labor"] = true
	log_event("稳稳收竿，钓到鲜鱼 ×%d。"%amount)
	return true

func kept_portions() -> int:
	var total:int=0
	for fish:Dictionary in fish_keep:total+=int(fish.portions)
	return total
static func valid_fish(fish:Variant) -> bool:
	if not fish is Dictionary or fish.get("species","") not in preload("res://scripts/life/fish_catalog.gd").DATA:return false
	var amount:Variant=fish.get("portions",0);var weight:Variant=fish.get("weight",0)
	return (amount is int or amount is float) and float(amount) in [1.0,2.0] and (weight is int or weight is float) and is_finite(float(weight)) and weight>0 and weight<=20
func secure_shore_fish(species:String,amount:int,weight:float) -> bool:
	var fish:Dictionary={"species":species,"portions":amount,"weight":weight}
	if not pending_fish.is_empty() or location!="island" or not valid_fish(fish):return false
	if not can_exchange({},{"鲜鱼":amount}):return say("背包已满，鱼已放回海里。")
	pending_fish=fish;return true
func stow_pending_fish() -> bool:
	if pending_fish.is_empty():return false
	var fish:Dictionary=pending_fish.duplicate(true);pending_fish.clear();fish_keep.append(fish)
	fish_catches[fish.species]=int(fish_catches.get(fish.species,0))+1
	flags["labor"]=true;log_event("摘钩装入鱼护：%s，约 %.1f 公斤。"%[preload("res://scripts/life/fish_catalog.gd").DATA[fish.species].name,fish.weight]);return true
func pack_keep_net() -> bool:
	stow_pending_fish()
	if fish_keep.is_empty():return false
	var amount:int=kept_portions();inventory["鲜鱼"]=count("鲜鱼")+amount;fish_keep.clear()
	log_event("收好鱼护，将鲜鱼 ×%d 带进背包。"%amount);return true
func catch_sea_species() -> bool:
	if not labor("捕鱼"):return false
	var id:String=preload("res://scripts/life/fish_catalog.gd").catch_id(true,randf(),true)
	fish_catches[id]=int(fish_catches.get(id,0))+1
	log_event("船边捕获：%s，已收好鲜鱼。"%preload("res://scripts/life/fish_catalog.gd").DATA[id].name);return true

func take_fridge_drink() -> bool:
	if location!="villa" or home_floor!=0:return say("先到一楼冰箱旁。")
	if home_drinks<=0:return say("冰箱里的饮料喝完了，可以补充库存。")
	if not can_exchange({},{"饮料":1}):return say("背包满了，先腾出一个位置。")
	home_drinks-=1;exchange({},{"饮料":1});log_event("从冰箱取出一瓶饮料。");return true
func drink_beverage() -> bool:
	if count("饮料")<1:return say("先从冰箱取一瓶饮料。")
	exchange({"饮料":1},{"空饮料瓶":1});thirst=minf(100,thirst+30);hunger=minf(100,hunger+8);advance(2)
	log_event("喝完饮料，留下一个空瓶，去垃圾桶旁丢掉吧。");return true
func nap_in_rocker() -> bool:
	energy=minf(100,energy+12);advance(45)
	log_event("在海风里摇着摇椅打了个盹。");return true
func nap_on_sofa() -> bool:
	energy=minf(100,energy+8);advance(60)
	log_event("靠在沙发上打了个盹，歇了一小时。");return true
func discard_bottle() -> bool:
	if count("空饮料瓶")<1:return say("没有需要丢弃的空瓶。")
	inventory["空饮料瓶"]-=1;log_event("把空饮料瓶投入垃圾桶。");return true
func restock_drink() -> bool:
	if coins<2:return say("补充一瓶饮料需要2贝币。")
	if home_drinks>=6:return say("冰箱里最多放6瓶饮料。")
	coins-=2;spending+=2;week_spending+=2;home_drinks+=1;log_event("花2贝币补充一瓶饮料。");return true
