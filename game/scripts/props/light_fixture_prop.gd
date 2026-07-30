class_name LightFixtureProp
extends FunctionalProp
## The building's period lighting family — seven original fixture types,
## one per room typology. Each is a conductor body (filament class: motif
## events surge the envelope, no audio of its own) and a client of the
## LightRig, which spends the compatibility renderer's light budget on
## the fixtures nearest the camera. Light QUALITY over quantity:
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
}
const ENERGY := {
	"pendant_shade": 2.1, "flush_dome": 0.9, "sconce_globe": 0.75,
	"kitchen_linear": 1.5, "cage_bulb": 1.5, "chandelier": 2.8,
	"eye_pendant": 2.2,
}
const RANGE := {
	"pendant_shade": 6.5, "flush_dome": 5.5, "sconce_globe": 4.0,
	"kitchen_linear": 4.5, "cage_bulb": 5.5, "chandelier": 9.0,
	"eye_pendant": 7.5,
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
## Per-room cap from the generator: pools die at their own walls
## instead of bleeding through shadowless neighbors (the light-leak
## pass, done as data).
var range_clamp := 0.0
## Room-character multiplier from the generator (Mina bright, Juno dim).
var energy_scale := 1.0
## Minimum direct contribution when outside the nearby full-light budget.
## Navigation fixtures receive a higher authored value from the light map.
var standby_scale := 0.0
var navigation_light := false


func _build_visual() -> void:
	_base_energy = ENERGY.get(prop_type, 1.5) * energy_scale
	var tone: Color = TONE.get(prop_type, Color(1.0, 0.84, 0.62))
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
	quad.size = Vector2(0.55, 0.55) if prop_type != "chandelier" \
			else Vector2(1.2, 1.2)
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
	light.omni_range = RANGE.get(prop_type, 5.0) if range_clamp <= 0.0 \
			else minf(RANGE.get(prop_type, 5.0), range_clamp)
	light.omni_attenuation = 1.75 if navigation_light else 2.0
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
			# Compact 1920s vestibule fixture: chain, turned hub, six curved
			# arms and downward opal shades kept above head clearance.
			make_cyl(0.055, 0.075, 0.035, Vector3(0, -0.018, 0), brass,
					0.3, 0.8, p)
			for link_i in range(5):
				var link := make_ring(0.025, 0.004,
						Vector3(0, -0.09 - link_i * 0.055, 0),
						brass, 0.32, 0.8, p)
				link.rotation_degrees = Vector3(90,
						0 if link_i % 2 == 0 else 90, 0)
			make_cyl(0.045, 0.085, 0.18, Vector3(0, -0.39, 0), brass,
					0.3, 0.8, p)
			make_ring(0.24, 0.012, Vector3(0, -0.47, 0), brass,
					0.3, 0.8, p).rotation_degrees = Vector3(90, 0, 0)
			for i in 6:
				var a := TAU * i / 6.0
				var inner := Vector3(cos(a) * 0.07, -0.45, sin(a) * 0.07)
				var outer := Vector3(cos(a) * 0.29, -0.61, sin(a) * 0.29)
				make_cyl(0.009, 0.009, inner.distance_to(outer),
						(inner + outer) * 0.5, brass, 0.3, 0.8, p
						).rotation_degrees = Vector3(
								62.0 * cos(a), -rad_to_deg(a),
								62.0 * sin(a))
				make_cyl(0.032, 0.045, 0.07,
						outer + Vector3(0, -0.035, 0), brass, 0.3, 0.8, p)
				var shade := make_cyl(0.105, 0.055, 0.12,
						outer + Vector3(0, -0.13, 0), opal, 0.22, 0.0, p)
				shade.name = "bulb_shade_%d" % i
			return Vector3(0, -0.58, 0)
		_:  # eye_pendant: the long drop down the atrium
			make_cyl(0.007, 0.007, 1.35, Vector3(0, -0.675, 0),
					Color(0.12, 0.12, 0.12), 0.4, 0.0, p)
			var g2 := MeshInstance3D.new()
			var s2 := SphereMesh.new()
			s2.radius = 0.14
			s2.height = 0.28
			g2.mesh = s2
			g2.name = "bulb_globe"
			g2.position = Vector3(0, -1.48, 0)
			p.add_child(g2)
			make_cyl(0.05, 0.075, 0.07, Vector3(0, -1.335, 0), brass,
					0.3, 0.8, p)
			return Vector3(0, -1.48, 0)
	return Vector3.ZERO


func _start_normal_function() -> void:
	state = PState.OPERATING


func set_budget(scale: float, with_bounce: bool, with_shadow: bool) -> void:
	_target_scale = scale
	_bounce_on = with_bounce
	if light:
		# Compatibility counts visible zero-energy lights against its
		# per-object limit, so dormant fixtures must leave the render list.
		light.visible = scale > 0.001
		light.shadow_enabled = with_shadow
	if bounce:
		bounce.visible = with_bounce and scale > 0.001


func _process(delta: float) -> void:
	if light == null:
		return
	var want := _base_energy * _target_scale * (1.0 + _surge)
	light.light_energy = lerpf(light.light_energy, want, delta * 6.0)
	bounce.light_energy = lerpf(bounce.light_energy,
			(_base_energy * 0.08 * _target_scale) if _bounce_on else 0.0,
			delta * 4.0)
	var envelope := 1.0 if prop_type == "flush_dome" else 1.6
	_bulb_mat.emission_energy_multiplier = lerpf(
			_bulb_mat.emission_energy_multiplier, envelope + _surge * 2.4,
			delta * 8.0)
	_surge = maxf(0.0, _surge - delta * 2.2)
	if prop_type in ["cage_bulb", "eye_pendant"] and _surge > 0.01:
		_swing_node.rotation.z = sin(Time.get_ticks_msec() * 0.004) \
				* _surge * 0.06


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_surge = maxf(_surge, accent * 0.9)
