extends RefCounted
## Prologue facts only. The director observes physical owners; this reducer
## cannot move a valve, spawn a companion or apply a campaign-clock jump.
const PHASES := ["dream", "awakening", "bedroom_exploration", "bathroom_entry",
	"curtain_interaction", "shower_temperature", "shower_complete", "mirror_tapping",
	"mirror_condensation", "protagonist_reveal", "cabinet_inspection", "reflection_visitor",
	"companion_crossing", "first_contact", "identity_mystery", "temporal_command",
	"temporal_synchronization", "title_reveal", "prologue_complete"]
const GATES := {
	"bedroom_exploration":["bathroom_entered"],
	"curtain_interaction":["curtain_pulled", "cold_water_started"],
	"shower_temperature":["hot_water_adjusted", "temperature_balanced"],
	"mirror_tapping":["shower_stopped"],
	"protagonist_reveal":["reflection_observed"],
	"cabinet_inspection":["cabinet_opened", "cabinet_closed"],
	"reflection_visitor":["visitor_seen", "looked_behind", "visitor_seen_again"],
	"first_contact":["murder_presented"],
	"identity_mystery":["identity_question_presented"],
	"temporal_command":["destination_accepted"],
	"temporal_synchronization":["temporal_transition_complete"],
	"title_reveal":["title_presented"]}
const KEYS := ["schema_version", "phase", "events", "skipped", "target", "effects"]
const EFFECTS := ["companion_materialized", "clock_applied"]
const MIN_UNIX := -62135596800 # Gregorian 0001-01-01, matching clock date range.
const MAX_UNIX := 253402300799 # Gregorian 9999-12-31 23:59:59.

static func initial() -> Dictionary:
	return {"schema_version":1, "phase":"dream", "events":[], "skipped":false,
		"target":{}, "effects":{"companion_materialized":false, "clock_applied":false}}

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

static func valid_target(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=3: return false
	if not value.has_all(["utc_unix_seconds", "local_bias_minutes", "local_zone"]): return false
	if not _whole(value.utc_unix_seconds) or float(value.utc_unix_seconds)<MIN_UNIX or float(value.utc_unix_seconds)>MAX_UNIX: return false
	if not _whole(value.local_bias_minutes) or absf(float(value.local_bias_minutes))>840: return false
	var local_seconds: float=float(value.utc_unix_seconds)+float(value.local_bias_minutes)*60.0
	if local_seconds<MIN_UNIX or local_seconds>MAX_UNIX: return false
	if value.local_zone is not String or value.local_zone.length()>96: return false
	for index in value.local_zone.length():
		var code: int=value.local_zone.unicode_at(index)
		if code<32 or code==127: return false
	return true

static func valid(value: Variant) -> bool:
	# Missing/empty optional domain is an unstarted opening, including old saves.
	if value is not Dictionary: return false
	if value.is_empty(): return true
	if value.size()!=KEYS.size() or not value.has_all(KEYS): return false
	if not _whole(value.schema_version) or int(value.schema_version)!=1: return false
	if value.phase is not String or value.phase not in PHASES: return false
	if value.skipped is not bool or value.events is not Array: return false
	if value.target is not Dictionary or (not value.target.is_empty() and not valid_target(value.target)): return false
	if value.effects is not Dictionary or value.effects.size()!=EFFECTS.size() or not value.effects.has_all(EFFECTS): return false
	for key in EFFECTS:
		if value.effects[key] is not bool: return false
	var at: int=PHASES.find(value.phase)
	if not value.target.is_empty() and at<PHASES.find("temporal_command"): return false
	var seen := {}
	for event: Variant in value.events:
		if event is not String or seen.has(event): return false
		var source := _event_phase(event)
		if source.is_empty() or PHASES.find(source)>at: return false
		seen[event]=true
	if not value.skipped:
		for phase: String in GATES:
			if PHASES.find(phase)>=at: continue
			for event: String in GATES[phase]:
				if not seen.has(event): return false
	if at>PHASES.find("companion_crossing") and not value.effects.companion_materialized: return false
	if at>=PHASES.find("temporal_synchronization") and value.target.is_empty(): return false
	if at>=PHASES.find("title_reveal") and not value.effects.clock_applied: return false
	if value.effects.clock_applied and (value.target.is_empty() or (at<PHASES.find("temporal_synchronization") and not value.skipped)): return false
	if value.effects.companion_materialized and at<PHASES.find("companion_crossing") and not value.skipped: return false
	return true

static func _event_phase(event: String) -> String:
	for phase: String in GATES:
		if event in GATES[phase]: return phase
	return ""

static func _copy(value: Dictionary) -> Dictionary:
	var result := initial() if value.is_empty() else value.duplicate(true)
	# Godot JSON numbers reload as floats; canonicalize only this validated
	# domain so equal destinations remain immutable/idempotent after disk load.
	result.schema_version=1
	if not result.target.is_empty(): result.target=_canonical_target(result.target)
	return result

static func _canonical_target(target: Dictionary) -> Dictionary:
	return {"utc_unix_seconds":int(target.utc_unix_seconds),
		"local_bias_minutes":int(target.local_bias_minutes),"local_zone":str(target.local_zone)}

static func restore(value: Variant) -> Dictionary:
	return _copy(value) if valid(value) else {}

static func observe(value: Dictionary, event: String) -> Dictionary:
	if not valid(value): return {}
	var result := _copy(value)
	if _event_phase(event)!=result.phase: return {}
	if event not in result.events: result.events.append(event)
	return result if valid(result) else {}

static func advance(value: Dictionary, next: String) -> Dictionary:
	if not valid(value): return {}
	var result := _copy(value)
	var at: int=PHASES.find(result.phase)
	if next==result.phase: return result
	if at+1>=PHASES.size() or PHASES[at+1]!=next: return {}
	result.phase=next
	return result if valid(result) else {}

static func request_skip(value: Dictionary) -> Dictionary:
	if not valid(value): return {}
	var result := _copy(value)
	if result.phase!="prologue_complete": result.skipped=true
	return result

static func with_target(value: Dictionary, target: Dictionary) -> Dictionary:
	if not valid(value) or not valid_target(target): return {}
	var result := _copy(value)
	if result.phase!="temporal_command": return {}
	# Never resample a destination on resume, retry or an asynchronous callback.
	var canonical := _canonical_target(target)
	if not result.target.is_empty(): return result if result.target==canonical else {}
	result.target=canonical
	return result

static func applied(value: Dictionary, effect: String) -> Dictionary:
	if not valid(value) or effect not in EFFECTS: return {}
	var result := _copy(value)
	result.effects[effect]=true
	return result if valid(result) else {}

static func sample_destination() -> Dictionary:
	# Read-only platform APIs. No OS command, geographic lookup or clock write.
	var stamp := int(floor(Time.get_unix_time_from_system()))
	var zone := Time.get_time_zone_from_system()
	var target := {"utc_unix_seconds":stamp,"local_bias_minutes":zone.get("bias",0),
		"local_zone":zone.get("name","")}
	return target if valid_target(target) else {}

static func date_command(target: Dictionary) -> String:
	if not valid_target(target): return ""
	var bias := int(target.local_bias_minutes)
	var date := Time.get_datetime_string_from_unix_time(int(target.utc_unix_seconds)+bias*60)
	var offset := "%s%02d:%02d" % ["-" if bias<0 else "+",int(absi(bias)/60.0),absi(bias)%60]
	return "root# date --set=\"%s%s\"" % [date,offset]
