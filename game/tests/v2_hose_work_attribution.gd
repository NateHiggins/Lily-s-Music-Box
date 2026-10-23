extends "res://tests/v2_hose_installed_world.gd"
## The same ten-waypoint repaired-hose input route and real disk reconstruction.
var work_probe: Node
var automatic_path: String=""
var original_path: String=""
var original_persistence:=false
func _ready() -> void:
	work_probe=preload("res://tests/v2_frame_work_probe.gd").new();work_probe.host=self;add_child(work_probe)
	super._ready()
func _play_route() -> void:
	if OS.get_environment("V2_WORK_PERSISTENCE")=="1":
		original_path=RealityState.save_path;original_persistence=RealityState.persistence_enabled
		automatic_path="user://v2_work_trace_%d.json"%Time.get_ticks_usec()
		RealityState.save_path=automatic_path;RealityState.persistence_enabled=true
	world.household_state.profiling=true
	player._grab.profiling=true
	await super._play_route()
	if not automatic_path.is_empty():
		var result: Dictionary={"evidence_class":"INERT","automatic_persistence":true,"owned_path":automatic_path,"file_exists_before_cleanup":FileAccess.file_exists(automatic_path),"last_save_result":RealityState._last_save_result.duplicate(true),"cleanup":[]}
		RealityState.persistence_enabled=original_persistence;RealityState.save_path=original_path
		for suffix: String in ["",".bak",".tmp",".txn"]:
			var path:=ProjectSettings.globalize_path(automatic_path+suffix)
			if FileAccess.file_exists(path):result.cleanup.append({"suffix":suffix,"error":DirAccess.remove_absolute(path)})
		FileAccess.open(OS.get_environment("SHOT_DIR").path_join("automatic_persistence.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
func _save_reload(wanted: Dictionary) -> void:
	profile_active=false
	work_probe.write(OS.get_environment("SHOT_DIR").path_join("work_trace.json"))
	await _paired_unchanged_control()
	if not automatic_path.is_empty():await _paired_commit_control()
	# The controls yield real frames: the remote cabinet can close normally.
	# Compare disk reconstruction with the pose at save time, not before the
	# diagnostic's extra elapsed time. Keep both expectations as evidence.
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
	var at_save: Dictionary=actor.mechanism_snapshot()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("save_expectation.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Expected physical state renewed after asynchronous diagnostic controls. Natural motion remains enabled; no restore tolerance changed.","before_controls":wanted,"at_save":at_save},"\t"))
	await super._save_reload(at_save)

func _paired_commit_control() -> void:
	var owner: Node=world.household_state
	var phases: Array=[]
	for index in 4:
		owner.reuse_unchanged_validation=index%2==1
		var rows: Array=[];var preserved:=true
		for sample in 8:
			await get_tree().process_frame
			owner.capture_now()
			var saved: Dictionary=owner._saved_value().duplicate(true)
			var started:=Time.get_ticks_usec()
			RealityState.commit()
			var elapsed:=Time.get_ticks_usec()-started
			var ok: bool=saved==owner._saved_value() and not owner._blocked and not RealityState.save_write_blocked and bool(RealityState._last_save_result.get("ok",false))
			preserved=preserved and ok
			rows.append({"elapsed_usec":elapsed,"saved_household_preserved":ok,"save_result":RealityState._last_save_result.duplicate(true)})
		phases.append({"index":index,"reuse":owner.reuse_unchanged_validation,"samples":rows})
		_check(preserved,"real automatic commit preserves household state and succeeds on disposable storage: "+str(index))
	owner.reuse_unchanged_validation=true
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("commit_pairs.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Interleaved synchronous RealityState.commit with normal persistence enabled on disposable storage. Outside measured route; includes snapshot, serialization, storage and state notifications.","phases":phases},"\t"))

func _paired_unchanged_control() -> void:
	# Outside route timing. Identical current payload, real production owner;
	# original/cached/restored/cached order controls CPU drift and saved authority.
	var owner: Node=world.household_state
	var phases: Array=[]
	for index in 4:
		owner.reuse_unchanged_validation=index%2==1
		var rows: Array=[];var preserved:=true
		for sample in 20:
			await get_tree().process_frame
			var document: Dictionary=RealityState.data
			var saved: Dictionary=owner._saved_value().duplicate(true)
			var previous: Dictionary=owner._last_saved.duplicate(true)
			var first: int=owner.profile_records.size()
			var started:=Time.get_ticks_usec();owner._on_state_changed();var elapsed:=Time.get_ticks_usec()-started
			var unchanged: bool=is_same(document,RealityState.data) and saved==owner._saved_value() and previous==owner._last_saved and not owner._blocked
			preserved=preserved and unchanged
			var stages: Array=[]
			for row: Dictionary in owner.profile_records.slice(first):stages.append(row.stage)
			rows.append({"elapsed_usec":elapsed,"authority_preserved":unchanged,"stages":stages})
		phases.append({"index":index,"reuse":owner.reuse_unchanged_validation,"samples":rows})
		_check(preserved,"paired unchanged notification preserves the campaign document and household payload: "+str(index))
	owner.reuse_unchanged_validation=true
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("unchanged_pairs.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Interleaved direct notification CPU controls after the actual route, before disk rebuild. Not player-input or whole-frame gain proof.","phases":phases},"\t"))
