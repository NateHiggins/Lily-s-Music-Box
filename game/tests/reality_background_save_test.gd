extends Node
## INERT development state/IO contract. Actual world input is a separate route.
var checks: Array=[]
var failures: Array=[]
var callbacks_main:=true
var captures:=0
var folder: String
var first_path: String
var second_path: String

func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label});print("BACKGROUND SAVE: ",label," = ",ok)
	if not ok:failures.append(label)

func _snapshot() -> void:
	callbacks_main=callbacks_main and Thread.is_main_thread();captures+=1
	RealityState.data["capture_sequence"]=captures

func _notice(_value: Dictionary) -> void:callbacks_main=callbacks_main and Thread.is_main_thread()
func _changed() -> void:callbacks_main=callbacks_main and Thread.is_main_thread()
func read(path: String) -> Dictionary:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
func _ready() -> void:run.call_deferred()
func run() -> void:
	CampaignTime.set_frozen_for_tests(true)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var run_id:=Time.get_ticks_usec()
	folder="user://tests/background_save_%d"%run_id
	first_path=folder.path_join("first.json");second_path=folder.path_join("second.json")
	DirAccess.make_dir_recursive_absolute(folder)
	RealityState.save_path=first_path;RealityState.persistence_enabled=true
	RealityState.background_save_profiling=true;RealityState.background_save_records.clear()
	RealityState.snapshot_preparing.connect(_snapshot);RealityState.player_notice_changed.connect(_notice);RealityState.state_changed.connect(_changed)
	RealityState.data["payload"]="detached snapshot ".repeat(16000)
	for value: String in ["A","B","C"]:
		RealityState.data.current_case_id=value;RealityState.commit_background()
	check(RealityState.background_save_status().pending>0,"background requests are explicitly pending before settlement")
	RealityState.data.current_case_id="UNSAVED"
	RealityState.flush_background_saves()
	check(read(first_path).current_case_id=="C" and read(first_path+".bak").current_case_id=="B","FIFO writes every detached snapshot and retains the previous generation")
	check(RealityState.data.current_case_id=="UNSAVED" and read(first_path).capture_sequence==3,"worker validation never swaps live state or reads later mutations")
	var worker_rows: Array=[]
	for row: Dictionary in RealityState.background_save_records:
		if row.stage=="completed":worker_rows.append(row)
	check(worker_rows.size()==3 and worker_rows.all(func(row):return row.result.ok and not row.result.worker_main_thread),"real verified transactions run off the main thread")
	check(callbacks_main and captures==3,"snapshot, state and notice callbacks stay on the main thread")
	RealityState.data.current_case_id="D";RealityState.commit_background()
	RealityState.data.current_case_id="E";RealityState.commit()
	check(RealityState.background_save_status().pending==0 and read(first_path).current_case_id=="E" and read(first_path+".bak").current_case_id=="D","ordinary commit drains older work then writes current state synchronously")
	RealityState.data.current_case_id="F";RealityState.commit_background();RealityState.save_path=second_path
	check(read(first_path).current_case_id=="F" and not FileAccess.file_exists(second_path),"path change drains the old path before switching")
	RealityState.data.current_case_id="G";RealityState.commit_background();RealityState.data.current_case_id="H"
	RealityState.data=RealityState.data.duplicate(true)
	check(read(second_path).current_case_id=="G" and RealityState.data.current_case_id=="H" and RealityState.background_save_status().pending==0,"campaign document replacement is a settlement barrier")
	RealityState.data.current_case_id="I";RealityState.commit_background();RealityState.reset_campaign_for_tests()
	check(read(second_path).current_case_id=="I" and RealityState.data.current_case_id=="","reset drains old work before creating fresh live data")
	RealityState.data.current_case_id="J";RealityState.commit_background();RealityState.persistence_enabled=false
	var requested: int=RealityState.background_save_status().requested
	RealityState.data.current_case_id="K";RealityState.commit_background()
	check(read(second_path).current_case_id=="J" and RealityState.background_save_status().requested==requested,"disabling persistence drains pending work and prevents new writes")
	RealityState.persistence_enabled=true;RealityState.commit_background();RealityState.load_game()
	check(read(second_path).current_case_id=="K" and RealityState.data.current_case_id=="K" and RealityState.can_continue(),"load waits for the current campaign's queued snapshot")
	RealityState.data.current_case_id="OLD_BEFORE_NEW";RealityState.commit_background()
	RealityState.new_campaign_time_provider=func():
		callbacks_main=callbacks_main and Thread.is_main_thread();return {"hour":10,"minute":5}
	check(RealityState.start_new_campaign() and RealityState.data.current_case_id=="" and read(second_path).current_case_id=="","explicit New settles prior writes and retains the original replacement authority")
	RealityState.new_campaign_time_provider=Callable()
	# Seed a future primary, then queue two detached jobs before dispatch so the
	# protection failure must prevent the second transaction from even starting.
	var future_path:=folder.path_join("future.json");RealityState.save_path=future_path
	var future:="{\"version\":99,\"future_fact\":\"preserve exact bytes\"}"
	FileAccess.open(future_path,FileAccess.WRITE).store_string(future)
	var bytes:=JSON.stringify(RealityState.data,"\t",true,true).to_utf8_buffer()
	var discarded_before: int=RealityState.background_save_status().discarded
	RealityState._save_queue.submit(future_path,bytes,RealityState.SAVE_VERSION)
	RealityState._save_queue.submit(future_path,bytes,RealityState.SAVE_VERSION)
	RealityState.flush_background_saves()
	check(RealityState.save_write_blocked and RealityState.player_notice().code=="future_save_read_only" and FileAccess.get_file_as_string(future_path)==future,"worker detects and protects a future primary without altering its bytes")
	check(RealityState.background_save_status().discarded==discarded_before+1 and not FileAccess.file_exists(future_path+".bak"),"protection failure discards queued attempts before another writer starts")
	RealityState.reset_campaign_for_tests();RealityState.save_path=folder.path_join("directory.json")
	DirAccess.make_dir_recursive_absolute(RealityState.save_path)
	RealityState.commit_background();RealityState.flush_background_saves()
	check(not RealityState.save_write_blocked and RealityState.player_notice().code=="save_write_failed" and not RealityState.last_save_result().ok,"ordinary worker IO failure publishes the existing failure notice without a false protection latch")
	RealityState.reset_campaign_for_tests();RealityState.save_path=folder.path_join("protected_while_pending.json")
	RealityState.commit_background();RealityState.block_invalid_campaign_clock("live clock refusal")
	RealityState.flush_background_saves()
	check(RealityState.save_write_blocked and RealityState.load_status().status=="protected" and RealityState.player_notice().code=="campaign_clock_read_only","older worker success cannot clear a newer live-domain protection latch")
	RealityState.reset_campaign_for_tests();RealityState.save_path=folder.path_join("burst.json")
	var bounded:=true
	for index in 15:
		RealityState.data.current_case_id=str(index);RealityState.commit_background()
		bounded=bounded and RealityState.background_save_status().pending<=8
	RealityState.flush_background_saves()
	check(bounded and read(RealityState.save_path).current_case_id=="14" and read(RealityState.save_path+".bak").current_case_id=="13","burst backpressure bounds memory while preserving ordered generations")
	check(callbacks_main and RealityState.background_save_status().pending==0,"all asynchronous results settle on main before teardown")
	var out:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"worker_records":RealityState.background_save_records,"callbacks_main":callbacks_main},"\t"))
	# Leave one owned final job for the real autoload exit barrier. The external
	# verifier reads these exact bytes only after the wrapper reports completion.
	RealityState.snapshot_preparing.disconnect(_snapshot);RealityState.player_notice_changed.disconnect(_notice);RealityState.state_changed.disconnect(_changed)
	RealityState.save_path=folder.path_join("exit.json");RealityState.data.current_case_id="QUIT_SETTLED"
	RealityState.data["exit_payload"]="exit settlement ".repeat(200000)
	RealityState.commit_background()
	var alive_at_quit: bool=RealityState._save_queue._thread!=null and RealityState._save_queue._thread.is_alive()
	FileAccess.open(out.path_join("exit_path.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","worker_alive_at_quit":alive_at_quit,"owned_root":ProjectSettings.globalize_path(folder),"path":ProjectSettings.globalize_path(RealityState.save_path)},"\t"))
	print("BACKGROUND SAVE: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks.size())
	get_tree().quit(0 if failures.is_empty() else 1)
