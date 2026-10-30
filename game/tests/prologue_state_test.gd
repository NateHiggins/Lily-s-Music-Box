extends Node
## Domain and real validated disk-save test; no prologue presentation acceptance.
const State := preload("res://scripts/game/prologue_state.gd")
const Document := preload("res://scripts/game/reality_save_document.gd")
const Stinger:=preload("res://scripts/game/prologue_tardi_stinger.gd")
var failures: Array[String]=[]
var checks := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PROLOGUE STATE ","PASS " if ok else "FAIL ",label)

func _ready() -> void:
	review_annual_destination()
	check(Stinger.DURATION==17 and not Stinger.sample(16.999).finished and Stinger.sample(17).finished,"historical cutaway has exactly17 seconds including title")
	check(not Stinger.sample(4.499).flash and Stinger.sample(4.5).flash and not Stinger.sample(4.8).flash,"controlled reveal occupies4.50 through4.80 seconds")
	check(Stinger.sample(6.5).lift==0 and Stinger.sample(8.5).lift==1,"greeting begins6.50 and settles at8.50")
	check(Stinger.sample(8.5).travel==Stinger.sample(10.5).travel and Stinger.sample(10.5).lift==1,"two-second expectant pause has identical body travel and greeting")
	check(Stinger.sample(12.5).travel==Stinger.WALK*2+Stinger.TURN,"retreat completes by12.50")
	check(not Stinger.sample(13.499).black and Stinger.sample(13.5).black and not Stinger.sample(13.999).title and Stinger.sample(14).title,"black and title boundaries remain13.50 and14.00")
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
	check(command=="root# date 1929/10/28 17.19.56 utc minus 05.00","non-hour host time maps to the same civil clock on the historical mechanical command")
	var keyboard:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/device/service_companion_v2.json"))
	var available:Array=[]
	for key:Dictionary in keyboard.keys:available.append(str(key.character))
	var supported:=true
	for character:String in command.trim_prefix("root# "):
		supported=supported and ("SPACE" if character==" " else character.to_upper()) in available
	check(supported,"every typed command character has a real physical key")
	var west:Dictionary=target.duplicate(true);west.local_bias_minutes=-210
	check(State.date_command(west)=="root# date 1929/10/28 08.04.56 utc minus 05.00","negative non-hour host offset preserves its local clock in Queens reference time")
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
	# Let the real owners retire their queued presentation nodes before exit.
	await get_tree().process_frame
	print("PROLOGUE STATE TEST: ",checks," checks; ",failures.size()," failures; domain/save only, not playable acceptance")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_clock_handoff(opening:Dictionary) -> void:
	var original:Dictionary=RealityState.data.duplicate(true)
	var clock:=CampaignClock.new()
	check(clock.configure_date(1928,11,10,1380),"handoff fixture retains the historical source through the visual transition")
	clock.advance_to(2.83) # Existing elapsed consumers must not be rewound by adoption.
	var elapsed_before_handoff:float=clock.elapsed_minutes()
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
	check(clock.elapsed_minutes()>=elapsed_before_handoff and clock.elapsed_minutes()<elapsed_before_handoff+1.0,"adoption keeps elapsed deadlines monotonic within the existing minute epoch resolution")
	check(int(Time.get_unix_time_from_datetime_dict(utc))==int(State.annual_destination(opening.target).utc_unix_seconds),"clock adopts the projected historical second despite a non-hour host offset")
	check(RealityState.data.campaign_clock.utc_offset_minutes==-300 and RealityState.data.campaign_clock.timezone=="America/New_York","host timezone does not relocate Queens or replace its clock convention")
	check(observed.size()==1 and observed[0].prologue.effects.clock_applied and CampaignClock.validate_snapshot(observed[0].clock).ok,"state observers receive clock and acknowledgement atomically")
	var after:Dictionary=JSON.parse_string(JSON.stringify(RealityState.data))
	var unchanged:=true
	for domain:String in before:
		if domain not in ["campaign_clock","prologue"]:unchanged=unchanged and before[domain]==after[domain]
	check(unchanged,"destination handoff preserves all unrelated gameplay domains")
	check(RealityState.save_game(),"validated save stores the applied clock and prologue acknowledgement")
	RealityState.load_game()
	check(State.restore(RealityState.data.prologue).effects.clock_applied and int(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))==int(State.annual_destination(opening.target).utc_unix_seconds),"validated reload retains the exact historical destination and immutable source anchor")
	clock.advance_seconds(125)
	var progressed:float=clock.absolute_minutes()
	check(clock.apply_prologue_destination() and clock.absolute_minutes()==progressed,"retry cannot rewind time after play resumes")
	var director:Node=preload("res://scripts/game/prologue_director.gd").new();add_child(director)
	RealityState.data.prologue=opening.duplicate(true)
	director.writing=preload("res://scripts/game/signal_surface_writing.gd").new()
	director.add_child(director.writing)
	director.state=State.restore(opening);director._document=RealityState.data
	check(director.finish_temporal_synchronization() and director.state.phase=="title_reveal" and "temporal_transition_complete" in director.state.events,"ordinary completed transition records only its real clock acknowledgement")
	var accepted_clock:Dictionary=RealityState.data.campaign_clock.duplicate(true)
	check(not director.finish_temporal_synchronization() and RealityState.data.campaign_clock==accepted_clock,"duplicate visual completion cannot apply another clock jump")
	check(director.finish_historical_cutaway(false) and director.state.phase=="prologue_complete" and "title_presented" in director.state.events and RealityState.data.campaign_clock==accepted_clock,"completed historical title preserves the present-day clock")
	var completed:Dictionary=RealityState.data.prologue.duplicate(true)
	check(director.finish_historical_cutaway(false) and RealityState.data.prologue==completed and RealityState.data.campaign_clock==accepted_clock,"duplicate historical completion is idempotent")
	director.shutdown();director.queue_free()
	var skip:Dictionary=opening.duplicate(true);skip.skipped=true;skip.events=[]
	RealityState.data.prologue=skip
	director=preload("res://scripts/game/prologue_director.gd").new();add_child(director)
	director.writing=preload("res://scripts/game/signal_surface_writing.gd").new()
	director.add_child(director.writing)
	director.state=State.restore(skip);director._document=RealityState.data
	check(director.finish_temporal_synchronization() and director.state.effects.clock_applied and director.state.events.is_empty(),"skip performs the real clock handoff without inventing witnessed transition events")
	check(director.finish_historical_cutaway(true) and director.state.phase=="prologue_complete" and director.state.events.is_empty(),"skipped cutaway completes without invented title or creature observations")
	director.shutdown();director.queue_free()
	# No state flag or timestamp is granted to a refused target/early phase.
	RealityState.data.prologue=opening.duplicate(true)
	RealityState.data.prologue.target.utc_unix_seconds+=.5
	RealityState.data.prologue.target.local_bias_minutes=0
	var edge:Dictionary=RealityState.data.duplicate(true)
	check(not clock.apply_prologue_destination() and RealityState.data==edge,"malformed destination refuses without partial effects")
	RealityState.data.prologue=State.initial()
	check(not clock.apply_prologue_destination(),"early prologue phase cannot use the privileged clock handoff")
	RealityState.data.prologue=State.applied(opening,"clock_applied")
	check(clock.configure_date(1929,11,9,1439),"annual seam fixture starts at the final modeled minute")
	var elapsed_before:=clock.elapsed_minutes();var absolute_before:=clock.absolute_minutes()
	clock.advance_seconds(75)
	check(clock.datetime_string()=="1928-11-10T00:00:15" and clock.day_info().day=="sat","acknowledged campaign civil date and weekday wrap into the same authored year")
	check(absf(clock.elapsed_minutes()-elapsed_before-1.25)<.00001 and absf(clock.absolute_minutes()-absolute_before-1.25)<.00001,"annual wrapping never rewinds elapsed or absolute deadline time")
	check(absf(CampaignWeather.clock_seconds(clock)-float(State.LOOP_START_UTC-18000+15))<.001,"weather and civil clock agree at the annual seam")
	check(RealityState.save_game(),"validated save retains the wrapped calendar and monotonic elapsed counter")
	RealityState.load_game()
	check(clock.datetime_string()=="1928-11-10T00:00:15" and absf(clock.elapsed_minutes()-elapsed_before-1.25)<.00001,"reload preserves annual projection without resetting campaign progress")
	_test_handoff_elapsed_edges(opening)
	RealityState.data=original

func review_annual_destination() -> void:
	for spec:Array in [
		["2026-10-29T11:12:34",-240,"1929-10-29T11:12:34"],
		["2026-11-09T23:59:59",840,"1929-11-09T23:59:59"],
		["2026-11-10T00:00:00",-840,"1928-11-10T00:00:00"],
		["2026-12-31T23:59:59",345,"1928-12-31T23:59:59"],
		["2030-01-01T00:00:00",-210,"1929-01-01T00:00:00"],
		["2028-02-29T12:34:56",0,"1929-02-28T12:34:56"]]:
		var anchor:Dictionary={"utc_unix_seconds":Time.get_unix_time_from_datetime_string(spec[0])-int(spec[1])*60,"local_bias_minutes":spec[1],"local_zone":"Injected local zone"}
		var before:=anchor.duplicate(true)
		var mapped:=State.annual_destination(anchor)
		var civil:=Time.get_datetime_string_from_unix_time(int(mapped.utc_unix_seconds)-18000)
		check(civil==spec[2] and anchor==before and mapped.local_bias_minutes==-300,"annual anchor preserves host civil time without changing source: "+str(spec[0]))
		check(State.annual_destination(mapped)==mapped,"historical destination projection is idempotent: "+str(spec[0]))
	var bounded:=true;var aligned:=true
	for day in 365:
		var source:float=State.LOOP_START_UTC+18*3600
		var destination:float=State.LOOP_START_UTC+day*86400+12345
		var ending:float=State.showcase_end(source,destination)
		bounded=bounded and ending-source>=State.LOOP_SECONDS and ending-source<2*State.LOOP_SECONDS
		aligned=aligned and absf(State.wrap_loop_utc(ending)-destination)<.001
	check(bounded and aligned,"all365 destinations get a bounded full seasonal lap and the exact final historical instant")
	check(State.wrap_loop_utc(State.LOOP_START_UTC+State.LOOP_SECONDS)==State.LOOP_START_UTC and State.wrap_loop_utc(State.LOOP_START_UTC-1)==State.LOOP_START_UTC+State.LOOP_SECONDS-1,"annual seam wraps both directions without a366th date")


func _test_handoff_elapsed_edges(opening:Dictionary) -> void:
	for minutes:float in [2.83,1440.93,576000.93]:
		for stamp:String in ["1928-11-10T05:00:02","1929-11-10T04:59:59","1929-03-01T05:00:01"]:
			var clock:=CampaignClock.new()
			clock.configure_date(1928,11,10,1200);clock.advance_to(minutes)
			var fixture:Dictionary=opening.duplicate(true)
			fixture.target={"utc_unix_seconds":Time.get_unix_time_from_datetime_string(stamp),"local_bias_minutes":-300,"local_zone":"Queens EST"}
			RealityState.data.prologue=fixture
			check(clock.apply_prologue_destination(),"elapsed-cursor handoff accepts annual seam: "+stamp+" / "+str(minutes))
			check(int(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))==int(State.annual_destination(fixture.target).utc_unix_seconds) and clock.elapsed_minutes()>=minutes and clock.elapsed_minutes()<minutes+1.0,"exact civil destination and monotonic elapsed agree across midnight, year wrap and long prelude")
