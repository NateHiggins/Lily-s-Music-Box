extends "res://tests/orison_v2_m08f_runtime_test.gd"
## Observe the existing composed route without replacing its interactions.

var audio_witnesses: Dictionary = {}

func _check(ok: bool, label: String) -> void:
	super._check(ok, label)
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if not (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
			continue
		if node.stream != null and node.stream.resource_path.ends_with("appliance_pop.ogg"):
			_watch(node.stream, str(node.get_path()), "stream", label)
			if node.has_stream_playback():
				_watch(node.get_stream_playback(), str(node.get_path()), "playback", label)
	if label == "committed selector remains v1":
		var alive: Array[Dictionary] = []
		for witness: Dictionary in audio_witnesses.values():
			if witness.reference.get_ref() != null:
				alive.append({"class": witness.reference.get_ref().get_class(),
						"kind": witness.kind, "owners": witness.owners})
		print("ASTRA_M08F_RETAINED " + JSON.stringify(alive))
		print("ASTRA_M08F_POLICY " + JSON.stringify(AudioPolicy.event_history()))
		if not alive.is_empty():
			failures += 1

func _watch(resource: RefCounted, owner_path: String, kind: String, label: String) -> void:
	var identity := resource.get_instance_id()
	if not audio_witnesses.has(identity):
		audio_witnesses[identity] = {"reference": weakref(resource), "kind": kind,
				"owners": []}
	var observation := owner_path + " @ " + label
	if observation not in audio_witnesses[identity].owners:
		audio_witnesses[identity].owners.append(observation)
