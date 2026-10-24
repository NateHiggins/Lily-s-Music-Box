extends Node3D
## Isolates the complete existing dense native world-contact programme.
## Diagnostic only: does not qualify deployment, input, art or runtime contracts.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var model: Node3D=load("res://assets/props/fire_capacity_candidate.glb").instantiate()
	add_child(model)
	var rig:=preload("res://scripts/props/native_hose_rig.gd").new()
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fire_capacity_rig.json"))
	if not rig.configure(model,projection):
		push_error("CONTACT ENVELOPE: native rig configuration failed")
		get_tree().quit(1)
		return
	var programme:=preload("res://tests/v2_fire_hose_world_contact_programme.gd").new()
	var excluded: Array[RID]=[]
	var contact: RefCounted=await programme.run(self,rig,excluded)
	print("CONTACT ENVELOPE: failures=",programme.failures.size()," capsule_queries=",contact.capsule_queries," clears=",contact.capsule_clears)
	get_tree().quit(0 if programme.failures.is_empty() else 1)
