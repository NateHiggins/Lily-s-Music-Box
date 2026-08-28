class_name NpcObservationLedger
extends Node
## The observation authority: a character learns something only through a
## concrete evidence route - hearing it through the building's acoustic
## fabric, seeing changed physical state while present, inspecting it
## directly, or reading a document left in the world. Coordinators emit
## neutral world events; THIS ledger decides who could observe them and
## records each belief with full provenance (who, what, where, channel,
## simulation minute, evidence). Nothing else may author NPC knowledge.

signal observation_recorded(npc: String, learned: String, channel: String)

## Sounds carried below this acoustic strength are absorbed by the
## building before anyone could honestly notice them.
const MIN_AUDIBLE_STRENGTH := 0.15

var _observers: Array = []
var _minute_provider: Callable
var _acoustic: Object
var _presence_provider: Callable


## observers: [{"npc": id, "unit": "2B"}, ...]. acoustic must answer
## audibility(origin) -> [{id, room, strength}]; null means only the
## source unit itself can hear. presence answers whether an npc is home
## to see in-flat changes; invalid means assume home.
func setup(observers: Array, minute_provider: Callable,
		acoustic: Object = null, presence := Callable()) -> void:
	_observers = observers.duplicate(true)
	_minute_provider = minute_provider
	_acoustic = acoustic
	_presence_provider = presence
	_store()


## A sound happened at a graph node. Whoever the acoustic fabric actually
## carries it to, above threshold, hears it - nobody else.
func witness_audible_event(origin_node: String, sound: String,
		evidence: Dictionary) -> Array:
	var audible_units := _audible_units(origin_node)
	var recorded: Array = []
	for observer in _observers:
		var unit := str(observer.get("unit", ""))
		if unit.is_empty() or not audible_units.has(unit):
			continue
		var channel := "in_home_hearing" \
				if unit == str(evidence.get("source_unit", "")) \
				else "heating_riser"
		if _record(str(observer.npc), "heard_%s" % sound, channel,
				unit, evidence):
			recorded.append(str(observer.npc))
	return recorded


## Physical state changed inside a unit. Residents of that unit see it
## only while present; nobody learns it from elsewhere.
func witness_visible_state(unit: String, seen: String,
		evidence: Dictionary) -> Array:
	var recorded: Array = []
	for observer in _observers:
		if str(observer.get("unit", "")) != unit:
			continue
		if not _is_present(str(observer.npc)):
			continue
		if _record(str(observer.npc), seen, "in_home_sight", unit,
				evidence):
			recorded.append(str(observer.npc))
	return recorded


## An actor reports its own first-hand perception (a porter inspecting
## the mechanism in front of it). Provenance still names the channel.
func record_direct_observation(npc: String, learned: String,
		channel: String, where: String, evidence: Dictionary) -> bool:
	return _record(npc, learned, channel, where, evidence)


func beliefs(npc: String) -> Array:
	return _store().get(npc, []).duplicate(true)


func has_learned(npc: String, learned: String) -> bool:
	for belief in _store().get(npc, []):
		if str(belief.get("learned", "")) == learned:
			return true
	return false


func _audible_units(origin_node: String) -> Dictionary:
	var units := {}
	if _acoustic != null and _acoustic.has_method("audibility"):
		for entry in _acoustic.audibility(origin_node):
			if float(entry.get("strength", 0.0)) < MIN_AUDIBLE_STRENGTH:
				continue
			var room := str(entry.get("room", ""))
			if room.length() == 2:  # unit-shaped room id ("2B", "3B")
				units[room] = true
	else:
		# No acoustic fabric bound: only the source unit itself hears.
		var source := str(origin_node)
		for observer in _observers:
			if source.contains(str(observer.get("unit", ""))):
				units[str(observer.unit)] = true
	return units


func _is_present(npc: String) -> bool:
	if _presence_provider.is_valid():
		return bool(_presence_provider.call(npc))
	return true


func _record(npc: String, learned: String, channel: String,
		where: String, evidence: Dictionary) -> bool:
	var store := _store()
	if not store.has(npc):
		store[npc] = []
	for belief in store[npc]:
		if str(belief.get("learned", "")) == learned:
			return false
	store[npc].append({
		"learned": learned,
		"channel": channel,
		"where": where,
		"at_minutes": _now(),
		"evidence": evidence.duplicate(true),
	})
	RealityState.commit()
	observation_recorded.emit(npc, learned, channel)
	return true


func _now() -> float:
	if _minute_provider.is_valid():
		return fposmod(float(_minute_provider.call()), 1440.0)
	return -1.0


func _store() -> Dictionary:
	if not RealityState.data.has("npc_observations"):
		RealityState.data.npc_observations = {}
	return RealityState.data.npc_observations
