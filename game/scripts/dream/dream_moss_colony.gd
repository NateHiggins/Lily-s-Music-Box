class_name DreamMossColony
extends RefCounted
## Bounded, transient ecology record for one existing LivingField source.
## DreamEcologyDirector owns these records; LivingField remains authoritative for
## physical body/trail/stain and incident owners remain authoritative for cleanup.

enum Phase { SEARCHING, SEEDED, TENDING, EXPLORING, NETWORKED, COMPLEX,
		DISTURBED, RECALLING, WITHERING, STAINED, CLEARED }
enum OrganismClass { CILIUM, PALPATOR, VIBRATION_LISTENER, OCULAR_EXAMINER,
		SUCKER_SAMPLER, MANIPULATOR, RELAY_TENDRIL, COMPLEX_ORGANELLE }

const PHASE_NAMES := ["searching", "seeded", "tending", "exploring", "networked",
		"complex", "disturbed", "recalling", "withering", "stained", "cleared"]
const CLASS_NAMES := ["cilium", "palpator", "vibration_listener", "ocular_examiner",
		"sucker_sampler", "manipulator", "relay_tendril", "complex_organelle"]
const MAX_TARGETS := 48
const MAX_ROUTES := 64
const MAX_ORGANISMS := 24
const MAX_CILIA := 8
const MAX_TENTACLES := 6
const MAX_COMPLEX := 4
const MAX_TARGET_RESERVATIONS := 8
const SUPPORT_RADIUS := [0.9, 2.2, 3.0, 2.8, 2.0, 2.4, 3.6, 2.8]
const ETHER_DRAIN := [0.015, 0.045, 0.035, 0.040, 0.055, 0.050, 0.025, 0.065]
const EXCURSION_S := [5.0, 14.0, 20.0, 16.0, 12.0, 14.0, 24.0, 18.0]
const INFO_CAPACITY := [0.20, 0.60, 0.72, 0.65, 0.78, 0.82, 0.50, 1.0]

var source_id := -1
var seed := 1
var phase: int = Phase.SEARCHING
var phase_reason := "pioneer created"
var origin := Vector3.INF
var extent := 0.18
var maturity := 0.0
var ether_production := 0.0
var ether_reserve := 0.08
var connected_ether_volume := 0.0
var stored_information := 0.0
var information_modalities: Dictionary = {}
var known_targets: Dictionary = {}
var target_reservations: Dictionary = {}
var routes: Dictionary = {}
var organisms: Array[Dictionary] = []
var disturbance := 0.0
var collapse_progress := 0.0
var stain_impressions: Array[Dictionary] = []
var transition_log: Array[Dictionary] = []
var clock := 0.0
var reinforced_routes := 0
var pruned_routes := 0
var reports := 0
var empty_returns := 0
var stranded_deaths := 0
var spawn_refusals := 0
var max_organisms_seen := 0
var _next_organism_id := 1


func configure(source: int, seed_value: int) -> void:
	source_id = source
	seed = seed_value
	transition_log.clear()
	_record_transition(Phase.SEARCHING, phase_reason)


## Candidate rows contain only observable eligibility and bounded fitness facts.
## No narrative/case truth is accepted by this API.
func choose_site(candidates: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for candidate in candidates:
		if not bool(candidate.get("reachable", false)) \
				or not bool(candidate.get("eligible", false)) \
				or bool(candidate.get("exterior", false)) \
				or bool(candidate.get("sealed", false)) \
				or bool(candidate.get("decorative", false)):
			continue
		var score := clampf(float(candidate.get("target_density", 0.0)), 0.0, 1.0) * 0.24
		score += clampf(float(candidate.get("information", 0.0)), 0.0, 1.0) * 0.25
		score += clampf(float(candidate.get("continuity", 0.0)), 0.0, 1.0) * 0.16
		score += clampf(float(candidate.get("volume", 0.0)), 0.0, 1.0) * 0.13
		score += (1.0 - clampf(float(candidate.get("disturbance", 0.0)), 0.0, 1.0)) * 0.10
		score += (1.0 - clampf(float(candidate.get("route_cost", 1.0)), 0.0, 1.0)) * 0.12
		# Stable sub-millimetric tie-breaker; choice never depends on frame order.
		var key := String(candidate.get("id", str(candidate.get("position", Vector3.ZERO))))
		score += float(posmod(key.hash() ^ seed, 997)) / 9970000.0
		if score > best_score:
			best_score = score
			best = candidate.duplicate(true)
	if not best.is_empty():
		origin = best.get("position", Vector3.ZERO)
		_transition(Phase.SEEDED, "viable site committed score=%.3f" % best_score)
	return best


func seed_at(at: Vector3) -> void:
	origin = at
	_transition(Phase.SEEDED, "authored eligible source")


func add_surface_access(amount: float) -> void:
	if phase >= Phase.DISTURBED:
		return
	var useful := clampf(amount, 0.0, 1.0)
	# Time alone cannot mature the colony: access and returned information gate it.
	maturity = clampf(maturity + useful * (0.012 + stored_information * 0.018), 0.0, 1.0)
	extent = 0.18 + maturity * 3.2
	ether_production = maturity * (0.16 + minf(stored_information, 2.0) * 0.08)
	ether_reserve = minf(1.0, ether_reserve + ether_production * 0.25)
	connected_ether_volume = extent * extent * 0.65 * maturity
	_update_growth_phase()


func register_route(route_id: String, target_id: String, points: Array, obstruction := 0.0) -> bool:
	if routes.size() >= MAX_ROUTES and not routes.has(route_id):
		return false
	var packed := PackedVector3Array()
	for point in points:
		packed.append(point as Vector3)
	routes[route_id] = {"target_id": target_id, "points": packed,
			"strength": 0.18, "empty_trips": 0,
			"obstruction": clampf(obstruction, 0.0, 1.0), "live": true}
	return true


func ether_at(at: Vector3, obstruction := 0.0) -> float:
	if origin == Vector3.INF or phase >= Phase.STAINED:
		return 0.0
	var best_distance := at.distance_to(origin)
	var conductance := 1.0
	for route in routes.values():
		if not bool(route.live):
			continue
		for point in route.points:
			var distance: float = at.distance_to(point)
			if distance < best_distance:
				best_distance = distance
				conductance = 0.35 + float(route.strength) * 0.65
	var falloff := clampf(1.0 - best_distance / maxf(0.25, extent), 0.0, 1.0)
	var wall_loss := 1.0 - clampf(maxf(obstruction, _nearest_route_obstruction(at)), 0.0, 1.0)
	return clampf(ether_reserve * falloff * conductance * wall_loss, 0.0, 1.0)


func remember_target(target_id: String, observation: Dictionary) -> float:
	if target_id.is_empty():
		return 0.0
	var existing: Dictionary = known_targets.get(target_id, {})
	var signature := String(observation.get("state_signature", "default"))
	var same_state := String(existing.get("state_signature", "")) == signature
	var repeats := int(existing.get("repeats", 0)) + (1 if same_state else 0)
	var novelty := 1.0 if existing.is_empty() or not same_state else 1.0 / float(1 + repeats)
	var value := observable_value(observation) * novelty
	var modalities: Array = observation.get("modalities", [])
	for modality in modalities:
		information_modalities[String(modality)] = true
	known_targets[target_id] = {"state_signature": signature, "repeats": repeats,
			"value": value, "last_seen": clock, "modalities": modalities.duplicate()}
	_trim_oldest_targets()
	stored_information = minf(8.0, stored_information + value)
	reports += 1
	_update_growth_phase()
	return value


func reserve_target(target_id: String, purpose: int, organism_id: int,
		duration_s := 8.0) -> bool:
	if target_id.is_empty():
		return false
	var expired: Array[String] = []
	for key in target_reservations:
		if float(target_reservations[key].until) <= clock:
			expired.append(String(key))
	for key in expired: target_reservations.erase(key)
	var reservation_key := "%s:%d" % [target_id, purpose]
	var existing: Dictionary = target_reservations.get(reservation_key, {})
	if not existing.is_empty() and int(existing.organism_id) != organism_id:
		return false
	if target_reservations.size() >= MAX_TARGET_RESERVATIONS \
			and not target_reservations.has(reservation_key):
		return false
	target_reservations[reservation_key] = {"target_id": target_id,
			"purpose": purpose, "organism_id": organism_id,
			"until": clock + clampf(duration_s, 0.5, 20.0)}
	return true


func release_target(target_id: String, purpose: int, organism_id: int) -> void:
	var reservation_key := "%s:%d" % [target_id, purpose]
	var existing: Dictionary = target_reservations.get(reservation_key, {})
	if not existing.is_empty() and int(existing.organism_id) == organism_id:
		target_reservations.erase(reservation_key)


static func observable_value(observation: Dictionary) -> float:
	var value := 0.0
	for key in ["moving_parts", "heat", "vibration", "electrical", "controls",
			"openings", "interaction", "material_complexity", "authorized_anomaly"]:
		value += clampf(float(observation.get(key, 0.0)), 0.0, 1.0)
	return clampf(value / 4.0, 0.0, 2.0)


static func class_preference(kind: int, observation: Dictionary) -> float:
	match kind:
		OrganismClass.PALPATOR:
			return float(observation.get("material_complexity", 0.0)) + float(observation.get("heat", 0.0))
		OrganismClass.VIBRATION_LISTENER:
			return float(observation.get("vibration", 0.0)) * 2.0 + float(observation.get("moving_parts", 0.0))
		OrganismClass.OCULAR_EXAMINER:
			return float(observation.get("movement", observation.get("moving_parts", 0.0))) * 2.0
		OrganismClass.SUCKER_SAMPLER:
			return float(observation.get("material_complexity", 0.0)) * 1.5 + float(observation.get("heat", 0.0))
		OrganismClass.MANIPULATOR:
			return float(observation.get("controls", 0.0)) * 2.0 + float(observation.get("openings", 0.0))
		OrganismClass.RELAY_TENDRIL:
			return float(observation.get("route_value", 0.0)) * 2.0
	return observable_value(observation)


func can_spawn(kind: int, root: Vector3, route_id := "") -> bool:
	if origin == Vector3.INF or phase >= Phase.DISTURBED or organisms.size() >= MAX_ORGANISMS:
		return _refuse()
	if kind != OrganismClass.CILIUM and _count_class(OrganismClass.CILIUM) == 0:
		return _refuse()
	var minimum_ether := 0.05 if kind == OrganismClass.CILIUM else 0.12
	if root.distance_to(origin) > SUPPORT_RADIUS[kind] or ether_at(root) < minimum_ether:
		return _refuse()
	if kind != OrganismClass.CILIUM and (maturity < 0.22 or stored_information < 0.18):
		return _refuse()
	if kind == OrganismClass.COMPLEX_ORGANELLE and not complex_unlocked():
		return _refuse()
	if kind == OrganismClass.CILIUM and _count_class(kind) >= MAX_CILIA:
		return _refuse()
	if kind > OrganismClass.CILIUM and kind < OrganismClass.COMPLEX_ORGANELLE \
			and _tentacle_count() >= MAX_TENTACLES:
		return _refuse()
	if kind == OrganismClass.COMPLEX_ORGANELLE and _count_class(kind) >= MAX_COMPLEX:
		return _refuse()
	if not route_id.is_empty() and (not routes.has(route_id) or not bool(routes[route_id].live)):
		return _refuse()
	return true


func spawn(kind: int, root: Vector3, route_id := "") -> Dictionary:
	if not can_spawn(kind, root, route_id):
		return {}
	var record := {"id": _next_organism_id, "class": kind, "root": root,
			"position": root, "route_id": route_id, "ether": 1.0, "information": 0.0,
			"away_s": 0.0, "returning": false, "senescent": false, "residue": false}
	_next_organism_id += 1
	organisms.append(record)
	max_organisms_seen = maxi(max_organisms_seen, organisms.size())
	_update_growth_phase()
	return record


func update_excursion(record: Dictionary, at: Vector3, delta: float, information_gain := 0.0) -> String:
	if bool(record.senescent):
		return "senescent"
	record.position = at
	record.away_s = float(record.away_s) + maxf(delta, 0.0)
	record.information = minf(INFO_CAPACITY[int(record["class"])], float(record.information) + maxf(information_gain, 0.0))
	var concentration := ether_at(at)
	if concentration < 0.55:
		record.ether = maxf(0.0, float(record.ether) - ETHER_DRAIN[int(record["class"])] * delta * (1.5 - concentration))
	else:
		record.ether = minf(1.0, float(record.ether) + 0.18 * delta)
	if disturbance > 0.0 or float(record.ether) < 0.22 \
			or float(record.information) >= INFO_CAPACITY[int(record["class"])] * 0.85 \
			or float(record.away_s) >= EXCURSION_S[int(record["class"])] :
		record.returning = true
	if bool(record.returning) and not has_support_path(at, int(record["class"]), String(record.route_id)):
		record.senescent = true
		record.residue = true
		stranded_deaths += 1
		stain_impressions.append({"at": at, "density": 0.65, "stranded": true})
		return "senescent"
	return "returning" if bool(record.returning) else "exploring"


func report(record: Dictionary, target_id := "", observation := {}) -> float:
	var value := 0.0
	if float(record.information) > 0.0 and not target_id.is_empty():
		value = remember_target(target_id, observation)
	var route_id := String(record.route_id)
	if routes.has(route_id):
		var route: Dictionary = routes[route_id]
		if value > 0.01:
			route.strength = minf(1.0, float(route.strength) + 0.16 * value)
			route.empty_trips = 0
			reinforced_routes += 1
		else:
			route.empty_trips = int(route.empty_trips) + 1
			empty_returns += 1
			if int(route.empty_trips) >= 3:
				route.strength = maxf(0.0, float(route.strength) - 0.24)
				if float(route.strength) <= 0.05:
					route.live = false
					pruned_routes += 1
	record.information = 0.0
	record.away_s = 0.0
	record.ether = minf(1.0, float(record.ether) + 0.55)
	record.returning = false
	return value


func has_support_path(at: Vector3, kind: int, route_id := "") -> bool:
	if at.distance_to(origin) <= SUPPORT_RADIUS[kind] and ether_at(at) >= 0.08:
		return true
	if route_id.is_empty() or not routes.has(route_id):
		return false
	var route: Dictionary = routes[route_id]
	return bool(route.live) and float(route.obstruction) < 0.85 and float(route.strength) >= 0.12


func complex_unlocked() -> bool:
	var stable := 0
	for route in routes.values():
		if bool(route.live) and float(route.strength) >= 0.45:
			stable += 1
	return maturity >= 0.62 and connected_ether_volume >= 1.2 \
			and information_modalities.size() >= 3 and stable >= 2 \
			and phase < Phase.DISTURBED


func disturb(amount: float, reason: String) -> void:
	if phase >= Phase.STAINED:
		return
	disturbance = maxf(disturbance, clampf(amount, 0.0, 1.0))
	_transition(Phase.DISTURBED, reason)
	for record in organisms:
		record.returning = true


func advance_collapse(delta: float) -> void:
	clock += maxf(delta, 0.0)
	if phase < Phase.DISTURBED:
		return
	collapse_progress = clampf(collapse_progress + delta * (0.10 + disturbance * 0.20), 0.0, 1.0)
	if collapse_progress >= 0.12 and phase == Phase.DISTURBED:
		_transition(Phase.RECALLING, "alert reached moss; organisms recalled")
	if collapse_progress >= 0.38 and phase == Phase.RECALLING:
		_transition(Phase.WITHERING, "ether production failed")
	if phase >= Phase.WITHERING:
		ether_production *= pow(0.35, delta)
		ether_reserve *= pow(0.22, delta)
		maturity *= pow(0.30, delta)
	if collapse_progress >= 0.94 and phase == Phase.WITHERING:
		_build_density_stain()
		_transition(Phase.STAINED, "living network settled into persistent stain")


func cleanup(amount: float, authorized: bool) -> float:
	if not authorized or phase != Phase.STAINED:
		return stain_coverage()
	var remaining: Array[Dictionary] = []
	for impression in stain_impressions:
		impression.density = maxf(0.0, float(impression.density) - clampf(amount, 0.0, 1.0))
		if float(impression.density) > 0.02:
			remaining.append(impression)
	stain_impressions = remaining
	if stain_impressions.is_empty():
		_transition(Phase.CLEARED, "authorized maintenance removed residue")
	return stain_coverage()


func recolonization_blocked() -> bool:
	return phase == Phase.STAINED and stain_coverage() > 0.02


func stain_coverage() -> float:
	var total := 0.0
	for impression in stain_impressions:
		total += float(impression.density)
	return total


func census() -> Dictionary:
	var counts := {}
	for label in CLASS_NAMES:
		counts[label] = 0
	for record in organisms:
		var label: String = CLASS_NAMES[int(record["class"])]
		counts[label] = int(counts[label]) + 1
	var live_routes := 0
	for route in routes.values():
		if bool(route.live):
			live_routes += 1
	return {"source_id": source_id, "phase": PHASE_NAMES[phase],
			"phase_reason": phase_reason, "moss_maturity": snappedf(maturity, 0.0001),
			"ether_reserve": snappedf(ether_reserve, 0.0001),
			"connected_ether_volume": snappedf(connected_ether_volume, 0.0001),
			"stored_information": snappedf(stored_information, 0.0001),
			"information_diversity": information_modalities.size(),
			"known_targets": known_targets.size(), "organisms": counts,
			"target_reservations": target_reservations.size(),
			"live_routes": live_routes, "reinforced_routes": reinforced_routes,
			"pruned_routes": pruned_routes, "disturbance": snappedf(disturbance, 0.001),
			"collapse_progress": snappedf(collapse_progress, 0.001),
			"stain_coverage": snappedf(stain_coverage(), 0.001),
			"budget": {"organisms": organisms.size(), "organism_cap": MAX_ORGANISMS,
				"targets": known_targets.size(), "target_cap": MAX_TARGETS,
				"routes": routes.size(), "route_cap": MAX_ROUTES,
				"max_organisms": max_organisms_seen}}


func deterministic_receipt() -> String:
	return JSON.stringify(census(), "", true, true)


func _update_growth_phase() -> void:
	if phase >= Phase.DISTURBED:
		return
	if complex_unlocked():
		_transition(Phase.COMPLEX, "maturity, ether, diversity and routes support complex life")
	elif maturity >= 0.45 and _stable_route_count() >= 1:
		_transition(Phase.NETWORKED, "useful path stabilized")
	elif _tentacle_count() > 0:
		_transition(Phase.EXPLORING, "information and ether justified specialization")
	elif _count_class(OrganismClass.CILIUM) > 0:
		_transition(Phase.TENDING, "cilia sampling beside moss")


func _transition(next_phase: int, reason: String) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_reason = reason
	_record_transition(next_phase, reason)


func _record_transition(next_phase: int, reason: String) -> void:
	transition_log.append({"at": snappedf(clock, 0.001), "phase": PHASE_NAMES[next_phase], "reason": reason})


func _refuse() -> bool:
	spawn_refusals += 1
	return false


func _count_class(kind: int) -> int:
	var total := 0
	for record in organisms:
		if int(record["class"]) == kind and not bool(record.senescent):
			total += 1
	return total


func _tentacle_count() -> int:
	var total := 0
	for record in organisms:
		var kind := int(record["class"])
		if kind > OrganismClass.CILIUM and kind < OrganismClass.COMPLEX_ORGANELLE and not bool(record.senescent):
			total += 1
	return total


func _stable_route_count() -> int:
	var total := 0
	for route in routes.values():
		if bool(route.live) and float(route.strength) >= 0.45:
			total += 1
	return total


func _nearest_route_obstruction(at: Vector3) -> float:
	var best := INF
	var obstruction := 0.0
	for route in routes.values():
		for point in route.points:
			var distance: float = at.distance_squared_to(point)
			if distance < best:
				best = distance
				obstruction = float(route.obstruction)
	return obstruction


func _trim_oldest_targets() -> void:
	while known_targets.size() > MAX_TARGETS:
		var oldest := ""
		var oldest_time := INF
		var keys := known_targets.keys()
		keys.sort()
		for key in keys:
			var seen := float(known_targets[key].last_seen)
			if seen < oldest_time:
				oldest_time = seen
				oldest = String(key)
		known_targets.erase(oldest)


func _build_density_stain() -> void:
	stain_impressions.clear()
	stain_impressions.append({"at": origin, "density": 1.0, "stranded": false})
	for route in routes.values():
		if float(route.strength) < 0.1:
			continue
		for point in route.points:
			stain_impressions.append({"at": point, "density": float(route.strength), "stranded": false})
			if stain_impressions.size() >= MAX_ROUTES:
				return
