extends RefCounted
## Read-only assertions for an already composed production world. This helper
## never creates a route/body, moves time, grants access or supplies attendance.
## A calling fixture must write its own source-bound runtime contract.
const EXPECTED := {
	"rhea_sato": {"unit": "3D", "source": "res://data/orison_v2/rhea_sato_routine.json", "seat": "balcony_north_03"},
	"transient_guests": {"unit": "4D", "source": "res://data/orison_v2/transient_guests_routine.json", "seat": "balcony_north_07"}}

static func inspect(world: Node3D) -> Dictionary:
	var result := {"checks": [], "failures": [], "actors": {}, "scope": "production registration and loaded-owner inspection only; no arrival or schedule proof"}
	if not is_instance_valid(world) or not world.is_inside_tree():
		_check(result, "live composed runtime required", false); return result
	var routes: Variant = world.get("resident_routes")
	if routes is not Dictionary:
		_check(result, "production runtime route dictionary exists", false); return result
	var region := world.get("bar_region") as Node3D
	var registry := region.get("resident_places") as Node3D if region != null else null
	_check(result, "production world started successfully", not bool(world.get("startup_failed")))
	for identity: String in EXPECTED:
		var expected: Dictionary = EXPECTED[identity]
		var route := routes.get(identity) as Node3D
		if not _check(result, "registered route present: " + identity, is_instance_valid(route)):
			continue
		_check(result, "production loop-aware owner retained: " + identity,
			route.get_script().resource_path == "res://scripts/characters/loop_resident_route.gd")
		_check(result, "route owns exact imported identity/source: " + identity,
			str(route.get("resident")) == identity and str(route.get("source_path")) == str(expected.source))
		var actor := route.get("actor") as AnimatedResident
		if not _check(result, "registered owner has one loaded body: " + identity,
			is_instance_valid(actor) and actor.get_parent() == route and actor._model != null):
			continue
		_check(result, "actor retains identity and original unit: " + identity,
			actor.resident_id == identity and actor.unit == str(expected.unit))
		var count := 0
		for body: Node in world.get_tree().get_nodes_in_group("animated_residents"):
			if world.is_ancestor_of(body) and str(body.get("resident_id")) == identity: count += 1
		_check(result, "one composed actor for identity: " + identity, count == 1)
		_check(result, "loaded walk and seated clips available: " + identity,
			actor._animation_player != null and actor._animation_player.has_animation("walk")
			and actor._animation_player.has_animation("clip_06"))
		var places: Dictionary = route.get("places")
		var adapter: Variant = route.get("_bar_route")
		_check(result, "existing bar graph and visit owner attached: " + identity,
			places.has("harukiya_bar") and adapter != null and adapter.get("visit") != null)
		var preferred: Dictionary = registry.call("preferred", identity) if registry != null else {}
		_check(result, "existing balcony assignment retained: " + identity,
			str(preferred.get("seat_id", "")) == str(expected.seat))
		result.actors[identity] = {"route_path": str(route.get_path()), "source": route.get("source_path"),
			"actor_path": str(actor.get_path()), "model": actor.model_path, "unit": actor.unit,
			"actual_feet": actor.global_position, "outside": route.get("outside"),
			"destination": route.get("destination"), "force_destination": route.get("force_destination")}
	# The declared guest identity remains one body; alternate wardrobe assets
	# do not authorize extra simultaneous guest route owners.
	_check(result, "no extra alternating guest route identities",
		not routes.has("transient_guests_a") and not routes.has("transient_guests_b"))
	return result

static func _check(result: Dictionary, label: String, ok: bool) -> bool:
	result.checks.append({"label": label, "ok": ok})
	if not ok: result.failures.append(label)
	return ok
