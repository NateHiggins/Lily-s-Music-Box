extends Node
## Canonical production-build timing probe. This intentionally measures the
## synchronous scene assembly separately from resource load; capture suites
## cannot spend the same 60-second ceiling twice.

const ROOT_SCENE := "res://scenes/building/orison_root.tscn"
const WARNING_MS := 24000.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	var start := Time.get_ticks_usec()
	var packed := load(ROOT_SCENE) as PackedScene
	var loaded := Time.get_ticks_usec()
	if packed == null:
		printerr("[BOOT COST] FAIL root scene did not load")
		get_tree().quit(1)
		return
	var root := packed.instantiate()
	var instantiated := Time.get_ticks_usec()
	add_child(root)
	var assembled := Time.get_ticks_usec()
	await get_tree().process_frame
	var first_frame := Time.get_ticks_usec()
	var load_ms := float(loaded - start) / 1000.0
	var instantiate_ms := float(instantiated - loaded) / 1000.0
	var assembly_ms := float(assembled - instantiated) / 1000.0
	var first_frame_ms := float(first_frame - assembled) / 1000.0
	var total_ms := float(first_frame - start) / 1000.0
	print("[BOOT COST] resource_load_ms=%.1f instantiate_ms=%.1f " % [
			load_ms, instantiate_ms] + "assembly_ms=%.1f first_frame_ms=%.1f " % [
			assembly_ms, first_frame_ms] + "total_ms=%.1f" % total_ms)
	print("[BOOT COST] RESULT: %s (warning ceiling %.0f ms)" % [
			"PASS" if total_ms <= WARNING_MS else "WARN", WARNING_MS])
	get_tree().quit(0)
