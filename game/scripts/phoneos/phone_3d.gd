class_name Phone3D
extends Node3D
## The NOCTURNE 900 as an actual object in space.
##
## The 2D Control version proved the OS; this is the handset. Body,
## chamfered shoulders, chrome rail, 35 real keys, a trackpad worn
## shiny, and a screen that is a SubViewport behind a CRT shader.
##
## Two things worth understanding before changing anything here:
##
## 1. PhoneOS is untouched. It still renders 60x24 characters into a
##    480x384 viewport and knows nothing about any of this. That was
##    the point of splitting hardware from software - the software
##    survived the hardware being replaced, which is exactly what you
##    want the first time a UI moves from flat to dimensional.
##
## 2. The screen is UNSHADED and emissive. A phone screen is a light
##    source, not a lit surface; shading it would make it dim when the
##    room is dim, which is backwards. All the panel character - scan
##    lines, subpixel grid, curvature, bloom, the flicker - lives in
##    the shader rather than in the drawn image, so the OS stays a
##    clean 480x384 and the display does the ageing.

const SCREEN_W := 480
const SCREEN_H := 384
# Real handset proportions in metres: 66 mm wide, 114 mm tall, 14 thick.
const BODY_W := 0.066
const BODY_H := 0.114
const BODY_D := 0.026          # it is a brick now, and it should be
const SCREEN_MM := Vector2(0.050, 0.0400)   # 5:4, sat above the keys
# Explicit Z planes rather than fractions of depth. The screen was once
# mounted at 0.335 of a depth whose front face was 0.36, i.e. inside
# the casing, and it rendered perfectly with the body drawn over it.
# Named planes make that mistake visible in the source.
const Z_BACK := -0.0130        # back plate, mostly missing
const Z_GUTS := -0.0040        # breadboard surface, where the build lives
const Z_FACE := 0.0090         # front bezel plane
const Z_KEY := 0.0104          # keycap tops
const Z_SCREEN := 0.0125       # panel, proud of everything

var os_sim := PhoneOS.new()
var cam := PhoneCamera.new()
var pairs := CartPairs.new()
var maze := CartMaze.new()
var screen_viewport: SubViewport
var screen_material: ShaderMaterial

var _font: Font
var _canvas: Control
var _led: OmniLight3D
var _led_mat: StandardMaterial3D
const TEX := "res://assets/ui/phone/%s.png"
var _grime: Texture2D
var _scratches: Texture2D
var _protector: Texture2D
var _overlay: Control
var _screen_quad: MeshInstance3D
var _glitch := 0.0
var _warm := 0.0
var _t := 0.0


func _ready() -> void:
	_font = TermGrid.make_font()
	_load_overlays()
	os_sim.boot()
	_build_screen_viewport()
	_build_body()
	_build_keys()
	_build_screen()
	add_child(cam)
	cam.setup(self)
	os_sim.cart_pairs = pairs
	os_sim.cart_maze = maze
	_isolate_from_world_light()
	set_process(true)


## HELD OBJECTS DO NOT LIVE IN THE WORLD'S LIGHTING.
##
## Two faults, both classic and both visible: the handset was casting
## shadows into the room it is being carried through, and the torch -
## a real SpotLight3D parented a few centimetres away on the same hand
## - was blasting the back of the thing holding it. A phone lit by its
## own beam reads as a lamp somebody is pointing at a phone.
##
## The fix is render layers rather than a second viewport. Every mesh
## on the handset moves to layer 2 and stops casting; the torch is told
## not to light layer 2; the carrier's fill is told to light NOTHING
## ELSE. The phone is then lit only by its own fill and by the room's
## own fixtures, which is what you want - walking past a lit doorway
## should still fall across it.
##
## A separate SubViewport would also stop the phone clipping through
## door frames and would lift it out of the beam mask entirely. That is
## the escalation if this is not enough; it costs a second 3D pass, so
## it is not the first thing to reach for.
const PHONE_LAYER := 2         # 1-indexed, as the inspector shows it


func _isolate_from_world_light() -> void:
	var n := 0
	for m in _all_meshes(self):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = 1 << (PHONE_LAYER - 1)
		n += 1
	print("[PHONE] %d meshes moved off the world's shadow pass" % n)


func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out


## The OS renders here, exactly as it did in 2D. Nothing below this
## line knows what a character cell is.
func _build_screen_viewport() -> void:
	screen_viewport = SubViewport.new()
	screen_viewport.size = Vector2i(SCREEN_W, SCREEN_H)
	screen_viewport.transparent_bg = false
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The panel is its own light source; the 3D scene's exposure must
	# not touch what the OS drew.
	screen_viewport.canvas_item_default_texture_filter = \
			Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(screen_viewport)
	_canvas = Control.new()
	_canvas.size = Vector2(SCREEN_W, SCREEN_H)
	_canvas.draw.connect(_draw_screen)
	screen_viewport.add_child(_canvas)
	# The grime layer is its own Control with an ADDITIVE material.
	# draw_texture_rect uses the CanvasItem's material, so mixing normal
	# and additive draws in one _draw is not possible - the marks would
	# composite over the OS instead of adding to it, and pure black
	# would paint the screen out rather than vanishing.
	_overlay = Control.new()
	_overlay.size = Vector2(SCREEN_W, SCREEN_H)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_overlay.material = add
	_overlay.draw.connect(_draw_overlays)
	screen_viewport.add_child(_overlay)


## Load once. Godot caches these, but doing it per frame in a draw call
## is the kind of thing that is free until it is not.
func _load_overlays() -> void:
	_grime = load(TEX % "screen_grime")
	_scratches = load(TEX % "screen_scratches")
	_protector = load(TEX % "screen_protector")


func _draw_screen() -> void:
	_canvas.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), TermGrid.BG)
	# The picture goes UNDER the character grid. The cam app draws only
	# chrome, so every cell it leaves as a space is a hole this shows
	# through - which is why that app must never paint a background.
	if os_sim.screen == PhoneOS.Screen.APP and os_sim.app_id == "pairs":
		pairs.draw(_canvas, Rect2(10, TermGrid.CH * 2.0,
				SCREEN_W - 20, TermGrid.CH * 19.0), _font)
	if os_sim.screen == PhoneOS.Screen.APP and os_sim.app_id == "maze":
		maze.draw(_canvas, Rect2(10, TermGrid.CH * 2.0,
				SCREEN_W - 20, TermGrid.CH * 19.0), _font)
	if os_sim.screen == PhoneOS.Screen.APP and os_sim.app_id == "cam":
		var frame := Rect2(24, TermGrid.CH * 3.5,
				SCREEN_W - 48, TermGrid.CH * 16.0)
		var tex: Texture2D = null
		if os_sim.gallery_open:
			if cam.roll.size() > 0:
				var i: int = clampi(os_sim.gallery_index, 0,
						cam.roll.size() - 1)
				tex = cam.load_photo(str(cam.roll[i]))
		else:
			tex = cam.viewfinder_texture()
		if tex:
			_canvas.draw_texture_rect(tex, frame, false)
		# The shutter flash is the torch firing, so it whites the frame
		# rather than fading it.
		var f := cam.flash_amount()
		if f > 0.0:
			_canvas.draw_rect(frame, Color(1, 1, 1, f * 0.85))
	os_sim.render().draw(_canvas, _font)


## Fingerprints, scratches and the badly-fitted protector, ADDED over
## everything the OS drew. They were generated as light marks on pure
## black, so black contributes nothing and only the marks land. Kept
## deliberately faint: the right amount of grime is the amount you only
## notice when it is switched off, and the temptation is always to
## crank it until you can see it.
func _draw_overlays() -> void:
	var full := Rect2(0, 0, SCREEN_W, SCREEN_H)
	if _grime:
		_overlay.draw_texture_rect(_grime, full, false,
				Color(1, 1, 1, 0.16))
	if _scratches:
		_overlay.draw_texture_rect(_scratches, full, false,
				Color(1, 1, 1, 0.22))
	if _protector:
		_overlay.draw_texture_rect(_protector, full, false,
				Color(1, 1, 1, 0.13))


## ---- the object -----------------------------------------------------

## A material wearing one of the delivered photographs. uv1_scale is
## the number of times the swatch repeats across the part, and it is
## the whole game here: these are small objects, so a body texture at
## 1x reads as a blurry smear and at 8x reads as sandpaper. The values
## below are set from each part's real size against the coverage the
## prompt asked for.
func _texmat(file: String, tint: Color, rough: float, metal := 0.0,
		uv := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex: Texture2D = load(TEX % file)
	if tex == null:
		push_warning("phone: missing texture " + file)
		return _mat(tint, rough, metal)
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.uv1_scale = Vector3(uv, uv, 1.0)
	return m


func _mat(albedo: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, at: Vector3, mat: Material,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	return mi


## ---- helpers --------------------------------------------------------

func _cyl(r: float, h: float, at: Vector3, mat: Material,
		axis := Vector3.RIGHT) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.position = at
	if axis == Vector3.RIGHT:
		mi.rotation.z = PI * 0.5
	elif axis == Vector3.FORWARD:
		mi.rotation.x = PI * 0.5
	mi.material_override = mat
	add_child(mi)
	return mi


## A wire: a short chain of segments sagging between two points. Real
## hookup wire never runs straight and the sag is most of what makes a
## build read as hand-made rather than as modelled.
func _wire(a: Vector3, b: Vector3, colour: Color, sag := 0.004) -> void:
	var mat := _mat(colour, 0.45)
	var steps := 5
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		var mid := (prev + p) * 0.5
		var seg := _cyl(0.00042, prev.distance_to(p), mid, mat)
		seg.look_at_from_position(mid, p, Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		prev = p


## THE SHELL. A BlackBerry that somebody opened and never closed.
##
## The frame is the only factory part left: bezel, side rails and the
## keypad surround, in plastic that has gone the colour of old ivory.
## The back is gone, so the build shows, and what holds the whole thing
## together is hot glue and the fact that nobody has dropped it.
func _build_body() -> void:
	# The frame is a BlackBerry again, in its own soft-touch. The ivory
	# was a stand-in for a photograph that did not exist yet; now that
	# it does, the dark shell is both more accurate and better for the
	# build, because hot glue and rainbow ribbon read far louder against
	# black plastic than against cream.
	var ivory: StandardMaterial3D = _texmat("phone_softtouch", Color(1, 1, 1), 0.86, 0.0, 1.6)
	var ivory_dk: StandardMaterial3D = _texmat("phone_softtouch", Color(0.72, 0.72, 0.75),
			0.88, 0.0, 2.2)
	var chrome: StandardMaterial3D = _texmat("phone_chrome_band", Color(1, 1, 1), 0.34,
			0.85, 3.0)
	var w := BODY_W * 0.5
	var h := BODY_H * 0.5
	# Front bezel: four rails, so the middle is open and the guts read.
	_box(Vector3(BODY_W, 0.010, 0.0035), Vector3(0, h - 0.005, Z_FACE),
			ivory)
	_box(Vector3(BODY_W, 0.006, 0.0035), Vector3(0, -h + 0.003, Z_FACE),
			ivory)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.006, BODY_H, 0.0035),
				Vector3(sx * (w - 0.003), 0, Z_FACE), ivory)
		# side rail, the one piece of the original that still looks new
		_box(Vector3(0.0022, BODY_H * 0.92, BODY_D * 0.80),
				Vector3(sx * w, 0, 0), chrome)
	# The keypad surround, still factory, still slightly grubby.
	_box(Vector3(BODY_W - 0.008, 0.030, 0.0030),
			Vector3(0, -h + 0.026, Z_FACE - 0.0004), ivory_dk)
	# What is left of the back: a corner of the original door, taped on.
	_box(Vector3(BODY_W * 0.62, BODY_H * 0.34, 0.0018),
			Vector3(-0.006, -h + 0.024, Z_BACK), ivory_dk)
	_build_guts()


## THE BUILD. Radio parts on a scrap of breadboard, glued in.
##
## In-universe this is the answer to a question the OS keeps raising:
## the radio app finds a carrier at 1610 kHz that has no transmitter,
## and a factory handset has no business hearing it. This one is not a
## factory handset. Somebody wound a coil onto a ferrite rod, hung a
## tuning capacitor off it, and hot-glued the lot inside a phone.
func _build_guts() -> void:
	var board: StandardMaterial3D = _texmat("breadboard", Color(1, 1, 1), 0.76, 0.0, 1.0)
	var pcb: StandardMaterial3D = _texmat("stripboard", Color(1, 1, 1), 0.58, 0.0, 1.0)
	var ic := _mat(Color("17171a"), 0.42)
	var tin: StandardMaterial3D = _texmat("solder_tinned", Color(1, 1, 1), 0.34, 0.55, 2.0)
	var copper: StandardMaterial3D = _texmat("copper_coil", Color(1, 1, 1), 0.36, 0.55, 1.0)
	var ferrite: StandardMaterial3D = _texmat("ferrite_rod", Color(1, 1, 1), 0.66, 0.0, 1.5)
	var kapton: StandardMaterial3D = _texmat("kapton_tape", Color(1, 1, 1, 0.80), 0.42,
			0.0, 1.2)
	kapton.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glue: StandardMaterial3D = _texmat("hot_glue", Color(1, 1, 1, 0.72), 0.22,
			0.0, 1.6)
	glue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Breadboard, sat slightly crooked because it was cut down with
	# snips to fit a hole it was never meant to fit.
	var bb := _box(Vector3(0.042, 0.030, 0.0042),
			Vector3(0.002, -0.010, Z_GUTS), board)
	bb.rotation.z = deg_to_rad(-2.4)
	# its centre channel and contact rows
	_box(Vector3(0.042, 0.0022, 0.0044), Vector3(0.002, -0.010, Z_GUTS),
			_mat(Color("bdb6a4"), 0.7))
	for r in 6:
		for c in 13:
			_box(Vector3(0.0007, 0.0007, 0.0046),
					Vector3(-0.018 + c * 0.0032,
					-0.0205 + r * 0.0042, Z_GUTS), _mat(Color("6d6659"), 0.6))
	# A scrap of stripboard bridged across the top, dead-bug style.
	_box(Vector3(0.030, 0.013, 0.0016), Vector3(-0.004, 0.014, Z_GUTS),
			pcb)
	# The radio front end: ferrite rod with its coil, and a tuning cap.
	_cyl(0.0026, 0.030, Vector3(-0.002, 0.0225, Z_GUTS + 0.004),
			ferrite)
	for i in 9:
		_cyl(0.0032, 0.0011,
				Vector3(-0.010 + i * 0.0024, 0.0225, Z_GUTS + 0.004),
				copper)
	var vcap := _cyl(0.0055, 0.0060,
			Vector3(0.0215, 0.0140, Z_GUTS + 0.004), tin, Vector3.FORWARD)
	vcap.rotation.x = PI * 0.5
	# Electrolytics, an IC, and a row of resistors with their bands.
	for spec in [[-0.014, -0.004, 0.0030, 0.0075],
			[-0.006, -0.006, 0.0024, 0.0060]]:
		_cyl(spec[2], spec[3], Vector3(spec[0], spec[1],
				Z_GUTS + spec[3] * 0.5), _mat(Color("2b3a52"), 0.40),
				Vector3.FORWARD).rotation.x = PI * 0.5
	_box(Vector3(0.0130, 0.0052, 0.0022),
			Vector3(0.008, -0.0035, Z_GUTS + 0.003), ic)
	for i in 8:
		_box(Vector3(0.0006, 0.0006, 0.0016),
				Vector3(0.0026 + (i % 4) * 0.0032,
				-0.0035 + (0.0034 if i < 4 else -0.0034),
				Z_GUTS + 0.001), tin)
	for i in 4:
		var rx := -0.016 + i * 0.0085
		_cyl(0.0011, 0.0042, Vector3(rx, -0.0175, Z_GUTS + 0.0028),
				_mat(Color("c8b48a"), 0.55))
		for b in 3:
			_cyl(0.00118, 0.0005,
					Vector3(rx - 0.0012 + b * 0.0011, -0.0175,
					Z_GUTS + 0.0028),
					_mat([Color("6b3a1c"), Color("1a1a1e"),
					Color("8a2020")][b], 0.5))
	# Hookup wire, sagging between the board and the shell.
	var wires := [
		[Vector3(-0.017, 0.0075, Z_GUTS + 0.003),
		 Vector3(0.014, 0.0180, Z_GUTS + 0.004), Color("c02a24")],
		[Vector3(-0.012, -0.0195, Z_GUTS + 0.003),
		 Vector3(0.017, -0.0090, Z_GUTS + 0.004), Color("1f56b8")],
		[Vector3(0.006, 0.0165, Z_GUTS + 0.004),
		 Vector3(0.020, -0.0035, Z_GUTS + 0.003), Color("d8b118")],
		[Vector3(-0.019, -0.0090, Z_GUTS + 0.003),
		 Vector3(-0.008, 0.0195, Z_GUTS + 0.004), Color("2c9a3e")],
		[Vector3(0.012, -0.0180, Z_GUTS + 0.003),
		 Vector3(-0.016, -0.0035, Z_GUTS + 0.003), Color("e8e4d8")],
	]
	for wv in wires:
		_wire(wv[0], wv[1], wv[2])
	# The ribbon: the display's own flat cable, looping out of the panel
	# and back down into the board. Straight from the reference.
	var ribbon_cols = [Color("8a2f2f"), Color("b8681e"), Color("c8b12a"),
			Color("3d8a3a"), Color("2f5aa8"), Color("6a3a8a"),
			Color("b8b2a4")]
	for i in ribbon_cols.size():
		var rz := Z_GUTS + 0.0055
		var x := -0.0075 + i * 0.0022
		var rib: StandardMaterial3D = _texmat("ribbon_cable", Color(1, 1, 1), 0.56, 0.0, 1.0)
		_box(Vector3(0.0020, 0.020, 0.0004), Vector3(x, 0.006, rz), rib)
		_box(Vector3(0.0020, 0.0044, 0.0004),
				Vector3(x, 0.0175, rz + 0.0016), rib)
	# Kapton over the ribbon's fold, and hot glue at every joint that
	# somebody did not trust.
	_box(Vector3(0.020, 0.0060, 0.0006), Vector3(-0.0005, 0.0172,
			Z_GUTS + 0.0064), kapton)
	for g in [[-0.0210, 0.0205, 0.0030], [0.0215, 0.0175, 0.0034],
			[-0.0190, -0.0200, 0.0026], [0.0180, -0.0190, 0.0030],
			[0.0000, 0.0245, 0.0028]]:
		var blob := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = g[2]
		sp.height = g[2] * 1.5
		sp.radial_segments = 8
		sp.rings = 5
		blob.mesh = sp
		blob.position = Vector3(g[0], g[1], Z_GUTS + 0.002)
		blob.material_override = glue
		add_child(blob)
	# A stub whip antenna, taped to the top edge and slightly bent.
	var whip := _cyl(0.00085, 0.034,
			Vector3(0.0255, BODY_H * 0.5 + 0.014, 0.0), tin,
			Vector3.FORWARD)
	whip.rotation = Vector3(PI * 0.5, 0, deg_to_rad(9))
	_box(Vector3(0.0055, 0.0075, 0.0035),
			Vector3(0.0255, BODY_H * 0.5 - 0.002, 0.0), kapton)
	# The buzzer from the reference: a round can, glued on, off to one
	# side because that is where there was room.
	var buzz := _cyl(0.0072, 0.0040, Vector3(0.0175, -0.0270, Z_GUTS
			+ 0.004), _mat(Color("35353b"), 0.45), Vector3.FORWARD)
	buzz.rotation.x = PI * 0.5
	_cyl(0.0022, 0.0042, Vector3(0.0175, -0.0270, Z_GUTS + 0.005),
			_mat(Color("17171a"), 0.5), Vector3.FORWARD).rotation.x = PI * 0.5
	# LED, wired not fitted, poking through a hole somebody drilled.
	_led_mat = _mat(Color("5cf07a"), 0.30)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color("5cf07a")
	_led_mat.emission_energy_multiplier = 3.0
	_cyl(0.0016, 0.0030, Vector3(BODY_W * 0.30, BODY_H * 0.44, Z_FACE),
			_led_mat, Vector3.FORWARD).rotation.x = PI * 0.5
	_led = OmniLight3D.new()
	_led.light_color = Color("5cf07a")
	_led.light_energy = 0.35
	_led.omni_range = 0.22
	_led.shadow_enabled = false
	_led.position = Vector3(BODY_W * 0.30, BODY_H * 0.44, Z_FACE + 0.004)
	add_child(_led)


## The keypad. Still the BlackBerry's own rubber mat, because nobody
## hand-builds thirty-five keys - but three caps have been replaced
## with whatever was in the drawer, and one is simply missing.
func _build_keys() -> void:
	# One keycap swatch across a 5 mm cap: the thumb-polish that came
	# back in the centre of the photograph lands in the centre of every
	# key, which is exactly where a thumb puts it.
	var cap: StandardMaterial3D = _texmat("phone_keycap", Color(1, 1, 1), 0.54, 0.0, 1.0)
	var cap_lit: StandardMaterial3D = _texmat("phone_keycap", Color(1.15, 1.15, 1.2), 0.44,
			0.0, 1.0)
	var odd := _mat(Color("8a5a2c"), 0.50)          # a salvaged cap
	var hole := _mat(Color("0d0c10"), 0.85)         # one is gone
	var rows := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
	var kw := 0.0050
	var kh := 0.0042
	var top := -BODY_H * 0.115
	for r in rows.size():
		var row: String = rows[r]
		var span := row.length() * (kw + 0.0006)
		for c in row.length():
			var x := -span * 0.5 + c * (kw + 0.0006) + kw * 0.5
			var y := top - r * (kh + 0.0009)
			var mat: Material = cap
			if (r == 0 and c == 4) or (r == 2 and c == 1):
				mat = odd
			elif r == 1 and c == 6:
				_box(Vector3(kw, kh, 0.0008), Vector3(x, y, Z_KEY - 0.0016),
						hole)
				continue
			_box(Vector3(kw, kh, 0.0015), Vector3(x, y, Z_KEY), mat)
			_box(Vector3(kw - 0.0010, kh - 0.0010, 0.0005),
					Vector3(x, y, Z_KEY + 0.0009), cap_lit)
	_box(Vector3(0.019, kh, 0.0015),
			Vector3(0, top - 3 * (kh + 0.0009), Z_KEY), cap)
	var ny := top + 0.0088
	for i in 5:
		var x := (i - 2) * 0.0100
		if i == 2:
			_box(Vector3(0.0074, 0.0074, 0.0011), Vector3(x, ny, Z_KEY),
					_mat(Color("3a3442"), 0.22))
			continue
		_box(Vector3(0.0078, 0.0050, 0.0013), Vector3(x, ny, Z_KEY), cap)


## The panel: a quad standing just proud of the body, wearing the CRT
## shader and lit by nothing.
##
## Z DISCIPLINE, learned the expensive way. The body's front slab spans
## 0.26 to 0.36 of BODY_D, and the first version mounted the screen at
## 0.335 - INSIDE the casing. The panel rendered correctly the whole
## time and the casing was drawn over the top of it, which looks
## exactly like a texture that failed to bind: a blank pale rectangle,
## no error, nothing in the log. Anything mounted on the face clears
## 0.36 now; the screen sits at 0.42 and the keycaps at 0.42/0.50.
func _build_screen() -> void:
	var quad := QuadMesh.new()
	quad.size = SCREEN_MM
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.position = Vector3(0, BODY_H * 0.235, Z_SCREEN)
	mi.rotation.z = deg_to_rad(-1.1)   # nobody mounts it straight
	screen_material = ShaderMaterial.new()
	screen_material.shader = _make_shader()
	mi.material_override = screen_material
	add_child(mi)
	# Bind the panel texture a frame late. A SubViewport's ViewportTexture
	# does not reliably resolve while the viewport is still being built
	# inside _ready, and an unresolved sampler reads as flat white - which
	# on an unshaded quad is a blank pale screen with no error anywhere,
	# exactly what the first framegrab showed.
	_screen_quad = mi
	# The panel is a salvaged LCD screwed to the shell through a hole
	# cut with a craft knife: a dark surround, four brass screws, and
	# an edge that does not quite line up with the aperture.
	var surround: StandardMaterial3D = _texmat("phone_bezel", Color(1, 1, 1), 0.58, 0.0, 1.4)
	var brass := _mat(Color("c8a54a"), 0.35, 0.80)
	var sy: float = BODY_H * 0.235
	_box(Vector3(SCREEN_MM.x + 0.0075, SCREEN_MM.y + 0.0075, 0.0022),
			Vector3(0, sy, Z_SCREEN - 0.0016), surround)
	for sx in [-1.0, 1.0]:
		for syy in [-1.0, 1.0]:
			_cyl(0.0011, 0.0016,
					Vector3(sx * (SCREEN_MM.x * 0.5 + 0.0026),
					sy + syy * (SCREEN_MM.y * 0.5 + 0.0026),
					Z_SCREEN - 0.0004), brass,
					Vector3.FORWARD).rotation.x = PI * 0.5
	call_deferred("_bind_panel")
	# No separate glass quad. The first version put one here at
	# roughness 0.06, which is a mirror: under any fill light at all it
	# blew to a white specular sheet that covered the screen completely,
	# and the framegrab showed a blank panel. The shader already does
	# reflection-ish work with its bloom and vignette, and a phone screen
	# in a dark building should be reading as a light source rather than
	# as a pane catching the room.


## The panel's whole personality. Deliberately one shader rather than a
## post-process chain: it only ever applies to this quad, it must run
## on gl_compatibility, and a phone screen in a dark room is the one
## surface in the project allowed to be gaudy.
func _make_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D screen_tex : filter_nearest;
uniform float warm = 1.0;      // 0 at power-on, 1 once the panel is up
uniform float glitch = 0.0;    // 0..1, punched by the OS on transitions
uniform float t = 0.0;

void fragment() {
	vec2 uv = UV;

	// Barrel curvature. Small - this is an LCD, not a CRT - but enough
	// that the corners bend and the panel stops reading as a decal.
	vec2 c = uv - 0.5;
	uv = uv + c * dot(c, c) * 0.16;

	// Horizontal tear. A band of the screen slips sideways for a few
	// frames when the OS punches `glitch`.
	float band = step(0.5, fract(uv.y * 9.0 + t * 3.0));
	uv.x += band * glitch * 0.035 * sin(t * 60.0);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
	} else {
		// Chromatic aberration, scaled by distance from centre so the
		// middle stays crisp and the corners fringe.
		float ca = (0.0016 + glitch * 0.006) * length(c) * 2.0;
		vec3 col;
		col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;

		// Subpixel matrix: RGB stripes at the panel's real pixel pitch,
		// which is what stops magnified text looking like big text.
		float sx = fract(uv.x * 480.0);
		vec3 mask = vec3(
			smoothstep(0.66, 0.34, abs(sx - 0.166)),
			smoothstep(0.66, 0.34, abs(sx - 0.5)),
			smoothstep(0.66, 0.34, abs(sx - 0.833)));
		col *= mix(vec3(1.0), mask * 1.6, 0.28);

		// Scanlines, and a slow refresh roll that never quite settles.
		float scan = 0.90 + 0.10 * sin(uv.y * 384.0 * 3.14159);
		float roll = 0.985 + 0.015 * sin(uv.y * 6.0 - t * 1.7);
		col *= scan * roll;

		// Cheap bloom: the panel's own brightness bleeding sideways.
		vec3 blur = texture(screen_tex, uv + vec2(0.004, 0.0)).rgb
				  + texture(screen_tex, uv - vec2(0.004, 0.0)).rgb
				  + texture(screen_tex, uv + vec2(0.0, 0.005)).rgb
				  + texture(screen_tex, uv - vec2(0.0, 0.005)).rgb;
		col += blur * 0.085;

		// Vignette, mains flicker, and the power-on ramp.
		col *= 1.0 - length(c) * 0.55;
		col *= 0.97 + 0.03 * sin(t * 47.0);
		col *= warm;

		ALBEDO = col;
		EMISSION = col * 2.4;
	}
}
"""
	return s


func _bind_panel() -> void:
	if screen_material and screen_viewport:
		screen_material.set_shader_parameter("screen_tex",
				screen_viewport.get_texture())


func _process(delta: float) -> void:
	_t += delta
	os_sim.advance(delta)
	_canvas.queue_redraw()
	_overlay.queue_redraw()
	# The panel warms up rather than snapping on, which is most of why
	# a boot sequence feels like hardware.
	_warm = minf(1.0, _warm + delta * 0.55)
	_glitch = maxf(0.0, _glitch - delta * 3.4)
	if screen_material:
		# Re-fetch the panel texture each frame. The 2D build pulled
		# get_texture() fresh inside _draw and worked; binding it once
		# here did not, and a ViewportTexture that has not resolved
		# reads as flat white with no error logged anywhere.
		screen_material.set_shader_parameter("screen_tex",
				screen_viewport.get_texture())
		screen_material.set_shader_parameter("t", _t)
		screen_material.set_shader_parameter("warm", _warm)
		screen_material.set_shader_parameter("glitch", _glitch)
	var in_cam: bool = os_sim.screen == PhoneOS.Screen.APP 			and os_sim.app_id == "cam" and not os_sim.gallery_open
	cam.set_active(in_cam)
	if in_cam:
		cam.track(self)
	if os_sim.screen == PhoneOS.Screen.APP and os_sim.app_id == "pairs":
		pairs.tick(delta)
	if os_sim.screen == PhoneOS.Screen.APP and os_sim.app_id == "maze":
		maze.tick(delta)
	os_sim.camera_roll = cam.roll.size()
	os_sim.camera_cap = PhoneCamera.CAP
	var pulse: float = 0.35 + 0.65 * absf(sin(os_sim.led_pulse * 1.7))
	if _led:
		_led.light_energy = 0.35 * pulse
	if _led_mat:
		_led_mat.emission_energy_multiplier = 1.0 + 3.0 * pulse


## The OS calls this when a screen changes, so a transition is felt as
## the panel struggling rather than as a UI animation.
func punch_glitch(amount := 1.0) -> void:
	_glitch = clampf(amount, 0.0, 1.0)


func key(action: String, typed := "") -> void:
	# The shutter is intercepted before the OS sees it: inside the cam
	# app with the gallery closed, enter takes the picture rather than
	# meaning "open".
	if action == "ok" and os_sim.screen == PhoneOS.Screen.APP 			and os_sim.app_id == "cam" and not os_sim.gallery_open:
		os_sim.last_shot = cam.capture()
		return
	var before_app := os_sim.app_id
	var before := os_sim.screen
	os_sim.key(action, typed)
	if os_sim.app_id == "pairs" and before_app != "pairs":
		pairs.start(cam.roll, func(p): return cam.load_photo(p))
	# The maze keeps its chamber number between visits, so re-entering
	# resumes the depth you reached rather than sending you back to I.
	if os_sim.app_id == "maze" and before_app != "maze":
		maze.start(cam.roll, func(p): return cam.load_photo(p))
	if os_sim.screen != before:
		punch_glitch(0.8)
