class_name LightFixtureProp
extends FunctionalProp
## The building's period lighting family — seven original fixture types,
## one per room typology. Each is a conductor body (filament class: motif
## events surge the envelope, no audio of its own) and a client of the
## LightRig, which enables every fixture on the active floor and electrically
## darkens the other storeys. Light QUALITY over quantity:
## tungsten-warm color ramps, inverse-square-ish falloff, an emissive
## envelope + additive halo so the source reads even when its OmniLight
## is budgeted away, and a low faux-bounce light the rig enables up close
## to fake the first ray bounce.

const TONE := {  # warm tungsten family, per fixture type
	"pendant_shade": Color(1.0, 0.83, 0.60),
	"flush_dome": Color(1.0, 0.86, 0.66),
	"sconce_globe": Color(1.0, 0.88, 0.72),
	"kitchen_linear": Color(0.95, 0.93, 0.82),
	"cage_bulb": Color(1.0, 0.76, 0.50),
	"chandelier": Color(1.0, 0.82, 0.58),
	"eye_pendant": Color(1.0, 0.84, 0.62),
	# Sodium: the warmest, most orange thing in the palette, and the one
	# colour that reads as "outside at night" without any other cue.
	"street_lamp": Color(1.0, 0.66, 0.28),
}
const ENERGY := {
	# flush_dome ran at 0.9 against the pendant's 2.1, and the two are not
	# decorative alternatives - ROOM_FIXTURE gives pendants to living rooms and
	# domes to BEDROOMS, halls and alcoves. So every bedroom in the building was
	# lit at under half the rate of the room next door, measured with its own
	# switch on: 2A main 39.7 mean luma, 2A bedroom 5.9, at 78% near-black.
	# A schoolhouse dome is a bare lamp behind opal glass; it is not a dim
	# fitting, it is a diffuse one.
	"pendant_shade": 2.1, "flush_dome": 1.9, "sconce_globe": 1.3,
	"kitchen_linear": 1.5, "cage_bulb": 1.5, "chandelier": 2.8,
	"eye_pendant": 2.2, "street_lamp": 3.4,
}
const RANGE := {
	"pendant_shade": 6.5, "flush_dome": 5.5, "sconce_globe": 4.0,
	"kitchen_linear": 4.5, "cage_bulb": 5.5, "chandelier": 9.0,
	"eye_pendant": 7.5, "street_lamp": 11.0,
}

var light: OmniLight3D
var bounce: OmniLight3D
var _bulb_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _base_energy := 1.5
var _target_scale := 1.0   # set by the LightRig
var _bounce_on := false    # set by the LightRig
var _surge := 0.0
var _swing_node: Node3D
var _individual_tone := Color.WHITE
var _individual_gain := 1.0
var _flicker_depth := 0.0
var _flicker_speed := 1.0
var _flicker_phase := 0.0
var _flicker_profile := 0
var _flicker_value := 1.0
var _intermittent_exterior_fault := false
var _weathered_exterior := false
var _entry_spot: SpotLight3D
var _entry_emphasis := 1.0
## Authored throw from the generator, fitted to the room the fixture hangs
## in. For ROOM fixtures it is a cap: pools die at their own walls instead
## of bleeding through shadowless neighbors (the light-leak pass, done as
## data). For CIRCULATION fixtures it is the throw itself, cap included —
## a corridor is longer than any single room, and clamping its domes to the
## family default is what left corridors black between pools.
var range_clamp := 0.0
## Room-character multiplier from the generator (Mina bright, Juno dim).
var energy_scale := 1.0
## Minimum direct contribution when outside the nearby full-light budget.
## Navigation fixtures receive a higher authored value from the light map.
var standby_scale := 0.0
var navigation_light := false
## Venue-state dimmer (Harukiya OPEN/CLOSED/AFTER-HOURS). Multiplies the
## final output the way a dimmed circuit would, leaving the switch state,
## the rig's budget, and the authored energy all untouched.
var _state_gain := 1.0


func set_state_gain(gain: float) -> void:
	_state_gain = clampf(gain, 0.0, 1.0)


func _build_visual() -> void:
	_base_energy = ENERGY.get(prop_type, 1.5) * energy_scale
	var tone: Color = TONE.get(prop_type, Color(1.0, 0.84, 0.62))
	_author_personality(tone)
	if name == "F01_ENTRY_SCONCE":
		_flicker_profile = 2
		_flicker_depth = 0.045
		_flicker_speed = 0.86
	elif prop_type == "chandelier":
		# The lobby chandelier never quite holds mains voltage and seems to
		# breathe even when the air below it is still.
		_flicker_profile = 4
		_flicker_depth = 0.14
		_flicker_speed = 0.58
		_individual_tone = Color(0.86, 0.62, 0.34)
	tone = _individual_tone
	_base_energy *= _individual_gain
	# A navigation source may be moody, but never so weak that the next
	# doorway or stair edge disappears. Room fixtures retain the wider
	# character range because darkness between their pools is intentional.
	if navigation_light:
		_base_energy = maxf(_base_energy, 0.72)
	_swing_node = Node3D.new()
	add_child(_swing_node)
	var bulb_at := _build_body(_swing_node)
	retexture(_swing_node, [
		[Color(0.62, 0.55, 0.30), "brass", Color.WHITE],
		[Color(0.78, 0.70, 0.58), "linen", Color(0.97, 0.90, 0.80), 0.5],
		[Color(0.88, 0.86, 0.80), "enamel", Color.WHITE],
		[Color(0.3, 0.3, 0.32), "metal", Color(0.46, 0.46, 0.50)],
	])
	# emissive envelope: the fixture reads lit even outside the budget
	_bulb_mat = _pmat(Color(1.0, 0.97, 0.9), 0.2)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = tone
	_bulb_mat.emission_energy_multiplier = 1.6
	for c in _swing_node.get_children():
		if c is MeshInstance3D:
			# The housing and diffuser surround the OmniLight. Including
			# either in its cubemap creates giant self-shadow spokes.
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if c is MeshInstance3D and c.name.begins_with("bulb"):
			c.material_override = _bulb_mat
	# additive halo billboard around the source
	_halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	if prop_type == "chandelier":
		quad.size = Vector2(1.2, 1.2)
	elif prop_type == "sconce_globe" and name.ends_with("_LT_SCONCE"):
		# The default 550 mm additive bloom was more than three times the
		# globe diameter. Beside a 460 mm medicine cabinet it overlapped the
		# mirror even though the brass bodies had measured clearance, making
		# the composition read crowded and the glass look self-illuminated.
		quad.size = Vector2(0.32, 0.32)
	else:
		quad.size = Vector2(0.55, 0.55)
	_halo.mesh = quad
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var grad := Gradient.new()
	grad.set_color(0, Color(tone.r, tone.g, tone.b, 0.30))
	grad.set_color(1, Color(tone.r, tone.g, tone.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	hm.albedo_texture = gt
	_halo.material_override = hm
	_halo.position = bulb_at
	_swing_node.add_child(_halo)
	# the main pool
	light = OmniLight3D.new()
	light.light_color = tone
	light.light_energy = 0.0     # the rig fades it in
	var family_range: float = RANGE.get(prop_type, 5.0)
	if range_clamp <= 0.0:
		light.omni_range = family_range
	elif navigation_light:
		light.omni_range = range_clamp
	else:
		light.omni_range = minf(family_range, range_clamp)
	# Circulation fixtures fall off gently so consecutive pools overlap
	# and a corridor reads to its far end; room fixtures keep the tighter
	# inverse-square-ish curve that gives interiors their modelling.
	# Falloff, and it is the reason twelve of twenty-eight rooms on F02 rendered
	# as black frames while LightingAudit passed - the audit counts fixtures and
	# never measures brightness, so a correctly-mapped room could be unlit.
	#
	# 2.0 is a steep curve: it puts a hot pool under the fitting and gives the
	# rest of the room nothing. Circulation was always exempted at 1.35 and
	# looked right, which is the tell - the harsh number was only ever applied
	# where the bible asks for the opposite. "Circulation is DIM and the homes
	# are WARM" (gen_layout ROOM_LIGHT) cannot survive the homes getting the
	# tighter light.
	#
	# Softening spreads the same bulb through the room instead of making it
	# brighter, so the peak does not move and nothing blows out.
	light.omni_attenuation = 1.35 if navigation_light else 1.4
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	# Tight contact shadows. The previous 0.42 normal bias pushed shadows
	# so far off furniture and trim that they disappeared under ambient fill.
	light.shadow_bias = 0.012
	light.shadow_normal_bias = 0.08
	light.shadow_opacity = 1.0
	light.light_size = 0.10 if prop_type in ["flush_dome", "kitchen_linear"] \
			else 0.16
	light.position = bulb_at
	_swing_node.add_child(light)
	# A tight downward cone makes the entrance a destination without letting
	# its wall fixture wash the lobby, facade, and half the street.
	if name == "F01_ENTRY_SCONCE":
		light.omni_range = minf(light.omni_range, 2.4)
		_entry_spot = SpotLight3D.new()
		_entry_spot.name = "EntrancePool"
		_entry_spot.light_color = Color(1.0, 0.64, 0.27)
		_entry_spot.light_energy = 0.0
		_entry_spot.spot_range = 5.2
		_entry_spot.spot_angle = 47.0
		_entry_spot.spot_angle_attenuation = 1.55
		_entry_spot.spot_attenuation = 1.45
		_entry_spot.shadow_enabled = true
		_entry_spot.shadow_bias = 0.012
		_entry_spot.shadow_normal_bias = 0.08
		_entry_spot.light_size = 0.18
		_entry_spot.position = bulb_at + Vector3(0, -0.02, 0.04)
		_entry_spot.rotation.x = -PI * 0.5
		_swing_node.add_child(_entry_spot)
	# faux first bounce: a dim, floor-tinted counter-light low in the room
	bounce = OmniLight3D.new()
	bounce.light_color = Color(0.62, 0.47, 0.33)  # oak-bounce warmth
	bounce.light_energy = 0.0
	bounce.omni_range = light.omni_range
	bounce.omni_attenuation = 1.35
	bounce.shadow_enabled = false
	# Keep this below the ceiling contact geometry. It is a deliberately
	# restrained first-bounce approximation, not a second visible source.
	bounce.position = bulb_at + Vector3(0, -1.0, 0)
	add_child(bounce)
	add_to_group("light_fixtures")
	set_meta("light_personality", {
		"tone": _individual_tone,
		"gain": _individual_gain,
		"flicker_profile": _flicker_profile,
		"flicker_depth": _flicker_depth,
		"flicker_speed": _flicker_speed,
	})


func _author_personality(base_tone: Color) -> void:
	# Names are authored IDs, so this produces stable variations per fixture
	# rather than randomized lighting that changes between launches.
	var seed := absi(str(name).hash())
	var hue_shift := (float(seed & 1023) / 1023.0 - 0.5) * 0.045
	var saturation_shift := (float((seed >> 10) & 255) / 255.0 - 0.5) * 0.10
	var value_shift := (float((seed >> 18) & 255) / 255.0 - 0.5) * 0.08
	_individual_tone = Color.from_hsv(
			fposmod(base_tone.h + hue_shift, 1.0),
			clampf(base_tone.s + saturation_shift, 0.0, 1.0),
			clampf(base_tone.v + value_shift, 0.72, 1.0))
	var raw_gain := lerpf(0.78, 1.13,
			float((seed >> 5) & 1023) / 1023.0)
	_individual_gain = clampf(raw_gain, 0.88, 1.10) \
			if navigation_light else raw_gain
	_flicker_profile = (seed >> 15) % 5
	_flicker_phase = float((seed >> 4) & 4095) * 0.017
	_flicker_speed = lerpf(0.55, 2.6,
			float((seed >> 9) & 1023) / 1023.0)
	# Most bulbs merely breathe at the edge of perception. Only one profile
	# has a visible starter/dropout, and fluorescents receive slightly more.
	_flicker_depth = lerpf(0.004, 0.025,
			float((seed >> 20) & 255) / 255.0)
	if _flicker_profile == 4:
		_flicker_depth = 0.11 if prop_type == "kitchen_linear" else 0.065


## Builds the body under `p`, returns the bulb's local position.
func _build_body(p: Node3D) -> Vector3:
	var brass := Color(0.62, 0.55, 0.30)
	var opal := Color(0.94, 0.93, 0.88)
	match prop_type:
		"pendant_shade":
			make_cyl(0.006, 0.006, 0.55, Vector3(0, -0.275, 0),
					Color(0.15, 0.14, 0.13), 0.4, 0.0, p)
			make_cyl(0.19, 0.23, 0.24, Vector3(0, -0.63, 0),
					Color(0.78, 0.70, 0.58), 0.8, 0.0, p)   # fabric drum
			make_cyl(0.20, 0.20, 0.012, Vector3(0, -0.755, 0), opal,
					0.3, 0.0, p).name = "bulb_diffuser"
			var b := make_cyl(0.032, 0.045, 0.075, Vector3(0, -0.56, 0),
					opal, 0.2, 0.0, p)
			b.name = "bulb"
			return Vector3(0, -0.62, 0)
		"flush_dome":
			# Period schoolhouse flush mount: stepped ceiling canopy, brass
			# retaining ring, and a rounded opal bowl. The old cone read as
			# a flat white marker once its emission bloomed.
			make_cyl(0.115, 0.095, 0.030, Vector3(0, -0.015, 0), brass,
					0.3, 0.7, p)
			make_cyl(0.135, 0.115, 0.040, Vector3(0, -0.050, 0), brass,
					0.3, 0.75, p)
			var rim := make_ring(0.142, 0.010, Vector3(0, -0.072, 0),
					brass, 0.28, 0.75, p)
			rim.rotation_degrees = Vector3(90, 0, 0)
			var d := MeshInstance3D.new()
			var bowl := SphereMesh.new()
			bowl.radius = 0.165
			bowl.height = 0.23
			bowl.radial_segments = 24
			bowl.rings = 12
			d.mesh = bowl
			d.position = Vector3(0, -0.145, 0)
			d.name = "bulb_dome"
			p.add_child(d)
			return Vector3(0, -0.15, 0)
		"sconce_globe":
			if name == "F01_ENTRY_SCONCE":
				return _build_entry_lantern(p, brass)
			make_box(Vector3(0.09, 0.16, 0.025),
					Vector3(0, 0, -0.012), brass).reparent(p)
			make_cyl(0.02, 0.03, 0.10, Vector3(0, 0.02, 0.06), brass,
					0.3, 0.7, p).rotation_degrees = Vector3(55, 0, 0)
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.085
			sm.height = 0.17
			g.mesh = sm
			g.name = "bulb_globe"
			g.position = Vector3(0, 0.09, 0.115)
			p.add_child(g)
			return Vector3(0, 0.09, 0.115)
		"kitchen_linear":
			make_box(Vector3(0.72, 0.05, 0.13), Vector3(0, -0.025, 0),
					Color(0.88, 0.86, 0.80)).reparent(p)
			var t := make_cyl(0.02, 0.02, 0.62, Vector3(0, -0.065, 0),
					opal, 0.2, 0.0, p)
			t.rotation_degrees = Vector3(0, 0, 90)
			t.name = "bulb_tube"
			return Vector3(0, -0.07, 0)
		"cage_bulb":
			make_cyl(0.005, 0.005, 0.42, Vector3(0, -0.21, 0),
					Color(0.1, 0.1, 0.1), 0.5, 0.0, p)
			var bu := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.045
			bs.height = 0.11
			bu.mesh = bs
			bu.name = "bulb"
			bu.position = Vector3(0, -0.49, 0)
			p.add_child(bu)
			for rz in [0.0, 60.0, 120.0]:
				var ring := make_ring(0.075, 0.004,
						Vector3(0, -0.49, 0), Color(0.3, 0.3, 0.32),
						0.4, 0.6, p)
				ring.rotation_degrees = Vector3(90, rz, 0)
			make_cyl(0.05, 0.06, 0.04, Vector3(0, -0.425, 0),
					Color(0.3, 0.3, 0.32), 0.4, 0.6, p)
			return Vector3(0, -0.50, 0)
		"chandelier":
			# The lobby's one piece of real money, and the only thing in the
			# building that was ever meant to be looked at.
			#
			# 1926 gives two hallmarks: the "pan" fixture and the bowl
			# pendant. A Queens house with aspirations bought the bowl - a
			# Colonial Revival electrolier, cast bronze crown on three
			# chains, an inverted opal bowl slung under it, and a ring of
			# candle lamps above the rim so the ceiling gets lit too. The
			# bowl does the work; the candles are the argument for the rent.
			#
			# It is NOT broken. The previous fixture here was modelled with
			# verdigris, a bent arm and an empty socket, which reads as a
			# missing asset rather than as atmosphere. Decay in this building
			# should be something the player notices, not something they
			# mistake for a bug. What is left of the wear is in the texture
			# and in the flicker.
			var bronze := Color(0.62, 0.55, 0.30)
			# canopy: stepped disc against the plaster, then the collar
			make_cyl(0.125, 0.105, 0.030, Vector3(0, -0.015, 0), bronze,
					0.34, 0.85, p)
			make_cyl(0.052, 0.062, 0.055, Vector3(0, -0.052, 0), bronze,
					0.34, 0.85, p)
			# three chains, canopy edge out to the crown
			for ch in 3:
				var ca := TAU * ch / 3.0 + 0.5
				var top := Vector3(cos(ca) * 0.105, -0.070, sin(ca) * 0.105)
				var bot := Vector3(cos(ca) * 0.165, -0.385, sin(ca) * 0.165)
				for li in 7:
					var t := (li + 0.5) / 7.0
					var link := make_ring(0.021, 0.0042,
							top.lerp(bot, t), bronze, 0.42, 0.85, p)
					link.rotation_degrees = Vector3(90,
							0 if li % 2 == 0 else 90, 0)
			# the crown: gallery collar, banded above and below
			make_ring(0.168, 0.013, Vector3(0, -0.400, 0), bronze,
					0.34, 0.85, p)
			make_cyl(0.150, 0.172, 0.062, Vector3(0, -0.434, 0), bronze,
					0.34, 0.85, p)
			make_ring(0.158, 0.010, Vector3(0, -0.470, 0), bronze,
					0.34, 0.85, p)
			# six candle lamps on arms that sweep out and back up, so the
			# bowl is not the only thing throwing light
			for i in 6:
				var a := TAU * i / 6.0
				var dir := Vector3(cos(a), 0, sin(a))
				var knee := dir * 0.255 + Vector3(0, -0.395, 0)
				_strut(dir * 0.165 + Vector3(0, -0.418, 0), knee,
						0.0105, bronze, p)
				var cup := dir * 0.310 + Vector3(0, -0.300, 0)
				_strut(knee, cup, 0.0105, bronze, p)
				# bobeche, candle tube, flame-tip lamp
				make_cyl(0.046, 0.020, 0.014, cup, bronze, 0.34, 0.85, p)
				make_cyl(0.019, 0.021, 0.090,
						cup + Vector3(0, 0.052, 0), Color(0.88, 0.86, 0.80),
						0.62, 0.0, p)
				var flame := make_cyl(0.005, 0.021, 0.062,
						cup + Vector3(0, 0.128, 0), opal, 0.2, 0.0, p)
				flame.name = "bulb_candle_%d" % i
			# three straps carrying the bowl out to its rim
			for sp in 3:
				var sa := TAU * sp / 3.0 + 0.5
				_strut(Vector3(cos(sa) * 0.160, -0.480, sin(sa) * 0.160),
						Vector3(cos(sa) * 0.330, -0.556, sin(sa) * 0.330),
						0.0095, bronze, p)
			# the bowl itself: a turned profile, not a cone. Named bulb_ so
			# it takes the emissive material and glows with the fixture.
			var prof := [[0.340, 0.329, 0.0675, -0.58375],
					[0.329, 0.294, 0.0675, -0.65125],
					[0.294, 0.243, 0.0540, -0.71200],
					[0.243, 0.179, 0.0405, -0.75925],
					# closes to a point rather than a 6 cm opening: from
					# directly underneath, which is where everyone walks,
					# an open bowl bottom reads as a hole punched in the
					# glass rather than as the turned base of a bowl.
					[0.179, 0.014, 0.0405, -0.79975]]
			for bi in prof.size():
				var seg: Array = prof[bi]
				var band := make_cyl(seg[0], seg[1], seg[2],
						Vector3(0, seg[3], 0), opal, 0.22, 0.0, p)
				band.name = "bulb_bowl_%d" % bi
			# rim band and the finial that finishes the underside
			make_ring(0.345, 0.013, Vector3(0, -0.552, 0), bronze,
					0.34, 0.85, p)
			make_cyl(0.050, 0.030, 0.026, Vector3(0, -0.833, 0), bronze,
					0.34, 0.85, p)
			make_cyl(0.030, 0.009, 0.048, Vector3(0, -0.870, 0), bronze,
					0.34, 0.85, p)
			return Vector3(0, -0.620, 0)
		"street_lamp":
			# cobra head on its mast: the lamp body already exists as site
			# geometry, so this is only the lit lens and its shroud
			make_cyl(0.10, 0.16, 0.10, Vector3(0, 0.02, 0),
					Color(0.3, 0.3, 0.32), 0.4, 0.6, p)
			var lens := MeshInstance3D.new()
			var ls := SphereMesh.new()
			ls.radius = 0.13
			ls.height = 0.16
			lens.mesh = ls
			lens.name = "stained_lens"
			lens.position = Vector3(0, -0.06, 0)
			var glass := StandardMaterial3D.new()
			glass.albedo_texture = load("res://assets/building/textures/" +
					"exterior_lighting/stained_cracked_prismatic_glass.png")
			glass.albedo_color = Color(0.54, 0.38, 0.18)
			glass.roughness = 0.48
			glass.emission_enabled = true
			glass.emission = Color(0.65, 0.27, 0.055)
			glass.emission_energy_multiplier = 0.42
			lens.material_override = glass
			p.add_child(lens)
			var core := make_cyl(0.035, 0.045, 0.065,
					Vector3(0, -0.055, 0), Color.WHITE, 0.2, 0.0, p)
			core.name = "bulb_core"
			return Vector3(0, -0.08, 0)
		_:  # eye_pendant: a fruit hanging off the court's bonsai
			# The court's light is fruit on a brass tree wound up the stair
			# well. The generator hangs these at the branch tips, so all
			# this owns is the fruit: a short stalk, a brass calyx, and a
			# heavy opal globe under it.
			make_cyl(0.008, 0.008, 0.10, Vector3(0, 0.10, 0),
					Color(0.42, 0.35, 0.18), 0.4, 0.6, p)
			make_cyl(0.030, 0.052, 0.028, Vector3(0, 0.048, 0), brass,
					0.3, 0.8, p)
			var fruit := MeshInstance3D.new()
			var fs := SphereMesh.new()
			# taller than wide: a hung globe pulls itself into a teardrop
			fs.radius = 0.115
			fs.height = 0.27
			fs.radial_segments = 18
			fs.rings = 10
			fruit.mesh = fs
			fruit.name = "bulb_fruit"
			fruit.position = Vector3(0, -0.10, 0)
			p.add_child(fruit)
			return Vector3(0, -0.10, 0)
	return Vector3.ZERO


func _build_entry_lantern(p: Node3D, brass: Color) -> Vector3:
	# Deep wall bracket, peaked cap, protective frame and stained prismatic
	# panes. The projection keeps the lens and light clear of the masonry.
	make_box(Vector3(0.30, 0.44, 0.045), Vector3(0, -0.02, 0.0),
			brass.darkened(0.48)).reparent(p)
	make_box(Vector3(0.10, 0.12, 0.30), Vector3(0, 0.02, 0.15),
			brass.darkened(0.35)).reparent(p)
	var glass := StandardMaterial3D.new()
	glass.albedo_texture = load("res://assets/building/textures/" +
			"exterior_lighting/stained_cracked_prismatic_glass.png")
	glass.albedo_color = Color(0.72, 0.50, 0.22)
	glass.roughness = 0.44
	glass.emission_enabled = true
	glass.emission = Color(0.72, 0.30, 0.07)
	glass.emission_energy_multiplier = 0.65
	for side in [-1.0, 1.0]:
		var pane := make_box(Vector3(0.23, 0.36, 0.012),
				Vector3(0, -0.08, 0.315 + side * 0.105), Color.WHITE)
		pane.name = "stained_glass"
		pane.material_override = glass
		pane.reparent(p)
	for x in [-0.145, 0.145]:
		make_box(Vector3(0.025, 0.48, 0.27), Vector3(x, -0.08, 0.315),
				brass.darkened(0.42)).reparent(p)
	for y in [-0.31, 0.15]:
		make_box(Vector3(0.32, 0.025, 0.27), Vector3(0, y, 0.315),
				brass.darkened(0.38)).reparent(p)
	var cap := make_cyl(0.24, 0.16, 0.12, Vector3(0, 0.20, 0.315),
			brass.darkened(0.32), 0.54, 0.75, p)
	cap.name = "weather_cap"
	var bulb := make_cyl(0.038, 0.050, 0.11, Vector3(0, -0.08, 0.315),
			Color.WHITE, 0.18, 0.0, p)
	bulb.name = "bulb_core"
	return Vector3(0, -0.10, 0.315)


func _start_normal_function() -> void:
	state = PState.OPERATING


## The wall switch's verdict. The LightRig decides what the BUDGET affords;
## this decides what the RESIDENT chose, and off is off whatever the rig
## can afford.
var powered := true

## Whether this fixture should be allowed to spend one of the sixteen shadow
## slots when the rig ranks it near the camera.
##
## `powered` and the budget already decide whether a light BURNS. This decides
## something separate: whether it is worth an entry in the positional atlas,
## which is a fixed 8192 subdividing per caster, so every slot granted shrinks
## every other shadow in the frame (TASKS L13).
##
## Default true, because an ordinary room light casts. It is turned off for
## fixtures that burn at a fraction of their authored output — an arcade shop's
## overnight security bulb is the first — where a sharp architectural shadow
## thrown down the nave is wrong to look at.
##
## The justification is the IMAGE, not the frame. An earlier draft of this
## comment claimed the ten arcade security lights cost 2,566 draw calls and
## 3.61 ms at passage northbound. They do not. That figure came from the
## diagnostic row that turns off EVERY light's shadow in the scene, and
## attributing the whole scene's shadow cost to the ten fixtures under
## suspicion was wrong. Measured properly, over a full eleven-station run
## against the same run without them, the security lights cost nothing
## outside the noise band (arcade +0.86, passage northbound -0.42 ms).
var wants_shadow := true


func set_powered(on: bool) -> void:
	powered = on
	if not on:
		set_budget(0.0, false, false)


## The rig asks this before a fixture is allowed into the ranking
## (light_rig.gd:493-496). LampProp answered it and LightFixtureProp never
## did, so a shop light the hours director had switched OFF still entered the
## contest, still won an index, and -- because set_budget writes
## shadow_enabled from that index BEFORE zeroing the scale for an unpowered
## fixture -- still held a shadow map while emitting nothing. Measured at the
## four arcade stations: 0 / 2 / 5 / 3 shadow maps held by dark bulbs, taken
## from lanterns that had something to show.
func is_locally_enabled() -> bool:
	return powered and _state_gain > 0.001


func set_budget(scale: float, with_bounce: bool, with_shadow: bool) -> void:
	if not powered:
		scale = 0.0
	_target_scale = scale
	_bounce_on = with_bounce
	if light:
		# Compatibility counts visible zero-energy lights against its
		# per-object limit, so dormant fixtures must leave the render list.
		light.visible = scale > 0.001
		light.shadow_enabled = with_shadow
	if _entry_spot:
		_entry_spot.visible = scale > 0.001
		_entry_spot.shadow_enabled = with_shadow
	if _halo:
		_halo.visible = scale > 0.001
	if bounce:
		bounce.visible = with_bounce and scale > 0.001


func set_intermittent_exterior_fault(enabled: bool) -> void:
	_intermittent_exterior_fault = enabled
	if enabled:
		_flicker_depth = 0.18
		_flicker_speed = 1.0


func set_weathered_exterior(enabled: bool) -> void:
	_weathered_exterior = enabled
	if enabled:
		_flicker_depth = 0.055
		_flicker_speed = 0.72 + float(absi(str(name).hash()) % 30) * 0.018
		_flicker_profile = 2 + absi(str(name).hash()) % 2


## Exterior art direction: street fixtures recede while the entry fixture
## carries the warmest and strongest pool in the composition.
func set_exterior_composition_gain(gain: float) -> void:
	_base_energy *= clampf(gain, 0.1, 2.0)


func set_entry_emphasis(gain: float) -> void:
	_entry_emphasis = clampf(gain, 0.5, 2.5)
	_base_energy *= _entry_emphasis
	if _entry_spot:
		_entry_spot.spot_range = 6.6
		_entry_spot.spot_angle = 41.0
		_entry_spot.spot_attenuation = 1.75


func _process(delta: float) -> void:
	if light == null:
		return
	var t := Time.get_ticks_msec() * 0.001 + _flicker_phase
	var drift := sin(t * _flicker_speed) * _flicker_depth
	match _flicker_profile:
		0: # unusually steady replacement bulb
			drift *= 0.18
		1: # slow tungsten filament breathing
			drift += sin(t * 0.23 + 1.7) * _flicker_depth * 0.45
		2: # asymmetric old-mains flutter
			drift += maxf(0.0, sin(t * 3.7)) * _flicker_depth * 0.35
		3: # paired beat frequencies, visible only in peripheral vision
			drift += sin(t * 1.93) * sin(t * 0.37) * _flicker_depth * 0.7
		4: # rare starter/contact dropout, never a constant horror strobe
			var gate := pow(maxf(0.0, sin(t * 0.19)), 42.0)
			drift -= gate * _flicker_depth * 4.2
	_flicker_value = clampf(1.0 + drift, 0.52, 1.08)
	if _intermittent_exterior_fault:
		# A failed photocell/ballast: mostly dead, then an ugly sputter
		# followed by a brief period of normal sodium light.
		var cycle := fmod(t + _flicker_phase, 19.0)
		var fault_value := 0.0
		if cycle > 12.8 and cycle < 14.4:
			var contact := sin(cycle * 47.0) * sin(cycle * 19.0)
			var chatter := 1.0 if contact >= 0.30 else 0.0
			fault_value = chatter * 0.72
		elif cycle >= 14.4 and cycle < 17.8:
			fault_value = 0.94 + sin(cycle * 8.0) * 0.035
		_flicker_value = fault_value
	var want := _base_energy * _target_scale * (1.0 + _surge) \
			* _flicker_value * _state_gain
	light.light_energy = lerpf(light.light_energy, want, delta * 6.0)
	if _entry_spot:
		_entry_spot.light_energy = lerpf(_entry_spot.light_energy,
				2.35 * _entry_emphasis * _target_scale * _flicker_value,
				delta * 5.0)
	bounce.light_energy = lerpf(bounce.light_energy,
			(_base_energy * 0.055 * _target_scale * _flicker_value)
			if _bounce_on else 0.0,
			delta * 4.0)
	var envelope := (1.0 if prop_type == "flush_dome" else 1.6) \
			* _target_scale * _flicker_value * _state_gain
	_bulb_mat.emission_energy_multiplier = lerpf(
			_bulb_mat.emission_energy_multiplier, envelope + _surge * 2.4,
			delta * 8.0)
	_surge = maxf(0.0, _surge - delta * 2.2)
	if prop_type == "chandelier":
		_swing_node.rotation.z = sin(t * 0.37) * 0.018 + sin(t * 0.11) * 0.006
		_swing_node.rotation.x = cos(t * 0.29) * 0.012
	if prop_type in ["cage_bulb", "eye_pendant"] and _surge > 0.01:
		_swing_node.rotation.z = sin(Time.get_ticks_msec() * 0.004) \
				* _surge * 0.06


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_surge = maxf(_surge, accent * 0.9)


## A tube running between two points, correctly oriented.
##
## The old chandelier faked this with a hand-tuned Euler triple that only
## held for the one radius it was written against. Arms that sweep in two
## planes need the real thing.
func _strut(from: Vector3, to: Vector3, r: float, color: Color,
		parent: Node3D) -> MeshInstance3D:
	var span := to - from
	var mi := make_cyl(r, r, span.length(), (from + to) * 0.5,
			color, 0.34, 0.85, parent)
	var dir := span.normalized()
	var dot := clampf(Vector3.UP.dot(dir), -1.0, 1.0)
	if absf(dot) < 0.9999:
		mi.rotation = Basis(Vector3.UP.cross(dir).normalized(),
				acos(dot)).get_euler()
	elif dot < 0.0:
		mi.rotation = Vector3(PI, 0, 0)
	return mi
