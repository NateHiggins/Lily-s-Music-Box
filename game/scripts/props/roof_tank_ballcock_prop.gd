class_name RoofTankBallcockProp
extends FunctionalProp
## The ball cock, float and overflow of the Orison's roof house-tank.
##
## SR7-C. The tank itself is real production geometry and predates this prop:
## `art/data/gen_layout.py` bakes a 2.80 x 2.20 x 2.30 timber tank on four
## cast-iron legs at building (-9.45, 4.95). What it never had was a mechanism.
## Nothing in `game/` referenced it, and the generator's own note records that
## an earlier `watertank` marker was deleted because it "owned nothing".
##
## The generator also already says, in prose, that the roof water butt stands
## "off the tank overflow" -- an overflow that did not exist as geometry. This
## apparatus makes that sentence true.
##
## THE TRUTH THIS TEACHES. A float does not know the water level. It makes a
## FORCE, and that force has to beat what the seat and the supply between them
## demand:
##
##     closing force  =  buoyancy  x  leverage
##
## A waterlogged float still rises. The arm still comes up. The tell-tale still
## reads full. It simply cannot close anything, and the tank pays the
## difference out through the overflow. Nothing about the position of the float
## reveals this; only the witness, watched over time, tells apparent closure
## from a valve that actually holds. That is why the transferable verb is
## `timing`.
##
## HISTORICAL BASIS.
##   * T. Hill and J. Houghton, GB 190,216,359 (1902): "The valve C seats under
##     the pressure of the water &c., and is connected to the float lever F by
##     the spindle B" and "The lever F is provided with a weight E, which is
##     adjustable to suit different pressures of water &c." The seating is
##     screw-threaded so it can be renewed when worn. The adjustable weight is
##     the period's own admission that closing force must be matched to supply
##     pressure -- it is the leverage half of the equation, documented.
##   * F. Biedenmeister, US 951,172 (filed 1909, granted 1910), "Ball-Cock": a
##     BALANCED cock, "one in which the water pressure is exerted oppositely on
##     both ends of the spindle", so that it "can be opened quickly and closed
##     tightly by a small ball or float". Balancing exists precisely because an
##     unbalanced cock demands more float than a small one can give.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: the float chamber standing on the
## tank's south face, its slotted guard, the tell-tale index and the routing of
## the overflow over the existing roof water butt are this building's
## arrangement, not a documented one. External float chambers on tanks and
## gauge columns on boilers are ordinary period practice -- the Orison's own
## basement boiler already has one -- but this particular column is authored,
## and it exists so the float, rod, lever, weight, seat, inlet and overflow are
## all legible from the roof deck instead of hidden inside a timber box.
##
## AUTHORING RULE. Local z = 0 is the mounting plane on the tank's south face
## and the apparatus is built OUTWARD along +z, toward the roof deck. The prop
## carries no rotation: `GameBoot.b2g` maps building -y to Godot +z, and the
## open roof lies at -y from the tank, so an unrotated prop already faces it.
##
## OWNERSHIP. This prop owns its own apparatus and nothing else. There is no
## water system in the Orison to join -- `BoilerProp` owns a steam plant's
## feedwater and is deliberately untouched -- so this holds its own local
## condition and publishes none of it. It closes no job, advances no case,
## creates no Dream fact and adds no save owner. Only
## `apply_maintenance_result` may mark the apparatus serviced.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## What the seat and today's riser pressure together demand of the lever.
const SEAT_DEMAND := 0.62
## A sound float lifts its whole displacement; a waterlogged one carries most
## of its own volume as water and has this fraction left to lift with.
const DROWNED_BUOYANCY := 0.24
## Where the lever weight has to reach for the arm to close against the riser.
const WEIGHT_HOME := 0.64
## Float travel in the guard, empty to full, in local metres.
const RIDE_LOW := 0.55
const RIDE_HIGH := 1.90

var _service_panel: MaintenanceActivityPanel

var _float: MeshInstance3D
var _rod: MeshInstance3D
var _lever: MeshInstance3D
var _weight: MeshInstance3D
var _cock: MeshInstance3D
var _seat: MeshInstance3D
var _riser: MeshInstance3D
var _stop: MeshInstance3D
var _overflow: MeshInstance3D
var _witness: MeshInstance3D
var _stream: MeshInstance3D
var _telltale: MeshInstance3D
var _stream_mat: StandardMaterial3D
var _pour: MeshInstance3D
var _run: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _spokes: Array[MeshInstance3D] = []
var _balk_left := 0.0
var _pour_left := 0.0
var _t := 0.0

## The apparatus's own facts.
##
## `float_waterlogged` true is the fault. Note what it is NOT: nothing is
## broken, nothing is seized, and the float still rides at the full mark. The
## tank simply has no way to shut its own inlet.
var float_waterlogged := true
var riser_open := true
var weight_set := 0.18
var tell_tale := 0.0
var float_lift := 0.0
var ballcock_serviced := false


# --- the physical model ------------------------------------------------------

## Buoyant lift available at the float, 0..1.
func buoyancy() -> float:
	return DROWNED_BUOYANCY if float_waterlogged else 1.0


## Mechanical advantage the lever weight currently gives the arm.
func leverage() -> float:
	return 0.30 + 0.62 * clampf(weight_set, 0.0, 1.0)


## Force the arm can bring onto the seat. This is the whole thesis in one line:
## the float contributes buoyancy, the lever contributes leverage, and neither
## alone is a closed valve.
func closing_force() -> float:
	return buoyancy() * leverage()


## Whether the cock actually seats. A shut riser is not a holding valve -- it
## is a shut riser -- so this asks only about the valve.
func valve_holds() -> bool:
	return closing_force() >= SEAT_DEMAND


## What the witness shows. The only honest report the apparatus makes.
func overflow_running() -> bool:
	return riser_open and not valve_holds()


## Where the float is riding, 0 empty to 1 full.
##
## This is a CONSTANT on purpose, and it is the sharpest thing in the file. A
## waterlogged float rides at the full mark exactly like a sound one -- it is
## buoyant enough to float, just not buoyant enough to close a valve. Nothing
## about the float's position distinguishes the fault, which is why reading the
## tell-tale can only ever confirm the contradiction and never resolve it.
func float_ride() -> float:
	return 0.86


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var iron := Color(0.27, 0.25, 0.23)
	var brass := Color(0.46, 0.37, 0.19)
	var copper := Color(0.44, 0.27, 0.15)

	# The bracket that carries the whole assembly off the tank's south face.
	make_box(Vector3(0.34, 0.26, 0.05), Vector3(0.0, 0.05, 0.026), iron)

	# THE FLOAT CHAMBER: a slotted cast-iron guard, balance-piped to the tank
	# top and bottom so its level is the tank's level. Built as a back and two
	# rails rather than a closed column, because a float nobody can see teaches
	# nothing.
	var col_h := RIDE_HIGH - RIDE_LOW + 0.50
	var col_y := (RIDE_LOW + RIDE_HIGH) * 0.5
	var column := make_box(Vector3(0.20, col_h, 0.035),
			Vector3(-0.14, col_y, 0.055), iron)
	column.name = "FloatColumn"
	for rail_x in [-0.235, -0.045]:
		make_box(Vector3(0.028, col_h, 0.11),
				Vector3(rail_x, col_y, 0.115), iron)
	# Balance pipes into the tank, top and bottom. They are why the column
	# knows anything at all.
	for pipe_y in [RIDE_LOW - 0.20, RIDE_HIGH + 0.20]:
		var balance := make_cyl(0.026, 0.026, 0.16,
				Vector3(-0.14, pipe_y, 0.02), brass, 0.42, 0.55)
		balance.rotation_degrees.x = 90.0

	# THE FLOAT: a soldered copper ball riding the chamber.
	_float = make_cyl(0.085, 0.085, 0.150, Vector3(-0.14, 0.0, 0.095),
			copper, 0.34, 0.68)
	_float.name = "Float"
	_float.rotation_degrees.x = 90.0
	# THE ROD: the linkage. Buoyancy leaves the float this way and no other.
	_rod = make_box(Vector3(0.022, 1.0, 0.022), Vector3(-0.14, 0.0, 0.095),
			Color(0.50, 0.46, 0.30))
	_rod.name = "FloatRod"

	# THE LEVER and its adjustable weight -- the leverage half of the thesis,
	# and the one part of this assembly the 1902 patent draws by name.
	_lever = make_box(Vector3(0.52, 0.030, 0.030),
			Vector3(0.12, 0.20, 0.115), Color(0.62, 0.56, 0.36))
	_lever.name = "LeverArm"
	_weight = make_box(Vector3(0.078, 0.078, 0.078),
			Vector3(0.0, 0.20, 0.115), Color(0.20, 0.19, 0.18))
	_weight.name = "LeverWeight"
	var wm := _weight.material_override as StandardMaterial3D
	if wm != null:
		wm.metallic = 0.55
		wm.roughness = 0.52

	# THE COCK, its renewable seating, and the inlet that feeds them.
	_cock = make_box(Vector3(0.15, 0.17, 0.14), Vector3(-0.14, 0.09, 0.135),
			Color(0.42, 0.33, 0.17))
	_cock.name = "CockBody"
	var cm := _cock.material_override as StandardMaterial3D
	if cm != null:
		cm.metallic = 0.62
		cm.roughness = 0.44
	_seat = make_cyl(0.048, 0.048, 0.030, Vector3(-0.14, -0.01, 0.135),
			Color(0.58, 0.52, 0.30), 0.30, 0.70)
	_seat.name = "ValveSeat"
	_riser = make_cyl(0.038, 0.038, 1.16, Vector3(-0.14, -0.60, 0.135),
			Color(0.46, 0.38, 0.25), 0.52, 0.48)
	_riser.name = "InletRiser"
	_stop = make_cyl(0.088, 0.088, 0.026, Vector3(-0.14, -0.30, 0.135),
			brass, 0.38, 0.62)
	_stop.name = "RiserStop"
	_stop.rotation_degrees.x = 90.0
	# The stop's spokes, so a turned handwheel reads as turned.
	for spoke in 3:
		var s := make_box(Vector3(0.155, 0.014, 0.014),
				Vector3(-0.14, -0.30, 0.135), brass)
		s.rotation.z = PI * float(spoke) / 3.0
		_spokes.append(s)

	# THE OVERFLOW: out of the chamber near the top, down the west side, and
	# discharging over the roof water butt that production already stands there
	# to catch it.
	_overflow = make_cyl(0.042, 0.042, 1.75, Vector3(-0.34, 1.28, 0.09),
			Color(0.44, 0.39, 0.32), 0.55, 0.42)
	_overflow.name = "OverflowPipe"
	var elbow := make_cyl(0.042, 0.042, 0.20, Vector3(-0.38, 0.40, 0.09),
			Color(0.44, 0.39, 0.32), 0.55, 0.42)
	elbow.rotation_degrees.z = 90.0
	_witness = make_box(Vector3(0.12, 0.055, 0.12),
			Vector3(-0.42, 0.38, 0.09), brass)
	_witness.name = "OverflowWitness"

	# THE RUNNING OVERFLOW ITSELF. This is the fault made visible: while the
	# cock cannot hold, the tank pays the difference out of here, in daylight,
	# where anyone on the roof can see it.
	# From the witness lip at local y 0.38 down to the water butt's lid at
	# local y -0.25: a 0.60 m fall that ends on something, which is what makes
	# it read as water going somewhere rather than a bar hanging in the air.
	_stream = make_box(Vector3(0.052, 0.60, 0.052),
			Vector3(-0.42, 0.06, 0.09), Color(0.74, 0.82, 0.84))
	_stream.name = "OverflowStream"
	_stream_mat = _stream.material_override as StandardMaterial3D
	if _stream_mat != null:
		_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stream_mat.albedo_color = Color(0.74, 0.82, 0.84, 0.72)
		_stream_mat.roughness = 0.04
		_stream_mat.metallic = 0.0

	# What pours out of the float's split seam when it is held clear.
	_pour = make_box(Vector3(0.020, 0.30, 0.020),
			Vector3(-0.14, 0.0, 0.095), Color(0.62, 0.72, 0.74))
	var pm := _pour.material_override as StandardMaterial3D
	if pm != null:
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_color = Color(0.62, 0.72, 0.74, 0.5)
		pm.roughness = 0.06
	_pour.visible = false

	# The full mark cut into the guard, and the tell-tale that is brought
	# across to read the float against it.
	make_box(Vector3(0.055, 0.012, 0.012),
			Vector3(-0.012, RIDE_LOW + (RIDE_HIGH - RIDE_LOW) * 0.86, 0.128),
			Color(0.62, 0.55, 0.32))
	_telltale = make_box(Vector3(0.075, 0.020, 0.026),
			Vector3(0.02, RIDE_LOW, 0.132), brass)
	_telltale.name = "TellTale"

	_run = make_emitter("sink_water", -19.0, true)
	_knock = make_emitter("knock", -14.0)
	_build_cock_reach()
	_refresh_mechanism()


## The service point, over the cock and its stop, at a standing hand's height
## on the roof deck. Built in the visual pass so the base class finds an
## authored area and does not wrap the whole assembly in a coarser one.
func _build_cock_reach() -> void:
	var reach := ControlArea.new()
	reach.name = "BallcockReach"
	reach.configure("ballcock")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.80, 0.80, 0.36)
	shape_node.shape = shape
	shape_node.position = Vector3(0.02, -0.02, 0.14)
	reach.add_child(shape_node)
	add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	if control_id != "ballcock":
		return ""
	if overflow_running():
		return "[E]  The tank is overflowing"
	return "[E]  Check the tank ball cock"


func interact_control(control_id: String, player: Node) -> bool:
	if control_id != "ballcock":
		return false
	return _begin_ballcock_service(player)


func interact(player: Node) -> void:
	_begin_ballcock_service(player)


func _begin_ballcock_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "roof_tank_ballcock_service"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"float_waterlogged": float_waterlogged, "riser_open": riser_open,
			"weight_set": weight_set, "tell_tale": tell_tale,
			"float_lift": float_lift, "ballcock_serviced": ballcock_serviced}


## Reversible. Working the visible apparatus moves the visible apparatus and
## publishes nothing: `ballcock_serviced` is deliberately untouched here and
## moves only in `apply_maintenance_result`.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"read_the_float":
			tell_tale = worked
		"shut_the_riser":
			riser_open = worked >= 0.5
		"lift_the_float":
			if riser_open:
				# The cock is still feeding. Lifting the float against a live
				# inlet only slams it, and tells you nothing about its weight.
				_balk(1.0)
			else:
				float_lift = worked
				if worked >= 0.45:
					# Held clear, it empties itself through the split seam --
					# which is the diagnosis, and is why it could never close.
					float_waterlogged = false
					_pour_left = maxf(_pour_left, 0.9)
		"set_the_weight":
			if float_waterlogged:
				# THE BODGE. Buying closing force with leverage to cover a
				# float that is full of water is how a tank ends up overflowing
				# for a month with a cock that everyone has "adjusted".
				_balk(1.4)
			else:
				weight_set = worked
		"prove_the_hold":
			if worked < 0.5:
				# The riser is still shut. Nothing can run, so nothing can be
				# proved: a dry witness under a shut stop is not a holding cock.
				riser_open = false
				_balk(0.9)
			else:
				riser_open = true
				if not valve_holds():
					# The honest failure. It reads shut and it is still paying
					# out through the overflow.
					_balk(1.2)
	_refresh_mechanism()


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	float_waterlogged = bool(snapshot.get("float_waterlogged", float_waterlogged))
	riser_open = bool(snapshot.get("riser_open", riser_open))
	weight_set = float(snapshot.get("weight_set", weight_set))
	tell_tale = float(snapshot.get("tell_tale", tell_tale))
	float_lift = float(snapshot.get("float_lift", float_lift))
	ballcock_serviced = bool(snapshot.get("ballcock_serviced", ballcock_serviced))
	_balk_left = 0.0
	_pour_left = 0.0
	_refresh_mechanism()


## The only guarded publication. Nothing above this line services the cock.
func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if patch.has("float_waterlogged"):
		float_waterlogged = bool(patch["float_waterlogged"])
	if patch.has("weight_set"):
		weight_set = clampf(float(patch["weight_set"]), 0.0, 1.0)
	if patch.has("riser_open"):
		riser_open = bool(patch["riser_open"])
	if patch.has("ballcock_serviced"):
		# An apparatus is not serviced because a data file says so. It is
		# serviced when the valve can actually hold, and the mechanism is the
		# last word on that.
		ballcock_serviced = bool(patch["ballcock_serviced"]) and valve_holds()
	tell_tale = 0.0
	float_lift = 0.0
	_balk_left = 0.0
	_pour_left = 0.0
	_refresh_mechanism()
	maintenance_completed.emit(result.duplicate(true))


# --- the readable refusal ----------------------------------------------------

## A balk is a knock in the riser and a visible shudder in the arm that clears
## itself. `design/PROP_ACTIVITIES.md` forbids a silent false; this is the
## honest refusal it asks for.
func _balk(seconds: float) -> void:
	var already := _balk_left > 0.0
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _balk_left > 0.0 or _pour_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_pour_left = maxf(0.0, _pour_left - delta)
		_refresh_mechanism()


func _refresh_mechanism() -> void:
	if _float == null:
		return
	# The float rides where the water is. It rides there whether or not it is
	# sound, which is the entire deceit the round exists to expose.
	var ride := RIDE_LOW + (RIDE_HIGH - RIDE_LOW) * float_ride()
	ride += 0.16 * clampf(float_lift, 0.0, 1.0)
	_float.position.y = ride
	# A waterlogged float sits lower in its own water line and reads duller;
	# a drained one rides proud and takes the light again.
	var drowned := 1.0 if float_waterlogged else 0.0
	_float.position.z = 0.095 - 0.004 * drowned
	var fm := _float.material_override as StandardMaterial3D
	if fm != null:
		fm.albedo_color = Color(0.30, 0.20, 0.12) if float_waterlogged \
				else Color(0.52, 0.32, 0.17)
		fm.roughness = 0.62 if float_waterlogged else 0.30

	# The rod is the linkage, and it is exactly as long as the gap between the
	# float and the lever it works.
	if _rod != null:
		var lever_y := 0.20
		var span := maxf(0.05, ride - 0.085 - lever_y)
		_rod.scale.y = span
		_rod.position.y = lever_y + span * 0.5

	# The lever weight runs out along the arm as it is set.
	if _weight != null:
		_weight.position.x = -0.10 + 0.46 * clampf(weight_set, 0.0, 1.0)
	# An arm with leverage sits up under the load; one without it hangs.
	if _lever != null:
		_lever.rotation.z = lerpf(-0.11, 0.02, clampf(closing_force()
				/ SEAT_DEMAND, 0.0, 1.0))

	# The riser stop, turned shut and turned open.
	if _stop != null:
		_stop.rotation.y = 0.0 if riser_open else 1.15
	for i in _spokes.size():
		_spokes[i].rotation.z = PI * float(i) / 3.0 \
				+ (0.0 if riser_open else 1.15)

	# THE WITNESS. This is the only place the apparatus reports on itself, and
	# it reports by running or by being dry.
	var running := overflow_running()
	if _stream != null:
		_stream.visible = running
		if running and _stream_mat != null:
			# A live overflow is not a static bar: it shivers.
			_stream.scale.y = 1.0 + 0.05 * sin(_t * 9.0)
	if _run != null:
		if running and not _run.playing:
			_run.play()
		elif not running and _run.playing:
			_run.stop()

	# The tell-tale is brought across to read the float.
	if _telltale != null:
		_telltale.position.y = RIDE_LOW + (RIDE_HIGH - RIDE_LOW) \
				* clampf(tell_tale, 0.0, 1.0)
		_telltale.position.x = 0.02 - 0.055 * clampf(tell_tale, 0.0, 1.0)

	# What pours out of the float while it is held clear.
	if _pour != null:
		_pour.visible = _pour_left > 0.0
		_pour.position.y = ride - 0.24

	if _balk_left > 0.0:
		var shake := sin(_t * 44.0) * 0.008 * clampf(_balk_left, 0.0, 1.0)
		if _lever != null:
			_lever.rotation.z += shake * 1.4
		_float.position.y += shake


func service_wire_card() -> Dictionary:
	return {
		"title": "HOUSE-TANK BALL COCK",
		"body": "The float makes a force, not a reading. Buoyancy times "
				+ "leverage has to beat the seat, or the overflow pays the "
				+ "difference.",
	}
