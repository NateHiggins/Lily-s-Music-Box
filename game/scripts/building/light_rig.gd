class_name LightRig
extends Node
## The lighting model that sells the fixtures. The compatibility renderer
## can't ray-trace and hates dozens of live omnis, so the rig fakes the
## expensive parts and spends the cheap parts where the camera is:
##
##   - budget: only the FULL_N nearest fixtures burn at full energy, the
##     next HALF_N at reduced energy, the rest fall to zero — but every
##     fixture keeps its emissive envelope + additive halo, so distant
##     sources still read as ON (the "it's lit" impression costs nothing)
##   - faux bounce: the nearest BOUNCE_N fixtures enable a dim warm
##     counter-light low in the room — the first ray bounce, precomputed
##     by taste rather than traced
##   - shadows: a small sticky set of nearby full-energy fixtures receives
##     real shadow maps. Every fixture family participates, so corridors,
##     kitchens and bathrooms do not become shadowless just because their
##     hardware differs from the apartment pendants
##   - hysteresis: fixtures lerp toward their budget target, so walking a
##     corridor reads as pools of light breathing in, never popping

const FULL_N := 14
const HALF_N := 10
const BOUNCE_N := 6
const SHADOW_N := 3
const SHADOW_DISTANCE_SQ := 100.0
const INTERVAL := 0.22

var _accum := 0.0
var _shadowed: Array[Node] = []


func _process(delta: float) -> void:
	_accum += delta
	if _accum < INTERVAL:
		return
	_accum = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var fixtures := get_tree().get_nodes_in_group("light_fixtures")
	var ranked: Array = []
	for f in fixtures:
		ranked.append([f.global_position.distance_squared_to(eye), f])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	# Retain eligible incumbents for two extra rank slots. This hysteresis
	# prevents a shadow map from flipping between adjacent corridor domes
	# whenever the camera crosses their exact midpoint.
	var chosen: Array[Node] = []
	for old in _shadowed:
		for i in range(mini(ranked.size(), FULL_N + 2)):
			if ranked[i][1] == old and ranked[i][0] < SHADOW_DISTANCE_SQ:
				chosen.append(old)
				break
		if chosen.size() >= SHADOW_N:
			break
	for i in range(mini(ranked.size(), FULL_N)):
		var candidate: Node = ranked[i][1]
		if ranked[i][0] < SHADOW_DISTANCE_SQ and candidate not in chosen:
			chosen.append(candidate)
		if chosen.size() >= SHADOW_N:
			break
	_shadowed = chosen
	for i in range(ranked.size()):
		var f: Node = ranked[i][1]
		var scale := 0.0
		if i < FULL_N:
			scale = 1.0
		elif i < FULL_N + HALF_N:
			scale = 0.4
		f.set_budget(scale, i < BOUNCE_N, f in chosen)


func stats() -> Dictionary:
	var full := 0
	var half := 0
	var shadows := 0
	for f in get_tree().get_nodes_in_group("light_fixtures"):
		if f.light and f.light.light_energy > f._base_energy * 0.7:
			full += 1
		elif f.light and f.light.light_energy > 0.05:
			half += 1
		if f.light and f.light.shadow_enabled:
			shadows += 1
	return {"full": full, "half": half, "shadows": shadows}
