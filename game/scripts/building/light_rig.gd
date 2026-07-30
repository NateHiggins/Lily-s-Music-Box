class_name LightRig
extends Node3D
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

const FULL_N := 8
const HALF_N := 6
const BOUNCE_N := 2
# Every fixture that contributes direct light also casts. Compatibility
# previously limited this to eight nearby fixtures, so a visible surface
# lost its shadow merely because its source was farther down the corridor.
const SHADOW_N := FULL_N + HALF_N
const STANDBY_DISTANCE_SQ := 36.0
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
		var d2: float = f.global_position.distance_squared_to(eye)
		# Circulation fixtures win ties against apartment lights behind walls.
		var score: float = d2 * (0.55 if f.navigation_light else 1.0)
		ranked.append([score, f])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	var nearest_navigation: Node = null
	for entry in ranked:
		if entry[1].navigation_light:
			nearest_navigation = entry[1]
			break
	# Preserve active incumbents to keep ordering stable, then fill the set
	# from every direct-light contributor. No world-distance cutoff: if a
	# light can affect a visible surface, it owns a shadow map.
	var active_count := mini(ranked.size(), FULL_N + HALF_N)
	var chosen: Array[Node] = []
	for old in _shadowed:
		for i in range(active_count):
			if ranked[i][1] == old:
				chosen.append(old)
				break
		if chosen.size() >= SHADOW_N:
			break
	for i in range(active_count):
		var candidate: Node = ranked[i][1]
		if candidate not in chosen:
			chosen.append(candidate)
		if chosen.size() >= SHADOW_N:
			break
	_shadowed = chosen
	for i in range(ranked.size()):
		var f: Node = ranked[i][1]
		var scale: float = f.standby_scale \
				if ranked[i][0] < STANDBY_DISTANCE_SQ else 0.0
		if i < FULL_N:
			scale = 1.0
		elif i < FULL_N + HALF_N:
			scale = maxf(0.4, f.standby_scale)
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
