class_name PhoneLightMask
extends Control
## The torch beam, blended live from three photographs.
##
## TWO CONSUMERS, one mix. `setup(player, true)` builds the COOKIE: the
## plate is rendered to a SubViewport and baked onto the spotlight's
## light_projector, so the pattern lands on geometry. `setup(player)`
## builds the ATMOSPHERE layer, which multiplies over the frame and
## holds the edges dark. (An older comment here said gl_compatibility
## ignores light_projector. It does not, in 4.7. That claim was true of
## an older Godot, was never re-checked, and nearly cost a renderer
## migration.)
##
## One static image means one mood for an entire shift, and this is the
## most-looked-at surface in the game — the torch is lit from the first
## frame. So three are mixed in a shader and the mix answers to what the
## building is doing to the player.
##
## The three poles, named for what they look like rather than for any
## theory:
##   CLEAN    a tight round core, concentric rings, a bite out of one
##            edge where the hot glue fouls the emitter
##   CRACKED  cold, asymmetric, a hard anamorphic streak — a lens with
##            something wrong with it
##   HAZE     soft, warm, wide, diffuse — light through breath or dust
##
## What moves the mix:
##
## - **Sanity pressure** pushes toward CRACKED. This is the one that
##   matters. The building's pressure model already drives the
##   poltergeists and the intrusions; hanging the torch off it means
##   the player reads their own condition in the light they are
##   holding, continuously, without a meter — which is the sanity
##   system's founding rule (see sanity_director.gd on why there is no
##   meter and must never be one).
## - **Walking** pushes toward HAZE and adds bob. A carried torch
##   breathes with the stride; a still one is a lamp on a stand.
##   Standing still settles it back to CLEAN, so stopping to look at
##   something is rewarded with a steadier beam.
##   - **Intrusions** punch a surge: a brief brightening and a hard
##   chromatic split, as if the emitter were overdriven for a moment.
##
## Everything is smoothed with move_toward rather than assigned, because
## a beam that snaps between states reads as a bug and a beam that
## drifts reads as a hand.

const DIR := "res://assets/ui/phone/%s.png"
const CHASE := 0.55            # how fast the mix follows its target
## How fast the vignette gets out of the way when you walk into a lit
## room, and back down when you leave it. Slow on purpose: this is the
## eye adapting, not a switch, and anything quicker reads as the gamma
## being yanked.
const LIFT_CHASE := 0.85


var _mat: ShaderMaterial
var _player: Node3D
var _sanity: Node
var _rig: Node
var _w_cracked := 0.0
var _w_haze := 0.0
var _surge := 0.0
var _lift := 0.0
var _t := 0.0
var _aim := Vector2.ZERO
var _cookie_mode := false


## `as_cookie` builds the projector version instead of the screen one:
## same three plates, same live mix, but rendered into a SubViewport to
## be baked onto the SpotLight3D rather than multiplied over the frame.
func setup(player: Node3D, as_cookie := false) -> void:
	_player = player
	_cookie_mode = as_cookie
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Oversized so its edges stay off-screen while the beam drifts.
	offset_left = -64
	offset_top = -64
	offset_right = 64
	offset_bottom = 64
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = _make_shader()
	for slot in [["m_clean", "mask_clean"], ["m_cracked", "mask_cracked"],
			["m_haze", "mask_haze"]]:
		var tex: Texture2D = load(DIR % slot[1])
		if tex == null:
			push_warning("torch: missing mask " + str(slot[1]))
		_mat.set_shader_parameter(str(slot[0]), tex)
	material = _mat
	set_process(true)
	# A bare Control issues NO draw call, so a shader on it never runs -
	# the mask was silently absent and the whole building rendered
	# unmasked and far too bright. The old code got this for free by
	# using a TextureRect, which draws its texture. Here the rect is
	# drawn explicitly and the fragment shader replaces every pixel of
	# it, so the white is only ever a carrier for the shader.
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


## Called by the intrusion layer when the building does something.
func punch(amount := 1.0) -> void:
	_surge = maxf(_surge, clampf(amount, 0.0, 1.0))


## Degrees the hand has taken the beam off the eye's axis, from the
## carrier's motion model. The light itself has ALREADY moved in the
## world by this much; this only slides the plate the same way so the
## screen layer and the 3D beam stay married.
func set_aim(a: Vector2) -> void:
	_aim = a


## HOW FAR THE BEAM IS THROWING, in metres, from the player's raycast
## down its own axis. Only the cookie wants this: the pattern on the
## light softens with range (see the shader), and the screen layer is a
## vignette that has no business knowing what the beam hit.
func set_throw(metres: float, reach: float) -> void:
	if not _cookie_mode or _mat == null:
		return
	# THE HAND IS THE BLUR. A torch pattern subtends the same angle at
	# every distance, so geometry alone would keep it equally sharp on a
	# wall 1 m away and one 7 m away — which is not what a held light
	# looks like, and the reason is already written down two files over:
	# at 7.5 m one degree of wrist walks the pool thirteen centimetres,
	# and at 1 m it walks it under two. The tremor that this codebase
	# already models is smearing the pattern across the eye's integration
	# time, linearly with range. So the blur is linear in throw, and the
	# near end is held sharp because inside about a metre the hand is not
	# fast enough to smear anything.
	var span: float = maxf(0.5, reach - THROW_NEAR)
	var t: float = clampf((metres - THROW_NEAR) / span, 0.0, 1.0)
	_mat.set_shader_parameter("blur", pow(t, 0.85) * BLUR_MAX)


## Sharp under this range; the smear has nothing to work with yet.
const THROW_NEAR := 1.10
## Kernel radius in cookie UV at full throw. Past about 0.07 the two
## rings start reading as two rings rather than as defocus.
const BLUR_MAX := 0.052


func _find_sanity() -> void:
	# Both, not just sanity: the two are built a few lines apart in
	# building_root, but keying the search off one of them means the other
	# is never looked for again if it happened to be a frame late.
	if _sanity != null and is_instance_valid(_sanity) \
			and _rig != null and is_instance_valid(_rig):
		return
	var root := get_tree().get_first_node_in_group("building_root")
	if root == null:
		root = get_tree().current_scene
	if root and root.get("light_rig") != null:
		_rig = root.light_rig
	if root and root.get("sanity") != null:
		_sanity = root.sanity
		# The building shoves the torch. Pressure already bends the beam
		# slowly, over a whole shift; this is the other half — the moment
		# something actually HAPPENS, felt in the light before the player
		# has found what moved.
		if not _sanity.intruded.is_connected(_on_intruded):
			_sanity.intruded.connect(_on_intruded)
		if not _sanity.attention_withheld.is_connected(_on_withheld):
			_sanity.attention_withheld.connect(_on_withheld)


## Rungs run 1..4. A rung one is a flicker you might talk yourself out
## of; a rung four is the light nearly going.
func _on_intruded(_case_id: String, tier: int) -> void:
	punch(clampf(0.28 + 0.24 * float(tier - 1), 0.0, 1.0))


## Ignoring the building does not make it quieter. Each unwitnessed
## intrusion in a row leans harder on the beam than the last, which is
## the same escalation the director applies to everything else.
func _on_withheld(_case_id: String, streak: int) -> void:
	punch(clampf(0.30 + 0.20 * float(streak), 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	_find_sanity()
	# Pressure is 0..1 in the sanity model; square it so the torch stays
	# honest through the ordinary run of a shift and only really turns
	# once the building has genuinely got hold of the player.
	var pressure := 0.0
	if _sanity and "pressure" in _sanity:
		pressure = clampf(float(_sanity.pressure), 0.0, 1.0)
	var speed := 0.0
	if _player and "velocity" in _player:
		speed = Vector3(_player.velocity.x, 0.0,
				_player.velocity.z).length()
	var want_cracked: float = pressure * pressure
	var want_haze: float = clampf(speed / 3.2, 0.0, 1.0) * 0.55
	_w_cracked = move_toward(_w_cracked, want_cracked, delta * CHASE)
	_w_haze = move_toward(_w_haze, want_haze, delta * CHASE * 2.2)
	_surge = maxf(0.0, _surge - delta * 1.8)
	# THE ROOM WINS WHERE THERE IS A ROOM. The rig measures what its own
	# fixtures are actually putting on the camera; the vignette gets out
	# of their way in proportion. In the Harukiya with the pendants lit
	# you should barely know the torch is on, and in the coal cellar it
	# should be the only thing you have.
	var room := 0.0
	if _rig and "room_light" in _rig:
		room = clampf(float(_rig.room_light), 0.0, 1.0)
	_lift = move_toward(_lift, room, delta * LIFT_CHASE)

	# The hand. A slow figure-of-eight that speeds up as you walk, so
	# the beam is never still and never mechanical.
	var rate: float = 1.0 + speed * 1.6
	var drift := Vector2(
			sin(_t * 0.9 * rate) * 0.006 + sin(_t * 2.3) * 0.002,
			sin(_t * 1.4 * rate) * 0.005 + cos(_t * 3.1) * 0.0015)
	drift *= 1.0 + speed * 0.5
	# The wrist's own wander, in the same units, so the plate and the
	# 3D beam move together instead of arguing.
	drift += Vector2(_aim.x, -_aim.y) * 0.004
	_mat.set_shader_parameter("drift", drift)
	_mat.set_shader_parameter("w_cracked", _w_cracked)
	_mat.set_shader_parameter("w_haze", _w_haze)
	_mat.set_shader_parameter("surge", _surge)
	_mat.set_shader_parameter("split", _w_cracked * 0.6 + _surge * 0.4)
	_mat.set_shader_parameter("lift", _lift)
	# A tighter beam when still, a slightly opener one when moving -
	# the eye reads the difference as the hand relaxing.
	#
	# Dropped from 2.35. That gamma was set when this layer WAS the beam
	# and had to manufacture a hotspot out of a flat plate; the cookie
	# carries the hotspot now, so all 2.35 was still doing was crushing
	# the building's own fixtures along with everything else.
	_mat.set_shader_parameter("falloff", 1.70 - _w_haze * 0.30)
	_mat.set_shader_parameter("t", _t)


func _make_shader() -> Shader:
	var s := Shader.new()
	# THE COOKIE VERSION. Same plates, same mix, but this one renders
	# into a SubViewport and is baked onto the SpotLight3D's
	# light_projector — so the pattern is carried by the LIGHT and lands
	# on geometry: it wraps a doorframe, stretches down a corridor, and
	# holds still on a wall while the player walks into it.
	#
	# gl_compatibility DOES support projectors in 4.7, whatever the old
	# comment in this file said. That claim had been true once, was
	# never re-checked, and cost a renderer migration before anyone
	# simply assigned one and looked.
	#
	# No blend_mul (it renders into a texture, not over a frame) and no
	# black floor (on a cookie, black means the light does not go there,
	# which is what the edge of a beam IS).
	if _cookie_mode:
		s.code = """
shader_type canvas_item;

uniform sampler2D m_clean : filter_linear, repeat_disable;
uniform sampler2D m_cracked : filter_linear, repeat_disable;
uniform sampler2D m_haze : filter_linear, repeat_disable;
uniform float w_cracked = 0.0;
uniform float w_haze = 0.0;
uniform float surge = 0.0;
uniform float split = 0.0;
uniform float t = 0.0;
uniform vec2 drift = vec2(0.0);
uniform float falloff = 1.55;
uniform float zoom = 1.10;
// Kernel radius in UV, set from the raycast throw. 0 = hard against a
// near wall, BLUR_MAX = thrown down a corridor with nothing to land on.
uniform float blur = 0.0;

// TWO RINGS, NOT A BOX. A 3x3 box at a radius this large reads as three
// copies of the beam rather than as one soft one — the taps are far
// enough apart to be individually visible. Six at 0.55r and six more at
// r rotated 30 degrees puts twelve samples on a disc with no axis for
// the eye to find, which is the cheapest arrangement that actually
// looks defocused.
const vec2 DISC[12] = vec2[12](
	vec2( 0.550,  0.000), vec2( 0.275,  0.476), vec2(-0.275,  0.476),
	vec2(-0.550,  0.000), vec2(-0.275, -0.476), vec2( 0.275, -0.476),
	vec2( 0.866,  0.500), vec2( 0.000,  1.000), vec2(-0.866,  0.500),
	vec2(-0.866, -0.500), vec2( 0.000, -1.000), vec2( 0.866, -0.500));

// The blend, at one point. Pulled out of fragment() so the blur can run
// it per tap. The two branches are on uniforms, so every pixel in the
// pass takes the same one and they cost nothing — and they matter,
// because most of a shift is spent with both weights at zero and no
// reason to pay for two more texture fetches.
vec3 plate(vec2 uv) {
	vec3 c = texture(m_clean, uv).rgb;
	if (w_cracked > 0.002) {
		c = mix(c, texture(m_cracked, uv).rgb, w_cracked);
	}
	if (w_haze > 0.002) {
		c = mix(c, texture(m_haze, uv).rgb, w_haze);
	}
	return c;
}

void fragment() {
	// Near 1:1 — the plate maps across the spotlight's cone rather than
	// across the screen. A little over, so the plate's dark surround
	// falls just inside the cone edge and the beam does not end on a
	// hard circle.
	vec2 uv = (UV - vec2(0.5)) * zoom + vec2(0.5) + drift;
	vec3 col;
	if (blur < 0.0015) {
		col = plate(uv);
	} else {
		// Centre weighted 3, inner ring 2, outer ring 1. Weighting the
		// middle keeps the hotspot a hotspot instead of flattening the
		// whole beam into an even disc as the radius opens up.
		col = plate(uv) * 3.0;
		float wsum = 3.0;
		for (int i = 0; i < 12; i++) {
			float w = i < 6 ? 2.0 : 1.0;
			col += plate(uv + DISC[i] * blur) * w;
			wsum += w;
		}
		col /= wsum;
	}
	// Chromatic split, and it is worth far more here than it was on the
	// screen: the fringe now separates ON THE WALL, at whatever distance
	// the wall happens to be.
	if (split > 0.001) {
		vec2 o = vec2(split * 0.012, split * 0.004);
		col.r = mix(col.r, texture(m_cracked, uv + o).r, split);
		col.b = mix(col.b, texture(m_cracked, uv - o).b, split);
	}
	col = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(falloff));
	COLOR = vec4(col, 1.0);
}
"""
		return s
	s.code = """
shader_type canvas_item;
// MULTIPLY. This is the ATMOSPHERE pass now, not the beam: the beam's
// pattern is on the light itself (see the cookie branch above). What
// this still does is hold the building dark around the edges of the
// frame, which is the job it was always secretly doing.
render_mode blend_mul;

// repeat_disable so sampling past the edge CLAMPS to the dark
// border rather than wrapping the beam back in as a second sun.
uniform sampler2D m_clean : filter_linear, repeat_disable;
uniform sampler2D m_cracked : filter_linear, repeat_disable;
uniform sampler2D m_haze : filter_linear, repeat_disable;
uniform float w_cracked = 0.0;
uniform float w_haze = 0.0;
uniform float surge = 0.0;
uniform float split = 0.0;
uniform float t = 0.0;
uniform vec2 drift = vec2(0.0);
uniform float falloff = 2.6;
uniform float zoom = 1.85;
// 0 = the room is dark and this layer owns the frame; 1 = the room's own
// fixtures are lighting the camera and this layer stands down. Driven by
// LightRig.room_light. See DARK_UNLIT / DARK_LIT below.
uniform float lift = 0.0;

void fragment() {
	// ZOOM OUT. The delivered plates put their bright core across most
	// of the frame, so stretched 1:1 they barely darken anything and
	// the building loses the dark it is lit for. Sampling a wider slice
	// pulls the falloff and the dark surround into view, which is what
	// turns a bright picture into a torch beam.
	vec2 uv = (UV - vec2(0.5)) * zoom + vec2(0.5) + drift;
	vec3 col = texture(m_clean, uv).rgb;
	col = mix(col, texture(m_cracked, uv).rgb, w_cracked);
	col = mix(col, texture(m_haze, uv).rgb, w_haze);

	// Chromatic split. Red and blue are pulled off the CRACKED plate in
	// opposite directions, so as the building gets hold of the player
	// their own torch starts fringing - the beam separates the way a
	// bad lens does, and it gets worse the longer they stay.
	if (split > 0.001) {
		vec2 o = vec2(split * 0.012, split * 0.004);
		col.r = mix(col.r, texture(m_cracked, uv + o).r, split);
		col.b = mix(col.b, texture(m_cracked, uv - o).b, split);
	}

	// The emitter overdriving for a moment, plus a fast flutter that
	// only exists while it is happening.
	float flutter = 1.0 + surge * sin(t * 63.0) * 0.14;
	col *= (1.0 + surge * 0.45) * flutter;

	// FALLOFF. The delivered plates are generous - big bright cores and
	// bright mid-fields - and multiplied straight in they barely darken
	// the room at all, which throws away the thing the whole building
	// is lit for. A gamma leaves white at white and crushes everything
	// below it, so the core stays a real beam and the rest of the frame
	// goes back to being a dark 1927 corridor.
	col = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(falloff));

	// Mains ripple, always there, far below conscious notice.
	col *= 0.985 + 0.015 * sin(t * 41.0);

	// THE FLOOR, AND WHY IT MOVES.
	//
	// This used to be a flat max() at 0.05 — meaning anything outside the
	// beam was multiplied down to a twentieth of itself, INCLUDING the
	// building's own fixtures. Two hundred and fifteen authored lights, a
	// per-fixture provenance table and a whole flicker model, all of it
	// arriving at the eye through a screen-space multiply that had never
	// heard of any of them. Stand in a lit bar and it still looked like a
	// dark room with a torch in it, because a dark room with a torch in
	// it was the only thing this layer could draw.
	//
	// So the floor is a mix instead of a max — the plate is remapped into
	// FLOOR..1 rather than clipped at it, which keeps the beam's shape
	// while bounding how much of the frame it is allowed to take away —
	// and the floor itself answers to the room. Dark room: 0.18, and the
	// torch is the only reason you can see. Lit room: 0.66, and the
	// vignette is barely more than a lens edge.
	//
	// The blue tint stays in both: it is the phosphor, and the building's
	// own tungsten reading warm against it is half of why the torch feels
	// like the wrong light to be looking at a home with.
	const vec3 DARK_UNLIT = vec3(0.180, 0.196, 0.230);
	const vec3 DARK_LIT = vec3(0.660, 0.672, 0.700);
	vec3 base = mix(DARK_UNLIT, DARK_LIT, lift);
	col = mix(base, vec3(1.0), clamp(col, vec3(0.0), vec3(1.0)));
	COLOR = vec4(col, 1.0);
}
"""
	return s
