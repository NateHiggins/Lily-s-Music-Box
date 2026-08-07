class_name VaultLightGlow
extends Node3D
## Cellar light coming up through the pavement prisms.
##
## The cast-iron frames and their glass are built in Blender and arrive in
## floor_01.gltf. What cannot come through the glTF is the only thing that
## makes them legible at night: a vault light is a hole in the pavement
## with a lit room under it, and unlit it reads as a grid of dirt specks.
##
## The building has a real basement directly beneath these panels, and it
## has bulbs in it. So each prism gets a faint amber disc and the panel
## gets one dim upward-facing source, which is enough to say "something is
## on down there" from across the street — and, on a horror building, to
## make anyone who notices wonder who turned it on.
##
## Deliberately weak. Vault prisms diffuse and lose most of what passes
## through them; a bright one would read as a floor light, which is a
## fixture nobody installed in 1926.

const CELL_COLS := 7
const CELL_ROWS := 3

var panel_w := 2.60
var panel_d := 1.15
## Which cells lost their glass and were patched with concrete. Must match
## the Blender assembly's rule exactly or a patch will glow.
static func _is_patched(i: int, j: int) -> bool:
	return ((i * 3 + j * 5) % 11) == 4


func _ready() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.56, 0.42)
	glass.roughness = 0.34
	glass.emission_enabled = true
	# A century of sunlight turns the manganese in old vault glass violet,
	# so what comes up is never quite the colour of the bulb below it.
	glass.emission = Color(0.86, 0.66, 0.52)
	glass.emission_energy_multiplier = 0.85

	var hw := panel_w * 0.5
	var hd := panel_d * 0.5
	for i in CELL_COLS:
		for j in CELL_ROWS:
			if _is_patched(i, j):
				continue
			var cx := -hw + panel_w * (i + 0.5) / CELL_COLS
			var cz := -hd + panel_d * (j + 0.5) / CELL_ROWS
			var disc := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.048
			cyl.bottom_radius = 0.048
			cyl.height = 0.004
			cyl.radial_segments = 10
			disc.mesh = cyl
			disc.material_override = glass
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			disc.position = Vector3(cx, 0.010, cz)
			add_child(disc)
	# one soft source just above the panel so the iron ribs catch an edge
	var spill := OmniLight3D.new()
	spill.position = Vector3(0.0, 0.14, 0.0)
	spill.light_color = Color(1.0, 0.82, 0.62)
	spill.light_energy = 0.55
	spill.omni_range = 1.6
	spill.omni_attenuation = 1.8
	spill.shadow_enabled = false
	add_child(spill)
