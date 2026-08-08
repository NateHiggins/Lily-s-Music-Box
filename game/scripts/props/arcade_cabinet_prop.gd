class_name ArcadeCabinetProp
extends FunctionalProp
## The part of an arcade cabinet that has a state: the picture, the marquee, the
## glow, and the switch.
##
## The carcass, the coin door, the vents, the feet and the three buttons are
## `asm_arcade_cab` in the merged floor mesh, in one of four silhouettes. That
## assembly leaves the screen as flat dark "screen" material on purpose - its own
## comment says the glow is the Godot prop's job - so this prop hangs a live
## SubViewport where the dark glass is and lets the machine behind it run.
##
## What is running is a compiled World Package: a semantic scene of pure gameplay
## plus a skin generated offline from a natural-language prompt. Every cabinet on
## the row runs `arcade_pit`, the same one, certified byte-identical by
## `worldc invariance` before the catalog was written. THE FRANCHISE is a
## management sim. APEX RUN is a racing game. MOVEMENT STUDY is sixty tracks of
## rhythm with no combat in it. They are one corridor with a sidearm in it, three
## times, wearing three coats of paint.
##
## Nobody is told this. The marquee makes its claim in good faith and the attract
## copy backs it up, over live footage of the shooting. That is the whole joke and
## it needs no narrator.
##
## THE EXTRA CONTROLS ARE THE JOKE MADE PHYSICAL. A cabinet claiming to be a
## driving game gets a wheel bolted to the panel; a trackball sim gets a
## trackball. The game reads a stick and one button regardless, so those controls
## are furniture, and they are furniture in exactly the way the genre on the
## marquee is.
##
## Under reality infection the picture goes first and the world goes second: the
## CRT faults come up, then the compiled skin lifts off entity by entity until
## what is on the screen is the authored graybox. The lie fails before the level
## does, because the level was never the lie.

signal played

## Blender-space geometry of `asm_arcade_cab`, per variant, so the picture lands
## exactly on the dark glass the assembly left for it. Read straight off
## art/blender/scripts/build_orison.py - if that function is edited, these move.
const _VARIANTS := [
	{"w": 0.66, "d": 0.72, "h": 1.83, "sz0": 1.10, "sz1": 1.48, "marquee": [1.67, 1.81]},
	{"w": 0.66, "d": 0.72, "h": 1.90, "sz0": 1.14, "sz1": 1.55, "marquee": [1.68, 1.90]},
	{"w": 0.66, "d": 0.72, "h": 1.72, "sz0": 1.02, "sz1": 1.38, "marquee": [1.56, 1.70]},
	{"w": 0.60, "d": 0.60, "h": 1.45, "sz0": 0.84, "sz1": 1.12, "marquee": []},
]

## An older machine has a worse picture, and that is the only thing `era` is
## allowed to drive here - the silhouette belongs to the layout's variant, not to
## the catalog. (scanline, base flicker, base chroma)
const _ERA_PICTURE := {
	"1979":   [0.42, 0.10, 0.09],
	"1985":   [0.36, 0.07, 0.06],
	"1991":   [0.30, 0.04, 0.04],
	"1998":   [0.26, 0.03, 0.02],
	"2004":   [0.20, 0.01, 0.01],
	"modern": [0.14, 0.00, 0.00],
}

var cabinet: Dictionary = {}
var machine: ArcadeMachine = null
var variant := 0

var _shape: Dictionary = _VARIANTS[0]
var _picture: Array = [0.30, 0.04, 0.04]
var _screen: MeshInstance3D
var _screen_mat: ShaderMaterial
var _glow: OmniLight3D
var _marquee_light: OmniLight3D
var _panel_ui: Node = null
var _catalog_dir := ArcadeCatalog.DIR
var _infection := 0.0
var _live := false
var _knock := 0.0


## Called before the prop enters the tree, by whatever is laying out the row.
func configure(entry: Dictionary, cab_variant: int, catalog_dir := ArcadeCatalog.DIR) -> void:
	cabinet = entry
	variant = posmod(cab_variant, _VARIANTS.size())
	_shape = _VARIANTS[variant]
	_catalog_dir = catalog_dir
	_picture = _ERA_PICTURE.get(String(entry.get("era", "1991")), _ERA_PICTURE["1991"])


# ---------------------------------------------------------------------- visual


func _build_visual() -> void:
	add_to_group("arcade_cabinets")
	if cabinet.is_empty():
		push_warning("ArcadeCabinetProp: no catalog entry; the screen will stay dark")
		return

	var d: float = _shape["d"]
	var w: float = _shape["w"]
	var sz0: float = _shape["sz0"]
	var sz1: float = _shape["sz1"]
	# Blender front is -y, which b2g sends to +Z, and the prop is turned a further
	# half circle to meet the room - so the face of the cabinet is local -Z. Same
	# reasoning, and the same empirical check, as TVProp's glass.
	#
	# 26 mm proud rather than flush: the assembly puts a bakelite surround 20 mm in
	# front of the dark glass, and a picture level with the glass is a picture
	# mostly behind that surround. This is the same mistake TVProp's own comment
	# records making with the interact box, in the same millimetres.
	var face := -(d * 0.5 + 0.026)

	machine = ArcadeMachine.new()
	machine.name = "Machine"
	add_child(machine)

	var quad := QuadMesh.new()
	quad.size = Vector2(w - 0.12, sz1 - sz0)
	_screen = MeshInstance3D.new()
	_screen.name = "Screen"
	_screen.mesh = quad
	_screen.position = Vector3(0.0, (sz0 + sz1) * 0.5, face)
	_screen.rotation.y = PI
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_screen)

	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = load("res://shaders/tv_screen.gdshader")
	_screen_mat.set_shader_parameter("feed", machine.get_texture())
	_screen.material_override = _screen_mat
	_apply_infection()

	# A dark screen in a lit room reads as a machine nobody has plugged in.
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.0, (sz0 + sz1) * 0.5, face - 0.12)
	_glow.omni_range = 1.9
	_glow.light_color = Color(0.72, 0.80, 1.0)
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	add_child(_glow)

	_build_marquee(face)
	_build_claimed_controls(w, d)


func _build_marquee(face: float) -> void:
	var band: Array = _shape["marquee"]
	if band.is_empty():
		# The compact unit has no marquee header. Its claim goes on the bezel.
		_bezel_title(face)
		return

	var accent := _colour(cabinet.get("marquee_color"), Color(0.91, 0.78, 0.29))
	var height: float = float(band[1]) - float(band[0])
	var centre: float = (float(band[0]) + float(band[1])) * 0.5

	# The assembly's marquee is milk glass: blank, waiting for artwork. This is
	# the artwork, and it is the most confident lie on the machine - backlit, in
	# the world's own accent colour, at eye height.
	var art := make_box(Vector3(_shape["w"] - 0.05, height * 0.94, 0.012),
			Vector3(0.0, centre, face - 0.028), accent)
	var mat := art.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = 0.8

	# Titles run from LATTICE to SOMETHING IN THE HALL, so the artwork is set to
	# fit rather than to a fixed size. A marquee whose title runs off the ends of
	# its own panel is a marquee nobody proofed, which is the wrong joke.
	var art_w: float = float(_shape["w"]) - 0.09
	_fitted_label(String(cabinet.get("title", "")),
			Vector3(0.0, centre + height * 0.14, face - 0.036),
			art_w, height * 0.44, accent)
	_fitted_label("%s   %s" % [
				String(cabinet.get("manufacturer", "")),
				String(cabinet.get("era", "")),
			],
			Vector3(0.0, centre - height * 0.26, face - 0.036),
			art_w * 0.7, height * 0.17, accent)

	_marquee_light = OmniLight3D.new()
	_marquee_light.position = Vector3(0.0, centre, face - 0.20)
	_marquee_light.omni_range = 1.5
	_marquee_light.light_color = accent
	_marquee_light.light_energy = 0.85
	_marquee_light.shadow_enabled = false
	add_child(_marquee_light)


func _bezel_title(face: float) -> void:
	# The compact unit has no marquee header, so its claim is screened onto the
	# bezel above the glass, which is where that generation actually put it.
	var accent := _colour(cabinet.get("marquee_color"), Color(0.91, 0.78, 0.29))
	var label := _fitted_label(String(cabinet.get("title", "")),
			Vector3(0.0, float(_shape["sz1"]) + 0.045, face - 0.006),
			float(_shape["w"]) - 0.12, 0.05, accent)
	label.modulate = accent


## A Label3D scaled so the text fills the space it was given and no more.
##
## Label3D has no fit-to-box mode: `width` wraps, it does not shrink. So the
## string is measured at a reference size and the pixel size solved from that,
## which is the only way one marquee template survives both LATTICE and
## SOMETHING IN THE HALL.
func _fitted_label(text: String, at: Vector3, width_m: float, height_m: float,
		background: Color) -> Label3D:
	const REFERENCE := 100
	var font := ThemeDB.fallback_font
	var measured := font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, REFERENCE
	)
	var pixel := minf(
		width_m / maxf(1.0, measured.x),
		height_m / maxf(1.0, measured.y)
	)

	var label := Label3D.new()
	label.text = text
	label.font_size = REFERENCE
	label.pixel_size = pixel
	label.modulate = _readable_on(background)
	label.position = at
	label.rotation.y = PI
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(label)
	return label


## Whatever the claimed genre needs that the assembly's stick and three buttons
## do not provide. None of it is wired to anything.
func _build_claimed_controls(w: float, d: float) -> void:
	var deck_y: float = [1.02, 1.06, 0.97, 0.80][variant]
	var deck_z := -(d * 0.5 + 0.07)
	var dark := Color(0.09, 0.09, 0.10)

	match String(cabinet.get("control_layout", "stick_1button")):
		"wheel":
			var rim := make_ring(0.085, 0.014, Vector3(0.0, deck_y + 0.08, deck_z - 0.03), dark)
			rim.rotation.x = deg_to_rad(68.0)
			var hub := make_cyl(0.016, 0.016, 0.055,
					Vector3(0.0, deck_y + 0.055, deck_z - 0.015), Color(0.30, 0.31, 0.33))
			hub.rotation.x = deg_to_rad(68.0)
		"trackball":
			make_cyl(0.040, 0.040, 0.010, Vector3(0.0, deck_y + 0.005, deck_z), dark)
			make_cyl(0.036, 0.036, 0.048, Vector3(0.0, deck_y + 0.022, deck_z),
					Color(0.86, 0.24, 0.22), 0.14)
		"twin_stick":
			# A second stick, mirrored, because the first one is already modelled.
			_stick(w * 0.22, deck_y, deck_z)
		"stick_6button":
			# Three more, staggered into a second row.
			for i in 3:
				make_cyl(0.014, 0.014, 0.011,
						Vector3(-w * 0.5 + 0.16 + i * 0.12, deck_y + 0.006, deck_z + 0.045),
						[Color(0.36, 0.62, 0.85), Color(0.44, 0.72, 0.36),
						Color(0.78, 0.45, 0.74)][i], 0.25)
		"lightgun":
			# In a holster on the side, wired to nothing at all.
			make_box(Vector3(0.045, 0.10, 0.13),
					Vector3(w * 0.5 + 0.03, 0.86, -d * 0.18), Color(0.14, 0.14, 0.16))
			make_box(Vector3(0.028, 0.05, 0.15),
					Vector3(w * 0.5 + 0.03, 0.93, -d * 0.20), Color(0.11, 0.12, 0.14))


func _stick(x: float, top: float, z: float) -> void:
	make_cyl(0.026, 0.030, 0.010, Vector3(x, top + 0.005, z), Color(0.10, 0.10, 0.11))
	make_cyl(0.007, 0.007, 0.072, Vector3(x, top + 0.045, z), Color(0.62, 0.63, 0.66), 0.3, 0.6)
	make_cyl(0.019, 0.019, 0.028, Vector3(x, top + 0.090, z), Color(0.83, 0.20, 0.18), 0.2)


# --------------------------------------------------------------------- running


func _start_normal_function() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if machine == null:
		return
	if _knock > 0.0:
		_knock = maxf(0.0, _knock - delta * 4.0)
		_screen_mat.set_shader_parameter("tear", _knock)

	# A row of cabinets is a row of 3D worlds. Only the ones somebody could
	# plausibly be looking at get built, and only those render.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var wanted := camera.global_position.distance_to(global_position) < 9.0
	if wanted == _live:
		return
	_live = wanted
	if wanted and not machine.is_booted():
		machine.boot(cabinet, _catalog_dir)
	machine.set_live(wanted)
	_glow.light_energy = 0.22 if wanted else 0.0


func interact_prompt() -> String:
	if cabinet.is_empty():
		return ""
	return "[E]  %s" % String(cabinet.get("title", "PLAY"))


func interact(player: Node) -> void:
	if cabinet.is_empty() or machine == null:
		return
	if _panel_ui and is_instance_valid(_panel_ui):
		return
	if not machine.is_booted():
		machine.boot(cabinet, _catalog_dir)
	machine.set_live(true)
	var script: GDScript = load("res://scripts/ui/arcade_panel.gd")
	_panel_ui = script.new()
	_panel_ui.open(player, self)
	get_tree().current_scene.add_child(_panel_ui)
	played.emit()


func panel_closed() -> void:
	_panel_ui = null


# ------------------------------------------------------------------- infection


## The cabinet stops being able to hold the picture together.
##
## The faults come up first, which is the machine failing. Then the compiled skin
## starts lifting off the world inside it, entity by entity in a fixed order,
## which is the machine admitting what it has been running the whole time. It
## never touches the level: colliders, transforms and waves are identical at full
## infection and at none, and a player who kept going through it could not tell
## from the controls that anything had happened.
func _on_reality_event(case_id: String, node_id: String, strength: float,
		recurrence: int) -> void:
	super._on_reality_event(case_id, node_id, strength, recurrence)
	if node_id != graph_node_id or graph_node_id == "":
		return
	_infection = clampf(maxf(_infection, strength), 0.0, 1.0)
	_apply_infection()


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	# A motif arriving through the acoustic graph knocks the picture sideways for
	# a moment. It decays in _process; only a reality event moves the floor.
	if _screen_mat != null:
		_knock = clampf(accent * 0.7, 0.0, 1.0)


func _apply_infection() -> void:
	if _screen_mat == null:
		return
	var i := _infection
	_screen_mat.set_shader_parameter("scanline", float(_picture[0]))
	_screen_mat.set_shader_parameter("flicker", float(_picture[1]) + i * 0.4)
	_screen_mat.set_shader_parameter("chroma", float(_picture[2]) + i * 0.5)
	_screen_mat.set_shader_parameter("static_amount", i * 0.35)
	_screen_mat.set_shader_parameter("roll_speed", i * 0.9)
	_screen_mat.set_shader_parameter("warp", i * 0.7)
	if _marquee_light != null:
		_marquee_light.light_energy = 0.85 * (1.0 - i * 0.7)
	if machine != null:
		# The picture goes wrong before the world does: at half infection the set
		# is rolling and the skin has barely started to lift.
		machine.degrade = clampf((i - 0.35) / 0.65, 0.0, 1.0)


func _colour(value: Variant, fallback: Color) -> Color:
	var text := String(value)
	return Color(text) if text.begins_with("#") else fallback


## Black or white, whichever the marquee can actually be read in.
func _readable_on(background: Color) -> Color:
	var luma := background.r * 0.299 + background.g * 0.587 + background.b * 0.114
	return Color(0.06, 0.06, 0.07) if luma > 0.55 else Color(0.96, 0.96, 0.95)
