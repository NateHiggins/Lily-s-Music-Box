class_name MailChuteProp
extends FunctionalProp
## The lobby mail chute, its choke, and the collection box under it.
##
## SR7-D. The Orison is a 1912 building running in 1928, which is exactly the
## span in which a Cutler chute would have been installed and then had a Cusick
## choke fitted to it in the twenties. Both halves are documented:
##
##   * J. G. CUTLER, US 284,951 (1883). The original multi-floor letter-box
##     connection, first installed in the Elwood Building, Rochester. Its
##     requirements are the useful part: the chute front must be AT LEAST
##     THREE-QUARTERS GLASS so that clogs can be identified; the lobby box is
##     metal, marked "U.S. LETTER BOX", with its door hinged at one side and
##     its bottom not less than two feet six inches above the floor; a chute
##     rising more than two storeys carries an elastic cushion in the
##     receptacle to prevent injury to the mail; and hinged, locked doors along
##     the chute exist so that stuck mail can be dislodged.
##   * J. J. CUSICK, US 1,450,139, filed 12 July 1922, granted 27 March 1923.
##     Cusick's problem statement is this activity's fault, in the period's own
##     words: bulky letters are "bent and compressed" to get through the slot,
##     then expand and jam. His answer is a floor-local auxiliary chute with an
##     expansion chamber above a deliberate CHOKE, so the choke "excludes from
##     the main chute matter that would clog the latter".
##
## THE TRUTH THIS TEACHES. The collection box is empty. That is not evidence.
##
## Two letters that sprang open across the choke are bearing on each other
## corner to corner, and the whole column above stands on that arch. Friction
## and geometry hold it, not weight, so pulling the box empty from below
## changes nothing and neither does shaking the chute. The arch has to be
## FOUND through the glass the 1883 patent put there for the purpose, its load
## has to be taken off before it is broken, and free passage afterwards is
## proved by something arriving -- not by the chute looking empty again.
##
## The transferable verb is `flow`, taken deliberately rather than invented.
## The radiator taught flow as air that must leave a pipe before steam can
## enter. This teaches the same word for solids, where the obstruction does not
## drain away but holds itself up.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: that THIS chute is jammed today,
## the particular two-envelope arch, the catch tray, the blade and the test
## piece are authored. What is NOT claimed is a traversable multi-floor shaft:
## the chute runs up into the lobby ceiling and stops being the player's
## business, because production has no letter slot on any upper landing and
## this apparatus does not invent one.
##
## AUTHORING RULE. Local z = 0 is the wall face and the apparatus is built
## OUTWARD along +z into the lobby, as SR7-A established for this wall run.
##
## OWNERSHIP. This prop owns its own apparatus and nothing else. It moves no
## mail anywhere in the building, simulates no postal round, closes no job,
## advances no case, publishes no Dream fact and adds no save owner. Only
## `apply_maintenance_result` may record the chute clear.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## Cutler's dimension: the lobby box door sits not less than two feet six
## inches above the floor. That is 0.762 m, and it is why the box, the choke
## and the glass all land where a standing hand and eye can reach them.
const BOX_DOOR_MIN := 0.762
## Where the arch has to be cut for the span to fail.
const BLADE_HOME := 0.41
## How far the glass must be drawn for the load to come off the arch.
const DRAW_CLEAR := 0.45

var _service_panel: MaintenanceActivityPanel

var _chute: MeshInstance3D
var _glass: MeshInstance3D
var _choke_w: MeshInstance3D
var _choke_e: MeshInstance3D
var _arch_a: MeshInstance3D
var _arch_b: MeshInstance3D
var _load: MeshInstance3D
var _cover: MeshInstance3D
var _key: MeshInstance3D
var _tray: MeshInstance3D
var _blade: MeshInstance3D
var _box: MeshInstance3D
var _box_door: MeshInstance3D
var _test_piece: MeshInstance3D
var _lamp_index: MeshInstance3D
var _glass_mat: StandardMaterial3D
var _slide: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _draw: AudioStreamPlayer3D
var _snap: AudioStreamPlayer3D
var _balk_left := 0.0
var _t := 0.0

## The apparatus's own facts. `arch_standing` true is the fault, and note what
## it is NOT: nothing is broken, nothing is worn, and the box below is
## perfectly empty. Two letters are simply leaning on each other.
var arch_standing := true
var load_taken := false
var cover_locked := true
var glass_drawn := 0.0
var lamp_scan := 0.0
var blade_set := 0.0
var test_piece_landed := false
var chute_clear := false


# --- the physical model ------------------------------------------------------

## Whether anything posted at the slot can actually reach the box.
func passage_clear() -> bool:
	return not arch_standing


## What the collection box shows. It is empty while the arch stands and empty
## after it falls, which is the whole reason it cannot be used as evidence --
## this function deliberately does not consult `arch_standing`.
func box_appears_empty() -> bool:
	return not test_piece_landed


## A test piece only reaches the box if the passage is clear AND the inspection
## glass is shut; an open glass simply lets the mail out into the lobby.
func drop_reaches_box() -> bool:
	return passage_clear() and glass_drawn <= 0.12


## The load standing on the arch, 0..1. It comes off as the glass is drawn,
## and only once, which is why taking it is its own verb.
func load_on_arch() -> float:
	return 0.0 if load_taken else 1.0


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var iron := Color(0.24, 0.22, 0.20)
	var brass := Color(0.48, 0.38, 0.20)
	var paper := Color(0.74, 0.70, 0.60)

	# THE CHUTE, running up out of the lobby ceiling. It is not a shaft the
	# player can follow and this prop does not pretend otherwise: it is the
	# bottom of one, which is the only part anybody ever services.
	# From just above the collection box to just under the lobby ceiling at
	# 3.02. Where it goes above that is not this prop's claim.
	#
	# A CHANNEL, NOT A SOLID. The first pass made this one box from z 0 to
	# 0.12, which buried the arch inside its own chute: the letters were
	# authored at z 0.06 and simply never rendered. A back and two cheeks
	# leaves the bore open behind the glass, which is the only arrangement in
	# which a three-quarters glass front means anything.
	_chute = make_box(Vector3(0.19, 1.84, 0.028), Vector3(0.0, 2.00, 0.014),
			iron)
	_chute.name = "ChuteBody"
	var cm := _chute.material_override as StandardMaterial3D
	if cm != null:
		cm.metallic = 0.48
		cm.roughness = 0.56
	for cheek_x in [-0.081, 0.081]:
		make_box(Vector3(0.028, 1.84, 0.115), Vector3(cheek_x, 2.00, 0.072),
				iron)

	# THE GLASS FRONT. Three-quarters glass is not decoration -- the 1883
	# patent requires it so that clogs can be identified, and it is the only
	# reason this fault is findable at all.
	_glass = make_box(Vector3(0.135, 1.06, 0.016),
			Vector3(0.0, 1.58, 0.124), Color(0.60, 0.66, 0.64))
	_glass.name = "GlassFront"
	_glass_mat = _glass.material_override as StandardMaterial3D
	if _glass_mat != null:
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.albedo_color = Color(0.60, 0.66, 0.64, 0.30)
		_glass_mat.roughness = 0.06
		_glass_mat.metallic = 0.0
	# The grooves the glass runs in, which is how Cusick's door comes out.
	for groove_x in [-0.082, 0.082]:
		make_box(Vector3(0.016, 1.10, 0.045),
				Vector3(groove_x, 1.58, 0.115), brass)

	# THE CHOKE: two angled cheeks narrowing the passage, with the expansion
	# chamber immediately above them.
	for side in [-1.0, 1.0]:
		var cheek := make_box(Vector3(0.075, 0.10, 0.10),
				Vector3(side * 0.055, 1.30, 0.068), iron)
		cheek.rotation.z = -side * 0.62
		if side < 0.0:
			_choke_w = cheek
			_choke_w.name = "ChokeCheekWest"
		else:
			_choke_e = cheek
			_choke_e.name = "ChokeCheekEast"
	# Cusick's expansion chamber: deliberately wider than the chute below it,
	# so over-thick mail can open out here instead of wedging further down.
	var chamber := make_box(Vector3(0.205, 0.30, 0.030),
			Vector3(0.0, 1.52, 0.016), Color(0.27, 0.25, 0.22))
	chamber.name = "ExpansionChamber"

	# THE ARCH. Two letters that sprang open across the choke and are bearing
	# on each other corner to corner. Neither is holding the other up; they are
	# holding EACH OTHER up, which is why removing one is enough.
	_arch_a = make_box(Vector3(0.115, 0.014, 0.080),
			Vector3(-0.022, 1.325, 0.070), paper)
	_arch_a.name = "ArchLetterWest"
	_arch_a.rotation.z = 0.46
	_arch_b = make_box(Vector3(0.115, 0.014, 0.080),
			Vector3(0.022, 1.335, 0.066), Color(0.70, 0.66, 0.57))
	_arch_b.name = "ArchLetterEast"
	_arch_b.rotation.z = -0.42

	# The loose mail standing on the arch. This is the weight that has to come
	# off before the span is broken.
	_load = make_box(Vector3(0.135, 0.18, 0.090),
			Vector3(0.0, 1.45, 0.068), Color(0.72, 0.68, 0.58))
	_load.name = "LoadStack"

	# THE LOCKING COVER and its key, at the inspection door.
	_cover = make_box(Vector3(0.215, 0.13, 0.030),
			Vector3(0.0, 1.14, 0.128), brass)
	_cover.name = "LockCover"
	_key = make_cyl(0.020, 0.020, 0.034, Vector3(0.0, 1.14, 0.150),
			Color(0.56, 0.46, 0.24), 0.34, 0.62)
	_key.name = "KeyBarrel"
	_key.rotation_degrees.x = 90.0

	# The tray held under the choke, and the blade that breaks the span.
	_tray = make_box(Vector3(0.20, 0.016, 0.14), Vector3(0.0, 1.06, 0.155),
			Color(0.40, 0.36, 0.28))
	_tray.name = "CatchTray"
	_blade = make_box(Vector3(0.028, 0.20, 0.010),
			Vector3(0.16, 1.30, 0.130), Color(0.62, 0.62, 0.58))
	_blade.name = "ClearingBlade"
	var bm := _blade.material_override as StandardMaterial3D
	if bm != null:
		bm.metallic = 0.72
		bm.roughness = 0.26

	# THE COLLECTION BOX. Metal, and its door bottom sits at Cutler's two feet
	# six above the floor, which is where the rest of the apparatus hangs from.
	# A CASE, NOT A SOLID -- and a glazed door, which is how a lobby box shows
	# the mail waiting in it. The first pass made the box one solid block, so
	# the test piece landed inside its own geometry and never rendered: the one
	# frame the whole activity exists to earn showed nothing arriving.
	_box = make_box(Vector3(0.34, 0.42, 0.026),
			Vector3(0.0, BOX_DOOR_MIN + 0.19, 0.014), iron)
	_box.name = "CollectionBox"
	var bxm := _box.material_override as StandardMaterial3D
	if bxm != null:
		bxm.metallic = 0.52
		bxm.roughness = 0.50
	for case_x in [-0.157, 0.157]:
		make_box(Vector3(0.026, 0.42, 0.21),
				Vector3(case_x, BOX_DOOR_MIN + 0.19, 0.105), iron)
	make_box(Vector3(0.34, 0.026, 0.21),
			Vector3(0.0, BOX_DOOR_MIN - 0.005, 0.105), iron)
	make_box(Vector3(0.34, 0.026, 0.21),
			Vector3(0.0, BOX_DOOR_MIN + 0.385, 0.105), iron)
	# The door: a brass frame carrying a glazed panel, hinged at one side as
	# the regulation asks. The glass is why an arrival is evidence.
	_box_door = make_box(Vector3(0.28, 0.30, 0.014),
			Vector3(0.0, BOX_DOOR_MIN + 0.18, 0.206), Color(0.58, 0.64, 0.62))
	_box_door.name = "BoxDoor"
	var dm := _box_door.material_override as StandardMaterial3D
	if dm != null:
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(0.58, 0.64, 0.62, 0.26)
		dm.roughness = 0.08
	for frame in [[0.30, 0.024, 0.0, 0.145], [0.30, 0.024, 0.0, -0.145],
			[0.024, 0.32, -0.147, 0.0], [0.024, 0.32, 0.147, 0.0]]:
		make_box(Vector3(frame[0], frame[1], 0.024),
				Vector3(frame[2], BOX_DOOR_MIN + 0.18 + frame[3], 0.210),
				brass)
	# The legend plate the regulation asks for.
	make_box(Vector3(0.20, 0.045, 0.008),
			Vector3(0.0, BOX_DOOR_MIN + 0.375, 0.212), brass)

	# The test piece, which lives in the box only once it has arrived there.
	# Bigger than a real envelope on purpose: this is the one arrival the whole
	# chain exists to produce, and it sits right behind the door glass where it
	# can be seen from the lobby floor.
	_test_piece = make_box(Vector3(0.175, 0.014, 0.115),
			Vector3(0.0, BOX_DOOR_MIN + 0.075, 0.168),
			Color(0.88, 0.85, 0.75))
	_test_piece.name = "TestPiece"
	_test_piece.visible = false

	# The lamp index run up the glass to find the clog.
	_lamp_index = make_box(Vector3(0.045, 0.022, 0.030),
			Vector3(0.115, 1.06, 0.140), brass)
	_lamp_index.name = "LampIndex"

	_slide = make_emitter("thud", -14.0)     # the piece landing in the box
	_knock = make_emitter("knock", -14.0)    # the refusal, and mail on glass
	_draw = make_emitter("creak", -16.0)     # the glass in its grooves
	_snap = make_emitter("pop", -15.0)       # the span letting go
	_build_chute_reach()
	_refresh_mechanism()


## The service point, over the choke and its cover, at a standing hand's
## height. Built in the visual pass so the base class finds an authored area
## and does not wrap the whole chute in a coarser one.
func _build_chute_reach() -> void:
	var reach := ControlArea.new()
	reach.name = "ChuteReach"
	reach.configure("chute")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 0.72, 0.34)
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 1.26, 0.14)
	reach.add_child(shape_node)
	add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	if control_id != "chute":
		return ""
	if arch_standing:
		return "[E]  The mail chute is choked"
	return "[E]  Check the mail chute"


func interact_control(control_id: String, player: Node) -> bool:
	if control_id != "chute":
		return false
	return _begin_chute_service(player)


func interact(player: Node) -> void:
	_begin_chute_service(player)


func _begin_chute_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "mail_chute_choke_clearing"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"arch_standing": arch_standing, "load_taken": load_taken,
			"cover_locked": cover_locked, "glass_drawn": glass_drawn,
			"lamp_scan": lamp_scan, "blade_set": blade_set,
			"test_piece_landed": test_piece_landed,
			"chute_clear": chute_clear}


## Reversible. Working the visible apparatus moves the visible apparatus and
## publishes nothing: `chute_clear` is deliberately untouched here and moves
## only in `apply_maintenance_result`.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"read_the_glass":
			lamp_scan = worked
		"unlock_the_cover":
			cover_locked = worked < 0.5
		"take_the_load":
			if cover_locked:
				# The glass cannot move in its grooves under a locked cover.
				_balk(0.9)
			else:
				var was := glass_drawn
				glass_drawn = worked
				if absf(worked - was) > 0.02:
					if _draw != null and not _draw.playing:
						_draw.play()
				if worked >= DRAW_CLEAR:
					load_taken = true
		"break_the_arch":
			if cover_locked:
				_balk(0.9)
			elif not load_taken:
				# THE DANGEROUS ORDER. Everything above is standing on this
				# span. Cut it with the load still on and the whole column
				# comes down the chute at once, past the open inspection door
				# and into the lobby.
				_balk(1.5)
			else:
				blade_set = worked
				if absf(worked - BLADE_HOME) <= 0.06:
					var was_standing := arch_standing
					arch_standing = false
					if was_standing and _snap != null:
						_snap.play()
		"prove_the_drop":
			# Posting a test piece shuts the glass first, because a chute with
			# its inspection door open does not deliver anything to the box.
			glass_drawn = 0.0
			if arch_standing:
				# It hangs at the choke, exactly where the last fortnight of
				# post has been hanging.
				test_piece_landed = false
				_balk(1.2)
			else:
				test_piece_landed = worked >= 0.5
				if test_piece_landed and _slide != null:
					_slide.play()
	_refresh_mechanism()


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	arch_standing = bool(snapshot.get("arch_standing", arch_standing))
	load_taken = bool(snapshot.get("load_taken", load_taken))
	cover_locked = bool(snapshot.get("cover_locked", cover_locked))
	glass_drawn = float(snapshot.get("glass_drawn", glass_drawn))
	lamp_scan = float(snapshot.get("lamp_scan", lamp_scan))
	blade_set = float(snapshot.get("blade_set", blade_set))
	test_piece_landed = bool(snapshot.get("test_piece_landed",
			test_piece_landed))
	chute_clear = bool(snapshot.get("chute_clear", chute_clear))
	_balk_left = 0.0
	_refresh_mechanism()


## The only guarded publication. Nothing above this line records the chute
## clear.
func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if patch.has("arch_standing"):
		arch_standing = bool(patch["arch_standing"])
	if patch.has("load_taken"):
		load_taken = bool(patch["load_taken"])
	if patch.has("cover_locked"):
		cover_locked = bool(patch["cover_locked"])
	if patch.has("glass_drawn"):
		glass_drawn = clampf(float(patch["glass_drawn"]), 0.0, 1.0)
	if patch.has("chute_clear"):
		# A chute is not clear because a data file says so. It is clear when
		# nothing is standing in it, and the apparatus is the last word.
		chute_clear = bool(patch["chute_clear"]) and passage_clear()
	lamp_scan = 0.0
	blade_set = 0.0
	_balk_left = 0.0
	_refresh_mechanism()
	maintenance_completed.emit(result.duplicate(true))


# --- the readable refusal ----------------------------------------------------

## A balk is a knock in the ironwork and a visible shudder in the standing
## mail. `design/PROP_ACTIVITIES.md` forbids a silent false; this is the honest
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
	if _arch_a == null:
		return
	# THE ARCH. While it stands the two letters bear on each other across the
	# choke. When it goes they drop out of the throat and lie flat -- they do
	# not vanish, because the mail is still mail.
	var standing := 1.0 if arch_standing else 0.0
	_arch_a.position.y = 1.325 - 0.30 * (1.0 - standing)
	_arch_b.position.y = 1.335 - 0.32 * (1.0 - standing)
	_arch_a.rotation.z = lerpf(0.02, 0.46, standing)
	_arch_b.rotation.z = lerpf(-0.03, -0.42, standing)
	_arch_a.position.x = lerpf(-0.048, -0.022, standing)
	_arch_b.position.x = lerpf(0.046, 0.022, standing)

	# The load standing on the arch comes off with the glass, once.
	if _load != null:
		_load.visible = not load_taken
		_load.position.y = 1.44 + 0.02 * sin(_t * 2.0) * standing

	# The glass rides up its grooves.
	if _glass != null:
		_glass.position.y = 1.58 + 0.62 * clampf(glass_drawn, 0.0, 1.0)
	# The cover and its key.
	if _key != null:
		_key.rotation.z = 0.0 if cover_locked else 1.30
	if _cover != null:
		_cover.position.z = 0.128 + 0.018 * (0.0 if cover_locked else 1.0)

	# The tray comes up under the choke while the load is being taken.
	if _tray != null:
		var catching := clampf(glass_drawn / maxf(DRAW_CLEAR, 0.001),
				0.0, 1.0) if not load_taken else 1.0
		_tray.position.y = 1.06 + 0.14 * catching
		_tray.visible = glass_drawn > 0.05 or load_taken

	# The blade goes in at the corner where the two letters bear.
	if _blade != null:
		_blade.position.x = 0.16 - 0.20 * clampf(blade_set, 0.0, 1.0)
		_blade.visible = blade_set > 0.02 or not arch_standing

	# The lamp index runs up the glass.
	if _lamp_index != null:
		_lamp_index.position.y = 1.06 + 1.02 * clampf(lamp_scan, 0.0, 1.0)

	# The test piece, in the box or not at all.
	if _test_piece != null:
		_test_piece.visible = test_piece_landed

	if _balk_left > 0.0:
		var shake := sin(_t * 46.0) * 0.006 * clampf(_balk_left, 0.0, 1.0)
		_arch_a.position.y += shake
		_arch_b.position.y -= shake
		if _load != null:
			_load.position.y += shake * 1.6


func service_wire_card() -> Dictionary:
	return {
		"title": "MAIL CHUTE AND CHOKE",
		"body": "The front is three-quarters glass by regulation, so a clog "
				+ "can be found. An empty box downstairs is not the same "
				+ "thing as a clear chute.",
	}
