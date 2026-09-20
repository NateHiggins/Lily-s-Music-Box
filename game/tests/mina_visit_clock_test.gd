extends Node
var failures := 0
var checks := 0

func _ready() -> void:
	var previous_path := RealityState.save_path
	var run_id := Crypto.new().generate_random_bytes(8).hex_encode()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests")) != OK:
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	for start in [1200,1423,1430]:
		RealityState.reset_campaign_for_tests()
		var clock := CampaignClock.new()
		clock.configure_date(1928,11,10,start)
		var tracker := ObjectiveTracker.new()
		add_child(tracker)
		var orders := WorkOrders.new()
		orders.setup(tracker)
		orders.bind_job_library(MaintenanceJobLibrary.load_default())
		add_child(orders)
		var gameplay := MinaCaseGameplay.new()
		gameplay.setup(tracker,orders)
		add_child(gameplay)
		RealityCases.activate_case(MinaCaseGameplay.CASE_ID)
		orders.issue_job(MinaCaseGameplay.JOB_ID,"reported")
		orders.acknowledge_job(MinaCaseGameplay.JOB_ID)
		orders.diagnose_job(MinaCaseGameplay.JOB_ID)
		orders.mark_job_awaiting_part(MinaCaseGameplay.JOB_ID)
		orders.mark_job_repairable(MinaCaseGameplay.JOB_ID)
		orders.record_job_repair(MinaCaseGameplay.JOB_ID,{"quality":"good"})
		RealityCases.record_conversation(MinaCaseGameplay.CASE_ID,"first_silence_named")
		_check(gameplay.shift_clock.enabled,"earned visit clock enabled")
		var before := clock.absolute_minutes()
		RealityState.save_path = "user://tests/mina_visit_%s_%d.json" % [run_id,start]
		RealityState.persistence_enabled = true
		gameplay.shift_clock.interact(null)
		await get_tree().create_timer(2.7).timeout
		RealityState.persistence_enabled = false
		var state := RealityState.case_state(MinaCaseGameplay.CASE_ID)
		_check(state.stage == "reopened" and state.recurrence_count == 1,"visit actually recurs once")
		_check(is_equal_approx(clock.minute_of_day(),1423) and clock.absolute_minutes()>before,
				"visit reaches the next actual 23:43")
		_check(clock.day_info().day_of_month == (10 if start<1423 else 11),"civil date follows midnight rollover")
		var elapsed := clock.elapsed_minutes()
		var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
		_check(persisted.get("campaign_clock",{}).get("elapsed_minutes",-1)==elapsed
				and persisted.get("cases",{}).get(MinaCaseGameplay.CASE_ID,{}).get("recurrence_count",0)==1,
				"one persisted snapshot contains both clock jump and recurrence")
		_check(gameplay.shift_clock.interact(null).is_empty() and clock.elapsed_minutes()==elapsed,
				"disabled clock cannot advance the visit twice")
		gameplay.free()
		orders.free()
		tracker.free()
		await get_tree().create_timer(.25).timeout
		RealityState.reset_campaign_for_tests()
		RealityState.load_game()
		_check(CampaignClock.new().elapsed_minutes()==elapsed
				and RealityState.case_state(MinaCaseGameplay.CASE_ID).get("recurrence_count",0)==1,
				"actual disk reload restores time and visit together")
	RealityState.save_path = previous_path
	print("MINA VISIT CLOCK: %d checks; %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("VISIT CLOCK: ",label," = ",ok)
