class_name AttentionLedger
extends Node
## SR6 owner-neutral playtest telemetry. It attributes each active second to
## one primary-attention lane and retains a rolling 45-minute window. It owns
## no objective, route, case, Dream behaviour or save fact.

enum Lane { MAINTENANCE, PEOPLE, DREAM }

const LANE_NAMES := ["maintenance", "people_travel_search", "dream_relationship"]
const WINDOW_S := 45.0 * 60.0
const TARGET_SHARE := 1.0 / 3.0
const TOLERANCE := 0.05
const MAX_FRAME_S := 0.25
const REPORT_EVERY_S := 5.0 * 60.0

var campaign_shell: Node
var _segments: Array[Dictionary] = []
var _window_seconds := 0.0
var _window_by_lane := [0.0, 0.0, 0.0]
var _session_seconds := 0.0
var _session_by_lane := [0.0, 0.0, 0.0]
var _next_report_s := REPORT_EVERY_S


func setup(shell: Node) -> void:
	campaign_shell = shell


func _process(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	record_sample(classify_primary_attention(), minf(delta, MAX_FRAME_S))
	if _session_seconds >= _next_report_s:
		print("[ATTENTION LEDGER] ", JSON.stringify(census()))
		_next_report_s += REPORT_EVERY_S


## Priority follows what has actually captured the player's attention. A live
## limb behind an open service panel cannot relabel maintenance as Dream; a
## resident conversation likewise remains a people beat. Inside the dream
## world, every active second is relationship by definition.
func classify_primary_attention() -> int:
	if campaign_shell != null and str(campaign_shell.get("active_kind")) == "dream":
		return Lane.DREAM
	if _group_claims("attention_maintenance"):
		return Lane.MAINTENANCE
	if _group_claims("attention_people"):
		return Lane.PEOPLE
	if _group_claims("attention_dream"):
		return Lane.DREAM
	# Waking traversal, diagnosis and searching are the connective people lane.
	# This default prevents ambient organism visibility from claiming time.
	return Lane.PEOPLE


func _group_claims(group_name: StringName) -> bool:
	for owner in get_tree().get_nodes_in_group(group_name):
		if owner.has_method("attention_active") \
				and bool(owner.call("attention_active")):
			return true
	return false


## Public so a playtest importer can feed recorded spans without replaying
## frames. Production calls it only from _process().
func record_sample(lane: int, seconds: float) -> bool:
	if lane < Lane.MAINTENANCE or lane > Lane.DREAM or seconds <= 0.0:
		return false
	_session_seconds += seconds
	_session_by_lane[lane] += seconds
	_window_seconds += seconds
	_window_by_lane[lane] += seconds
	if not _segments.is_empty() and int(_segments[-1].lane) == lane:
		_segments[-1].seconds = float(_segments[-1].seconds) + seconds
	else:
		_segments.append({"lane": lane, "seconds": seconds})
	_trim_window()
	return true


func _trim_window() -> void:
	var excess := _window_seconds - WINDOW_S
	while excess > 0.0001 and not _segments.is_empty():
		var first := _segments[0]
		var removed := minf(excess, float(first.seconds))
		var lane := int(first.lane)
		first.seconds = float(first.seconds) - removed
		_window_seconds -= removed
		_window_by_lane[lane] -= removed
		excess -= removed
		if float(first.seconds) <= 0.0001:
			_segments.pop_front()
		else:
			_segments[0] = first


func reset() -> void:
	_segments.clear()
	_window_seconds = 0.0
	_window_by_lane = [0.0, 0.0, 0.0]
	_session_seconds = 0.0
	_session_by_lane = [0.0, 0.0, 0.0]
	_next_report_s = REPORT_EVERY_S


func census() -> Dictionary:
	var shares := {}
	var seconds := {}
	var session_seconds := {}
	var balanced := _window_seconds >= 40.0 * 60.0
	for lane in LANE_NAMES.size():
		var share: float = float(_window_by_lane[lane]) / _window_seconds \
				if _window_seconds > 0.0 else 0.0
		shares[LANE_NAMES[lane]] = snappedf(share, 0.0001)
		seconds[LANE_NAMES[lane]] = snappedf(_window_by_lane[lane], 0.01)
		session_seconds[LANE_NAMES[lane]] = snappedf(
				float(_session_by_lane[lane]), 0.01)
		balanced = balanced and absf(share - TARGET_SHARE) <= TOLERANCE
	return {
		"window_seconds": snappedf(_window_seconds, 0.01),
		"window_minutes": snappedf(_window_seconds / 60.0, 0.01),
		"seconds": seconds,
		"shares": shares,
		"balanced": balanced,
		"target": TARGET_SHARE,
		"tolerance": TOLERANCE,
		"segments": _segments.size(),
		"session_seconds": snappedf(_session_seconds, 0.01),
		"session_by_lane": session_seconds,
	}
