extends Node
## Domain and real validated disk-save test; no prologue presentation acceptance.
const State := preload("res://scripts/game/prologue_state.gd")
const Document := preload("res://scripts/game/reality_save_document.gd")
var failures: Array[String]=[]
var checks := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PROLOGUE STATE ","PASS " if ok else "FAIL ",label)

func _ready() -> void:
	var old_path: String=RealityState.save_path
	var old_persistence: bool=RealityState.persistence_enabled
	var old_data: Dictionary=RealityState.data.duplicate(true)
	var old_blocked: bool=RealityState.save_write_blocked
	var path := "user://tests/prologue_%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	RealityState.persistence_enabled=false
	RealityState.save_path=path
	RealityState.start_new_campaign()
	RealityState.persistence_enabled=true
	check(State.valid({}) and State.valid(State.initial()),"old optional domain and initial state valid")
	var record := State.initial()
	check(State.advance(record,"first_contact").is_empty(),"cannot jump past unperformed tutorial")
	check(State.observe(record,"temperature_balanced").is_empty(),"future physical evidence refused")
	check(State.applied(record,"companion_materialized").is_empty(),"cannot fabricate early companion crossing")
	var target := {"utc_unix_seconds":1856345696,"local_bias_minutes":345,"local_zone":"Example +05:45"}
	var early := State.initial();early.target=target.duplicate(true)
	check(not State.valid(early),"saved destination cannot precede synchronization request")
	var fractional := target.duplicate(true);fractional.utc_unix_seconds+=0.5
	check(not State.valid_target(fractional),"fractional or corrupt persisted target refused")
	var legacy: Dictionary=RealityState.data.duplicate(true);legacy.erase("prologue");legacy.intro_complete=true
	check(Document.validate(legacy,RealityState.SAVE_VERSION).ok,"old completed intro save accepted without inventing new prologue facts")
	var command := State.date_command(target)
	check(command.ends_with("utc plus 05.45") and command.begins_with("root# date "),"non-hour timezone represented exactly in the mechanical command")
	var keyboard:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/device/service_companion_v2.json"))
	var available:Array=[]
	for key:Dictionary in keyboard.keys:available.append(str(key.character))
	var supported:=true
	for character:String in command.trim_prefix("root# "):
		supported=supported and ("SPACE" if character==" " else character.to_upper()) in available
	check(supported,"every typed command character has a real physical key")
	var west:Dictionary=target.duplicate(true);west.local_bias_minutes=-210
	check(State.date_command(west).ends_with("utc minus 03.30"),"negative non-hour timezone retains its sign and minutes")
	check(State.valid_target(State.sample_destination()),"real host destination sampled using read-only APIs")
	for index in range(State.PHASES.size()-1):
		var phase: String=State.PHASES[index]
		if phase=="companion_crossing": record=State.applied(record,"companion_materialized")
		if phase=="temporal_command":
			record=State.with_target(record,target)
			var changed := target.duplicate(true);changed.utc_unix_seconds+=1
			check(State.with_target(record,changed).is_empty(),"destination immutable after initial capture")
		if phase=="temporal_synchronization":
			_test_clock_handoff(record)
			record=State.applied(record,"clock_applied")
		for event: String in State.GATES.get(phase,[]):
			record=State.observe(record,event)
		if index in [4,10,12,15,16,17]:
			RealityState.data.prologue=record.duplicate(true)
			check(RealityState.save_game(),"checkpoint disk write "+phase)
			RealityState.data.prologue={}
			RealityState.load_game()
			check(not RealityState.save_write_blocked and State.restore(RealityState.data.prologue)==record,"validated restore retains exact stage/effects/target "+phase)
			if phase=="temporal_command":
				check(State.with_target(RealityState.data.prologue,target)==record,"same destination accepted idempotently after JSON numeric conversion")
		var next := State.advance(record,State.PHASES[index+1])
		check(not next.is_empty(),"ordered transition "+phase)
		if next.is_empty(): break
		record=next
	check(record.get("phase","")=="prologue_complete","ordered sequence reaches durable completion")
	var skipped := State.request_skip(State.initial())
	check(State.advance(skipped,"prologue_complete").is_empty(),"skip cannot leap over effect handoffs")
	for index in range(State.PHASES.size()-1):
		var phase: String=State.PHASES[index]
		if phase=="companion_crossing":
			check(State.advance(skipped,"first_contact").is_empty(),"skip still requires actual companion handoff")
			skipped=State.applied(skipped,"companion_materialized")
		if phase=="temporal_command": skipped=State.with_target(skipped,target)
		if phase=="temporal_synchronization":
			check(State.advance(skipped,"title_reveal").is_empty(),"skip cannot complete without clock owner acknowledgement")
			skipped=State.applied(skipped,"clock_applied")
		skipped=State.advance(skipped,State.PHASES[index+1])
	check(State.valid(skipped) and skipped.phase=="prologue_complete" and skipped.events.is_empty(),"skip completes without invented observations")
	var invalid: Dictionary=record.duplicate(true);invalid.phase="dream"
	check(not State.valid(invalid),"corrupt phase rollback with later effects refused")
	for bad: Variant in [null,[],{"schema_version":2},invalid]:
		var candidate: Dictionary=RealityState.data.duplicate(true);candidate.prologue=bad
		check(not Document.validate(candidate,RealityState.SAVE_VERSION).ok,"save validator rejects invalid prologue domain")
	# Remove the valid backup: this control tests refusal, not recovery from it.
	for suffix in [".bak",".txn",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var corrupt: Dictionary=RealityState.data.duplicate(true);corrupt.prologue=invalid
	var bytes := JSON.stringify(corrupt)
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(bytes);file=null
	RealityState.load_game()
	check(RealityState.save_write_blocked,"invalid on-disk prologue blocks writes")
	RealityState.commit()
	check(FileAccess.get_file_as_string(path)==bytes,"protected invalid file retained byte-for-byte")
	RealityState.persistence_enabled=false
	RealityState.save_write_blocked=false
	RealityState.data=old_data
	RealityState.save_path=old_path
	RealityState.save_write_blocked=old_blocked
	RealityState.persistence_enabled=old_persistence
	for suffix in ["",".bak",".txn",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("PROLOGUE STATE TEST: ",checks," checks; ",failures.size()," failures; domain/save only, not playable acceptance")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_clock_handoff(opening:Dictionary) -> void:
	var original:Dictionary=RealityState.data.duplicate(true)
	var clock:=CampaignClock.new()
	check(clock.configure_date(1928,11,10,1380),"handoff fixture retains the historical source through the visual transition")
	RealityState.data.prologue=opening.duplicate(true)
	var before:Dictionary=JSON.parse_string(JSON.stringify(RealityState.data))
	RealityState.save_write_blocked=true
	check(not clock.apply_prologue_destination() and JSON.parse_string(JSON.stringify(RealityState.data))==before,"protected campaign refuses temporal application without mutation")
	RealityState.save_write_blocked=false
	var observed:Array[Dictionary]=[]
	var observer:Callable=func():observed.append({"clock":RealityState.data.campaign_clock.duplicate(true),"prologue":RealityState.data.prologue.duplicate(true)})
	RealityState.state_changed.connect(observer)
	check(clock.apply_prologue_destination(),"campaign clock accepts the completed prologue destination")
	RealityState.state_changed.disconnect(observer)
	var utc:Dictionary=clock.utc_datetime()
	check(int(Time.get_unix_time_from_datetime_dict(utc))==int(opening.target.utc_unix_seconds),"clock preserves the exact target UTC second despite a non-hour host offset")
	check(RealityState.data.campaign_clock.utc_offset_minutes==-300 and RealityState.data.campaign_clock.timezone=="America/New_York","host timezone does not relocate Queens or replace its clock convention")
	check(observed.size()==1 and observed[0].prologue.effects.clock_applied and CampaignClock.validate_snapshot(observed[0].clock).ok,"state observers receive clock and acknowledgement atomically")
	var after:Dictionary=JSON.parse_string(JSON.stringify(RealityState.data))
	var unchanged:=true
	for domain:String in before:
		if domain not in ["campaign_clock","prologue"]:unchanged=unchanged and before[domain]==after[domain]
	check(unchanged,"destination handoff preserves all unrelated gameplay domains")
	check(RealityState.save_game(),"validated save stores the applied clock and prologue acknowledgement")
	RealityState.load_game()
	check(State.restore(RealityState.data.prologue).effects.clock_applied and int(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))==int(opening.target.utc_unix_seconds),"validated reload retains the exact applied destination")
	clock.advance_seconds(125)
	var progressed:float=clock.absolute_minutes()
	check(clock.apply_prologue_destination() and clock.absolute_minutes()==progressed,"retry cannot rewind time after play resumes")
	var director:Node=preload("res://scripts/game/prologue_director.gd").new();add_child(director)
	RealityState.data.prologue=opening.duplicate(true)
	director.state=State.restore(opening);director._document=RealityState.data
	check(director.finish_temporal_synchronization() and director.state.phase=="title_reveal" and "temporal_transition_complete" in director.state.events,"ordinary completed transition records only its real clock acknowledgement")
	var accepted_clock:Dictionary=RealityState.data.campaign_clock.duplicate(true)
	check(not director.finish_temporal_synchronization() and RealityState.data.campaign_clock==accepted_clock,"duplicate visual completion cannot apply another clock jump")
	director.shutdown();director.queue_free()
	var skip:Dictionary=opening.duplicate(true);skip.skipped=true;skip.events=[]
	RealityState.data.prologue=skip
	director=preload("res://scripts/game/prologue_director.gd").new();add_child(director)
	director.state=State.restore(skip);director._document=RealityState.data
	check(director.finish_temporal_synchronization() and director.state.effects.clock_applied and director.state.events.is_empty(),"skip performs the real clock handoff without inventing witnessed transition events")
	director.shutdown();director.queue_free()
	# No state flag or timestamp is granted to a refused target/early phase.
	RealityState.data.prologue=opening.duplicate(true)
	RealityState.data.prologue.target.utc_unix_seconds=State.MIN_UNIX
	RealityState.data.prologue.target.local_bias_minutes=0
	var edge:Dictionary=RealityState.data.duplicate(true)
	check(not clock.apply_prologue_destination() and RealityState.data==edge,"destination outside Queens civil range refuses without partial effects")
	RealityState.data.prologue=State.initial()
	check(not clock.apply_prologue_destination(),"early prologue phase cannot use the privileged clock handoff")
	RealityState.data=original
