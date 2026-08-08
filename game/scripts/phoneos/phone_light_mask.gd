class_name PhoneLightMask
extends Control
## The torch beam, blended live from three photographs.
##
## The mask multiplies over the whole frame (gl_compatibility ignores
## light_projector, so the beam is a screen-space layer rather than a
## projector cookie). One static image means one mood for an entire
## shift, and this is the most-looked-at surface in the game — the
## torch is lit from the first frame. So three are mixed in a shader
## and the mix answers to what the building is doing to the player.
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


var _mat: ShaderMaterial
var _player: Node3D
var _sanity: Node
var _w_cracked := 0.0
var _w_haze := 0.0
var _surge := 0.0
var _t := 0.0
var _aim := Vector2.ZERO


func setup(player: Node3D) -> void:
	_player = player
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


func _find_sanity() -> void:
	if _sanity != null and is_instance_valid(_sanity):
		return
	var root := get_tree().get_first_node_in_group("building_root")
	if root == null:
		root = get_tree().current_scene
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
	# A tighter beam when still, a slightly opener one when moving -
	# the eye reads the difference as the hand relaxing.
	_mat.set_shader_parameter("falloff", 2.35 - _w_haze * 0.40)
	_mat.set_shader_parameter("t", _t)


func _make_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
// MULTIPLY. The mask's brightness IS the lighting: white passes the
// frame through and is the beam, dark is the mask.
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

	// Never let the mask reach pure black: at zero the frame is gone
	// rather than dark, and the building's own fixtures stop reading.
	col = max(col, vec3(0.050, 0.058, 0.078));
	COLOR = vec4(col, 1.0);
}
"""
	return s
