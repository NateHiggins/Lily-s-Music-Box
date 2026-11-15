extends Node
## Isolated real conversation director/panel and authored data; no world actors.
var director: ResidentConversations
var panel: CaseDialoguePanel
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var output := ""
var prior_data: Dictionary
var prior_text := ""
var prior_files: Dictionary = {}
var prior_mouse := 0
var prior_frozen := false
var lease := false
var source: Dictionary = {}
var logger: Logger
var started := 0
var diagnostics: Dictionary = {}
const REQUIRED := ["bar_context_first_and_earned", "decorated_social_return", "default_studio_preserved", "preview_source_cleanup"]

func _ready() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label); print("ADELA BAR CONTEXT FAIL: ",label)
	return ok

func _contract(id: String, before: int) -> void:
	contracts[id] = {"executed":true,"status":"PASS" if failures.size()==before else "FAIL"}

func _run() -> void:
	started = Time.get_ticks_msec()
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or FileAccess.file_exists(output.path_join("runtime_contract.json")):
		output = "C:/ov/reports/harukiya_overhaul_20261112/adela_runtime_intake_01/context_early_error_" + str(Time.get_ticks_usec())
		_check(false,"fresh explicit output required")
	if DirAccess.make_dir_recursive_absolute(output) != OK: get_tree().quit(2); return
	for id: String in REQUIRED: contracts[id] = {"executed":false,"status":"NOT_RUN"}
	prior_data = RealityState.data
	prior_text = JSON.stringify(prior_data,"",true,true)
	prior_files = _files()
	prior_mouse = Input.mouse_mode
	prior_frozen = CampaignTime._frozen_for_tests
	logger = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(logger)
	source = _inputs()
	var profile: String = OS.get_environment("ADELA_CONTEXT_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	_check(profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/adela_runtime_intake_01/") and OS.get_environment("APPDATA").replace("\\","/").simplify_path()==profile and OS.get_user_data_dir().replace("\\","/").simplify_path()==profile.path_join("PleaseRemainOnTheLine"),"isolated APPDATA before autoload")
	for key: String in ["SCHEDULE","SCHEDULE_DAY","SCHEDULE_DOY","SCHEDULE_MINUTE","AGENDA","CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(),"no inherited clock/agenda override "+key)
	if not failures.is_empty(): await _finish(); return
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease,"exclusive nonpersistent preview"): await _finish(); return
	CampaignTime.set_frozen_for_tests(true)
	_check(CampaignClock.new().configure_date(1929,2,15,1200),"real authored opinion date")
	panel = CaseDialoguePanel.new(); add_child(panel)
	director = ResidentConversations.new(); add_child(director); director.setup(panel)
	if not _check(director.errors.is_empty() and director.has_tree("adela_voss"),"actual authored conversation director loads"): await _finish(); return
	var original: String = JSON.stringify(director.trees.adela_voss,"",true,true)
	var before: int = failures.size()
	_check(director.entry_for("adela_voss")=="first_stable","fresh preview first contact")
	_check(director.start("adela_voss","harukiya_bar") and panel.current_node_id=="ad_singing","first social entry uses existing authored singing node")
	_check(not panel.offered_labels().has("I'd like a photograph taken."),"social entry offers no studio portrait service")
	director.cancel_for_transition()
	var first_studio: bool = director.start("adela_voss") and panel.current_node_id=="ad_open" and panel.offered_labels().has("I'd like a photograph taken.")
	_check(first_studio,"default first-stable studio greeting and portrait discussion unchanged")
	director.cancel_for_transition()
	RealityState.add_resident_trust("adela_voss",6)
	_check(director.entry_for("adela_voss")=="integration","existing earned trust selects integration phase")
	_check(director.start("adela_voss","harukiya_bar") and panel.current_node_id=="ad_singing","high-trust social entry remains at bar")
	_check(not RealityState.has_knowledge("adela_voss:integration") and director.entry_for("adela_voss")=="integration","social alias cannot award studio integration")
	_check(JSON.stringify(director.trees.adela_voss,"",true,true)==original,"private context projection never mutates registered tree")
	_contract("bar_context_first_and_earned",before)
	before = failures.size()
	var active: Array[Dictionary] = director.active_opinions("adela_voss",director.today())
	if _check(not active.is_empty(),"actual authored dated opinion available"):
		var hook: String = str(director.opinions.adela_voss.hook)
		var offered: Array = panel.offered_labels()
		var index: int = offered.find(hook)
		diagnostics.opinion_entry={"node":panel.current_node_id,"offered_labels":offered.duplicate(),"raw_button_texts":panel.get("_choices").get_children().filter(func(n):return n is Button).map(func(n):return str(n.text)),"authored_hook":hook,"matched_panel_index":index,"actual_node_choices":panel._tree.nodes[panel.current_node_id].get("choices",[]).duplicate(true)}
		if _check(index>=0,"actual decorated opinion hook offered at social entry"):
			panel.choose(index)
			var node: Dictionary = panel._tree.nodes[panel.current_node_id]
			if panel.current_node_id==director.OPINION_MENU:
				_check(str(node.get("line",""))==str(director.trees.adela_voss.nodes.ad_singing.line),"social opinion menu uses existing bar text instead of studio invitation")
				panel.choose(0)
				node = panel._tree.nodes[panel.current_node_id]
			_check(panel.current_node_id.begins_with(director.OPINION_PREFIX),"actual opinion entered through panel choice")
			var labels: Array = panel.offered_labels()
			if _check(not labels.is_empty(),"authored opinion reply offered"):
				panel.choose(0)
				node = panel._tree.nodes[panel.current_node_id]
				_check(str(node.get("silence_goto",""))=="ad_singing","decorator reply targets contextual home")
				panel.choose(0)
				_check(panel.current_node_id=="ad_singing","actual decorated reply returns to social root")
			_check(not RealityState.has_knowledge("adela_voss:integration"),"decorated social path awards no studio integration")
	director.cancel_for_transition()
	_contract("decorated_social_return",before)
	before = failures.size()
	_check(first_studio,"default first-stable studio behavior preserved")
	_check(director.start("adela_voss") and panel.current_node_id=="ad_int_open","default high-trust studio entry unchanged")
	_check(RealityState.has_knowledge("adela_voss:integration"),"existing studio integration authority unchanged")
	director.cancel_for_transition()
	_check(JSON.stringify(director.trees.adela_voss,"",true,true)==original,"default start also preserves registered authored tree")
	_contract("default_studio_preserved",before)
	await _finish()

func _files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["",".bak",".txn",".tmp"]:
		var path: String = RealityState.save_path + suffix
		result[suffix] = {"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return result

func _inputs() -> Dictionary:
	var root: String = ProjectSettings.globalize_path("res://..").simplify_path()
	var values: Array = []
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],values)==0,"runtime source binding")
	var paths: Dictionary = {}
	for path: String in [get_script().resource_path,scene_file_path,"res://tests/guide_bell_error_capture.gd","res://scripts/game/resident_conversations.gd","res://data/dialogue/adela_voss.json","res://data/opinions/adela_voss.json","res://data/mystery/adela_voss.json","res://scripts/ui/case_dialogue_panel.gd"]:
		paths[path] = FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return {"runtime_inputs_sha256":str(values[0]).strip_edges() if not values.is_empty() else "","test_dependencies":paths}

func _finish() -> void:
	var before: int = failures.size()
	if is_instance_valid(director): director.cancel_for_transition(); director.free()
	if is_instance_valid(panel): panel.free()
	if lease: _check(RealityState.end_preview_campaign(self),"preview returned"); lease=false
	CampaignTime.set_frozen_for_tests(prior_frozen)
	Input.mouse_mode = prior_mouse
	_check(is_same(RealityState.data,prior_data) and JSON.stringify(RealityState.data,"",true,true)==prior_text,"campaign identity/content restored")
	_check(_files()==prior_files,"save backup/transaction files unchanged")
	_check(_inputs()==source,"source inputs unchanged")
	var errors: Array = logger.get("errors")
	OS.remove_logger(logger)
	_check(errors.is_empty(),"no genuine engine errors")
	_contract("preview_source_cleanup",before)
	for id: String in REQUIRED: _check(bool(contracts[id].executed) and str(contracts[id].status)=="PASS","required context contract "+id)
	var passed: bool = failures.is_empty()
	var result: Dictionary = {"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":false,"selector":"v2","suite":"AdelaBarContextTest","status":"PASS" if passed else "FAIL","scope":"Isolated actual conversation director/panel and authored data: first/high-trust social entry, actual opinion reply return, studio integration isolation/default preservation, source/save preview cleanup. No in-world physical interaction, model, rendered surface or artistic acceptance.","execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},"source":source,"contracts":contracts,"checks":checks,"failures":failures,"engine_errors":errors,"details":diagnostics}
	result.source.test_path = "game/" + get_script().resource_path.trim_prefix("res://")
	result.source.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
	result.source.test_scene_path = "game/" + scene_file_path.trim_prefix("res://")
	result.source.test_scene_sha256 = FileAccess.get_sha256(scene_file_path)
	var file: FileAccess = FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush()
	var written: bool = file.get_error()==OK
	file.close(); get_tree().quit(0 if passed and written else 1)
