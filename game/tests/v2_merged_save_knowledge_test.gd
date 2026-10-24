extends Node
## INERT integration diagnostic: main's knowledge/editorial fields through worker saves.
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label});print("MERGED SAVE KNOWLEDGE: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:run.call_deferred()
func run() -> void:
	CampaignTime.set_frozen_for_tests(true)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	RealityState.save_path="user://tests/merged_knowledge_%d.json"%Time.get_ticks_usec()
	RealityState.persistence_enabled=true;RealityState.background_save_profiling=true
	check(RealityState.data.knowledge_flags is Array and RealityState.data.newspapers_collected is Array and RealityState.data.resident_trust is Dictionary and RealityState.data.conversation_visits is Dictionary,"fresh campaign retains all four main editorial fields")
	check(RealityState.grant_knowledge("integration_known") and RealityState.add_resident_trust("mina_vale",2)==2 and RealityState.record_conversation_visit("mina_vale")==1,"existing dialogue authorities update the live campaign")
	var book: GDScript=load("res://scripts/props/v2_readable_book.gd")
	check(not book.note_spread_read("minutes",.3) and not RealityState.has_knowledge("minutes_read"),"partly opened minutes retain main's reading threshold")
	check(book.note_spread_read("minutes",1.2) and RealityState.has_knowledge("minutes_read"),"native book retains main's knowledge grant")
	RealityState.data.newspapers_collected=["integration_fixture:1928-10-24"]
	var snapshot:=RealityState.data.duplicate(true)
	RealityState.commit_background();RealityState.flush_background_saves()
	var disk: Variant=JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	check(disk is Dictionary and disk.knowledge_flags==snapshot.knowledge_flags and disk.newspapers_collected==snapshot.newspapers_collected and disk.resident_trust==snapshot.resident_trust and disk.conversation_visits==snapshot.conversation_visits,"background transaction preserves all editorial fields on disk")
	var worker:=false
	for row: Dictionary in RealityState.background_save_records:
		if row.stage=="completed":worker=worker or (row.result.ok and not row.result.worker_main_thread)
	check(worker,"merged save uses the actual off-main-thread transaction")
	RealityState.data.knowledge_flags.clear();RealityState.load_game()
	check(RealityState.can_continue() and RealityState.has_knowledge("integration_known") and RealityState.has_knowledge("minutes_read") and RealityState.resident_trust("mina_vale")==2 and RealityState.conversation_visits("mina_vale")==1 and RealityState.data.newspapers_collected==snapshot.newspapers_collected,"reload validates and restores knowledge, trust, visits and newspaper collection")
	var validator:=preload("res://scripts/game/reality_save_document.gd")
	for field: String in ["knowledge_flags","newspapers_collected","resident_trust","conversation_visits"]:
		var invalid:=snapshot.duplicate(true)
		invalid[field]={} if snapshot[field] is Array else []
		var refusal: Dictionary=validator.validate(invalid,RealityState.SAVE_VERSION)
		check(not refusal.ok and refusal.code=="save_invalid_read_only","worker validator retains main's shape refusal: "+field)
	RealityState.persistence_enabled=false
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("merged_save_knowledge.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Real worker disk transaction and integration API checks; no played acquisition or runtime_contract grant","checks":checks,"failures":failures},"\t"))
	get_tree().quit(1 if not failures.is_empty() else 0)
