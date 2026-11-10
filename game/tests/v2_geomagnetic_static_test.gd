extends Node
## Aurora-night static on the V2 radios (v1r_geomagnetic_static_20261109):
## a switched-on set hears the storm while the aurora shows, at the set and on
## its own bus; the static stops when the aurora fades and goes with the set.
const RadioProp := preload("res://scripts/building/orison_v2_radio_prop.gd")
const AURORA := 20

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	var radio: Node = null
	for node in world.find_children("*", "", true, false):
		if node.get_script() == RadioProp:
			radio = node
			break
	_check(radio != null, "the V2 world has a household set")
	var weather := get_tree().get_first_node_in_group("weather_manager")
	_check(weather != null, "V2 runs the weather manager that schedules the aurora")
	if radio == null or weather == null:
		_finish(world)
		return
	if radio.powered:
		radio.interact()
	radio.interact()
	_check(radio.powered, "the set is switched on")
	var storm: AudioStreamPlayer3D = radio.get_node_or_null("GeomagneticStatic")
	_check(storm != null, "a switched-on set carries the storm receiver")
	if storm == null:
		_finish(world)
		return
	_check(storm.bus == radio._programme.bus, "the static plays on the set's own bus (%s)" % storm.bus)
	_check(storm.global_position.is_equal_approx(radio._programme.global_position), "the static is heard at the set")
	weather.force_phenomenon("aurora", 0.0)
	for i in 5: await get_tree().process_frame
	_check(not storm.playing, "no aurora, no static")
	# Bring the aurora through the weather manager's own phenomenon path.
	weather.force_phenomenon("aurora", 1.0)
	for i in 30: await get_tree().process_frame
	_check(storm.playing and storm.level > 0.9, "the aurora brings the static (level %.2f)" % storm.level)
	radio.interact()
	await get_tree().process_frame
	_check(not radio.powered and not is_instance_valid(storm) or storm.is_queued_for_deletion(),
		"switching the set off takes the static with it")
	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 GEOMAGNETIC STATIC] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
