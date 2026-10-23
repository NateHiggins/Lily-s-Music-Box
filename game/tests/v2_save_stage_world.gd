extends "res://tests/v2_hose_work_attribution.gd"
## INERT same actual route; component controls run AFTER timed input capture.
const StorageProbe := preload("res://tests/save_stage_storage_probe.gd")

func _paired_commit_control() -> void:
	await super._paired_commit_control()
	var owner: Node = world.household_state
	owner.capture_now()
	var out := OS.get_environment("SHOT_DIR")
	var pretty := JSON.stringify(RealityState.data,"\t",true,true).to_utf8_buffer()
	FileAccess.open(out.path_join("snapshot.json"),FileAccess.WRITE).store_buffer(pretty)
	var serialization: Array = []
	for index in 4:
		var times: Array = []
		var size := 0
		for sample in 8:
			var started := Time.get_ticks_usec()
			var bytes := JSON.stringify(RealityState.data,"\t" if index%2==0 else "",true,true).to_utf8_buffer()
			times.append(Time.get_ticks_usec()-started)
			size = bytes.size()
		serialization.append({"pretty":index%2==0,"bytes":size,"times_usec":times})
	var probe := StorageProbe.new()
	probe.path = "user://v2_storage_stage_%d.json" % Time.get_ticks_usec()
	probe.validate_document = Callable(RealityState,"_validate_document")
	var seed_result: Dictionary = probe.write_snapshot(pretty)
	var phases: Array = []
	for phase in 4:
		probe.fast_utf8 = phase%2==1
		var rows: Array = []
		var succeeded := bool(seed_result.ok)
		for sample in 6:
			await get_tree().process_frame
			probe.records.clear()
			var started := Time.get_ticks_usec()
			var result: Dictionary = probe.write_snapshot(pretty)
			var elapsed := Time.get_ticks_usec()-started
			succeeded = succeeded and bool(result.ok)
			rows.append({"usec":elapsed,"result":result,"stages":probe.records.duplicate(true)})
		phases.append({"fast_utf8":probe.fast_utf8,"rows":rows})
		_check(succeeded,"component storage controls use real verified writes without changing save authority: "+str(phase))
	probe.records.clear()
	var reloaded: Dictionary = probe.load_snapshot()
	_check(reloaded.status=="loaded" and reloaded.data==JSON.parse_string(pretty.get_string_from_utf8()),"component storage reader reconstructs exact snapshot values")
	var cleanup: Array = []
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path := ProjectSettings.globalize_path(probe.path+suffix)
		if FileAccess.file_exists(path): cleanup.append({"suffix":suffix,"error":DirAccess.remove_absolute(path)})
	FileAccess.open(out.path_join("storage_stages.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Same occupied-world snapshot, alternating original/sparse UTF-8 candidate in diagnostic subclass only. Same verified storage path, outside active route timing. Nested stage costs are inclusive.","bytes":pretty.size(),"serialization":serialization,"phases":phases,"cleanup":cleanup},"\t"))
