class_name HeatBalance
extends RefCounted
## The Orison has one boiler and a finite quantity of steam. A radiator does
## not manufacture heat when its vent is opened: it wins a larger share of
## the same cycle, and somebody else gets what remains. That zero-sum fact is
## the maintenance activity's joke and the reason this belongs in one model
## rather than twenty-three unrelated prop scripts.

signal balance_changed(results: Dictionary)

## Fixed service inserts, from slow bedroom vent to fast top-of-riser vent.
## The player replaces an orifice; this is not a disguised thermostat.
const VENT_WEIGHTS := [0.30, 0.48, 0.72, 1.00, 1.32]
const DEFAULT_TARGET := 0.62

var _states: Dictionary = {}
var _results: Dictionary = {}
var _riser_members: Dictionary = {}
var _boiler_output := 1.0


func configure(layout: Dictionary) -> void:
	_states.clear()
	_results.clear()
	_riser_members.clear()
	for floor_data in layout.get("floors", []):
		for marker in floor_data.get("markers", []):
			if marker.get("kind") != "radiator":
				continue
			var node_id := String(marker.get("id", ""))
			var riser := String(marker.get("riser", "H-X"))
			var unit := String(marker.get("unit", ""))
			var grade := 2 + posmod(hash(unit), 2)
			_states[node_id] = {
				"unit": unit, "riser": riser,
				"height": float(marker.get("pos", [0, 0, 0])[2]),
				"supply_position": 1.0, "vent_grade": grade,
				"pitch": 0.35, "target": _target_for(unit),
			}
			if not _riser_members.has(riser):
				_riser_members[riser] = []
			_riser_members[riser].append(node_id)
	_solve()


func update_radiator(node_id: String, supply_position: float,
		vent_grade: int, pitch: float) -> void:
	if not _states.has(node_id):
		return
	var state: Dictionary = _states[node_id]
	state.supply_position = clampf(supply_position, 0.0, 1.0)
	state.vent_grade = clampi(vent_grade, 0, VENT_WEIGHTS.size() - 1)
	state.pitch = clampf(pitch, -1.0, 1.0)
	_solve()


func set_boiler_output(value: float) -> void:
	_boiler_output = clampf(value, 0.0, 1.0)
	_solve()


func boiler_output() -> float:
	return _boiler_output


func result_for(node_id: String) -> Dictionary:
	return _results.get(node_id, {}).duplicate()


func all_results() -> Dictionary:
	return _results.duplicate(true)


func total_delivered_heat() -> float:
	var total := 0.0
	for result in _results.values():
		total += float(result.get("heat", 0.0))
	return total


func _solve() -> void:
	var requests: Dictionary = {}
	var request_total := 0.0
	for node_id in _states:
		var state: Dictionary = _states[node_id]
		var supply := float(state.supply_position)
		var request := 0.0
		if supply > 0.02:
			request = VENT_WEIGHTS[int(state.vent_grade)]
			# A partly shut one-pipe valve is not a useful control. It admits
			# steam while obstructing the condensate returning through that same
			# throat, so it loses useful output and earns a hammer fault.
			if supply < 0.98:
				request *= lerpf(0.22, 0.52, supply)
		requests[node_id] = request
		request_total += request
	var budget := float(_states.size()) * DEFAULT_TARGET * _boiler_output
	_results.clear()
	for node_id in _states:
		var state: Dictionary = _states[node_id]
		var share := 0.0
		if request_total > 0.0001:
			share = budget * float(requests[node_id]) / request_total
		var supply := float(state.supply_position)
		var bad_pitch := float(state.pitch) < 0.0
		var partial := supply > 0.02 and supply < 0.98
		var target := float(state.target)
		var satisfaction := clampf(1.0 - absf(share - target) /
				maxf(target, 0.01), 0.0, 1.0)
		_results[node_id] = {
			"unit": state.unit, "riser": state.riser,
			"heat": share, "target": target,
			"satisfaction": satisfaction,
			"hammer": partial or (bad_pitch and share > 0.05),
			"hiss": int(state.vent_grade) >= 4 and share > 0.55,
			"supply_open": supply >= 0.98,
			"supply_partial": partial,
			"vent_grade": int(state.vent_grade),
			"pitch": float(state.pitch),
			"boiler_output": _boiler_output,
		}
	balance_changed.emit(_results)


func _target_for(unit: String) -> float:
	# Complaint thresholds belong to households. The small spread prevents a
	# mathematically even solution from becoming a morally even one.
	return 0.54 + float(posmod(hash(unit), 7)) * 0.025
