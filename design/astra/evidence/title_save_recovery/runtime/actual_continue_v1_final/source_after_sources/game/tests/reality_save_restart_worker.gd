extends Node
## Separate-process fixture. The controller isolates APPDATA before autoload,
## seeds an old production save, and kills only this PID after a verified marker.

var failures := 0
var samples := 0


func _ready() -> void:
	CampaignTime.set_frozen_for_tests(true)
	RealityState.new_campaign_time_provider = _sample
	var mode := OS.get_environment("SAVE_RECOVERY_WORKER_MODE")
	if mode == "writer":
		var next: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				OS.get_environment("SAVE_RECOVERY_NEXT")))
		_check(RealityState.can_continue(), "writer boot loaded the old campaign")
		RealityState.data.merge(next, true)
		RealityState.storage_operation_override = _checkpoint
		RealityState.save_game()
		# The controller must terminate us inside _checkpoint. Reaching here is
		# a timeout/error, never a simulated successful process interruption.
		_check(false, "writer unexpectedly returned from interruption checkpoint")
	elif mode == "reader":
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				OS.get_environment("SAVE_RECOVERY_EXPECTED")))
		_check(RealityState.can_continue(), "new reader autoload selected a complete campaign")
		_check(_projection(RealityState.data) == _projection(expected),
				"new reader reconstructs one complete job/item/dream/clock generation")
		_check(samples == 0, "reader's scene-installed callback remains unused after scene initialization")
	elif mode == "first_fail":
		_check(RealityState.load_status().status == "missing", "first creation begins with no save or artifacts")
		RealityState.storage_operation_override = _fail_temp_readback
		_check(not RealityState.start_new_campaign(), "first New reports actual temp verification failure")
		_check(samples == 1 and not RealityState.can_continue(), "failed creation sampled once and exposes no Continue")
		_check(not FileAccess.file_exists(RealityState.SAVE_PATH)
				and FileAccess.file_exists(RealityState.SAVE_PATH + ".tmp"),
				"failed first creation leaves only the uncommitted temporary candidate")
	elif mode == "first_protected":
		_check(RealityState.load_status().status == "protected" and RealityState.save_write_blocked,
				"new process protects orphan-only first-creation artifacts")
		_check(not RealityState.can_continue() and not FileAccess.file_exists(RealityState.SAVE_PATH),
				"new reader never promotes the orphan temp into Continue")
		var before := FileAccess.get_sha256(RealityState.SAVE_PATH + ".tmp")
		RealityState.commit()
		var clock := CampaignClock.new()
		clock.creation_time_provider = _sample
		_check(not clock.bind_state() and samples == 0, "protected orphan load never resamples its clock")
		_check(FileAccess.get_sha256(RealityState.SAVE_PATH + ".tmp") == before,
				"ordinary commit preserves the orphan artifact bytes")
	elif mode == "first_retry":
		_check(RealityState.save_write_blocked and not RealityState.can_continue(),
				"explicit retry starts from protected orphan state")
		var old_hash := FileAccess.get_sha256(RealityState.SAVE_PATH + ".tmp")
		_check(RealityState.start_new_campaign(), "explicit retry creates a verified primary")
		_check(samples == 1 and RealityState.can_continue() and not RealityState.save_write_blocked,
				"retry samples once and releases protection only after success")
		_check(RealityState.data.campaign_clock.epoch_date == "1928-11-10"
				and RealityState.data.campaign_clock.start_minute_of_day == 807
				and RealityState.data.campaign_clock.elapsed_minutes == 0.0,
				"retry commits the authored date and one chosen start minute")
		_check(FileAccess.file_exists(RealityState.SAVE_PATH + ".replaced." + old_hash),
				"retry preserves the original orphan bytes by content hash")
	else:
		_check(false, "unknown worker mode")
	RealityState.storage_operation_override = Callable()
	RealityState.new_campaign_time_provider = Callable()
	var report := {"mode": mode, "pid": OS.get_process_id(), "failures": failures,
			"sample_counter_scope": "Callback installed in scene _ready; does not observe earlier autoload host sampling.",
			"load_status": RealityState.load_status(), "can_continue": RealityState.can_continue(),
			"write_blocked": RealityState.save_write_blocked, "samples": samples,
			"projection": _projection(RealityState.data), "last_save_result": RealityState.last_save_result()}
	_write_json(OS.get_environment("SAVE_RECOVERY_REPORT"), report)
	print("[SAVE RESTART] %s mode=%s failures=%d" % ["PASS" if failures == 0 else "FAIL", mode, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _checkpoint(stage: String, operation: String, arguments: Dictionary) -> Variant:
	var boundary := OS.get_environment("SAVE_RECOVERY_BOUNDARY")
	var wanted := "primary_verify" if boundary == "after_promote" else "promote"
	if stage != wanted:
		return null
	var deletion_error := OK
	if boundary == "deletion_gap":
		# The old/new native rename gap is not hookable inside Godot. This
		# control performs the real deletion at that boundary, with the real
		# verified backup/journal intact, before external process termination.
		if str(arguments.get("to", "")) != RealityState.SAVE_PATH:
			return {"ok": false, "error": ERR_INVALID_PARAMETER}
		deletion_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(RealityState.SAVE_PATH))
	_write_json(OS.get_environment("SAVE_RECOVERY_MARKER"), {
			"pid": OS.get_process_id(), "nonce": OS.get_environment("SAVE_RECOVERY_NONCE"),
			"boundary": boundary, "stage": stage, "operation": operation,
			"gap_delete_error": deletion_error, "save_path": ProjectSettings.globalize_path(RealityState.SAVE_PATH)})
	print("[SAVE RESTART] WAIT pid=%d boundary=%s" % [OS.get_process_id(), boundary])
	for _tick in range(150):
		OS.delay_msec(100)
	return {"ok": false, "kind": "unreadable", "error": ERR_TIMEOUT}


func _fail_temp_readback(stage: String, _operation: String, _arguments: Dictionary) -> Variant:
	return {"kind": "unreadable", "error": ERR_FILE_CANT_READ} if stage == "temp_verify" else null


func _sample() -> Dictionary:
	samples += 1
	return {"hour": 13, "minute": 27}


func _projection(value: Dictionary) -> Dictionary:
	return {"version": value.get("version"), "job": value.get("maintenance_jobs", {}).get("vantry_chirp_2a", {}),
			"item": value.get("maintenance_items", {}).get("carbon_transmitter_capsule", {}),
			"dream": value.get("dream", {}), "seed": value.get("dream_seed", ""),
			"clock": value.get("campaign_clock", {})}


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null and file.store_string(JSON.stringify(value)), "worker evidence write failed")
	file.flush()
	file.close()


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
	print("  PASS " if condition else "  FAIL ", label)
