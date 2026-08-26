class_name TourKeyGuardProp
extends FunctionalProp
## The tour-key guard: one hook, one latch, one numbered check.
##
## SR7-L, and the last missing piece of the watchman's line.
##
## SR7-J built a station box with an EMPTY tour-key socket and said so: the
## building never issued a key, which made the box weaker evidence than a real
## 1928 station and made its "who" lesson literal. This is the key, and the
## hook it lives on.
##
## THE TRUTH THIS TEACHES. Possession proves the key is not on its hook.
##
## That is the whole of it. The check hanging in the key's place carries a
## NUMBER, not a name -- it says this hook is empty and somebody emptied it,
## and it has no opinion whatever about who, or where they went, or whether
## they came back by way of anywhere. It is the same silence SR7-G's key board
## keeps about its two keys, kept about a third.
##
## AND WHAT THE KEY IS NOT. It is not a quest token and it is not a permit.
##
##   * It opens NO door. Not an apartment, not a service closet, not the
##     plant. `DoorProp.leaf_state` is the layout's and
##     `orison_detail_pass._unlock_for_case`'s, and this apparatus cannot
##     write it -- the focused proof reads this file and finds no `leaf_state`
##     in it at all.
##   * It gates ONE optional thing: the watch station's crank. A watchman with
##     no key cannot work the box, and can still investigate, repair, file and
##     clock out, because the mark was always optional and the key does not
##     make it less so.
##   * It is not carried in an inventory. `MaintenanceInventory` says of itself
##     that an item is "granted at most once per campaign and consumed at most
##     once -- deterministic single use", it refuses a second `grant`, and it
##     commits to `RealityState`. A key taken and hung back every night is none
##     of those things, so custody lives here, in the iron, and is transient by
##     design: a guard is emptied and refilled, it is not a ledger.
##
## HISTORICAL BASIS.
##   * J. P. VENEGAS, US 1,626,987, "Key Lock", filed 24 November 1925,
##     granted 3 May 1927 -- one year before the Orison's 1928. "A suitable
##     locking device or latch is adapted to hold the split ring", and the
##     keys are retained by toothed flanges "preventing removal until the
##     operator manipulates the locking mechanism". A key you can only take by
##     working a latch is a key whose taking is an ACT, and that is the whole
##     reason this apparatus is a guard rather than a nail.
##   * R. H. THAYER, THAYER TELKEE CORP, US 1,749,399, "Key Tag", filed
##     6 April 1926 -- a pending application in 1928, and the same source
##     SR7-G's night register cites for its numbered checks. One check system,
##     three hooks, two apparatus: the tour key hangs apart from the apartment
##     and plant keys because it is a different kind of permission, and the
##     building keeps them on different boards.
##   * H. MACHINIST, US 2,220,937, cited by SR7-J for the practice already
##     established: "the watchman is provided with an implement, sometimes
##     called a tour key, which he carries on his rounds".
##
## ORISON-SPECIFIC INFERENCE, stated plainly: this guard, its latch, its check
## number and the key's shape are authored. The wall it hangs on, the lane it
## hangs in and the box at the other end of the round are not.
##
## AUTHORING RULE. Local z = 0 is the mounting plane and the guard is built
## OUTWARD along +z into the lobby.

## Transient custody, published as facts. Nothing here subscribes to them.
signal tour_key_taken(check_number: int)
signal tour_key_returned()

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## The number stamped on the check that hangs in the key's place. Distinct
## from the night register's 14 (apartment) and 7 (plant): one building, one
## check series, three hooks.
const CHECK_NUMBER := 3
const KEY_LEGEND := "TOUR KEY"

var _plate: MeshInstance3D
var _latch: Node3D
var _key: Node3D
var _check: Node3D
var _hook: MeshInstance3D
var _clink: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D

## THE ONLY STATE, and it is transient by design. A guard is emptied and
## refilled; it is not a ledger, and nothing here reaches RealityState.
var key_on_hook := true

var _balk_left := 0.0
var _balk_focus := ""


func _ready() -> void:
	super()
	_refresh_guard()


# --- custody -----------------------------------------------------------------

func key_carried() -> bool:
	return not key_on_hook


## What the hook reads, which is all a hook can ever read. A number, never a
## name: the check says the key is out and says nothing else.
func hook_reads() -> String:
	return "check %d" % CHECK_NUMBER if key_carried() else KEY_LEGEND


## Work the latch and take the key. The check goes on the hook in its place,
## because a hook this building can look at must never be simply bare.
func take_key() -> bool:
	if key_carried():
		# The hook is carrying its check. Somebody has the key, and the guard
		# has no second one to give.
		_balk(1.2, "hook")
		return false
	key_on_hook = false
	if _clink != null:
		_clink.play()
	_refresh_guard()
	tour_key_taken.emit(CHECK_NUMBER)
	return true


## Hang it back. Refuses a key onto a hook that already has one -- which is
## the copied-key case, and a guard that accepted a copy could not account for
## anything afterwards.
func return_key() -> bool:
	if key_on_hook:
		_balk(1.4, "key")
		return false
	key_on_hook = true
	if _clink != null:
		_clink.play()
	_refresh_guard()
	tour_key_returned.emit()
	return true


# --- the abort seam ----------------------------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"key_on_hook": key_on_hook}


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	key_on_hook = bool(snapshot.get("key_on_hook", key_on_hook))
	_balk_left = 0.0
	_balk_focus = ""
	_refresh_guard()


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var oak := Color(0.31, 0.20, 0.13)
	var brass := Color(0.62, 0.50, 0.24)
	var brass_bright := Color(0.78, 0.66, 0.32)
	var enamel := Color(0.83, 0.80, 0.73)
	var steel := Color(0.44, 0.44, 0.47)

	# A small board: 0.16 x 0.26. Deliberately the smallest thing in the lane.
	# One key does not need a cabinet, and a guard that looked like the night
	# register would invite the reading that they are one apparatus.
	_plate = make_box(Vector3(0.160, 0.260, 0.022),
			Vector3(0.0, 0.130, 0.011), oak)
	_plate.name = "GuardPlate"
	for edge_x in [-0.074, 0.074]:
		var stile := make_box(Vector3(0.012, 0.260, 0.034),
				Vector3(edge_x, 0.130, 0.017), oak)
		stile.name = "GuardStile"
	var head := make_box(Vector3(0.130, 0.030, 0.004),
			Vector3(0.0, 0.226, 0.024), enamel)
	head.name = "GuardHead"
	_print("GuardLegend", KEY_LEGEND, Vector3(0.0, 0.226, 0.028), 0.0125,
			Color(0.16, 0.13, 0.11))

	# THE HOOK, and Venegas's latch across it. The latch is what makes taking
	# the key an act rather than a lift.
	_hook = make_cyl(0.0035, 0.0035, 0.030, Vector3(0.0, 0.170, 0.026),
			brass, 0.34, 0.72)
	_hook.name = "GuardHook"
	_hook.rotation_degrees.x = 90.0
	var lip := make_cyl(0.0035, 0.0035, 0.016, Vector3(0.0, 0.163, 0.041),
			brass, 0.34, 0.72)
	lip.name = "HookLip"
	_latch = Node3D.new()
	_latch.name = "GuardLatch"
	_latch.position = Vector3(0.030, 0.170, 0.034)
	add_child(_latch)
	var bar := make_box(Vector3(0.044, 0.007, 0.006), Vector3(-0.022, 0.0, 0.0),
			brass_bright)
	bar.name = "LatchBar"
	_adopt(bar, _latch)
	var knob := make_cyl(0.008, 0.008, 0.012, Vector3(0.004, 0.0, 0.0),
			Color(0.19, 0.19, 0.21), 0.42, 0.20)
	knob.name = "LatchKnob"
	knob.rotation_degrees.z = 90.0
	_adopt(knob, _latch)

	# THE TOUR KEY. A barrel key with a heavy bow and a single ward -- not the
	# night register's flat apartment bit and not its long plant key. Three
	# keys in this building and no two of them the same silhouette.
	_key = Node3D.new()
	_key.name = "TourKey"
	_key.position = Vector3(0.0, 0.146, 0.038)
	add_child(_key)
	var bow := make_cyl(0.015, 0.015, 0.005, Vector3.ZERO, brass_bright,
			0.34, 0.74)
	bow.name = "KeyBow"
	bow.rotation_degrees.x = 90.0
	_adopt(bow, _key)
	var bow_eye := make_cyl(0.008, 0.008, 0.007, Vector3(0.0, 0.0, 0.0),
			Color(0.10, 0.09, 0.08), 0.50, 0.10)
	bow_eye.name = "KeyEye"
	bow_eye.rotation_degrees.x = 90.0
	_adopt(bow_eye, _key)
	var barrel := make_cyl(0.005, 0.005, 0.052, Vector3(0.0, -0.034, 0.0),
			steel, 0.36, 0.70)
	barrel.name = "KeyBarrel"
	_adopt(barrel, _key)
	var ward := make_box(Vector3(0.014, 0.014, 0.005),
			Vector3(0.008, -0.052, 0.0), steel)
	ward.name = "KeyWard"
	_adopt(ward, _key)

	# THE CHECK. Round, numbered, and obviously not a key from across the
	# lobby -- the same design requirement SR7-G's checks answer.
	_check = Node3D.new()
	_check.name = "TourCheck"
	_check.position = Vector3(0.0, 0.146, 0.038)
	add_child(_check)
	var disc := make_cyl(0.019, 0.019, 0.004, Vector3.ZERO,
			Color(0.66, 0.56, 0.26), 0.44, 0.58)
	disc.name = "CheckDisc"
	disc.rotation_degrees.x = 90.0
	_adopt(disc, _check)
	_print("CheckNumber", str(CHECK_NUMBER), Vector3(0.0, 0.0, 0.004),
			0.0175, Color(0.18, 0.14, 0.07), _check)

	_clink = make_emitter("knock", -17.0)
	_knock = make_emitter("knock", -13.0)
	_build_reach()
	_refresh_guard()


func _adopt(node: Node3D, pivot: Node3D) -> void:
	var local := node.position
	var spin := node.rotation
	remove_child(node)
	pivot.add_child(node)
	node.position = local
	node.rotation = spin


func _print(node_name: String, text: String, at: Vector3, em: float,
		tint: Color, parent: Node3D = null) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = 64
	label.pixel_size = em / 64.0
	label.modulate = tint
	label.outline_size = 0
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = true
	label.double_sided = false
	(parent if parent != null else self).add_child(label)


## One literal service point, an Area3D reach that obstructs nothing.
func _build_reach() -> void:
	var reach := ControlArea.new()
	reach.name = "GuardReach"
	reach.configure("tour_key")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.20, 0.26, 0.16)
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.150, 0.060)
	reach.add_child(shape_node)
	add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	if control_id != "tour_key":
		return ""
	if key_carried():
		return "[E]  Hang the tour key back  (check %d on the hook)" \
				% CHECK_NUMBER
	return "[E]  Take the tour key  (opens no door)"


func interact_control(control_id: String, _player: Node) -> bool:
	if control_id != "tour_key":
		return false
	return return_key() if key_carried() else take_key()


func interact_prompt() -> String:
	return control_prompt("tour_key")


func interact(player: Node) -> void:
	interact_control("tour_key", player)


func service_wire_card() -> Dictionary:
	return {
		"title": "TOUR KEY",
		"body": "The key that works the watch stations, and nothing else. It "
				+ "opens no door in this building. The check on its hook says "
				+ "the key is out; it does not say who has it.",
	}


# --- the readable refusal ----------------------------------------------------

func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()
	_refresh_guard()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_guard()


func _refresh_guard() -> void:
	if _plate == null:
		return
	# The hook carries EITHER the key or the check. Never both, never neither.
	if _key != null:
		_key.visible = key_on_hook
		_key.position = Vector3(0.0, 0.146, 0.038)
		_key.rotation.z = 0.0
	if _check != null:
		_check.visible = key_carried()
		_check.position = Vector3(0.0, 0.146, 0.038)
		_check.rotation.z = 0.0
	# The latch lies across a loaded hook and stands open on an empty one, so
	# the guard's condition reads even before the eye reaches the hook itself.
	if _latch != null:
		_latch.rotation.z = 0.0 if key_on_hook else 1.15

	var balk := clampf(_balk_left, 0.0, 1.0)
	if balk <= 0.0:
		return
	match _balk_focus:
		"hook":
			# Reaching for a key that is not there: the check swings on it.
			if _check != null:
				_check.rotation.z = 0.52 * balk
				_check.position.y = 0.146 + 0.012 * balk
		"key":
			# Offering a second key to a loaded hook: the latch shoves it off.
			if _key != null:
				_key.position.y = 0.146 + 0.016 * balk
				_key.rotation.z = -0.34 * balk
			if _latch != null:
				_latch.rotation.z = -0.30 * balk
