extends Node
## Actual unmounted runtime caller + authored director, isolated preview only.
const Runtime = preload("res://scripts/building/orison_v2_runtime_root.gd")
var failures: Array[String] = []
var checks := 0
var preview_owned := false
var runtime: OrisonV2RuntimeRoot
var director: ScheduleDirector
var agenda: ResidentAgenda
var prior_data: Dictionary
var prior_text := ""
var prior_status := {}
var prior_files := {}
var observations: Array[Dictionary] = []
var source_before := {}
const SOURCES := ["res://tests/resident_whereabouts_date_test.gd", "res://scripts/building/orison_v2_runtime_root.gd", "res://scripts/characters/schedule_director.gd", "res://scripts/game/campaign_clock.gd", "res://scripts/game/reality_game_state.gd", "res://data/resident_schedules.json", "res://scripts/characters/resident_agenda.gd", "res://data/resident_motives.json"]

func _ready() -> void:
	var profile := OS.get_environment("WHEREABOUTS_DATE_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var actual_user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/") or actual_user_dir != profile.path_join("PleaseRemainOnTheLine"):
		push_error("Whereabouts date test requires its dedicated isolated APPDATA")
		get_tree().quit(2); return
	if OS.get_environment("SHOT_DIR").is_empty():
		push_error("Whereabouts date test requires diagnostic output directory")
		get_tree().quit(2); return
	source_before = _sources()
	prior_data = RealityState.data
	prior_text = JSON.stringify(prior_data,"",true,true)
	prior_status = _status().duplicate(true)
	prior_files = _save_bundle()
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned,"exclusive nonpersistent preview acquired"):
		_finish(); return
	# The real preview owner resets to fresh data; no prologue destination is acknowledged.
	if not _check(RealityState.data.get("prologue",null) is Dictionary and RealityState.data.prologue.is_empty(),"preview owner established fresh prologue context"):
		_finish(); return
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	if not _check(decoded is Dictionary,"authored layout parsed"):
		_finish(); return
	var clock := CampaignClock.new()
	if not _check(clock.configure_date(1929,7,12,1200),"preview civil clock configured"):
		_finish(); return
	if not _civil_matches(clock,1929,7,12,1200,"initial preview fixture"):
		_finish(); return
	director = ScheduleDirector.new()
	director.setup(null,decoded)
	if not _check(director.data.get("staff",{}).has("adela_voss") and director.data.staff.has("stacy"),"authored staff schedule loaded"):
		_finish(); return
	if not _civil_matches(clock,1929,7,12,1200,"after real director setup") or not _civil_matches(director.campaign_clock,1929,7,12,1200,"director bound same civil fixture"):
		_finish(); return
	agenda = ResidentAgenda.new()
	if not _check(agenda.setup(director) and agenda.enabled,"actual authored agenda enabled"):
		_finish(); return
	_check(not agenda.order.has("adela_voss") and not agenda.order.has("stacy"),"staff use the actual agenda timetable fallback")
	# No node enters the tree: no runtime world boot or director/agenda poll.
	runtime = Runtime.new()
	runtime.resident_presence = director
	runtime.campaign_clock = clock
	runtime.resident_agenda = null
	runtime.loop_performances = null
	_check(not runtime.is_inside_tree() and runtime.get_child_count()==0,"actual runtime root remains unmounted")
	var sensitive_boundary := 0
	var sensitive_later := false
	var cases: Array = [
		[1929,7,12,1200,"harukiya_bar",false,"pre-death Friday"],
		[1929,7,19,1262,"roof",false,"minute before"],
		[1929,7,19,1263,"out",true,"exact boundary"],
		[1929,7,19,1264,"out",true,"minute after"],
		[1929,7,20,1200,"out",true,"later Saturday business hours"]]
	for c: Array in cases:
		if not _check(clock.configure_date(c[0],c[1],c[2],c[3]),"configure "+str(c[6])): continue
		if not _civil_matches(clock,int(c[0]),int(c[1]),int(c[2]),int(c[3]),str(c[6])): continue
		var info := clock.day_info()
		var minute := clock.minute_of_day()
		_check(bool(info.get("civil_date_valid",false)),"actual civil context "+str(c[6]))
		var actual := runtime.resident_whereabouts("adela_voss")
		runtime.resident_agenda = agenda
		var with_agenda := runtime.resident_whereabouts("adela_voss")
		runtime.resident_agenda = null
		var expected := director.resolve("adela_voss",str(info.day),minute,int(info.doy),bool(info.first_sat),info)
		# This is the real resolver invoked with the old omitted-date signature,
		# not a replacement/mock implementation of death or schedule logic.
		var omitted := director.resolve("adela_voss",str(info.day),minute,int(info.doy),bool(info.first_sat))
		_check(actual == expected,"actual runtime caller forwards civil date "+str(c[6]))
		_check(with_agenda == expected,"enabled agenda staff fallback forwards civil date "+str(c[6]))
		_check(str(actual.get("place",""))==str(c[4]),"authored place "+str(c[6]))
		if c[5]:
			_check(actual == ScheduleDirector.GONE_BLOCK,"exact gone block "+str(c[6]))
			if omitted != ScheduleDirector.GONE_BLOCK:
				if int(c[2])==19:sensitive_boundary+=1
				else:sensitive_later=true
		else:
			_check(actual != ScheduleDirector.GONE_BLOCK,"positive living presence "+str(c[6]))
		var stacy := runtime.resident_whereabouts("stacy")
		var stacy_direct := director.resolve("stacy",str(info.day),minute,int(info.doy),bool(info.first_sat),info)
		var stacy_omitted := director.resolve("stacy",str(info.day),minute,int(info.doy),bool(info.first_sat))
		_check(not stacy.is_empty() and stacy == stacy_direct and stacy == stacy_omitted,"unaffected Stacy fallback "+str(c[6]))
		runtime.resident_agenda = agenda
		_check(runtime.resident_whereabouts("stacy") == stacy_direct,"unaffected Stacy with enabled agenda "+str(c[6]))
		runtime.resident_agenda = null
		observations.append({"case":c[6],"actual":actual,"enabled_agenda":with_agenda,"direct_with_date":expected,"actual_old_signature":omitted,"stacy":stacy})
	_check(sensitive_boundary==2,"omitted-date bug is exposed at exact and immediate-after boundaries")
	_check(sensitive_later,"omitted-date bug is exposed during later ordinary bar hours")
	_check(not ScheduleDirector.is_gone(director.data.staff.adela_voss,{},1263),"existing undated diagnostic convention unchanged")
	_finish()

func _civil_matches(clock: CampaignClock, year: int, month: int, day: int, minute: int, label: String) -> bool:
	var info := clock.day_info()
	var valid := bool(info.get("valid",false)) and bool(info.get("civil_date_valid",false))
	var date_ok := valid and int(info.get("year",-1))==year and int(info.get("month",-1))==month and int(info.get("day_of_month",-1))==day
	var minute_ok := valid and is_equal_approx(float(info.get("minute_of_day",-1)),float(minute)) and is_equal_approx(clock.minute_of_day(),float(minute))
	var ok := _check(date_ok,"exact returned civil date "+label)
	ok = _check(minute_ok,"exact returned civil minute "+label) and ok
	return ok


func _status() -> Dictionary:
	return {"load":RealityState.load_status(),"notice":RealityState.player_notice(),"last_save":RealityState.last_save_result(),"blocked":RealityState.save_write_blocked,"version":RealityState.incompatible_save_version,"persistence":RealityState.persistence_enabled,"save_path":RealityState.save_path}

func _save_bundle() -> Dictionary:
	var out := {}
	for suffix: String in ["", ".bak", ".txn", ".tmp"]:
		var path: String = RealityState.save_path+suffix
		out[suffix] = {"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return out

func _check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok: failures.append(label); push_error("WHEREABOUTS DATE: "+label)
	return ok

func _finish() -> void:
	# Release unmounted owner references BEFORE returning original state.
	if is_instance_valid(runtime):
		runtime.resident_presence=null;runtime.resident_agenda=null;runtime.campaign_clock=null;runtime.free()
	if is_instance_valid(agenda):agenda.free()
	if is_instance_valid(director):director.free()
	if preview_owned:
		_check(RealityState.end_preview_campaign(self),"preview lease returned")
		preview_owned=false
	_check(is_same(prior_data,RealityState.data) and JSON.stringify(RealityState.data,"",true,true)==prior_text,"original data identity and values restored")
	_check(_status()==prior_status,"original persistence/protection/save status restored")
	_check(_save_bundle()==prior_files,"save/backup/transaction bytes unchanged")
	_check(_sources()==source_before,"consumed caller and calendar inputs stable")
	var result := {"evidence_kind":"diagnostic_observation","test":"resident_whereabouts_date","scope":"actual unmounted runtime bare and enabled-agenda staff fallback with authored resolver; no world, resident needs simulation, loop performance, actors or played acceptance","checks":checks,"failures":failures,"cases":observations,"source_bindings":source_before}
	var directory := OS.get_environment("SHOT_DIR")
	var file := FileAccess.open(directory.path_join("result.json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write whereabouts diagnostic result")
		get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("WHEREABOUTS DATE: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func _sources() -> Dictionary:
	var result := {}
	for path: String in SOURCES:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return result
