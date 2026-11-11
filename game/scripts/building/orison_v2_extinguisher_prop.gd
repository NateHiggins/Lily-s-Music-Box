extends "res://scripts/props/soda_acid_extinguisher_prop.gd"
## The soda-acid extinguisher in V2 (v1r_extinguisher_20261109).
##
## The V1 apparatus keeps every fact, predicate, refusal, record and word. This
## script gives it Blender-authored stock (art/blender/scripts/
## build_fire_apparatus.py) and puts the hand on the real parts (RUL-013):
##
##   cap      turned off its thread, then lifted clear and stood on the rest
##   seal     the lead pellet pulled until the wire parts; a fresh one threaded
##   bottle   drawn out of the cage and stood on the shelf, and put back
##   loose    the bottle's little cap lifted: it comes off, or the bottle comes
##            up with it, which is the whole diagnosis
##   body     its weight taken on the straps
##   hooks    tipped on its foot as far as the straps let it go, and no further
##
## Each of those moves a value with a travel stop and calls V1's own function at
## the point the metal changes state, so sealed(), charged(), will_lift() and
## the tag are exactly V1's. Signing the tag stays V1's click: it is an entry in
## pencil, not a mechanism.
##
## ONE CONSTRUCTION CHANGE FROM V1. V1 set the unscrewed cap "across the
## shoulder", which with a rigid cage under it puts the cage through the copper.
## Here the cap stands on a two-pronged rest on the board with the cage, and
## whatever is in it, hanging clear between the prongs.

const Stock := preload("res://scripts/building/orison_v2_native_fire_apparatus.gd")

## V1's own rest poses for the cap (on VesselPivot), read off its refresh.
const V1_CAP_ON := Vector3(0.0, 0.632, 0.0)
const V1_CAP_OFF := Vector3(0.128, 0.694, 0.015)
const V1_CAP_OFF_ROLL := -0.42
const V1_BOTTLE_ON := Vector3(0.0, 0.664, 0.135)
const V1_BOTTLE_OFF := Vector3(0.167, 0.730, 0.150)
const V1_BOTTLE_DRAWN := Vector3(-0.192, 0.126, 0.150)
const V1_BOTTLE_TIPPED := Vector3(-0.1065, 0.6533, 0.135)
const V1_STOPPLE_Y := 0.0655
const V1_STOPPLE_PROUD := 0.026

## The cap's travel: 0 screwed home, CAP_THREAD free of its thread, 1 standing
## on the rest.
const CAP_THREAD := 0.6
const CAP_TURNS := 1.5
const CAP_THREAD_RISE := 0.008
const CAP_CLEAR_LIFT := 0.185
## How far the wire lets the cap turn before it takes the pull.
const SEAL_SLACK := 0.03
## The bottle leaves its clips this far into its travel.
const BOTTLE_UNCLIPPED := 0.08
const STOPPLE_SEIZED_LIFT := 0.078
const TIP_LIMIT := 0.20
const HEFT_LIFT := 0.012
## Metres of working a seized cap back and forth before it comes free.
const WORK_FREE := 0.20

var stock: RefCounted
var cap_travel := 0.0
var bottle_travel := 0.0
var seal_pull := 0.0
var stopple_lift := 0.0
var heft_lift := 0.0
var tip := 0.0

var _hand := ""
var _refused := false
var _tested_this_grip := false
var _worked := 0.0
var _settle: Tween
var _cap_rest := Vector3.ZERO
var _in_cage := Vector3.ZERO
var _stopple_live := false
var _settle_property := ""
var _settle_goal := 0.0


# --- build -------------------------------------------------------------------

func _build_visual() -> void:
	stock = Stock.shared()
	if stock == null:
		push_error("V2 extinguisher has no native stock: " + station_id)
		return
	_cap_rest = stock.datum("extinguisher", "cap_rest")
	_in_cage = stock.datum("extinguisher", "bottle_in_cage")
	var face := float(stock.data.extinguisher.plate_face_z)
	_hooks = Node3D.new()
	_hooks.name = "Bracket"
	add_child(_hooks)
	for part_name: String in ["Ext__Board_ON_fire_cabinet_enamel", "Ext__Iron_ON_iron_blackened",
			"Ext__ChargePlate_ON_enamel_appliance", "Ext__PlateScrews_ON_brass"]:
		_hooks.add_child(stock.draw(part_name))
	_letter("ChargeLegend", CHARGE_LEGEND, Vector3(-0.196, 0.601, face + 0.0008),
			0.0148, Color(0.90, 0.88, 0.83))
	_letter("ChargeLegend2", CHARGE_LEGEND_2, Vector3(-0.196, 0.577, face + 0.0008),
			0.0148, Color(0.84, 0.82, 0.77))
	_vessel = Node3D.new()
	_vessel.name = "VesselPivot"
	_vessel.position = stock.datum("extinguisher", "vessel_pivot")
	add_child(_vessel)
	_body = stock.draw("Ext__Vessel_ON_copper_aged", "Vessel")
	_vessel.add_child(_body)
	_vessel.add_child(stock.draw("Ext__VesselBrass_ON_brass"))
	_vessel.add_child(stock.draw("Ext__Hose_ON_rubber_aged"))
	_seal = stock.draw("Ext__Seal_ON_zinc_quiet", "LeadAndWireSeal")
	_seal.position = V1_CAP_ON
	_vessel.add_child(_seal)
	_cap = stock.draw("Ext__Cap_ON_brass", "Cap")
	_vessel.add_child(_cap)
	_cage = stock.draw("Ext__Cage_ON_fire_hardware_steel", "AcidBottleCage")
	_cap.add_child(_cage)
	_bottle = stock.draw("Ext__Bottle_ON_glass_drawn_expressive", "AcidBottle")
	add_child(_bottle)
	_acid_band = stock.draw("Ext__Acid_ON_bakelite_black", "AcidLevel")
	_bottle.add_child(_acid_band)
	_loose_cap = stock.draw("Ext__Stopple_ON_zinc_quiet", "LooseCap")
	_bottle.add_child(_loose_cap)
	_tag = stock.draw("Ext__Tag_ON_paper", "InspectionTag")
	_tag.position = stock.datum("extinguisher", "tag")
	add_child(_tag)
	_tag_label = _letter("TagLine", TAG_BLANK, Vector3(0.0, 0.002, 0.003), 0.0102,
			Color(0.13, 0.12, 0.11), _tag)
	_build_reaches()
	# The bottle and its little cap are two reaches on one small object: size
	# them to the glass and to the lead so they cannot answer for each other.
	_size_reach("bottle", Vector3(0.09, 0.10, 0.10))
	_size_reach("loose", Vector3(0.08, 0.075, 0.10))
	_knock = make_emitter("knock", -14.0)
	_click = make_emitter("pop", -19.0)
	cap_travel = 0.0 if cap_on else 1.0
	bottle_travel = 1.0 if bottle_drawn else 0.0
	_refresh_extinguisher()


# --- V1's hand work, kept in step with where the parts are ---------------------

func unscrew_cap() -> bool:
	var done := super.unscrew_cap()
	if done and _hand != "cap":
		cap_travel = 1.0
		_refresh_extinguisher()
	return done


func screw_cap() -> bool:
	var done := super.screw_cap()
	if done and _hand != "cap":
		cap_travel = 0.0
		_refresh_extinguisher()
	return done


func draw_bottle() -> bool:
	var done := super.draw_bottle()
	if done and _hand != "bottle":
		bottle_travel = 1.0
		_refresh_extinguisher()
	return done


func seat_bottle() -> bool:
	var done := super.seat_bottle()
	if done and _hand != "bottle":
		bottle_travel = 0.0
		_refresh_extinguisher()
	return done


func maintenance_snapshot() -> Dictionary:
	var snapshot := super.maintenance_snapshot()
	snapshot["cap_travel"] = cap_travel
	return snapshot


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	_end_hand()
	super.restore_maintenance_snapshot(snapshot)
	var rest := 0.0 if cap_on else 1.0
	cap_travel = clampf(float(snapshot.get("cap_travel", rest)), 0.0, 1.0)
	if cap_on != (cap_travel < CAP_THREAD):
		cap_travel = rest
	bottle_travel = 1.0 if bottle_drawn else 0.0
	seal_pull = 0.0
	stopple_lift = 0.0
	_stopple_live = false
	heft_lift = 0.0
	tip = 0.0
	_worked = 0.0
	_refresh_extinguisher()


# --- direct manipulation -------------------------------------------------------

## Each reach names the part under the hand. The grip moves that part's own
## travel; V1's functions are called where the state changes.
func control_grip(control_id: String, _area: Node) -> Dictionary:
	if stock == null:
		return {"legacy": true}
	match control_id:
		"cap":
			return _grip("cap", _cap, 0.0, 1.0, 560.0, Vector2.RIGHT,
					func() -> float: return cap_travel, _move_cap, _begin_plain.bind("cap"))
		"seal":
			return _grip("seal", _vessel, 0.0, 1.0, 150.0, Vector2.DOWN,
					func() -> float: return seal_pull, _move_seal, _begin_seal)
		"bottle":
			return _grip("bottle", _bottle, 0.0, 1.0, 520.0, Vector2.LEFT,
					func() -> float: return bottle_travel, _move_bottle, _begin_bottle)
		"loose":
			var top := V1_STOPPLE_PROUD if loose_cap_free else STOPPLE_SEIZED_LIFT
			return _grip("loose", _loose_cap, 0.0, top, 150.0 * top / V1_STOPPLE_PROUD, Vector2.UP,
					func() -> float: return stopple_lift, _move_stopple, _begin_stopple)
		"body":
			return _grip("body", _vessel, 0.0, HEFT_LIFT, 70.0, Vector2.UP,
					func() -> float: return heft_lift, _move_heft, _begin_heft)
		"hooks":
			return _grip("hooks", _vessel, 0.0, TIP_LIMIT, 220.0, Vector2.LEFT,
					func() -> float: return tip, _move_tip, _begin_plain.bind("hooks"))
	# The tag is signed, not operated.
	return {"legacy": true}


func _grip(id: String, part: Node3D, low: float, high: float, pixels: float, screen: Vector2,
		read: Callable, write: Callable, begin: Callable) -> Dictionary:
	return {"owner": self, "part": part, "frame": self, "kind": "slide", "axis": Vector3.UP,
		"minimum": low, "maximum": high, "gesture_travel_px": pixels, "gesture_screen_axis": screen,
		"unobstructed_hold": true, "read": read, "write": write, "begin": begin,
		"owns": func() -> bool: return _hand == id, "end": _end_hand}


func _take(id: String) -> bool:
	if _hand != "":
		return false
	_finish_settle()
	_hand = id
	_refused = false
	_tested_this_grip = false
	return true


func _begin_plain(id: String) -> bool:
	return _take(id)


func _begin_seal() -> bool:
	if not seal_wired:
		# Threading a fresh one needs the cap screwed home under it.
		if not cap_on or cap_travel > SEAL_SLACK:
			if cap_on:
				_balk(1.6, "cap")
			else:
				wire_seal()
			return false
		if not _take("seal"):
			return false
		seal_pull = 1.0
		_refresh_extinguisher()
		return true
	return _take("seal")


func _begin_bottle() -> bool:
	if cap_on:
		# V1's refusals: it is under the cap, or the cap is on over an empty cage.
		if bottle_drawn:
			seat_bottle()
		else:
			draw_bottle()
		return false
	if cap_travel < 0.98:
		# The cage is still in the neck until the cap stands on its rest.
		_balk(1.6, "cap")
		return false
	return _take("bottle")


func _begin_stopple() -> bool:
	if not bottle_drawn or bottle_travel < 0.98:
		try_loose_cap()   # V1's refusal: the bottle is in the cage
		return false
	if not _take("loose"):
		return false
	_stopple_live = true
	stopple_lift = V1_STOPPLE_PROUD if loose_cap_free else 0.0
	return true


func _begin_heft() -> bool:
	if not _take("body"):
		return false
	heft()
	return true


func _move_cap(value: float) -> void:
	if _hand != "cap":
		return
	var wanted := clampf(value, 0.0, 1.0)
	if seal_wired and wanted > SEAL_SLACK:
		# The wire passes through the lugs and takes the pull.
		wanted = SEAL_SLACK
		if not _refused:
			_refused = true
			unscrew_cap()
	cap_travel = wanted
	if cap_on and cap_travel >= CAP_THREAD:
		unscrew_cap()
	elif not cap_on and cap_travel < CAP_THREAD:
		screw_cap()
	_refresh_extinguisher()


func _move_seal(value: float) -> void:
	if _hand != "seal":
		return
	seal_pull = clampf(value, 0.0, 1.0)
	if seal_wired and seal_pull >= 1.0:
		seal_pull = 0.0
		_hand = ""
		cut_seal()
		return
	if not seal_wired and seal_pull <= 0.0:
		_hand = ""
		wire_seal()
		return
	_refresh_extinguisher()


func _move_bottle(value: float) -> void:
	if _hand != "bottle":
		return
	bottle_travel = clampf(value, 0.0, 1.0)
	if not bottle_drawn and bottle_travel >= BOTTLE_UNCLIPPED:
		draw_bottle()
	elif bottle_drawn and bottle_travel < BOTTLE_UNCLIPPED:
		seat_bottle()
	_refresh_extinguisher()


func _move_stopple(value: float) -> void:
	if _hand != "loose":
		return
	var top := V1_STOPPLE_PROUD if loose_cap_free else STOPPLE_SEIZED_LIFT
	var wanted := clampf(value, 0.0, top)
	var moved := absf(wanted - stopple_lift)
	stopple_lift = wanted
	if not _tested_this_grip and (moved > 0.0):
		# The lift IS the test. V1 records it; the hand, not a timed refusal,
		# shows what came up.
		_tested_this_grip = true
		try_loose_cap()
		_balk_left = 0.0
		_balk_focus = ""
		if not loose_cap_free:
			_worked += moved
	elif not loose_cap_free:
		_worked += moved
		if _worked >= WORK_FREE:
			free_loose_cap()
			stopple_lift = minf(stopple_lift, V1_STOPPLE_PROUD)
	_refresh_extinguisher()


func _move_heft(value: float) -> void:
	if _hand != "body":
		return
	heft_lift = clampf(value, 0.0, HEFT_LIFT)
	_refresh_extinguisher()


func _move_tip(value: float) -> void:
	if _hand != "hooks":
		return
	tip = clampf(value, 0.0, TIP_LIMIT)
	if tip >= TIP_LIMIT and not _refused:
		# It tips on its hooks and does not come off them.
		_refused = true
		invert()
	_refresh_extinguisher()


## Letting go. Nothing snaps: a part left where the metal can hold it stays, and
## a part left in the air goes where its weight takes it.
func _end_hand() -> void:
	var was := _hand
	_hand = ""
	_finish_settle()
	match was:
		"cap":
			if cap_travel > CAP_THREAD and cap_travel < 1.0:
				_settle_to("cap_travel", 1.0 if cap_travel >= 0.8 else CAP_THREAD)
		"bottle":
			if bottle_travel > 0.0 and bottle_travel < 1.0:
				_settle_to("bottle_travel", 1.0 if bottle_travel >= 0.5 else 0.0)
		"seal":
			seal_pull = 0.0
		"loose":
			_settle_to("stopple_lift", V1_STOPPLE_PROUD if loose_cap_free else 0.0)
		"body":
			_settle_to("heft_lift", 0.0)
		"hooks":
			_settle_to("tip", 0.0)
	_refresh_extinguisher()


func _settle_to(property: String, goal: float) -> void:
	var from: float = get(property)
	_settle_property = property
	_settle_goal = goal
	if is_equal_approx(from, goal) or not is_inside_tree():
		_finish_settle()
		return
	_settle = create_tween()
	_settle.tween_method(_set_travel.bind(property), from, goal,
			clampf(absf(goal - from) * 0.9, 0.08, 0.45)).set_trans(Tween.TRANS_SINE)
	_settle.tween_callback(_finish_settle)


## A settling part reaches its rest at once if a hand arrives before it has.
func _finish_settle() -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
	_settle = null
	if _settle_property.is_empty():
		return
	var property := _settle_property
	_settle_property = ""
	if property == "stopple_lift":
		_stopple_live = false
	_set_travel(_settle_goal, property)


func _set_travel(value: float, property: String) -> void:
	set(property, value)
	match property:
		"cap_travel":
			if cap_on and cap_travel >= CAP_THREAD:
				super.unscrew_cap()
			elif not cap_on and cap_travel < CAP_THREAD:
				super.screw_cap()
		"bottle_travel":
			if not bottle_drawn and bottle_travel >= BOTTLE_UNCLIPPED:
				super.draw_bottle()
			elif bottle_drawn and bottle_travel < BOTTLE_UNCLIPPED:
				super.seat_bottle()
	_refresh_extinguisher()


# --- pose --------------------------------------------------------------------

## Where the cap is for a travel, in this prop's frame, with the vessel where
## V1 has just put it.
func _cap_pose(travel: float) -> Transform3D:
	var seat := _vessel.transform * Transform3D(Basis(), V1_CAP_ON)
	if travel <= CAP_THREAD:
		var turn := travel / CAP_THREAD
		return seat * Transform3D(Basis(Vector3.UP, turn * CAP_TURNS * TAU),
				Vector3(0.0, turn * CAP_THREAD_RISE, 0.0))
	var top_of_thread := seat * Transform3D(Basis(Vector3.UP, CAP_TURNS * TAU),
			Vector3(0.0, CAP_THREAD_RISE, 0.0))
	var lifted := top_of_thread.origin + Vector3(0.0, CAP_CLEAR_LIFT, 0.0)
	var over := Vector3(_cap_rest.x, lifted.y, _cap_rest.z)
	var path: Array[Vector3] = [top_of_thread.origin, lifted, over, _cap_rest]
	var along := (travel - CAP_THREAD) / (1.0 - CAP_THREAD)
	var turned := top_of_thread.basis.slerp(Basis(), smoothstep(0.0, 0.6, along))
	return Transform3D(turned, _along(path, along))


## A point a share of the way along a polyline, by length.
func _along(path: Array[Vector3], share: float) -> Vector3:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var left := clampf(share, 0.0, 1.0) * total
	for i in range(1, path.size()):
		var step := path[i - 1].distance_to(path[i])
		if left <= step or i == path.size() - 1:
			return path[i - 1].lerp(path[i], clampf(left / maxf(step, 0.000001), 0.0, 1.0))
		left -= step
	return path[path.size() - 1]


func _refresh_extinguisher() -> void:
	super._refresh_extinguisher()
	if stock == null or _vessel == null or _cap == null or _bottle == null:
		return
	var tipping := _balk_left > 0.0 and _balk_focus == "invert"
	_vessel.position.y += heft_lift
	if not tipping:
		_vessel.rotation.z = tip
	# The cap: V1 has written a rest pose plus whatever its refusal adds. Keep
	# what the refusal added and put it on the cap's real place.
	var v1_at := V1_CAP_ON if cap_on else V1_CAP_OFF
	var v1_roll := 0.0 if cap_on else V1_CAP_OFF_ROLL
	var cap_nudge := _cap.position - v1_at
	var cap_twist := _cap.rotation - Vector3(0.0, 0.0, v1_roll)
	var cap_here := _vessel.transform.affine_inverse() * _cap_pose(cap_travel)
	_cap.transform = Transform3D(cap_here.basis * Basis.from_euler(cap_twist), cap_here.origin + cap_nudge)
	if _seal != null:
		_seal.visible = seal_wired or _hand == "seal"
		_seal.position += Vector3(0.0, -0.006, 0.014) * seal_pull
	# The bottle: in the cage it goes wherever the cap goes.
	var v1_bottle := V1_BOTTLE_DRAWN
	var v1_bottle_roll := 0.0
	if not bottle_drawn:
		if cap_on:
			v1_bottle = V1_BOTTLE_TIPPED if tipping else V1_BOTTLE_ON
			v1_bottle_roll = TIP_LIMIT if tipping else 0.0
		else:
			v1_bottle = V1_BOTTLE_OFF
			v1_bottle_roll = V1_CAP_OFF_ROLL
	var bottle_nudge := _bottle.position - v1_bottle
	var bottle_twist := _bottle.rotation - Vector3(0.0, 0.0, v1_bottle_roll)
	var caged := _vessel.transform * _cap.transform * Transform3D(Basis(), _in_cage)
	var bottle_here := caged
	if bottle_travel > 0.0:
		var clear := caged.origin + Vector3(0.0, 0.0, 0.300 - caged.origin.z)
		var over := Vector3(V1_BOTTLE_DRAWN.x, V1_BOTTLE_DRAWN.y + 0.065, clear.z)
		var path: Array[Vector3] = [caged.origin, clear, over, V1_BOTTLE_DRAWN]
		bottle_here = Transform3D(caged.basis.slerp(Basis(), smoothstep(0.0, 0.3, bottle_travel)),
				_along(path, bottle_travel))
	if _stopple_live:
		# Lifting at the little cap. Free, it leaves the neck; seized, the bottle
		# comes up with it.
		_loose_cap.position.y = V1_STOPPLE_Y + (stopple_lift if loose_cap_free else 0.0)
		if not loose_cap_free:
			bottle_here.origin.y += stopple_lift
			bottle_here.basis = bottle_here.basis * Basis(Vector3.BACK, stopple_lift / STOPPLE_SEIZED_LIFT * 0.24)
	_bottle.transform = Transform3D(bottle_here.basis * Basis.from_euler(bottle_twist),
			bottle_here.origin + bottle_nudge)
	_place_reaches()


## The reaches follow the parts they stand for, and a part that cannot be got at
## offers no reach.
func _place_reaches() -> void:
	var cap_at := (_vessel.transform * _cap.transform) * Vector3(0.0, 0.035, 0.0)
	_reach("cap", cap_at, true)
	var loose_ready := bottle_drawn and bottle_travel >= 0.98
	var bottle_ready := loose_ready or (not cap_on and cap_travel >= 0.98) or _hand == "bottle"
	_reach("bottle", _bottle.transform * Vector3(0.0, -0.006, 0.0), bottle_ready)
	_reach("loose", _bottle.transform * Vector3(0.0, 0.085, 0.0), loose_ready)


func _reach(control_id: String, at: Vector3, enabled: bool) -> void:
	var area := get_node_or_null("Reach_" + control_id) as Area3D
	if area == null or area.get_child_count() == 0:
		return
	var shape := area.get_child(0) as CollisionShape3D
	shape.position = at
	shape.disabled = not enabled


func _size_reach(control_id: String, size: Vector3) -> void:
	var area := get_node_or_null("Reach_" + control_id) as Area3D
	if area == null or area.get_child_count() == 0:
		return
	((area.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
