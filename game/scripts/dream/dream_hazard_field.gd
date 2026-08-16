class_name DreamHazardField
extends RefCounted
## N7: the dream's hazards as one steppable owner.
##
## Shaped deliberately like DreamPursuer — `setup(...)` then
## `advance_fixed(delta)` — so a test can drive it at a fixed rate and
## get the same answer every time, which is how N3 and N6 got numbers
## anybody could re-run.
##
## It owns three things the brief asks for and nothing else: which
## hazards this case actually runs, the per-frame evaluation, and the
## logs that make Gate C measurable rather than asserted. It does not own
## geometry (the builder does), outcomes (DreamMazeRoot's one funnel
## does), or presentation (the caption layer will).

signal tell_started(hazard_id: String, bearing_deg: float, caption: String)
signal hazard_contact(hazard_id: String, outcome: String)

var hazards: Array[DreamHazard] = []
var player: Node3D
var elapsed_s := 0.0

## Everything a player could have perceived, in order. The identification
## harness is only ever allowed to read THIS -- never the plan, never a
## socket, never a module id -- which is what makes the 80% bar a real
## blind test instead of a lookup.
var perception_log: Array[Dictionary] = []
## Every contact, with its realised warning. One row per impact.
var impact_log: Array[Dictionary] = []


## `profile_hazards` is the case's own block: an `allow` list and a
## `tuning` dictionary. A socket with no allow entry is placed in the
## world by the builder and simply never armed here — which is how the
## slot-3 rhythmic counterweight sits in Mina's D03 without being one of
## Mina's dangers.
func setup(plan: Dictionary, profile_hazards: Dictionary,
		target: Node3D) -> void:
	player = target
	hazards.clear()
	perception_log.clear()
	impact_log.clear()
	elapsed_s = 0.0
	var allow: Array = profile_hazards.get("allow", [])
	var tuning: Dictionary = profile_hazards.get("tuning", {})
	for record in plan.get("hazards", []):
		var hid := str(record.get("id", ""))
		if not allow.has(hid):
			continue
		var hazard := DreamHazard.new()
		hazard.configure(record, tuning.get(hid, {}))
		hazards.append(hazard)


## One deterministic step. Returns "" or the outcome of the first hazard
## to contact this frame; DreamMazeRoot decides what to do with it, and
## its latch means a simultaneous capture cannot double-commit.
func advance_fixed(delta: float) -> String:
	if player == null:
		return DreamHazard.NONE
	elapsed_s += delta
	var lamp_on: bool = player.has_method("lamp_is_enabled") \
			and bool(player.call("lamp_is_enabled"))
	var speed := 0.0
	if player.has_method("planar_speed"):
		speed = float(player.call("planar_speed"))
	var fired := DreamHazard.NONE
	for hazard in hazards:
		var was_silent: bool = hazard.tell_started_s < 0.0
		var result := hazard.evaluate(player.global_position, lamp_on,
				speed, elapsed_s)
		if was_silent and hazard.tell_started_s >= 0.0:
			var bearing := _bearing_to(hazard.position)
			perception_log.append({
				"at_s": hazard.tell_started_s,
				"hazard_id": hazard.id,
				"kind": hazard.kind,
				"bearing_deg": bearing,
				"sector": bearing_sector(bearing),
				"caption": hazard.caption,
				"lamp_on": lamp_on,
			})
			tell_started.emit(hazard.id, bearing, hazard.caption)
		if hazard.contacted and hazard.contact_s == elapsed_s:
			impact_log.append(hazard.impact_record(lamp_on))
			hazard_contact.emit(hazard.id, result)
			if result != DreamHazard.NONE and fired == DreamHazard.NONE:
				fired = result
	return fired


## Compass bearing from the player to a point, in degrees, 0 = the
## player's forward. Presentation gets a SECTOR rather than a number,
## because a caption that reads "4.2 m north-east" tells the player
## something their ears could not have.
func _bearing_to(point: Vector3) -> float:
	if player == null:
		return 0.0
	var to := Vector3(point.x - player.global_position.x, 0.0,
			point.z - player.global_position.z)
	if to.length() < 0.0001:
		return 0.0
	var forward := -player.global_transform.basis.z
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var angle := rad_to_deg(forward.signed_angle_to(to.normalized(),
			Vector3.UP))
	return fmod(angle + 360.0, 360.0)


## Eight 45-degree sectors. Accessibility captions name one of these and
## never a distance, so directional-caption mode conveys what the ear
## conveys and nothing the eye could not have earned.
static func bearing_sector(deg: float) -> String:
	const NAMES := ["AHEAD", "AHEAD RIGHT", "RIGHT", "BEHIND RIGHT",
			"BEHIND", "BEHIND LEFT", "LEFT", "AHEAD LEFT"]
	var idx := int(floor(fmod(deg + 22.5 + 360.0, 360.0) / 45.0)) % 8
	return NAMES[idx]


## Did every impact get at least the warning its socket authored? This is
## Gate C's fairness bar as a single answerable question.
func unfair_impacts() -> Array[Dictionary]:
	var bad: Array[Dictionary] = []
	for row in impact_log:
		var realised: float = float(row.get("realised_warning_s", -1.0))
		if realised < float(row.get("minimum_warning_s", 0.0)):
			bad.append(row)
	return bad
