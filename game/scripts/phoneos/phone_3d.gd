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
const BODY_D := 0.014
const SCREEN_MM := Vector2(0.052, 0.0416)   # 5:4, sat above the keys

var os_sim := PhoneOS.new()
var cam := PhoneCamera.new()
var screen_viewport: SubViewport
var screen_material: ShaderMaterial

var _font: Font
var _canvas: Control
var _led: OmniLight3D
var _led_mat: StandardMaterial3D
var _screen_quad: MeshInstance3D
var _glitch := 0.0
var _warm := 0.0
var _t := 0.0


func _ready() -> void:
	_font = TermGrid.make_font()
	os_sim.boot()
	_build_screen_viewport()
	_build_body()
	_build_keys()
	_build_screen()
	add_child(cam)
	cam.setup(self)
	set_process(true)


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


func _draw_screen() -> void:
	_canvas.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), TermGrid.BG)
	# The picture goes UNDER the character grid. The cam app draws only
	# chrome, so every cell it leaves as a space is a hole this shows
	# through - which is why that app must never paint a background.
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


## ---- the object -----------------------------------------------------

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


## Chamfer by stacking three slabs of decreasing footprint rather than
## generating a rounded prism. Under a soft key light the silhouette
## reads as a bevelled edge, it costs three boxes instead of a few
## hundred triangles, and on a gl_compatibility mobile target that
## trade is not close.
func _build_body() -> void:
	var soft := _mat(Color("14111a"), 0.86)     # soft-touch plastic
	var chrome := _mat(Color("9aa0aa"), 0.28, 0.95)
	var d := BODY_D
	_box(Vector3(BODY_W, BODY_H, d * 0.62), Vector3(0, 0, -d * 0.19), soft)
	_box(Vector3(BODY_W - 0.004, BODY_H - 0.004, d * 0.24),
			Vector3(0, 0, d * 0.19), soft)
	_box(Vector3(BODY_W - 0.010, BODY_H - 0.010, d * 0.10),
			Vector3(0, 0, d * 0.31), soft)
	# the chrome rail down each flank
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.0022, BODY_H * 0.86, d * 0.66),
				Vector3(sx * BODY_W * 0.5, 0, -d * 0.16), chrome)
	# earpiece slot above the screen
	_box(Vector3(0.016, 0.0022, 0.002),
			Vector3(0, BODY_H * 0.455, d * 0.40),
			_mat(Color("07060a"), 0.9))
	# notification LED, top right, and a real light so it marks the room
	_led_mat = _mat(Color("5cf07a"), 0.3)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color("5cf07a")
	_led_mat.emission_energy_multiplier = 3.0
	_box(Vector3(0.003, 0.002, 0.001),
			Vector3(BODY_W * 0.34, BODY_H * 0.455, d * 0.42), _led_mat)
	_led = OmniLight3D.new()
	_led.light_color = Color("5cf07a")
	_led.light_energy = 0.35
	_led.omni_range = 0.22
	_led.shadow_enabled = false
	_led.position = Vector3(BODY_W * 0.34, BODY_H * 0.455, d * 0.46)
	add_child(_led)


## 35 keys in the staggered rows the hardware actually used, plus the
## nav cluster. Every one is its own mesh because they are what the eye
## checks first to decide whether a phone is modelled or drawn.
func _build_keys() -> void:
	var cap := _mat(Color("1b1620"), 0.52)
	var cap_lit := _mat(Color("221c28"), 0.44)
	var rows := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
	var kw := 0.0054
	var kh := 0.0046
	var top := -BODY_H * 0.10
	for r in rows.size():
		var row: String = rows[r]
		var span := row.length() * (kw + 0.0006)
		for c in row.length():
			var x := -span * 0.5 + c * (kw + 0.0006) + kw * 0.5
			var y := top - r * (kh + 0.0009)
			# keycaps sit proud and are very slightly domed: a second
			# thinner slab on top does the job at this scale
			_box(Vector3(kw, kh, 0.0016), Vector3(x, y, BODY_D * 0.42),
					cap)
			_box(Vector3(kw - 0.0010, kh - 0.0010, 0.0006),
					Vector3(x, y, BODY_D * 0.50), cap_lit)
	# space bar
	_box(Vector3(0.020, kh, 0.0016),
			Vector3(0, top - 3 * (kh + 0.0009), BODY_D * 0.42), cap)
	# nav cluster: call / menu / trackpad / back / end
	var ny := top + 0.0092
	for i in 5:
		var x := (i - 2) * 0.0104
		if i == 2:
			# the trackpad, worn shinier than anything else on the phone
			_box(Vector3(0.0078, 0.0078, 0.0012), Vector3(x, ny,
					BODY_D * 0.43), _mat(Color("2a2432"), 0.22))
			continue
		_box(Vector3(0.0082, 0.0052, 0.0014),
				Vector3(x, ny, BODY_D * 0.42), cap)


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
	mi.position = Vector3(0, BODY_H * 0.235, BODY_D * 0.42)
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
	var before := os_sim.screen
	os_sim.key(action, typed)
	if os_sim.screen != before:
		punch_glitch(0.8)
