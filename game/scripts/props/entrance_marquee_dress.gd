class_name EntranceMarqueeDress
extends Node3D
## The lit half of the entrance marquee.
##
## The structure - tray, glazing, cresting, tie rods, drainage - is built
## in Blender and arrives in floor_01.gltf. What cannot come through the
## glTF is the part that makes the type worth having: a prismatic-glass
## marquee is a lit ceiling over the door, not a rain hood. Unlit it is
## a black slab on a black facade, which is exactly how it read on the
## first pass.
##
## So this hangs the lamps inside the tray, washes the soffit, and puts
## the building's name on the bronze fascia panel that the Blender
## assembly leaves blank.
##
## Local origin: the facade face at the door centreline, matching the
## Blender assembly, so the two cannot drift apart.

const PROJ := 1.80          # canopy projection, must match the assembly
const GLASS_Z := 3.395      # top of the glazed deck
const FASCIA_Y := 1.93      # bronze name panel, outboard of the front rail

var _inspection_tap: AudioStreamPlayer3D


func _ready() -> void:
	name = "EntranceMarqueeDress"
	_glaze_lamps()
	_soffit_wash()
	_fascia_wash()
	_nameplate()
	_build_interaction()
	_inspection_tap = AudioStreamPlayer3D.new()
	_inspection_tap.bus = "Interaction"
	_inspection_tap.name = "MarqueeBracketTap"
	_inspection_tap.stream = PropAudio.get_stream("tick")
	_inspection_tap.volume_db = -19.0
	_inspection_tap.pitch_scale = 0.72
	_inspection_tap.unit_size = 3.2
	_inspection_tap.max_distance = 20.0
	add_child(_inspection_tap)


## The imported canopy and this runtime light dress are one set hero.  A
## single shallow plane on the outboard fascia lets the worker inspect that
## assembly from under the rain hood; fittings, letters, glass panes and
## ornament do not become separate targets.
func _build_interaction() -> void:
	var area := Area3D.new()
	area.name = "MarqueeInspection"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.add_to_group("functional_interaction_areas")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.30, 0.44, 0.24)
	collision.shape = shape
	# Proud of the imported fascia, but below the lettering: a look-point at a
	# plausible standing angle rather than an impossible reach to the glazing.
	collision.position = Vector3(0.0, 2.75, 2.05)
	area.add_child(collision)
	add_child(area)


func interact_prompt() -> String:
	return "[E]  Inspect Orison entrance marquee"


func interact(_player: Node) -> Dictionary:
	if _inspection_tap:
		_inspection_tap.play()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("marquee", {
		"roof_state": "PRISMATIC GLASS TRAY / RAIN SHEDDING",
		"bracket_state": "IRON RETURNS AND TIE RODS SEATED",
		"light_state": "TWO SOFFIT LAMPS / FASCIA WASH LIT",
	})


## Two lamps sitting in the tray, under the glass. Prismatic glass was
## specified precisely because it throws this light down and outward
## instead of letting it escape upward, so the fittings are warm and
## close to the deck rather than bright and high.
func _glaze_lamps() -> void:
	for x in [-0.72, 0.72]:
		var lamp := OmniLight3D.new()
		# Tucked right up under the deck. Hung lower they lit the pavement
		# and left the glazing dark, so from the street the tray read as a
		# black slab with a bright patch underneath it.
		lamp.position = Vector3(x, GLASS_Z - 0.045, PROJ * 0.52)
		lamp.light_color = Color(1.0, 0.87, 0.66)
		lamp.light_energy = 2.3
		lamp.omni_range = 3.4
		lamp.omni_attenuation = 1.4
		lamp.shadow_enabled = false
		add_child(lamp)
		_soffit_fitting(lamp.position)


## The fitting a 1926 marquee actually carried, instead of a bare bulb
## hanging in the tray.
##
## Under a glazed canopy the lamp is not the thing you are meant to see -
## the glass is. So the bulb sits inside a HOLOPHANE-pattern prismatic
## reflector: a shallow ribbed opal cone on a spun brass canopy ring,
## which throws the light down and outward and turns the bare filament
## into a soft disc. The ring hangs on a short stem off the tray's
## underside, with the porcelain socket visible above it, because that is
## how it was fitted and because a canopy with nothing behind it reads as
## a sticker.
func _soffit_fitting(at: Vector3) -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.42, 0.29, 0.11)
	brass.metallic = 0.86
	brass.roughness = 0.36
	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Color(0.80, 0.78, 0.72)
	porcelain.roughness = 0.42

	# stem and canopy ring up against the tray
	var stem := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.014
	sc.bottom_radius = 0.014
	sc.height = 0.085
	sc.radial_segments = 8
	stem.mesh = sc
	stem.material_override = brass
	stem.position = at + Vector3(0, 0.075, 0)
	add_child(stem)
	var ring := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.075
	rc.bottom_radius = 0.058
	rc.height = 0.026
	rc.radial_segments = 12
	ring.mesh = rc
	ring.material_override = brass
	ring.position = at + Vector3(0, 0.030, 0)
	add_child(ring)
	# porcelain socket, just visible inside the ring
	var socket := MeshInstance3D.new()
	var kc := CylinderMesh.new()
	kc.top_radius = 0.030
	kc.bottom_radius = 0.026
	kc.height = 0.048
	kc.radial_segments = 8
	socket.mesh = kc
	socket.material_override = porcelain
	socket.position = at + Vector3(0, 0.006, 0)
	add_child(socket)

	# the prismatic reflector: a ribbed opal cone, lit from within
	var opal := StandardMaterial3D.new()
	opal.albedo_color = Color(0.94, 0.90, 0.82)
	opal.roughness = 0.30
	opal.emission_enabled = true
	opal.emission = Color(1.0, 0.88, 0.66)
	opal.emission_energy_multiplier = 1.5
	opal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.052
	cone.bottom_radius = 0.115
	cone.height = 0.085
	cone.radial_segments = 14
	shade.mesh = cone
	shade.material_override = opal
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = at + Vector3(0, -0.036, 0)
	add_child(shade)
	# the ribs that make it prismatic rather than a plain bowl
	for i in 12:
		var a: float = TAU * i / 12.0
		var rib := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.010, 0.088, 0.012)
		rib.mesh = rb
		rib.material_override = opal
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rib.position = at + Vector3(cos(a) * 0.086, -0.036, sin(a) * 0.086)
		rib.rotation.y = -a
		rib.rotation.x = 0.36
		add_child(rib)
	# and the filament itself, small and hot, seen through the opal
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.030
	sphere.height = 0.060
	sphere.radial_segments = 8
	sphere.rings = 5
	bulb.mesh = sphere
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(1.0, 0.93, 0.78)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.86, 0.62)
	hot.emission_energy_multiplier = 2.6
	bulb.material_override = hot
	bulb.position = at + Vector3(0, -0.030, 0)
	add_child(bulb)


## A wide, soft pool on the pavement under the canopy. This is the light
## a resident actually walks through, and the reason the doorway stops
## looking like a hole in a wall.
func _soffit_wash() -> void:
	var wash := SpotLight3D.new()
	wash.position = Vector3(0.0, 3.24, PROJ * 0.46)
	wash.rotation_degrees = Vector3(-90, 0, 0)
	wash.light_color = Color(1.0, 0.85, 0.63)
	wash.light_energy = 2.4
	wash.spot_range = 6.4
	wash.spot_angle = 62.0
	wash.spot_angle_attenuation = 1.1
	wash.shadow_enabled = false
	add_child(wash)


## The ornament is the reason this thing is a centrepiece and none of it
## was lit. Cast iron at night is black, so the bead course, the palmette
## cresting and the fascia returns all disappeared and the marquee read as
## a box. This is the sign trough a 1920s installer would have hung: a
## wide, shallow wash raking UP the fascia from just in front of it, which
## is the angle that finds relief.
func _fascia_wash() -> void:
	for x in [-1.15, 0.0, 1.15]:
		var trough := SpotLight3D.new()
		trough.position = Vector3(x, 2.86, PROJ + 0.30)
		trough.rotation_degrees = Vector3(52, 180, 0)
		trough.light_color = Color(1.0, 0.87, 0.66)
		trough.light_energy = 1.7
		trough.spot_range = 2.6
		trough.spot_angle = 46.0
		trough.spot_angle_attenuation = 1.3
		trough.shadow_enabled = false
		add_child(trough)
	# and a low grazing pass along the returns, so the sides of the tray
	# are not a silhouette when you approach from up the block
	for sx in [-1.0, 1.0]:
		var side := SpotLight3D.new()
		side.position = Vector3(sx * 2.15, 3.05, PROJ * 0.55)
		side.rotation_degrees = Vector3(14, sx * 90.0, 0)
		side.light_color = Color(1.0, 0.88, 0.68)
		side.light_energy = 1.25
		side.spot_range = 3.2
		side.spot_angle = 50.0
		side.shadow_enabled = false
		add_child(side)


## The bronze panel is modeled in Blender; the legend is not, because
## baked-in lettering would need its own atlas cell for one string.
func _nameplate() -> void:
	var label := Label3D.new()
	label.text = "THE ORISON"
	label.font_size = 128
	# 1.60 m of bronze panel to fill; this lands the legend at
	# about 1.34 m, so it sits inside its border instead of
	# running off the ends of it.
	label.pixel_size = 0.0019
	label.modulate = Color(0.93, 0.80, 0.48)
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.035, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.no_depth_test = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# +Z is south here: the street side, which is the side that reads it.
	label.position = Vector3(0.0, 3.325, FASCIA_Y)
	add_child(label)
	# A small dedicated wash so the name survives a dark street. Aimed up
	# at the panel from the tray's underside, the way a real sign trough
	# would have been fitted.
	var sign_light := SpotLight3D.new()
	sign_light.position = Vector3(0.0, 3.05, PROJ + 0.42)
	sign_light.rotation_degrees = Vector3(28, 180, 0)
	sign_light.light_color = Color(1.0, 0.89, 0.70)
	sign_light.light_energy = 2.2
	sign_light.spot_range = 3.2
	sign_light.spot_angle = 40.0
	sign_light.shadow_enabled = false
	add_child(sign_light)
