extends "res://tests/v2_handheld_profile.gd"
## Same occupied-world timed route, then real carried-part input qualification.
func review_controls() -> Dictionary:
	var helper:=preload("res://tests/service_set_hand_test.gd").new()
	helper.standalone=false;helper.player=player;helper.carrier=carrier;helper.directory=directory
	add_child(helper)
	await helper.exercise()
	var sources: Dictionary={}
	for path in ["v2_service_set_hand_world_test.gd","v2_handheld_profile.gd","service_set_hand_test.gd"]:
		sources["game/tests/"+path]=FileAccess.get_file_as_string("res://tests/"+path).replace("\r\n","\n").sha256_text()
	var digest:=runtime_digest()
	helper.check(digest==source_before and not digest.is_empty(),"runtime inputs unchanged through composed device input")
	var status: String="PASS" if helper.failures.is_empty() else "FAIL"
	var contracts: Dictionary={}
	for key in ["specific_part_target","latched_grab_motion_release","continuous_travel_stops","circuit_authority","inspection_interruption"]:
		contracts[key]={"executed":helper.checks>60,"status":status}
	var result: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Installed carried instrument: E deployment, explicit Space free-cursor inspection, six specific native controls, click/motion/release, partial positions, four full-travel stops, lamp/radio authority and Escape/E interruption. Does not qualify saved device positions, incoming-call answering, every V2 interaction, whole-world performance or human acceptance.",
		"execution":{"completed":true,"exit_code":0 if helper.failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
		"source":{"test_path":"game/tests/v2_service_set_hand_world_test.gd","test_sha256":sources["game/tests/v2_service_set_hand_world_test.gd"],"runtime_inputs_sha256":digest,"test_sources":sources},
		"contracts":contracts,"checks":helper.checks,"failures":helper.failures,"observations":helper.observations}
	FileAccess.open(directory.path_join("carried_controls_runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	helper.queue_free()
	return result
