extends "res://scripts/props/possessed_domestic_prop.gd"
## A possessed household object in V2 that V2's own furniture had no
## counterpart for. V1's prop keeps the owner, the cases, the inspection copy
## and its tap; this replaces the procedural stand-in with the Blender-authored
## period object and performs V1's tell on that object's real moving part.
##
## The domestic witnesses reach it through an ordinary tell row whose motion is
## `seize`: the tell calls `possess_as` (whose case, how bad) and then
## `set_possessed`. V1's own `stage_haunt` still works and ends in the same two
## overrides.
const Native := preload("res://scripts/building/orison_v2_native_possessed_objects.gd")
## The part V1's inspection tap nudges, by V1 kind.
const INSPECT_PART := {"mirror": "Mirror", "intercom": "Receiver", "telephone": "Receiver", "door_chain": "Chain",
	"spirit_level": "Bubble", "typewriter": "Carriage"}
## Parts that are not there until the tell.
const HIDDEN_AT_REST := ["ExtraHook", "ExtraKey"]
## The thermostat's pointer rests at V1's 72; the cold stop is 51 degrees left.
const COLD_STOP := 0.890
## The spring balance's whole chart, zero to its foot.
const FULL_SCALE := 0.150
## The telephone cord's slack below the hung receiver.
const CORD_DROP := 0.058

var native: RefCounted
var stock := ""
var unit := ""
var possessed := false
var _parts: Dictionary = {}
var _rest: Dictionary = {}
var _case := ""
var _tier := 2
var _jewel: MeshInstance3D
var _jewel_dark: Material
var _jewel_lit: StandardMaterial3D


func _build_visual() -> void:
	_rig = Node3D.new()
	_rig.name = "PossessionRig"
	add_child(_rig)
	if native == null:
		native = Native.new()
	var mounted: Dictionary = native.mount_on(self, stock) if native.prepare() else {}
	if mounted.is_empty():
		push_error("V2 possessed object stock refused: %s (%s)" % [prop_id, stock])
	else:
		_parts = mounted.parts
	for component: String in _parts:
		var part: Node3D = _parts[component]
		_rest[component] = part.transform
		if component in HIDDEN_AT_REST:
			part.visible = false
	_moving = _parts.get(str(INSPECT_PART.get(kind, "")))
	if _parts.has("Indicator"):
		_jewel = (_parts["Indicator"] as Node3D).get_child(0) as MeshInstance3D
		_jewel_dark = _jewel.material_override
		_jewel_lit = (_jewel_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
		_jewel_lit.albedo_color = Color(0.95, 0.16, 0.10)
		_jewel_lit.emission_enabled = true
		_jewel_lit.emission = Color(1.0, 0.12, 0.06)
		_jewel_lit.emission_energy_multiplier = 2.4
	_build_collision()
	_sound = make_emitter("tick", -34.0)
	_sound.max_distance = 4.5
	var copy: Dictionary = INSPECTION_COPY.get(kind, {})
	_inspect_sound = make_emitter(str(copy.get("sound", "tick")), -20.0)
	_inspect_sound.max_distance = 3.2


func _build_collision() -> void:
	var extent: AABB = native.bounds(stock) if native != null else AABB()
	if extent.size.length_squared() < 0.000001:
		extent = AABB(Vector3(-0.1, -0.1, 0.0), Vector3(0.2, 0.2, 0.05))
	var body := StaticBody3D.new()
	body.name = "PossessedBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent.size.max(Vector3(0.02, 0.02, 0.02))
	shape.shape = box
	shape.position = extent.get_center()
	body.add_child(shape)
	add_child(body)


## Whose intrusion this is and how bad, set by the tell before it seizes.
func possess_as(case_id: String, tier: int) -> void:
	_case = case_id
	_tier = tier


## The domestic witnesses' hand: on performs the tell, off puts it all back.
func set_possessed(on: bool) -> void:
	if possessed == on:
		return
	if on:
		_cancel_inspection_motion()
		_busy = true
		state = PState.INFECTED
		_apply_tell(_case, _tier)
	else:
		_restore()


func _apply_tell(case_id: String, tier: int) -> void:
	possessed = true
	var steps := float(clampi(tier, 1, 4))
	match tell:
		"late_reflection":
			# The glass hangs off true on its nail.
			_turn("Mirror", 0.045 * steps)
		"unlisted_call":
			_turn("Receiver", -0.16 * steps)
		"one_more_hook":
			_show("ExtraHook", true)
		"wrong_voltage":
			_light(true)
		"open_line":
			# The receiver stands off its hook and the hook has sprung up.
			var lift := 0.025 * steps
			_shift("Receiver", Vector3(0.0, lift, 0.0))
			_turn("Hook", -0.15)
			if _parts.has("CordDrop"):
				(_parts["CordDrop"] as Node3D).scale = Vector3(1.0, (CORD_DROP + lift) / CORD_DROP, 1.0)
		"approval_required":
			# V1's readout said DENIED; the lever has gone to the cold stop.
			_turn("Pointer", COLD_STOP)
		"shared_threshold":
			_turn("Chain", (-0.20 if case_id == "cam_tilted_room" else 0.20) * steps)
		"departure_weight":
			# V1's readout said infinity; the pointer is at the foot of the chart
			# with nothing on the hook.
			_shift("Pointer", Vector3(0.0, -FULL_SCALE, 0.0))
		"false_level":
			_shift("Bubble", Vector3(0.0045 * steps, 0.0, 0.0))
		"finishes_sentence":
			_shift("Carriage", Vector3(-0.12, 0.0, 0.0))
		"extra_key":
			_show("ExtraKey", true)


func _restore() -> void:
	_busy = false
	possessed = false
	state = PState.OPERATING
	for component: String in _parts:
		var part: Node3D = _parts[component]
		part.transform = _rest[component]
		part.visible = not (component in HIDDEN_AT_REST)
	_light(false)


func _turn(component: String, angle: float) -> void:
	var part := _parts.get(component) as Node3D
	if part != null:
		part.transform = (_rest[component] as Transform3D) * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)


func _shift(component: String, by: Vector3) -> void:
	var part := _parts.get(component) as Node3D
	if part != null:
		part.transform = (_rest[component] as Transform3D).translated_local(by)


func _show(component: String, on: bool) -> void:
	var part := _parts.get(component) as Node3D
	if part != null:
		part.visible = on


func _light(on: bool) -> void:
	if _jewel != null:
		_jewel.material_override = _jewel_lit if on else _jewel_dark


## The part the tell acts on, for the tests and the capture.
func tell_part() -> Node3D:
	for component: String in ["Mirror", "Receiver", "ExtraHook", "Indicator", "Pointer", "Chain", "Bubble", "Carriage",
			"ExtraKey"]:
		if _parts.has(component):
			return _parts[component]
	return null


## Everything a tell may change, to compare before and after.
func tell_signature() -> Array:
	var result: Array = [_jewel != null and _jewel.material_override == _jewel_lit]
	for component: String in _parts:
		var part: Node3D = _parts[component]
		result.append(part.transform)
		result.append(part.visible)
	return result
