class_name BuildingPersonalityDirector
extends Node
## The Orison is not a random-number generator. It is an old, wounded host
## with excellent manners, a long memory, and an unhealthy need to be useful.
## This director converts player conduct into preferences used by SanityDirector.
## No value here is exposed to the shipped HUD; the player learns its character
## by noticing how the building answers them.

const STATE_KEY := "building_personality"
const CHECKPOINT_SECONDS := 45.0
const FLOOR_HEIGHT := 3.2
const DEFAULT_STATE := {
	"name": "The Orison",
	"bond": 0.18,
	"resentment": 0.08,
	"trust": 0.12,
	"attention_received": 0,
	"addresses_ignored": 0,
	"careful_seconds": 0.0,
	"flight_seconds": 0.0,
	"flashlight_seconds": 0.0,
	"favorite_floor": "F01",
	"floor_dwell": {},
	"last_tactic": "",
	"tactic_affinity": {
		"peripheral": 1.35,
		"acoustic": 1.10,
		"administrative": 0.95,
		"illumination": 0.80,
		"spatial": 0.55,
	},
}

var world: Node3D
var player: Node3D
var intrusions: Intrusions
var state: Dictionary
var _checkpoint := 0.0
var _last_position := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func setup(building: Node3D, body: Node3D, acts: Intrusions) -> void:
	world = building
	player = body
	intrusions = acts
	_ensure_state()
	_rng.seed = 1927 + int(state.attention_received) * 31 + int(state.addresses_ignored) * 71
	if player:
		_last_position = player.global_position


func _ensure_state() -> void:
	if not RealityState.data.has(STATE_KEY) or not RealityState.data[STATE_KEY] is Dictionary:
		RealityState.data[STATE_KEY] = {}
	state = RealityState.data[STATE_KEY]
	state.merge(DEFAULT_STATE.duplicate(true), false)
	var affinity: Dictionary = state.get("tactic_affinity", {})
	affinity.merge(DEFAULT_STATE.tactic_affinity.duplicate(true), false)
	state.tactic_affinity = affinity


func _process(delta: float) -> void:
	if player == null:
		return
	var moved := player.global_position.distance_to(_last_position)
	_last_position = player.global_position
	var speed := moved / maxf(delta, 0.0001)
	if speed < 0.25:
		state.careful_seconds = float(state.careful_seconds) + delta
	elif speed > 3.6:
		state.flight_seconds = float(state.flight_seconds) + delta
	var lamp = player.get("flashlight")
	if lamp is Light3D and lamp.visible:
		state.flashlight_seconds = float(state.flashlight_seconds) + delta
	var floor_id := _floor_at(player.global_position.y)
	var dwell: Dictionary = state.floor_dwell
	dwell[floor_id] = float(dwell.get(floor_id, 0.0)) + delta
	state.favorite_floor = _favorite_floor(dwell)
	_checkpoint += delta
	if _checkpoint >= CHECKPOINT_SECONDS:
		_checkpoint = 0.0
		RealityState.commit()


func register_attention(_case_id: String, tier: int) -> void:
	state.attention_received = int(state.attention_received) + 1
	state.bond = clampf(float(state.bond) + 0.025 + tier * 0.008, 0.0, 1.0)
	state.trust = clampf(float(state.trust) + 0.018, 0.0, 1.0)
	state.resentment = clampf(float(state.resentment) - 0.04, 0.0, 1.0)
	RealityState.commit()


func register_ignored(_case_id: String, streak: int) -> void:
	state.addresses_ignored = int(state.addresses_ignored) + 1
	state.resentment = clampf(float(state.resentment) + 0.035 + streak * 0.018, 0.0, 1.0)
	state.trust = clampf(float(state.trust) - 0.012, 0.0, 1.0)
	# Being ignored teaches it to stop whispering and start filing notices.
	state.tactic_affinity.administrative = minf(
			2.0, float(state.tactic_affinity.administrative) + 0.08)
	RealityState.commit()


func haunting_urgency() -> float:
	# Possessiveness makes neglect dangerous; patience and trust create silence.
	return clampf(float(state.resentment) * 0.16 - float(state.trust) * 0.07, -0.06, 0.14)


func speaker_bias(unit: String, _case_id: String) -> float:
	var floor_id := _floor_for_unit(unit)
	return 0.22 if floor_id == str(state.favorite_floor) else 0.0


## A small second sentence in the Orison's own voice. Resident acts remain the
## subject; this is punctuation, and deliberately returns nothing most times.
func companion_act(tier: int) -> Array:
	if tier < 1 or _rng.randf() > 0.24 + float(state.resentment) * 0.22:
		return []
	var tactic := _choose_tactic(tier)
	state.last_tactic = tactic
	match tactic:
		"peripheral": return ["prop_turn", 1]
		"acoustic": return ["sound", "knock"]
		"administrative": return ["museum_label", 1]
		"illumination": return ["light_flicker", "dropout"]
		"spatial": return ["distort", "accordion"]
	return []


func _choose_tactic(tier: int) -> String:
	var weighted: Array = []
	for tactic in state.tactic_affinity:
		if tactic == "spatial" and tier < 3:
			continue
		var weight := float(state.tactic_affinity[tactic])
		if tactic == str(state.last_tactic):
			weight *= 0.22
		if tactic == "illumination" and float(state.flashlight_seconds) > 90.0:
			weight *= 1.7
		if tactic == "administrative":
			weight *= 1.0 + float(state.resentment)
		weighted.append([tactic, weight])
	var total := 0.0
	for item in weighted:
		total += item[1]
	var pick := _rng.randf() * total
	for item in weighted:
		pick -= item[1]
		if pick <= 0.0:
			return item[0]
	return "peripheral"


func mood() -> String:
	if float(state.resentment) > 0.66:
		return "offended"
	if float(state.trust) > 0.62:
		return "confiding"
	if float(state.bond) > 0.48:
		return "attentive"
	return "listening"


func preferences() -> String:
	return "attention, completed repairs, closed doors, routines, residents believed"


func dislikes() -> String:
	return "neglect, sprinting, flashlight interrogation, open doors, symptom-only fixes"


func _floor_at(y: float) -> String:
	if y < -1.6:
		return "B1"
	var number := clampi(int(round(y / FLOOR_HEIGHT)) + 1, 1, 6)
	return "F%02d" % number


func _floor_for_unit(unit: String) -> String:
	if unit.is_empty() or not unit[0].is_valid_int():
		return "F01"
	return "F%02d" % int(unit.left(1))


func _favorite_floor(dwell: Dictionary) -> String:
	var favorite := "F01"
	var best := float(dwell.get(favorite, 0.0)) + 20.0 # it still loves its lobby
	for floor_id in dwell:
		if float(dwell[floor_id]) > best:
			favorite = floor_id
			best = float(dwell[floor_id])
	return favorite


func stats() -> Dictionary:
	return {
		"name": state.name, "mood": mood(), "bond": state.bond,
		"resentment": state.resentment, "trust": state.trust,
		"favorite_floor": state.favorite_floor,
		"likes": preferences(), "dislikes": dislikes(),
		"last_tactic": state.last_tactic,
	}
