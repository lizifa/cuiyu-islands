extends Node
## Event-based pulses with a global gap; never queue delayed vibration patterns.
signal played(event: String, duration_ms: int, amplitude: float)
const STORE := "user://haptics.cfg"
const PULSES := {
	"cast": [24, .25, 250],
	"bite": [65, .8, 500],
	"hook": [45, .65, 250],
	"reel": [12, .22, 650],
	"tension": [35, .7, 700],
	"slack": [18, .3, 700],
	"land": [75, .85, 500],
	"escape": [45, .35, 500],
}
var app: Node
var enabled := true
var clock: Callable = Time.get_ticks_msec
var last_at: Dictionary = {}
var last_pulse := -100000
func setup(owner_app: Node) -> void:
	app=owner_app
	var config := ConfigFile.new()
	if not app.test_mode and config.load(STORE)==OK:
		var value: Variant=config.get_value("feedback","enabled",true)
		if value is bool: enabled=value
func set_enabled(value: bool) -> void:
	enabled=value
	if not enabled: reset()
	if app.test_mode: return
	var config := ConfigFile.new()
	config.set_value("feedback","enabled",enabled)
	config.save(STORE)
func reset() -> void:
	last_at.clear()
	last_pulse=-100000
func play(event: String) -> bool:
	if not enabled or app.perf_probe or not app.movement_enabled() or not PULSES.has(event): return false
	var now: int=int(clock.call())
	var pulse: Array=PULSES[event]
	if now-last_pulse<80 or now-int(last_at.get(event,-100000))<int(pulse[2]): return false
	last_at[event]=now
	last_pulse=now
	played.emit(event,int(pulse[0]),float(pulse[1]))
	if not app.test_mode and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(pulse[0]),float(pulse[1]))
	return true
