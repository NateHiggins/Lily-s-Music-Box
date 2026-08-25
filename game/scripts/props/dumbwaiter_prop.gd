class_name DumbwaiterProp
extends FunctionalProp
## The service dumbwaiter on the lobby's back wall, and its holding brake.
##
## SR7-A. The mechanical basis is the 1910 New York dumbwaiter in
## `design/ORISON_SERVICE_ROUND_BRIEF.md`: a counterweight, a lift sheave and
## an automatic holding brake (US 950,828).
##
## THE TRUTH THIS TEACHES. The counterweight carries nearly all of the car, so
## the band brake only ever holds the DIFFERENCE between them. That is why a
## brake this small is enough, and why letting the rope go before the band has
## bitten is the entire danger: the hand is holding the same few pounds the
## brake is about to. The activity makes the player feel that order --
## strain first, pawl second, brake back before the strain is spent.
##
## OWNERSHIP. This prop owns its own visible mechanism and nothing else. It
## closes no job, advances no case, publishes no plant state and creates no
## Dream fact. Committed appearance arrives through `apply_maintenance_result`,
## which is the same seam the radiator, annunciator and boiler already use, and
## it reports completion by signal for whoever is listening rather than
## reaching for a work order itself.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## Where the band sits when it is properly home on the drum. The authored
## activity's final two steps target this, so the prop and the book agree on
## what "seated" means without either one importing the other.
const BAND_HOME := 0.88

var _service_panel: MaintenanceActivityPanel
var _rope: MeshInstance3D
var _sheave: MeshInstance3D
var _counterweight: MeshInstance3D
var _band: MeshInstance3D
var _pawl: MeshInstance3D
var _car: MeshInstance3D
var _rattle: AudioStreamPlayer3D
var _slip_left := 0.0
var _t := 0.0

## The mechanism's own facts. `band_seated` false is the fault the round
## exists to correct: the band is off its drum and the pawl is doing work it
## was never meant to do alone.
var band_seated := false
var brake_bite := 0.34
var pawl_lift := 0.0
var rope_strain := 0.0
var car_travel := 0.0


## AUTHORING RULE FOR THIS PROP: local z = 0 IS THE WALL FACE, and the whole
## apparatus is built OUTWARD along +z into the corridor.
##
## This is not a stylistic choice. The first two passes recessed the shaft into
## negative z, which put it inside a solid partition: the render came back with
## the corridor wallpaper showing straight through the opening, because the wall
## is drawn in front of the shaft. A back-of-house dumbwaiter in a building like
## this is a boxed-out casing standing against the wall, and building it that
## way is both truer and the only way the car is ever visible.
func _build_visual() -> void:
	const OPEN_W := 0.66
	const OPEN_H := 0.62
	const JAMB := 0.09
	const SHAFT_D := 0.26          # back of the casing (z 0) to the frame
	const FRAME_Z := SHAFT_D + 0.045
	const HEAD_Z := SHAFT_D + 0.115
	var casing := Color(0.24, 0.14, 0.09)
	var shaft := Color(0.055, 0.045, 0.040)
	var sill_y := 0.30 - OPEN_H * 0.5
	var head_y := 0.30 + OPEN_H * 0.5
	var jamb_x := OPEN_W * 0.5 + JAMB * 0.5

	# The casing box: back against the wall, two cheeks and a top, open to the
	# corridor. Dark inside, because a shaft is dark.
	var back := make_box(Vector3(OPEN_W + JAMB * 2.0, OPEN_H + JAMB * 2.0, 0.03),
			Vector3(0.0, 0.30, 0.015), shaft)
	back.name = "Shaftway"
	make_box(Vector3(0.03, OPEN_H, SHAFT_D),
			Vector3(-OPEN_W * 0.5, 0.30, SHAFT_D * 0.5), shaft)
	make_box(Vector3(0.03, OPEN_H, SHAFT_D),
			Vector3(OPEN_W * 0.5, 0.30, SHAFT_D * 0.5), shaft)
	make_box(Vector3(OPEN_W, 0.03, SHAFT_D),
			Vector3(0.0, head_y, SHAFT_D * 0.5), shaft)

	# The car, standing in the casing a little below the sill where it was left.
	_car = make_box(Vector3(0.42, 0.30, 0.20),
			Vector3(-0.09, 0.13, SHAFT_D * 0.5), Color(0.36, 0.27, 0.17))
	_car.name = "Car"
	# The counterweight, in its guides down the right of the shaft, riding high
	# because the car is low. It is the other end of the same rope.
	_counterweight = make_box(Vector3(0.11, 0.24, 0.11),
			Vector3(0.23, 0.44, SHAFT_D * 0.45), Color(0.20, 0.20, 0.22))
	_counterweight.name = "Counterweight"
	var cm := _counterweight.material_override as StandardMaterial3D
	if cm != null:
		cm.metallic = 0.70
		cm.roughness = 0.52

	# The frame around the mouth of the casing.
	make_box(Vector3(JAMB, OPEN_H + JAMB * 2.0, 0.09),
			Vector3(-jamb_x, 0.30, FRAME_Z), casing)
	make_box(Vector3(JAMB, OPEN_H + JAMB * 2.0, 0.09),
			Vector3(jamb_x, 0.30, FRAME_Z), casing)
	make_box(Vector3(OPEN_W, JAMB, 0.09),
			Vector3(0.0, head_y + JAMB * 0.5, FRAME_Z), casing)
	# The sill takes the weight of everything that ever came up, so it is the
	# one board that is thicker and stands proud of the rest.
	make_box(Vector3(OPEN_W + JAMB * 2.0, JAMB * 1.3, 0.15),
			Vector3(0.0, sill_y - JAMB * 0.65, FRAME_Z - 0.02),
			Color(0.31, 0.20, 0.12))

	# THE WORKING HEAD, above the mouth and out where a hand can reach it: the
	# lift sheave, the drum, the band around the drum, and the pawl that has
	# been carrying the load on its own since the band came off.
	make_box(Vector3(OPEN_W + JAMB * 2.0, 0.055, 0.20),
			Vector3(0.0, head_y + JAMB * 1.6, HEAD_Z - 0.05),
			Color(0.19, 0.12, 0.08))
	_sheave = make_cyl(0.105, 0.105, 0.042,
			Vector3(-0.17, head_y + 0.28, HEAD_Z), Color(0.44, 0.35, 0.18),
			0.44, 0.62)
	_sheave.name = "LiftSheave"
	_sheave.rotation_degrees.x = 90.0
	var drum := make_cyl(0.078, 0.078, 0.050,
			Vector3(0.17, head_y + 0.28, HEAD_Z), Color(0.32, 0.28, 0.23),
			0.58, 0.45)
	drum.rotation_degrees.x = 90.0
	# The band wraps the drum. It stays a band at every bite: what changes is
	# how tightly it is drawn down, never whether it exists.
	_band = make_ring(0.090, 0.016,
			Vector3(0.17, head_y + 0.28, HEAD_Z), Color(0.15, 0.11, 0.10),
			0.70, 0.15)
	_band.name = "BrakeBand"
	_band.rotation_degrees.x = 90.0
	_pawl = make_box(Vector3(0.15, 0.028, 0.028),
			Vector3(0.31, head_y + 0.21, HEAD_Z + 0.015),
			Color(0.48, 0.39, 0.21))
	_pawl.name = "HoldingPawl"
	var pm := _pawl.material_override as StandardMaterial3D
	if pm != null:
		pm.metallic = 0.58
		pm.roughness = 0.46

	# The hand rope, falling from the sheave down the left of the mouth, where a
	# hand finds it without looking.
	_rope = make_box(Vector3(0.026, 0.98, 0.026),
			Vector3(-0.17, 0.40, HEAD_Z), Color(0.50, 0.42, 0.27))
	_rope.name = "HandRope"

	# A slipping band creaks; it does not click. The prop borrows the shared
	# creak the building already uses rather than importing a new stream.
	_rattle = make_emitter("creak", -13.0)
	_build_brake_reach()
	_refresh_mechanism()


## The literal service point. The band and the rope are worked from the same
## stand, so one reach names the brake rather than pretending a player can
## choose between two handholds they cannot see apart.
##
## Built here, in the visual pass, so that `FunctionalProp._build_primary_interaction`
## finds an authored area already present and does not wrap the whole hatch in a
## second, coarser one -- the same arrangement the porter's board uses.
func _build_brake_reach() -> void:
	var brake := ControlArea.new()
	brake.name = "BrakeReach"
	brake.configure("brake")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Around the working head -- drum, band, pawl and the top of the hand rope.
	shape.size = Vector3(0.64, 0.50, 0.32)
	shape_node.shape = shape
	shape_node.position = Vector3(0.04, 0.90, 0.36)
	brake.add_child(shape_node)
	add_child(brake)


func control_prompt(control_id: String) -> String:
	if control_id != "brake":
		return ""
	return ("[E]  Prove the holding brake" if not band_seated
			else "[E]  Check the holding brake")


func interact_control(control_id: String, player: Node) -> bool:
	if control_id != "brake":
		return false
	return _begin_brake_service(player)


func interact(player: Node) -> void:
	_begin_brake_service(player)


func _begin_brake_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "dumbwaiter_brake_service"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


## --- the shared maintenance contract ---------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"band_seated": band_seated, "brake_bite": brake_bite,
			"pawl_lift": pawl_lift, "rope_strain": rope_strain,
			"car_travel": car_travel}


## Reversible. Working the visible mechanism moves the visible mechanism and
## publishes nothing: `band_seated` -- the fact anything downstream would read
## -- is deliberately untouched here and only moves in `apply_maintenance_result`.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"take_strain":
			rope_strain = worked
		"ease_pawl":
			# The pawl only comes clear if the hand is already carrying the
			# load. Easing it against a slack rope is the mistake the whole
			# apparatus is about, so the mechanism refuses to mislead.
			if rope_strain >= 0.30:
				pawl_lift = worked
			else:
				_slip(0.9)
		"prove_balance":
			if pawl_lift >= 0.30 and rope_strain >= 0.30:
				car_travel = worked
			else:
				_slip(1.0)
		"seat_band":
			brake_bite = worked
		"prove_bite":
			brake_bite = maxf(brake_bite, worked)
			# Spending the strain before the band is home is the failure this
			# teaches. It reads immediately and recovers on its own.
			if worked < BAND_HOME - 0.12:
				_slip(1.2)
	_refresh_mechanism()


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	band_seated = bool(snapshot.get("band_seated", band_seated))
	brake_bite = float(snapshot.get("brake_bite", brake_bite))
	pawl_lift = float(snapshot.get("pawl_lift", pawl_lift))
	rope_strain = float(snapshot.get("rope_strain", rope_strain))
	car_travel = float(snapshot.get("car_travel", car_travel))
	_slip_left = 0.0
	_refresh_mechanism()


## The only guarded publication. Nothing above this line changes `band_seated`.
func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if patch.has("band_seated"):
		band_seated = bool(patch["band_seated"])
	if patch.has("brake_bite"):
		brake_bite = clampf(float(patch["brake_bite"]), 0.0, 1.0)
	if patch.has("pawl_lift"):
		pawl_lift = clampf(float(patch["pawl_lift"]), 0.0, 1.0)
	if patch.has("rope_strain"):
		rope_strain = clampf(float(patch["rope_strain"]), 0.0, 1.0)
	car_travel = 0.0
	_slip_left = 0.0
	_refresh_mechanism()
	maintenance_completed.emit(result.duplicate(true))


## --- the readable failure --------------------------------------------------

## A slip is a rattle and a visible shudder that clears itself. It costs the
## player nothing but the second it takes to watch, which is what makes the
## order legible rather than punitive.
func _slip(seconds: float) -> void:
	_slip_left = maxf(_slip_left, clampf(seconds, 0.0, 3.4))
	if _rattle != null:
		_rattle.play()


func slipping() -> bool:
	return _slip_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _slip_left > 0.0:
		_slip_left = maxf(0.0, _slip_left - delta)
		_refresh_mechanism()


func _refresh_mechanism() -> void:
	if _band == null:
		return
	# Kept in one place so the visual pass and the animation cannot drift apart.
	const HEAD_Y := 0.61
	const DRUM_Y := HEAD_Y + 0.28
	const CAR_LOW := 0.13
	const WEIGHT_HIGH := 0.44
	const TRAVEL := 0.17

	# The band closes onto the drum as the bite comes on. It never leaves the
	# drum and it never scales away: it is a band at 0.0 and a band at 1.0, and
	# what changes is how tightly it is drawn down and how it takes the light.
	var bite := clampf(brake_bite, 0.0, 1.0)
	_band.scale = Vector3(1.0 - 0.11 * bite, 1.0, 1.0 - 0.11 * bite)
	_band.position.y = DRUM_Y - 0.012 * bite
	var bm := _band.material_override as StandardMaterial3D
	if bm != null:
		# Pressed brake lining goes darker and harder, not brighter.
		bm.albedo_color = Color(0.15, 0.11, 0.10).lerp(
				Color(0.085, 0.062, 0.058), bite)
		bm.roughness = lerpf(0.70, 0.50, bite)

	# The pawl swings up and out of the ratchet as it is eased clear.
	if _pawl != null:
		_pawl.rotation.z = 0.62 * pawl_lift
		_pawl.position.y = HEAD_Y + 0.21 + 0.045 * pawl_lift

	# Strain draws the rope taut: it shortens its visible fall and swings in
	# toward the sheave instead of hanging plumb.
	if _rope != null:
		_rope.scale.y = 1.0 - 0.10 * rope_strain
		_rope.position.y = 0.40 + 0.049 * rope_strain
		_rope.rotation.z = -0.085 * rope_strain

	# The car rises and the counterweight falls, on one rope, together. This is
	# the whole lesson of the apparatus, and it is shown rather than narrated.
	if _car != null:
		_car.position.y = CAR_LOW + TRAVEL * car_travel
	if _counterweight != null:
		_counterweight.position.y = WEIGHT_HIGH - TRAVEL * car_travel
	if _sheave != null:
		# `rotation_degrees.x = 90` tipped the cylinder onto its side, so the
		# wheel's own axis is now Z and that is the one the rope turns.
		_sheave.rotation.z = car_travel * 2.1

	# A slip is a shudder in the parts that are carrying: the car on its rope
	# and the band that has not yet taken it.
	if _slip_left > 0.0:
		var shake := sin(_t * 42.0) * 0.010 * clampf(_slip_left, 0.0, 1.0)
		if _car != null:
			_car.position.y += shake
		if _rope != null:
			_rope.rotation.z += shake * 1.6
		_band.position.y += shake * 0.45


func service_wire_card() -> Dictionary:
	return {
		"title": "SERVICE DUMBWAITER",
		"body": "Counterweight, lift sheave and automatic holding brake. "
				+ "The weight carries the car; the band holds the difference.",
	}
