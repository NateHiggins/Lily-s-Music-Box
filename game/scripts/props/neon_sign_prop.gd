class_name NeonSignProp
extends FunctionalProp
## Neon on the Orison's street elevation: a projecting blade reading down
## the pavement, and the ground-floor tenant's sign flat on the wall.
##
## Built from glass tube rather than a lit billboard — the letters are
## strokes of bent tube on a dark backing panel, which is what makes neon
## read as neon at a glancing angle. Each stroke is unshaded and emissive,
## so it costs nothing to light and stays legible whatever the LightRig is
## doing with its budget that frame.
##
## It is a conductor body, and the most naturally infected object on the
## building. A tube with a failing transformer already stutters; when the
## motif arrives this one stutters ON THE BEAT, and at high infection it
## drops whole letters. Nobody has to be told that is wrong.

## Letters as stroke lists on a 3-wide, 5-tall cell. Each stroke is
## (x0, y0, x1, y1) in cell units. Only the letters the building needs.
const GLYPHS := {
	"O": [[0, 0, 0, 5], [3, 0, 3, 5], [0, 5, 3, 5], [0, 0, 3, 0]],
	"R": [[0, 0, 0, 5], [0, 5, 3, 5], [3, 5, 3, 2.6], [0, 2.6, 3, 2.6],
		  [0, 2.6, 3, 0]],
	"I": [[1.5, 0, 1.5, 5], [0.4, 5, 2.6, 5], [0.4, 0, 2.6, 0]],
	"S": [[3, 5, 0, 5], [0, 5, 0, 2.6], [0, 2.6, 3, 2.6], [3, 2.6, 3, 0],
		  [3, 0, 0, 0]],
	"N": [[0, 0, 0, 5], [0, 5, 3, 0], [3, 0, 3, 5]],
	"D": [[0, 0, 0, 5], [0, 5, 2.2, 5], [2.2, 5, 3, 4.1],
		  [3, 4.1, 3, 0.9], [3, 0.9, 2.2, 0], [2.2, 0, 0, 0]],
	"U": [[0, 5, 0, 0], [0, 0, 3, 0], [3, 0, 3, 5]],
	"G": [[3, 5, 0, 5], [0, 5, 0, 0], [0, 0, 3, 0], [3, 0, 3, 2.3],
		  [1.7, 2.3, 3, 2.3]],
}
const CELL := 0.15          # metres per cell unit
const TUBE_R := 0.022
const GAP := 1.1            # cell units between glyphs
## A sign is a sign, not a streetlamp. It throws a coloured wash onto its
## own masonry and a little onto the pavement below, and that is all — the
## first pass lit the entire block red from four metres away.
const TUBE_EMISSION := 1.35
const GLOW_ENERGY := 0.55
const GLOW_RANGE := 3.6

var sign_text := "ORISON"
var vertical := true
var tint := Color(1.0, 0.30, 0.42)

var _tube_mat: StandardMaterial3D
var _glow: OmniLight3D
var _letters: Array[Node3D] = []
var _surge := 0.0
var _dropped := -1
var _drop_until := 0.0


func _build_visual() -> void:
	var w: float = 3.0 * CELL
	var n: int = sign_text.length()
	var run: float = n * (3.0 + GAP) * CELL
	# backing panel + the bracket that ties it to the masonry
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(w + 0.22, run + 0.18, 0.06) if vertical \
			else Vector3(run + 0.18, w + 0.30, 0.06)
	panel.mesh = pm
	panel.position = Vector3(0, 0, -0.05)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.55
	dark.metallic = 0.4
	panel.material_override = dark
	add_child(panel)
	if vertical:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.07, 0.07, 0.46)
		arm.mesh = am
		arm.position = Vector3(0, run * 0.42, -0.30)
		arm.material_override = dark
		add_child(arm)

	_tube_mat = StandardMaterial3D.new()
	_tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tube_mat.albedo_color = tint
	_tube_mat.emission_enabled = true
	_tube_mat.emission = tint
	_tube_mat.emission_energy_multiplier = TUBE_EMISSION

	for i in n:
		var glyph: String = sign_text[i]
		var holder := Node3D.new()
		# vertical signs read top-down, so the first letter sits highest
		if vertical:
			holder.position = Vector3(0.0,
					run * 0.5 - (i + 0.5) * (3.0 + GAP) * CELL, 0.0)
		else:
			holder.position = Vector3(
					-run * 0.5 + (i + 0.5) * (3.0 + GAP) * CELL, 0.0, 0.0)
		add_child(holder)
		_letters.append(holder)
		for stroke in GLYPHS.get(glyph, []):
			_tube(holder, stroke)

	_glow = OmniLight3D.new()
	_glow.light_color = tint
	_glow.light_energy = GLOW_ENERGY
	_glow.omni_range = GLOW_RANGE
	_glow.omni_attenuation = 1.6
	_glow.shadow_enabled = false
	_glow.position = Vector3(0, 0, 0.35)
	add_child(_glow)


## One bent stroke of tube, centred on the glyph cell.
func _tube(holder: Node3D, s: Array) -> void:
	var a := Vector3((float(s[0]) - 1.5) * CELL,
			(float(s[1]) - 2.5) * CELL, 0.0)
	var b := Vector3((float(s[2]) - 1.5) * CELL,
			(float(s[3]) - 2.5) * CELL, 0.0)
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	if len < 0.001:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TUBE_R
	cyl.bottom_radius = TUBE_R
	cyl.height = len + TUBE_R * 2.0
	cyl.radial_segments = 6
	mi.mesh = cyl
	mi.material_override = _tube_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = mid
	# CylinderMesh runs along +Y; aim it down the stroke
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.look_at_from_position(mid, mid + dir, Vector3.FORWARD)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	holder.add_child(mi)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_surge = maxf(_surge, accent)
	# Deep infection kills a letter outright for a moment. A sign missing
	# one glyph is a far older, more specific kind of wrong than a sign
	# that merely dims.
	if Conductor.infection > 0.55 and _letters.size() > 0 \
			and rng.randf() < Conductor.infection * 0.5:
		_dropped = rng.randi_range(0, _letters.size() - 1)
		_drop_until = Time.get_ticks_msec() / 1000.0 \
				+ rng.randf_range(0.06, 0.34)


func _process(delta: float) -> void:
	if _tube_mat == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	# a slow mains hum under everything, so the tube is never quite steady
	var idle := 1.0 + sin(now * 7.3) * 0.03
	var want := idle * (1.0 + _surge * 1.4)
	_tube_mat.emission_energy_multiplier = lerpf(
			_tube_mat.emission_energy_multiplier, TUBE_EMISSION * want, delta * 14.0)
	if _glow:
		_glow.light_energy = lerpf(_glow.light_energy, GLOW_ENERGY * want,
				delta * 14.0)
	_surge = maxf(0.0, _surge - delta * 3.2)
	if _dropped >= 0:
		var out: bool = now < _drop_until
		_letters[_dropped].visible = not out
		if not out:
			_dropped = -1
