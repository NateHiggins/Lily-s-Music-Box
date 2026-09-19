extends Node
class Probe extends FunctionalProp:
	var deliveries := 0
	func _perform_synced_event(_index: int, _accent: float, _pitch: float) -> void:
		deliveries += 1

var failures := 0
func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("PROP EVENT LIFETIME: " + label)

func _run() -> void:
	var old_infection: float = Conductor.infection
	Conductor.infection = 1.0
	var prop := Probe.new()
	prop.graph_node_id = "lifetime_test_only"
	add_child(prop)
	prop.profile = {"infection_receptivity": 1.0, "minimum_action_interval": 0.0,
			"response_latency": 0.05, "timing_drift": 0.0}
	AcousticGraphData.network_event.emit(prop.graph_node_id, 1, 1.0, 0.0, 1.0)
	await get_tree().create_timer(0.08).timeout
	_check(prop.deliveries == 1, "live delivery reaches mechanism")
	remove_child(prop)
	AcousticGraphData.network_event.emit(prop.graph_node_id, 2, 1.0, 0.0, 1.0)
	AcousticGraphData.reality_event.emit("test", prop.graph_node_id, 1.0, 1)
	await get_tree().create_timer(0.08).timeout
	_check(prop.deliveries == 1, "detached global deliveries are ignored")
	add_child(prop)
	AcousticGraphData.network_event.emit(prop.graph_node_id, 3, 1.0, 0.0, 1.0)
	remove_child(prop)
	add_child(prop)
	await get_tree().create_timer(0.08).timeout
	_check(prop.deliveries == 1, "old timer cannot act on a later attachment")
	AcousticGraphData.network_event.emit(prop.graph_node_id, 4, 1.0, 0.0, 1.0)
	await get_tree().create_timer(0.08).timeout
	_check(prop.deliveries == 2, "new attachment still receives current events")
	prop.free()
	Conductor.infection = old_infection
	print("PROP EVENT LIFETIME: 4 checks; %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
