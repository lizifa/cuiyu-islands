extends SceneTree
const State=preload("res://scripts/life/life_state.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize():
 if "--test-mode" not in OS.get_cmdline_user_args():quit(1);return
 var state=State.new()
 check(state.secure_shore_fish("bass",2,2.1),"landed fish enters durable pending custody")
 check(state.count("鲜鱼")==0 and state.load_count()==6,"pending fish reserves capacity without entering backpack")
 check(not state.secure_shore_fish("bream",1,.6),"duplicate landing cannot replace pending fish")
 var recovered=State.new();check(recovered.restore(JSON.parse_string(JSON.stringify(state.snapshot()))),"pending fish survives serialized save/load")
 check(recovered.stow_pending_fish() and recovered.kept_portions()==2 and recovered.fish_catches.bass==1,"recovery deposits pending fish once")
 check(not recovered.stow_pending_fish() and recovered.kept_portions()==2,"repeated recovery cannot duplicate fish")
 var stored=State.new();check(stored.restore(JSON.parse_string(JSON.stringify(recovered.snapshot()))),"keep net species and weight survive save/load")
 check(stored.pack_keep_net() and stored.count("鲜鱼")==2 and stored.fish_keep.is_empty(),"leaving packs fish exactly once")
 check(not stored.pack_keep_net() and stored.count("鲜鱼")==2,"repeated packing grants no extra fish")
 var old:Dictionary=State.new().snapshot();old.erase("fish_keep");old.erase("pending_fish");old.erase("fish_catches")
 check(State.new().restore(old),"old save migrates with empty keep net")
 var malformed:Dictionary=recovered.snapshot();malformed.fish_keep[0].species="invalid"
 check(not State.new().restore(malformed),"unknown species rejects corrupt save")
 malformed=recovered.snapshot();malformed.fish_keep[0].weight=-1
 check(not State.new().restore(malformed),"invalid fish weight rejects corrupt save")
 var full=State.new();full.inventory["浆果"]=0;full.inventory["木材"]=78
 check(full.secure_shore_fish("grouper",2,3) and not full.can_exchange({},{"石材":1}),"pending catch reserves the last bag slots")
 full.stow_pending_fish();check(full.load_count()==80 and not full.can_exchange({},{"石材":1}),"stored fish continues reserving capacity")
 full.pack_keep_net();check(full.load_count()==80 and full.count("鲜鱼")==2,"packing preserves total load")
 print("KEEP NET: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
