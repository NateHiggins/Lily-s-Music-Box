class_name DomesticWitnessClock
extends FunctionalProp
## A familiar clock that behaves like it remembers the room differently.
## Static housing is cheap procedural geometry; hands, face and tell are kept
## separate so the director can animate them without cloth, particles or
## per-prop skeletal rigs.

var case_id := ""
var resident := ""
var style := "bauhaus"
var tell := "correction"
var frozen_time := "04:17"
var accent := Color(0.7, 0.2, 0.2)
var mounting := "wall"

var _hour: Node3D
var _minute: Node3D
var _second: Node3D
var _face: Node3D
var _tell_mark: Node3D
var _display: Label3D
var _tick: AudioStreamPlayer3D
var _home_rotation := 0.0
var _haunt_tween: Tween
var _possessed := false
## Printed dial faces. Two atlases in the same cell order, so possession
## is a texture swap rather than a rebuild: the wrongness lands on the
## same dial the player has been reading all night.
const DIAL_HONEST := "res://assets/building/textures/clocks/dials_honest.png"
const DIAL_WRONG := "res://assets/building/textures/clocks/dials_possessed.png"
const DIAL_INDEX := {
	"schoolhouse": [0, 0], "hospital": [1, 0], "bauhaus": [2, 0],
	"stitch": [3, 0], "vantry_modular": [0, 1], "sunray_1920": [1, 1],
	"industrial": [2, 1], "railway": [3, 1], "courier": [0, 2],
	"mantel": [1, 2], "architect": [2, 2], "palette": [3, 2],
}
var _dial_mat: StandardMaterial3D
var _tick_accum := 0.0
var _tick_interval := 1.0


func configure(spec: Dictionary) -> void:
	prop_type = "wall_clock"
	case_id = str(spec.case_id)
	resident = str(spec.resident)
	style = str(spec.style)
	tell = str(spec.tell)
	frozen_time = str(spec.time)
	accent = Color.from_string(str(spec.accent), Color(0.7, 0.2, 0.2))


func _ready() -> void:
	name = "DomesticWitness_%s" % case_id
	add_to_group("domestic_witness_clocks")
	add_to_group("reality_affected_props")
	super._ready()
	_home_rotation = rotation.y


func _build_visual() -> void:
	_face = Node3D.new()
	_face.name = "FaceRig"
	add_child(_face)
	_build_housing()
	_build_face()
	_build_hands()
	_build_collision()
	_tick = make_emitter("tick", -31.0)
	_tick.max_distance = 5.5
	# The witness faces used to be hundreds of individually submitted flat
	# primitives.  Semantic finishes make them belong to the same material
	# world as the ordinary clocks, then the immobile carcass collapses by
	# finish.  FaceRig and the tell remain independent because the case system
	# moves them; clear glass is deliberately optical, never a baked bitmap.
	var body := _style_body_color()
	var body_key := "oak_quartered" if style in ["schoolhouse", "sunray_1920",
			"mantel"] else ("nickel_plated" if style in ["travel_alarm",
			"architect", "industrial"] else ("bakelite_black" if style in [
			"vantry_modular", "nixie", "railway", "writer"] else "enamel"))
	retexture(self, [
		[body, body_key, Color.WHITE],
		[body.darkened(0.15), body_key, Color(0.76, 0.72, 0.66)],
		[body.darkened(0.25), body_key, Color(0.64, 0.60, 0.55)],
		[body.darkened(0.30), body_key, Color(0.58, 0.55, 0.50)],
		[Color(0.88, 0.86, 0.78), "paper", Color(0.90, 0.85, 0.74)],
		[Color(0.025, 0.03, 0.032), "bakelite_black", Color(0.55, 0.55, 0.55)],
		[Color(0.46, 0.43, 0.36), "brass_dull", Color(0.77, 0.71, 0.55)],
		[Color(0.62, 0.46, 0.16), "brass_dull", Color(0.91, 0.72, 0.36)],
		[accent, "enamel", accent], [accent.darkened(0.25), "enamel", accent],
	])
	merge_static(self, [_face, _tell_mark])


func _style_body_color() -> Color:
	match style:
		"hospital": return Color(0.76, 0.79, 0.75)
		"vantry_modular": return Color(0.10, 0.12, 0.16)
		"sunray_1920": return Color(0.30, 0.20, 0.10)
		"travel_alarm": return Color(0.47, 0.48, 0.46)
		"palette": return Color(0.83, 0.72, 0.57)
		"nixie": return Color(0.055, 0.06, 0.065)
		"deco": return Color(0.08, 0.13, 0.12)
		"schoolhouse": return Color(0.34, 0.21, 0.11)
		"bauhaus": return Color(0.90, 0.90, 0.88)
		"stitch": return Color(0.80, 0.74, 0.64)
		"industrial": return Color(0.30, 0.32, 0.33)
		"studio": return Color(0.18, 0.18, 0.19)
		"railway": return Color(0.07, 0.07, 0.08)
		"courier": return Color(0.28, 0.28, 0.30)
		"mantel": return Color(0.26, 0.16, 0.10)
		"architect": return Color(0.72, 0.70, 0.66)
		"split_flap": return Color(0.82, 0.78, 0.68)
		"writer": return Color(0.09, 0.09, 0.10)
	return Color(0.11, 0.105, 0.095)


func _build_housing() -> void:
	var body_color := Color(0.11, 0.105, 0.095)
	var metal := Color(0.46, 0.43, 0.36)
	# Eighteen residents, eighteen clocks, and only seven of them had a
	# case. The other eleven fell through to this near-black default and
	# hung on the wall as unstyled dark discs - the "clock remnants".
	# Each one below is a real type somebody would actually own, chosen
	# to agree with whose wall it is on.
	match style:
		"hospital": body_color = Color(0.76, 0.79, 0.75)
		# These three display or synchronise a signal, so VIII.2 licenses
		# precision hardware no later than 1967.  This is not a general
		# licence for their neighbours: Malcolm's mechanical sunray and the
		# guests' travelling alarm carry nothing and remain honest 1927.
		"vantry_modular": body_color = Color(0.10, 0.12, 0.16)
		"sunray_1920": body_color = Color(0.30, 0.20, 0.10)
		"travel_alarm": body_color = Color(0.47, 0.48, 0.46)
		"palette": body_color = Color(0.83, 0.72, 0.57)
		"nixie": body_color = Color(0.055, 0.06, 0.065)
		"deco": body_color = Color(0.08, 0.13, 0.12)
		# oak schoolhouse regulator, the clock a proofreader trusts
		"schoolhouse": body_color = Color(0.34, 0.21, 0.11)
		# Bauhaus wall clock: white dial, chrome ring, no numerals at all
		"bauhaus": body_color = Color(0.90, 0.90, 0.88)
		# a face set into an embroidery hoop, pale beech
		"stitch": body_color = Color(0.80, 0.74, 0.64)
		# caged industrial shop clock, painted steel
		"industrial": body_color = Color(0.30, 0.32, 0.33)
		# a VU meter that happens to tell the time
		"studio": body_color = Color(0.18, 0.18, 0.19)
		# station regulator, black enamel and a red sweep hand
		"railway": body_color = Color(0.07, 0.07, 0.08)
		# a bicycle sprocket with hands through it
		"courier": body_color = Color(0.28, 0.28, 0.30)
		# walnut tambour, the camelback on somebody's shelf since 1931
		"mantel": body_color = Color(0.26, 0.16, 0.10)
		# exposed movement on brass standoffs, drafting-triangle markers
		"architect": body_color = Color(0.72, 0.70, 0.66)
		# 1970s split-flap in cream plastic
		"split_flap": body_color = Color(0.82, 0.78, 0.68)
		# typewriter-black case with a paper dial
		"writer": body_color = Color(0.09, 0.09, 0.10)
	var radius := 0.19
	if style in ["nixie", "split_flap", "writer", "travel_alarm", "studio",
			"vantry_modular"]:
		make_box(Vector3(0.42, 0.22, 0.055), Vector3(0, 0, 0), body_color)
	else:
		var shell := make_cyl(radius, radius, 0.05, Vector3.ZERO,
				body_color, 0.38, 0.15)
		shell.rotation_degrees.x = 90
	# Design-language silhouette details, kept restrained and low-poly.
	if style == "sunray_1920":
		for i in 12:
			var a := TAU * i / 12.0
			var spoke := make_box(Vector3(0.018, 0.13, 0.018),
					Vector3(sin(a) * 0.245, cos(a) * 0.245, 0.01), metal)
			spoke.rotation.z = -a
	if style == "deco":
		for x in [-0.17, 0.17]:
			var fin := make_box(Vector3(0.025, 0.28, 0.025),
					Vector3(x, 0, 0.008), accent.darkened(0.25))
			fin.rotation.z = x * 1.4
	if style == "courier":
		make_box(Vector3(0.30, 0.025, 0.025), Vector3(0, -0.215, 0), accent)
	if style == "stitch":
		for i in 8:
			var stitch := make_box(Vector3(0.025, 0.008, 0.012),
					Vector3(-0.13 + i * 0.037, -0.18, 0.033), accent)
			stitch.rotation.z = 0.18
		# the hoop's tightening screw, at the top where it always is
		make_box(Vector3(0.05, 0.035, 0.03), Vector3(0, 0.205, 0.0),
				Color(0.55, 0.52, 0.45))
	if style == "schoolhouse":
		# octagonal bezel over the round movement, then the drop case
		for i in 8:
			var a := TAU * i / 8.0 + PI / 8.0
			var seg := make_box(Vector3(0.155, 0.030, 0.055),
					Vector3(sin(a) * 0.196, cos(a) * 0.196, 0.0),
					body_color.darkened(0.15))
			seg.rotation.z = -a
		make_box(Vector3(0.17, 0.30, 0.055), Vector3(0, -0.33, 0.0),
				body_color)
		# The wall itself is the dark field behind this open economy case.  A
		# second backing plate added a draw without changing the silhouette.
		var bob := make_cyl(0.045, 0.045, 0.012, Vector3(0, -0.38, 0.034),
				Color(0.62, 0.46, 0.16), 0.34, 0.75)
		bob.rotation_degrees.x = 90
	if style == "bauhaus":
		var ring := make_cyl(0.205, 0.205, 0.016, Vector3(0, 0, 0.020),
				Color(0.86, 0.87, 0.88), 0.18, 0.9)
		ring.rotation_degrees.x = 90
	if style == "industrial":
		# the wire guard that stops a ladder going through the glass
		for i in 3:
			var a2 := PI * i / 3.0
			var bar := make_box(Vector3(0.006, 0.40, 0.006),
					Vector3(0, 0, 0.050), Color(0.42, 0.44, 0.45))
			bar.rotation.z = a2
		for i in 6:
			var a3 := TAU * i / 6.0
			make_cyl(0.010, 0.010, 0.010,
					Vector3(sin(a3) * 0.175, cos(a3) * 0.175, 0.026),
					Color(0.52, 0.54, 0.55), 0.3, 0.8).rotation_degrees.x = 90
	if style == "railway":
		var bezel := make_cyl(0.212, 0.212, 0.030, Vector3(0, 0, 0.012),
				Color(0.05, 0.05, 0.06), 0.42, 0.2)
		bezel.rotation_degrees.x = 90
		make_box(Vector3(0.06, 0.09, 0.05), Vector3(0, -0.225, -0.02),
				Color(0.09, 0.09, 0.10))
	if style == "courier":
		# sprocket teeth around the rim
		for i in 16:
			var a4 := TAU * i / 16.0
			var tooth := make_box(Vector3(0.020, 0.034, 0.028),
					Vector3(sin(a4) * 0.203, cos(a4) * 0.203, 0.0),
					Color(0.44, 0.45, 0.47))
			tooth.rotation.z = -a4
	if style == "mantel":
		# tambour: a low arch on a shelf, not a disc on a nail
		make_box(Vector3(0.46, 0.16, 0.11), Vector3(0, -0.11, 0.0),
				body_color)
		for i in 5:
			var t := (i - 2.0) / 2.0
			make_box(Vector3(0.085, 0.055 - absf(t) * 0.018, 0.11),
					Vector3(t * 0.155, 0.005 + (1.0 - absf(t)) * 0.035, 0.0),
					body_color)
		make_box(Vector3(0.52, 0.028, 0.15), Vector3(0, -0.20, 0.0),
				body_color.darkened(0.25))
		for fx in [-0.19, 0.19]:
			make_box(Vector3(0.035, 0.03, 0.035), Vector3(fx, -0.225, 0.03),
					Color(0.55, 0.42, 0.16))
	if style == "architect":
		# exposed movement on brass standoffs, and a set square
		for sx2 in [-1.0, 1.0]:
			for sy2 in [-1.0, 1.0]:
				var post := make_cyl(0.008, 0.008, 0.055,
						Vector3(sx2 * 0.135, sy2 * 0.135, -0.028),
						Color(0.60, 0.45, 0.16), 0.3, 0.8)
				post.rotation_degrees.x = 90
		var tri := make_box(Vector3(0.16, 0.012, 0.012),
				Vector3(0.02, -0.135, 0.034), accent)
		tri.rotation.z = -0.52
	if style == "split_flap":
		# the split across the middle is the whole idea
		make_box(Vector3(0.40, 0.006, 0.062), Vector3(0, 0, 0.0),
				Color(0.20, 0.19, 0.17))
		make_box(Vector3(0.30, 0.035, 0.08), Vector3(0, -0.125, 0.0),
				body_color.darkened(0.30))
	if style == "travel_alarm":
		# Cheap nickel travelling alarm, hinged into its own folding case.
		# It packs because 4D's occupants do; no wire and no signal licence.
		var cover := make_box(Vector3(0.32, 0.20, 0.018),
				Vector3(0, -0.155, -0.065), body_color.darkened(0.18))
		cover.rotation.x = -0.62
		make_box(Vector3(0.30, 0.018, 0.018), Vector3(0, -0.115, -0.035),
				Color(0.62, 0.60, 0.52))
	if style == "nixie":
		# Four warm cathode tubes behind one smoked aperture; never an LED.
		for nx in [-0.115, -0.038, 0.038, 0.115]:
			make_box(Vector3(0.052, 0.105, 0.018), Vector3(nx, 0, 0.036),
					Color(0.11, 0.055, 0.025))
	if style == "writer":
		# platen knobs, because it is made from a typewriter
		for kx in [-0.225, 0.225]:
			var knob := make_cyl(0.032, 0.032, 0.030, Vector3(kx, 0, 0.0),
					Color(0.14, 0.13, 0.12), 0.5, 0.2)
			knob.rotation_degrees.z = 90


func _build_face() -> void:
	var face_color := Color(0.88, 0.86, 0.78)
	if style in ["nixie", "split_flap", "writer", "travel_alarm"]:
		face_color = Color(0.025, 0.03, 0.032)
		make_box(Vector3(0.34, 0.13, 0.008), Vector3(0, 0, 0.033), face_color)
	else:
		var face_disc := make_cyl(0.158, 0.158, 0.008,
				Vector3(0, 0, 0.031), face_color, 0.82)
		face_disc.rotation_degrees.x = 90
		_build_printed_dial()
		for i in 12:
			var a := TAU * float(i) / 12.0
			var long_mark := i % 3 == 0
			var mark := make_box(Vector3(0.010 if long_mark else 0.006,
					0.028 if long_mark else 0.014, 0.006),
					Vector3(sin(a) * 0.126, cos(a) * 0.126, 0.041),
					accent if long_mark else Color(0.17, 0.16, 0.14))
			mark.rotation.z = -a
	# A Label3D dot is still a physical-looking painted tell in the frame, but
	# it does not spend a separate submitted mesh on all eighteen clocks.
	# It must stay independent because the case system reveals it.
	var tell_label := Label3D.new()
	tell_label.text = "•"
	tell_label.font_size = 26
	tell_label.pixel_size = 0.0012
	tell_label.modulate = accent
	tell_label.position = Vector3(0, -0.112, 0.048)
	_tell_mark = tell_label
	add_child(_tell_mark)
	_tell_mark.visible = false
	_display = Label3D.new()
	_display.text = frozen_time if style in ["nixie", "split_flap", "writer", "travel_alarm"] else ""
	_display.font_size = 46
	_display.pixel_size = 0.0024
	_display.position = Vector3(0, -0.005, 0.043)
	_display.modulate = accent.lightened(0.18)
	_display.outline_size = 5
	_display.outline_modulate = Color(0, 0, 0, 0.85)
	_face.add_child(_display)


## The dial itself: a printed face on a quad just proud of the disc.
##
## Cut to a circle in the atlas rather than trimmed here, so the square
## corners of the cell never appear over the bezel. Styles with no cell -
## the boxed digitals, deco - keep their plain disc and their Label3D.
func _build_printed_dial() -> void:
	if not DIAL_INDEX.has(style):
		return
	var cell: Array = DIAL_INDEX[style]
	_dial_mat = StandardMaterial3D.new()
	# Crop with UV scale/offset, not AtlasTexture. An AtlasTexture region
	# is honoured by the 2D pipeline; on a 3D material the mesh's own UVs
	# still address the whole image, so every clock wore all twelve dials
	# at once.
	_dial_mat.albedo_texture = load(DIAL_HONEST)
	_dial_mat.uv1_scale = Vector3(1.0 / 4.0, 1.0 / 3.0, 1.0)
	_dial_mat.uv1_offset = Vector3(int(cell[0]) / 4.0, int(cell[1]) / 3.0, 0.0)
	_dial_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dial_mat.roughness = 0.72
	_dial_mat.texture_filter = 			BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad := MeshInstance3D.new()
	quad.name = "Dial"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.316, 0.316)
	quad.mesh = qm
	quad.material_override = _dial_mat
	quad.position = Vector3(0, 0, 0.036)
	_face.add_child(quad)


## Swap the printed face for its wrong twin. Same cell, same layout, same
## typography - one detail moved. The player is not shown a new object,
## they are shown the object they know, disagreeing.
func _set_dial_possessed(wrong: bool) -> void:
	if _dial_mat == null or not DIAL_INDEX.has(style):
		return
	# Same cell, other sheet: the UV window never moves, only the image
	# behind it, so the dial the player knows is the dial that goes wrong.
	_dial_mat.albedo_texture = load(DIAL_WRONG if wrong else DIAL_HONEST)


func _build_hands() -> void:
	if style in ["nixie", "split_flap", "writer", "travel_alarm"]:
		return
	_hour = _hand("HourHand", 0.080, 0.012, 0.052)
	_minute = _hand("MinuteHand", 0.118, 0.008, 0.055)
	_second = _hand("SecondHand", 0.132, 0.004, 0.059, accent)
	_set_hand_time(frozen_time)


func _hand(title: String, length: float, width: float, depth: float,
		color := Color(0.08, 0.075, 0.07)) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = title
	_face.add_child(pivot)
	var blade := make_box(Vector3(width, length, 0.006),
			Vector3(0, length * 0.42, depth), color)
	remove_child(blade)
	pivot.add_child(blade)
	return pivot


func _set_hand_time(value: String) -> void:
	if _hour == null or "_" in value:
		return
	var parts := value.split(":")
	var h := float(parts[0].to_int() % 12)
	var m := float(parts[1].to_int())
	_hour.rotation.z = -TAU * (h + m / 60.0) / 12.0
	_minute.rotation.z = -TAU * m / 60.0
	_second.rotation.z = 0.0


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WitnessBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.44, 0.34, 0.08)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _process(delta: float) -> void:
	_tick_accum += delta
	var target := 1.0 if not _possessed else 60.0 / maxf(48.0, Conductor.bpm)
	_tick_interval = lerpf(_tick_interval, target, minf(1.0, delta * 0.8))
	if _tick_accum >= _tick_interval:
		_tick_accum = fmod(_tick_accum, _tick_interval)
		if _tick and not _tick.playing:
			_tick.pitch_scale = 0.96 + rng.randf_range(-0.025, 0.025)
			_tick.play()
	if not _possessed:
		_show_live_time()


## An honest clock, until the building takes it.
##
## These used to sit permanently at their resident's frozen_time - 04:17
## on Evelyn's wall from the moment the game loaded, before anything had
## gone wrong. That spends the anomaly before it is earned: a clock that
## has always been wrong is scenery, and the player has no reading to
## measure the wrongness against.
##
## So the clock keeps real time, and frozen_time becomes what it reads
## WRONG once possession starts. Eighteen clocks agreeing with each other
## and with the player's own night is what makes one of them disagreeing
## mean something.
func _show_live_time() -> void:
	var t := Time.get_time_dict_from_system()
	var h := float(int(t.hour) % 12)
	var m := float(t.minute)
	var sec := float(t.second)
	if _display and style in ["nixie", "split_flap", "writer", "travel_alarm"]:
		_display.text = "%02d:%02d" % [int(t.hour) % 12 if int(t.hour) % 12 				else 12, int(t.minute)]
	if _hour == null:
		return
	_hour.rotation.z = -TAU * (h + m / 60.0) / 12.0
	_minute.rotation.z = -TAU * (m + sec / 60.0) / 60.0
	if _second:
		_second.rotation.z = -TAU * sec / 60.0


func stage_haunt(tier: int, player: Node3D) -> bool:
	if tier < 1 or _possessed:
		return false
	var watched := _is_watched(player)
	# While watched, only sound can be wrong. Visible mechanical movement is
	# reserved for the rare address rung; otherwise the player discovers it.
	if watched and tier < 4:
		_whisper_tick(tier)
		return true
	_possessed = true
	state = PState.INFECTED
	_set_dial_possessed(true)
	if _haunt_tween:
		_haunt_tween.kill()
	_haunt_tween = create_tween()
	_apply_tell(tier)
	_haunt_tween.tween_interval(9.0 + tier * 2.5)
	_haunt_tween.tween_callback(_restore)
	return true


func _apply_tell(tier: int) -> void:
	var turns := deg_to_rad(6.0 + tier * 4.0)
	match tell:
		"correction", "pending": _rewind_minutes(1 + tier * 2)
		"call_bell":
			if _minute:
				_minute.rotation.z += PI
			else:
				_flash_display("02:36")
		"label_time": _flash_display("YOU: NOW")
		"loose_second":
			if _second: _second.rotation.z = PI * 0.92
		"sample_skip": _rewind_minutes(4); _whisper_tick(tier + 2)
		"last_minute": _flash_display("05:42"); _rewind_minutes(1)
		"new_fault": _tell_mark.visible = true; rotation.z = turns * 0.25
		"listen_back": _rewind_minutes(3); _whisper_tick(tier + 3)
		"level": rotation.z = turns
		"untouched": _tell_mark.visible = true; _face.rotation.y = PI
		"checkout": _flash_display("11:00")
		"egress": rotation.z = -turns; _flash_display("NO EXIT")
		"broadcast": _flash_display("11:57"); _whisper_tick(tier + 4)
		"audience": _tell_mark.visible = true; _face.scale = Vector3(1.0 + tier * 0.025, 1.0, 1.0)
		"delay": _flash_display("-00:07")
		"unfinished": _flash_display("09:__")
		"two_histories": _flash_display("03:16 / 04:17"); rotation.z = turns * 0.35
		_: _rewind_minutes(tier)


func _rewind_minutes(amount: int) -> void:
	if _minute:
		_minute.rotation.z += TAU * float(amount) / 60.0
	if _hour:
		_hour.rotation.z += TAU * float(amount) / 720.0


func _flash_display(value: String) -> void:
	if _display:
		_display.text = value
	_tell_mark.visible = true


func _whisper_tick(tier: int) -> void:
	if _tick == null:
		return
	for i in mini(6, tier + 1):
		await get_tree().create_timer(0.11 + i * 0.035, false).timeout
		if is_instance_valid(_tick):
			_tick.pitch_scale = 0.78 + i * 0.035
			_tick.play()


func _restore() -> void:
	_possessed = false
	_set_dial_possessed(false)
	state = PState.OPERATING
	rotation.y = _home_rotation
	rotation.z = 0.0
	_face.rotation = Vector3.ZERO
	_face.scale = Vector3.ONE
	_tell_mark.visible = false
	_display.text = frozen_time if style in ["nixie", "split_flap", "writer", "travel_alarm"] else ""
	_set_hand_time(frozen_time)


func _is_watched(player: Node3D) -> bool:
	if player == null:
		return false
	var candidate = player.get("camera")
	if not (candidate is Camera3D):
		return false
	var camera: Camera3D = candidate
	if not camera.is_position_in_frustum(global_position):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
			global_position)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(global_position) < 0.5


func _perform_synced_event(_index: int, accent_strength: float,
		_pitch: float) -> void:
	if _second:
		_second.rotation.z -= (TAU / 60.0) * clampf(accent_strength, 0.2, 1.0)
