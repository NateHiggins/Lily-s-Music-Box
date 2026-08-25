class_name FusePanelProp
extends FunctionalProp
## The house panelboard in B1_ELECTRICAL: main knife switch and plug fuses.
##
## SR7-E. THE ELECTRICAL PLANT ALREADY EXISTS AND THIS DOES NOT REPLACE IT.
## `art/data/gen_layout.py` bakes a real basement electrical room --
## `B1_ELECTRICAL`, rect [5.51, -9.65, 13.65, -1.0] -- carrying three
## panelboards `b1_panel0/1/2` on its east wall at x 13.30..13.44 and the
## feeder conduit `b1_econduit` that runs to them. What none of them had was
## an inside. This apparatus is the working face of the first of those three
## cabinets: it stands on that panel's own front plane and builds outward into
## the room, so the baked cabinet is its back and nothing is duplicated.
##
## THE TRUTH THIS TEACHES. A fuse protects the WIRE, not the lamp.
##
## The link is sized to the conductor behind the wall, not to whatever is
## plugged in at the far end of it. Put a thirty-ampere plug in a fifteen-
## ampere circuit and every lamp still lights, nothing ever blows, and the
## last thing left to fail is the wire itself. There is no symptom. The panel
## is working exactly as somebody intended, and that is the fault.
##
## The second truth is the safety one: the panel is LIVE whatever the lamps
## are doing. A fuse is not a switch, and the main comes out first.
##
## HISTORICAL BASIS.
##   * The physical hazard is the Edison base itself: a 15, 20 or 30 ampere
##     plug all screw into the same holder, so nothing about the fitting
##     prevents the wrong one. The National Electrical Code still answers this
##     by restricting Edison-base plug fuses to existing installations showing
##     no evidence of overfusing or tampering.
##   * E. H. TAYLOR, assigned to Chase Shawmut Co., US 2,147,221,
##     "Nontamperable and Noninterchangeable Plug Fuse", filed 21 September
##     1935, granted 14 February 1939. Its stated objects name both period
##     abuses exactly: that "a plug fuse having a larger current carrying
##     capacity than is intended for the circuit cannot be inserted in the
##     receptacle", and that "the terminals of the receptacle cannot be
##     bridged readily by a metal conductor" -- the coin behind the fuse.
##
## NOTE THE DATES, because they are the point. Taylor's rejection base is the
## CURE, and it is invented seven years after the Orison's 1928. This panel is
## the disease with no cure yet available: every plug in the drawer fits every
## hole, and the only thing standing between the building and a fire in the
## wall is somebody reading a stamped number.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: that THIS circuit is over-fused
## today, the particular 30-in-a-15, the circuit card, the spare drawer and the
## lamp index are authored. The room, the cabinets and the conduit are not --
## they predate this work.
##
## AUTHORING RULE. Local z = 0 is the baked cabinet's front plane and the
## apparatus is built OUTWARD along +z into the electrical room.
##
## OWNERSHIP. This prop owns its own panel and nothing else. It does not own
## the building's lighting: `SwitchSystem` and the light rig keep every fixture
## they already had, and this apparatus never turns one on or off. It closes no
## job, advances no case, mutates no Dream state and adds no save owner. Only
## `apply_maintenance_result` may record the panel safe.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## What the conductor behind this circuit can actually carry. A fixed fact of
## the wiring, not a setting: the whole activity is about matching to it.
const CONDUCTOR_RATING := 15
## The rating found in the holder.
const FOUND_RATING := 30
## How far the plug must be backed out before it is clear of its base.
const PLUG_CLEAR := 0.45

var _service_panel: MaintenanceActivityPanel

var _door: MeshInstance3D
var _blades: MeshInstance3D
var _jaws: MeshInstance3D
var _handle: MeshInstance3D
var _block: MeshInstance3D
var _plug: MeshInstance3D
var _window: MeshInstance3D
var _link: MeshInstance3D
var _stamp: MeshInstance3D
var _card: MeshInstance3D
var _conductor: MeshInstance3D
var _spares: MeshInstance3D
var _index: MeshInstance3D
var _offered: MeshInstance3D
var _offered_mat: StandardMaterial3D
var _link_mat: StandardMaterial3D
var _stamp_mat: StandardMaterial3D
var _clack: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _live: AudioStreamPlayer3D
var _balk_left := 0.0
var _t := 0.0

## The apparatus's own facts.
##
## `fitted_rating` above `CONDUCTOR_RATING` is the fault. Note what it is NOT:
## nothing is blown, nothing is loose, nothing is even inconvenient. Every lamp
## on the circuit works, which is precisely why it has been like this for years.
var fitted_rating := FOUND_RATING
var main_open := false
var plug_out := false
var stamp_read := 0.0
var load_proved := false
var panel_safe := false
## The oversized plug currently being held at the base, 0 when none is.
var offered_rating := 0


# --- the electrical model ----------------------------------------------------

## The panel is energised unless the main is open. The lamps have no opinion
## about this and neither does the fuse.
func panel_live() -> bool:
	return not main_open


## The link never parted, because nothing on this circuit could ever draw
## enough to part a thirty. A whole link is not evidence of a healthy circuit.
func link_whole() -> bool:
	return true


## Whether the fitted plug is larger than the conductor it is supposed to
## protect. This is the fault, and it is a comparison of two numbers that
## nothing in an Edison base enforces.
func over_fused() -> bool:
	return fitted_rating > CONDUCTOR_RATING


## Whether the fitted plug would part before the conductor overheats. The one
## question the apparatus exists to answer.
func protects_conductor() -> bool:
	return not plug_out and fitted_rating <= CONDUCTOR_RATING


## Which plug a slider position selects, in amperes. Every one of these fits
## the same hole, which is the period's whole problem.
func rating_at(value: float) -> int:
	var v := clampf(value, 0.0, 1.0)
	if v < 0.25:
		return 10
	if v < 0.45:
		return 15
	if v < 0.70:
		return 20
	return 30


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var iron := Color(0.26, 0.25, 0.24)
	var brass := Color(0.48, 0.38, 0.20)
	var porcelain := Color(0.76, 0.73, 0.66)
	var copper := Color(0.56, 0.33, 0.16)

	# The cabinet interior. The baked `b1_panel0` box is the back of this; only
	# what a hand touches is authored here.
	make_box(Vector3(0.62, 0.86, 0.03), Vector3(0.0, 0.50, 0.018), iron)
	for cheek_x in [-0.30, 0.30]:
		make_box(Vector3(0.03, 0.86, 0.13),
				Vector3(cheek_x, 0.50, 0.078), iron)

	# THE MAIN KNIFE SWITCH, across the head of the cabinet. Blades, jaws and
	# a fibre handle: the whole point of it is that you can SEE whether it is
	# open, which a modern breaker deliberately does not show you.
	_jaws = make_box(Vector3(0.30, 0.045, 0.045), Vector3(0.0, 0.80, 0.085),
			brass)
	_jaws.name = "SwitchJaws"
	_blades = make_box(Vector3(0.26, 0.030, 0.030), Vector3(0.0, 0.80, 0.095),
			Color(0.62, 0.52, 0.28))
	_blades.name = "SwitchBlades"
	var bm := _blades.material_override as StandardMaterial3D
	if bm != null:
		bm.metallic = 0.74
		bm.roughness = 0.26
	_handle = make_box(Vector3(0.040, 0.11, 0.040),
			Vector3(0.16, 0.80, 0.100), Color(0.20, 0.16, 0.13))
	_handle.name = "SwitchHandle"

	# THE FUSE BLOCK: porcelain, four Edison bases, one of them the circuit
	# this round is about.
	_block = make_box(Vector3(0.46, 0.20, 0.075), Vector3(0.0, 0.46, 0.062),
			porcelain)
	_block.name = "FuseBlock"
	for i in 3:
		make_cyl(0.038, 0.038, 0.030,
				Vector3(-0.145 + float(i) * 0.145, 0.46, 0.104),
				Color(0.30, 0.22, 0.14), 0.62, 0.10)

	# THE FITTED PLUG, in the fourth base. Its mica window shows a link that
	# has never parted and never will.
	_plug = make_cyl(0.042, 0.042, 0.040, Vector3(0.145, 0.46, 0.108),
			Color(0.32, 0.24, 0.15), 0.58, 0.12)
	_plug.name = "PlugFuse"
	_window = make_cyl(0.026, 0.026, 0.010, Vector3(0.145, 0.46, 0.130),
			Color(0.74, 0.72, 0.60), 0.14, 0.0)
	_window.name = "FuseWindow"
	var wm := _window.material_override as StandardMaterial3D
	if wm != null:
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.albedo_color = Color(0.80, 0.78, 0.66, 0.34)
	_link = make_box(Vector3(0.030, 0.006, 0.006),
			Vector3(0.145, 0.46, 0.126), copper)
	_link.name = "FuseLink"
	_link_mat = _link.material_override as StandardMaterial3D
	# The stamped rating on the cap. The only place the fault is written down.
	_stamp = make_box(Vector3(0.034, 0.016, 0.004),
			Vector3(0.145, 0.487, 0.131), Color(0.86, 0.82, 0.70))
	_stamp.name = "RatingStamp"
	_stamp_mat = _stamp.material_override as StandardMaterial3D

	# THE CIRCUIT CARD, which says what the conductor is, and the conductor
	# itself leaving the block.
	_card = make_box(Vector3(0.20, 0.13, 0.005), Vector3(-0.12, 0.20, 0.086),
			Color(0.80, 0.77, 0.68))
	_card.name = "CircuitCard"
	_conductor = make_cyl(0.011, 0.011, 0.30, Vector3(0.145, 0.30, 0.060),
			copper, 0.44, 0.66)
	_conductor.name = "ConductorTail"

	# The drawer of spares. Every plug in it fits every hole in the block,
	# which is exactly the hazard Taylor's rejection base was invented to end.
	_spares = make_box(Vector3(0.20, 0.075, 0.11), Vector3(0.16, 0.18, 0.072),
			Color(0.34, 0.30, 0.24))
	_spares.name = "SpareDrawer"
	for i in 3:
		make_cyl(0.026, 0.026, 0.018,
				Vector3(0.10 + float(i) * 0.055, 0.185, 0.126),
				Color(0.36, 0.27, 0.17), 0.60, 0.10)

	# THE DOOR, hinged at the left, and the lamp index run down the block.
	_door = make_box(Vector3(0.64, 0.90, 0.022), Vector3(0.0, 0.50, 0.140),
			Color(0.30, 0.29, 0.27))
	_door.name = "PanelDoor"
	_index = make_box(Vector3(0.05, 0.020, 0.026),
			Vector3(-0.26, 0.20, 0.120), brass)
	_index.name = "LampIndex"

	# THE REJECTED PLUG: the oversized one, held at the mouth of the base it
	# will not be allowed into. It is the frame that shows a refusal, and it is
	# also the thing Taylor's rejection base was invented to make impossible --
	# in 1928 only the hand holding it can refuse.
	_offered = make_cyl(0.044, 0.044, 0.042,
			Vector3(0.145, 0.46, 0.215), Color(0.40, 0.26, 0.15), 0.56, 0.12)
	_offered.name = "RejectedPlug"
	_offered_mat = _offered.material_override as StandardMaterial3D
	_offered.visible = false

	_clack = make_emitter("power_down", -13.0)
	_knock = make_emitter("knock", -14.0)
	_live = make_emitter("buzz_loop", -26.0, true)
	_build_panel_reach()
	_refresh_mechanism()


## The service point, over the block and the main. Built in the visual pass so
## the base class finds an authored area and does not wrap the whole cabinet in
## a coarser one.
func _build_panel_reach() -> void:
	var reach := ControlArea.new()
	reach.name = "PanelReach"
	reach.configure("panel")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.72, 0.86, 0.34)
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.52, 0.14)
	reach.add_child(shape_node)
	add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	if control_id != "panel":
		return ""
	if over_fused():
		return "[E]  Read the house panel"
	return "[E]  Check the house panel"


func interact_control(control_id: String, player: Node) -> bool:
	if control_id != "panel":
		return false
	return _begin_panel_service(player)


func interact(player: Node) -> void:
	_begin_panel_service(player)


func _begin_panel_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "fuse_panel_rating_service"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"fitted_rating": fitted_rating, "main_open": main_open,
			"plug_out": plug_out, "stamp_read": stamp_read,
			"load_proved": load_proved, "panel_safe": panel_safe,
			"offered_rating": offered_rating}


## Reversible. Working the visible panel moves the visible panel and publishes
## nothing: `panel_safe` is deliberately untouched here and moves only in
## `apply_maintenance_result`.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"read_the_stamp":
			stamp_read = worked
		"pull_the_main":
			var was := main_open
			main_open = worked < 0.5
			if main_open != was and _clack != null:
				_clack.play()
		"draw_the_plug":
			if panel_live():
				# THE SAFETY REFUSAL. A fuse is not a switch. The holder is at
				# line potential whatever the lamps are doing, and this is the
				# one refusal in the round that is about the hand rather than
				# the building.
				_balk(1.5)
			else:
				plug_out = worked >= PLUG_CLEAR
		"match_the_wire":
			if not plug_out:
				# Nothing to change while the old plug is still in its base.
				_balk(0.9)
			else:
				var chosen := rating_at(worked)
				if chosen > CONDUCTOR_RATING:
					# THE FAULT ITSELF, OFFERED AS A REPAIR. Fitting a bigger
					# plug is what put the building here. The apparatus will
					# not hand it back, and it holds the rejected plug up at
					# the base mouth so the refusal is a thing you can see and
					# not merely a thing that happened.
					offered_rating = chosen
					_balk(1.4)
				else:
					offered_rating = 0
					# Fitting the right plug SEATS it. Matching the wire is not
					# an abstract choice of number; it is screwing a new plug
					# home into the base the old one came out of, and the
					# holder is not empty afterwards.
					fitted_rating = chosen
					plug_out = false
		"prove_under_load":
			if plug_out:
				# There is no fuse in the holder to prove.
				_balk(0.9)
			else:
				main_open = worked < 0.5
				load_proved = not main_open and protects_conductor()
				if not main_open and over_fused():
					# It carries the load perfectly, and that is the problem.
					_balk(1.2)
	_refresh_mechanism()


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	fitted_rating = int(snapshot.get("fitted_rating", fitted_rating))
	main_open = bool(snapshot.get("main_open", main_open))
	plug_out = bool(snapshot.get("plug_out", plug_out))
	stamp_read = float(snapshot.get("stamp_read", stamp_read))
	load_proved = bool(snapshot.get("load_proved", load_proved))
	panel_safe = bool(snapshot.get("panel_safe", panel_safe))
	offered_rating = int(snapshot.get("offered_rating", 0))
	_balk_left = 0.0
	_refresh_mechanism()


## The only guarded publication. Nothing above this line records the panel safe.
func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if patch.has("fitted_rating"):
		fitted_rating = int(patch["fitted_rating"])
	if patch.has("main_open"):
		main_open = bool(patch["main_open"])
	if patch.has("plug_out"):
		plug_out = bool(patch["plug_out"])
	if patch.has("panel_safe"):
		# A panel is not safe because a data file says so. It is safe when the
		# fitted plug is no larger than the conductor it protects, and the
		# apparatus is the last word on that.
		panel_safe = bool(patch["panel_safe"]) and protects_conductor()
	stamp_read = 0.0
	offered_rating = 0
	load_proved = panel_safe and not main_open
	_balk_left = 0.0
	_refresh_mechanism()
	maintenance_completed.emit(result.duplicate(true))


# --- the readable refusal ----------------------------------------------------

## A balk is a knock in the cabinet and a visible shudder at the block.
## `design/PROP_ACTIVITIES.md` forbids a silent false; this is the honest
## refusal it asks for.
func _balk(seconds: float) -> void:
	var already := _balk_left > 0.0
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_mechanism()


func _refresh_mechanism() -> void:
	if _blades == null:
		return
	# THE MAIN. Open blades stand clear of their jaws, which is a thing you can
	# see from across the room and the entire reason this switch is shaped the
	# way it is.
	var open := 1.0 if main_open else 0.0
	_blades.position.y = 0.80 + 0.055 * open
	_blades.rotation.z = -0.42 * open
	if _handle != null:
		_handle.position.y = 0.80 + 0.075 * open
		_handle.rotation.z = -0.42 * open

	# The panel hums while it is alive and stops when it is not.
	if _live != null:
		if panel_live() and not _live.playing:
			_live.play()
		elif not panel_live() and _live.playing:
			_live.stop()

	# THE PLUG. Backed out of its base it stands proud and then clear.
	if _plug != null:
		_plug.position.z = 0.108 + 0.055 * (1.0 if plug_out else 0.0)
		_plug.visible = true
	# The window, link and stamp ride with the plug: they are parts of it, not
	# of the block it screws into.
	var plug_lift := 0.055 * (1.0 if plug_out else 0.0)
	if _window != null:
		_window.position.z = 0.130 + plug_lift
	if _link != null:
		_link.position.z = 0.126 + plug_lift
	if _stamp != null:
		_stamp.position.z = 0.131 + plug_lift

	# THE STAMP. A thirty reads bright and wrong against the card; a fifteen
	# sits quiet. The rating is the only visible difference between a panel
	# that protects a wire and one that does not, so it is the one thing on
	# this apparatus that changes colour.
	if _stamp_mat != null:
		_stamp_mat.albedo_color = Color(0.88, 0.62, 0.24) if over_fused() \
				else Color(0.72, 0.78, 0.70)
	# The link runs warm only when it is carrying a load it was sized for.
	if _link_mat != null:
		_link_mat.albedo_color = Color(0.62, 0.40, 0.20) if load_proved \
				else Color(0.50, 0.30, 0.15)
	# A conductor behind an oversized plug is the part actually at risk, and it
	# is drawn as the one thing with no protection in front of it.
	if _conductor != null:
		var cm := _conductor.material_override as StandardMaterial3D
		if cm != null:
			cm.albedo_color = Color(0.64, 0.30, 0.16) if over_fused() \
					else Color(0.56, 0.33, 0.16)

	# The door stands open through the whole round; it is opened by arriving.
	if _door != null:
		_door.rotation.y = -1.15
		_door.position.x = -0.30
		_door.position.z = 0.36
	# The lamp index runs down the block as the stamp is read.
	if _index != null:
		_index.position.y = 0.20 + 0.30 * clampf(stamp_read, 0.0, 1.0)
		_index.position.x = -0.26 + 0.34 * clampf(stamp_read, 0.0, 1.0)

	# The rejected plug, held at the mouth of a base that will not take it.
	if _offered != null:
		_offered.visible = offered_rating > CONDUCTOR_RATING
		if _offered_mat != null:
			_offered_mat.albedo_color = Color(0.88, 0.50, 0.20)

	# THE REFUSAL POSE. Deterministic and proportional to the balk, never a
	# function of `_t`: a refusal that only exists while the clock runs cannot
	# be photographed, and this apparatus is photographed frozen.
	var balk := clampf(_balk_left, 0.0, 1.0)
	if balk > 0.0:
		if _plug != null:
			_plug.position.y = 0.46 + 0.012 * balk
			_plug.rotation.z = 0.16 * balk
		if _block != null:
			_block.position.y = 0.46 + 0.005 * balk
		if _handle != null:
			_handle.rotation.z += 0.10 * balk


func service_wire_card() -> Dictionary:
	return {
		"title": "HOUSE PANELBOARD",
		"body": "A fuse is sized to the wire behind the wall, not the lamp in "
				+ "front of it. Every plug in the drawer fits every hole, "
				+ "which is the whole danger.",
	}
