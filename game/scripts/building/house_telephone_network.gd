class_name HouseTelephoneNetwork
extends Node
## Transient physical line truth. Story owners may ask it to present a call;
## it never decides who calls or what the call means.

signal line_changed(snapshot: Dictionary)
signal endpoint_answered(endpoint_id: String)
signal endpoint_unanswered(endpoint_id: String)
signal line_connected(endpoint_id: String, trunk_id: String)
signal line_released(previous: Dictionary)

# PHONE-A's closed ordinary table. BUSY is a refusal while ANSWERED/CARRYING;
# OPEN and FAULT require physical owners and enter in later vertical slices.
# Naming unreachable enum values here would pretend those mechanisms exist.
enum LineState { IDLE, ASKING, ANSWERED, CARRYING }

var endpoints: Dictionary = {}
var state := LineState.IDLE
var asking := ""
var answered_by := ""
var carried_by := ""
var sequence := 0


func register_endpoint(spec: Dictionary) -> bool:
	var ident := str(spec.get("id", ""))
	var extension := str(spec.get("extension", ""))
	if ident == "" or extension == "": return false
	for known in endpoints.values():
		if str(known.get("extension", "")) == extension: return false
	if endpoints.has(ident): return false
	endpoints[ident] = spec.duplicate(true)
	return true


func request(endpoint_id: String) -> bool:
	if state != LineState.IDLE or not endpoints.has(endpoint_id): return false
	state = LineState.ASKING
	asking = endpoint_id
	sequence += 1
	_publish()
	return true


func answer(operator_id: String) -> bool:
	if state != LineState.ASKING or operator_id == "": return false
	state = LineState.ANSWERED
	answered_by = operator_id
	endpoint_answered.emit(asking)
	_publish()
	return true


func carry(trunk_id: String) -> bool:
	if state != LineState.ANSWERED or trunk_id == "": return false
	state = LineState.CARRYING
	carried_by = trunk_id
	_publish()
	line_connected.emit(asking, trunk_id)
	return true


func expire_unanswered(expected_sequence: int) -> bool:
	## Time belongs to the caller. It may ask the physical line to expire only
	## the same unanswered appearance it originally presented; a late timer can
	## never tear down a newer call.
	if state != LineState.ASKING or expected_sequence != sequence: return false
	var missed := asking
	state = LineState.IDLE
	asking = ""
	_publish()
	endpoint_unanswered.emit(missed)
	return true


func release(released_by: String) -> bool:
	if state not in [LineState.ANSWERED, LineState.CARRYING]: return false
	if released_by != answered_by: return false
	var previous := snapshot()
	state = LineState.IDLE
	asking = ""
	answered_by = ""
	carried_by = ""
	_publish()
	line_released.emit(previous)
	return true


func snapshot() -> Dictionary:
	return {"state":LineState.keys()[state], "asking":asking,
			"answered_by":answered_by, "carried_by":carried_by,
			"sequence":sequence}


func _publish() -> void:
	line_changed.emit(snapshot())
