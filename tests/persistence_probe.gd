extends SceneTree
const State = preload("res://scripts/life/life_state.gd")
func _initialize() -> void:
	var path := "user://restart_probe.json"
	var s = State.new()
	if "--write-probe" in OS.get_cmdline_user_args():
		s.labor("伐木")
		s.drink()
		var error: Error = s.save_game(path)
		print("RESTART WRITE: ", error_string(error))
		quit(0 if error == OK else 1)
	else:
		var ok: bool = s.load_game(path) and s.count("木材") == 4 and is_equal_approx(s.minute, 535)
		print("RESTART READ: ", "PASS" if ok else "FAIL")
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
		quit(0 if ok else 1)
