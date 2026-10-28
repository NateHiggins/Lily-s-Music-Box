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
	check(command.ends_with("+05:45\"") and command.begins_with("root# date --set="),"non-hour timezone represented in inert command")
	check(State.valid_target(State.sample_destination()),"real host destination sampled using read-only APIs")
	for index in range(State.PHASES.size()-1):
		var phase: String=State.PHASES[index]
		if phase=="companion_crossing": record=State.applied(record,"companion_materialized")
		if phase=="temporal_command":
			record=State.with_target(record,target)
			var changed := target.duplicate(true);changed.utc_unix_seconds+=1
			check(State.with_target(record,changed).is_empty(),"destination immutable after initial capture")
		if phase=="temporal_synchronization": record=State.applied(record,"clock_applied")
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
