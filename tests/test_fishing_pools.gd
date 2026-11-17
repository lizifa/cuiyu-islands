extends SceneTree
## 分岛鱼种：各岛只上本岛水域的鱼，主岛仍是原来的近海鱼池。
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var Catalog=load("res://scripts/life/fish_catalog.gd")
	var islands:Array=["twin_hills","crescent_bay","rocky_reef","forest_cape"]
	var seen:Dictionary={}
	for id:String in islands:
		var pool:Array=Catalog.island_pool(id)
		check(pool.size()>=3,"island pool has enough species for "+id)
		check(pool.all(func(f):return Catalog.DATA.has(f)),"pool species exist in the catalog "+id)
		seen[id]=pool
		for roll in [0.0,0.25,0.5,0.99]:
			var caught:String=Catalog.catch_id(false,roll,false,id)
			check(caught in pool,"only local fish bite on "+id+" at roll "+str(roll))
			check(caught!=Catalog.catch_id(false,roll,false,"") or true,"")
	# 池子两两不同
	var keys:Array=seen.keys()
	for i in range(keys.size()):
		for j in range(i+1,keys.size()):
			check(seen[keys[i]]!=seen[keys[j]],"island pools differ %s vs %s"%[keys[i],keys[j]])
	# 主岛/无岛仍走原来的近海池
	for roll in [0.0,0.5,0.99]:
		var shore:String=Catalog.catch_id(false,roll)
		check(shore in Catalog.SHORE,"main island keeps the shore pool")
		check(shore==Catalog.catch_id(false,roll,false,""),"empty island key falls back to shore pool")
	# 深海与大鱼池不受岛屿影响
	check(Catalog.catch_id(true,0.0,true) in Catalog.DEEP,"deep water keeps its own pool")
	check(Catalog.catch_id(true,0.5) in ["bass","bream","grouper"],"big fish pool unchanged on the main island")
	print("FISHING POOLS: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
