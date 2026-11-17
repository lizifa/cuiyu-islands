extends Node
## Opt-in device telemetry. Never advances survival state or writes game saves.
var elapsed := 0.0
var sampled := 0.0
var count := 0
var totals := Vector4.ZERO
var started_at := Time.get_unix_time_from_system()
func _ready() -> void:
	var start := FileAccess.open("user://perf_probe_started.txt",FileAccess.WRITE)
	if start: start.store_string("measurement-only; saves disabled")
	var pending := FileAccess.open("user://perf_probe.json",FileAccess.WRITE)
	if pending: pending.store_string(JSON.stringify({"status":"running","started_at":started_at}))
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 10: return
	sampled += delta
	count += 1
	totals += Vector4(Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if elapsed >= 90:
		var report := {"started_at":started_at,"seconds":sampled,"frames":count,"fps":count/sampled,"process_ms":totals.x/count,"physics_ms":totals.y/count,"draw_calls":totals.z/count,"primitives":totals.w/count,"renderer":RenderingServer.get_video_adapter_name(),"location":get_parent().state.location}
		var file := FileAccess.open("user://perf_probe.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report))
		print("PERF_PROBE ", JSON.stringify(report))
		set_process(false)
		get_parent().paused = true
		get_parent().inactive = true
		Engine.max_fps = 5
		get_tree().quit()
