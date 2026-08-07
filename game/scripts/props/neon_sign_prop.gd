class_name NeonSignProp
extends FunctionalProp
## Neon on the Orison's street elevation, built the way the trade built it.
##
## Two forms. The building's own sign is a PROJECTING BLADE: a double-sided
## board standing out from the facade so it reads down the pavement from
## either end of the block. A blade whose face is parallel to the wall is
## not a blade at all - it is a wall sign, and it disappears the moment you
## are not standing square in front of it, which is how this one used to be
## built. The ground-floor tenant's is a WALL CABINET, flat on the masonry,
## which is correct for a druggist's.
##
## The letters are strokes of bent glass tube, not a lit billboard: that is
## what makes neon read as neon at a glancing angle. Each stroke is unshaded
## and emissive, so it costs nothing to light.
##
## Everything else here is the hardware that makes it real, and every piece
## of it is doing a job a sign-hanger would recognise:
##
##   CABINET     formed sheet metal with a rolled edge and returns. Dark
##               face, because contrast is the whole trick at night.
##   STANDOFFS   the tube does not touch the face. It floats 75 mm off it on
##               glass supports, which is why neon has a shadow behind it.
##   BOOTS       every tube run ends in an electrode, sleeved in a porcelain
##               boot where it passes through the cabinet.
##   TRANSFORMER a heavy iron box with cooling fins. 15,000 volts has to
##               come from somewhere and it is never hidden.
##   CONDUIT     rigid conduit from the transformer to an LB condulet at the
##               wall, on straps. This is the part nobody models and the
##               part that sells it.
##   BULBS       an incandescent border. Neon plus chaser bulbs is the
##               period combination, and it is what makes a blade catch an
##               eye from a block away.
##   NEGLECT     one dead tube run, still glass but no longer lit, and rust
##               bleeding out of the bracket bolts.
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
	# The table above covered exactly ORISON + DRUGS, which worked until
	# the street grew shops: "DELI GROCERY" rendered as D_LI G_O_E__ and
	# the KARAOKE blade as _R_O__ - missing glyphs leave their advance
	# behind as a gap, so a sign with absent letters reads as one that is
	# half burnt out in a pattern no tube ever fails in.
	"A": [[0, 0, 0, 3.5], [0, 3.5, 1.5, 5], [1.5, 5, 3, 3.5],
		  [3, 3.5, 3, 0], [0, 2, 3, 2]],
	"B": [[0, 0, 0, 5], [0, 5, 2.3, 5], [2.3, 5, 3, 4.1],
		  [3, 4.1, 2.3, 2.6], [0, 2.6, 2.3, 2.6], [2.3, 2.6, 3, 1.6],
		  [3, 1.6, 2.3, 0], [2.3, 0, 0, 0]],
	"C": [[3, 5, 0, 5], [0, 5, 0, 0], [0, 0, 3, 0]],
	"E": [[3, 5, 0, 5], [0, 5, 0, 0], [0, 0, 3, 0], [0, 2.6, 2.2, 2.6]],
	"H": [[0, 0, 0, 5], [3, 0, 3, 5], [0, 2.6, 3, 2.6]],
	"K": [[0, 0, 0, 5], [3, 5, 0, 2.6], [0, 2.6, 3, 0]],
	"L": [[0, 5, 0, 0], [0, 0, 3, 0]],
	"M": [[0, 0, 0, 5], [0, 5, 1.5, 2.8], [1.5, 2.8, 3, 5], [3, 5, 3, 0]],
	"T": [[0, 5, 3, 5], [1.5, 5, 1.5, 0]],
	"W": [[0, 5, 0.6, 0], [0.6, 0, 1.5, 3], [1.5, 3, 2.4, 0],
		  [2.4, 0, 3, 5]],
	"Y": [[0, 5, 1.5, 2.8], [3, 5, 1.5, 2.8], [1.5, 2.8, 1.5, 0]],
}
const CELL := 0.15          # metres per cell unit
const TUBE_R := 0.022
## Gap between glyphs, in cell units. Measured along the axis the text
## actually runs: a stacked blade advances by the glyph's HEIGHT, not its
## width. Using the width made every vertical sign overlap its own letters
## by 135 mm, so ORISON read as a single bright smear.
const GAP_ACROSS := 1.1
const GAP_DOWN := 0.85
## How far the tube floats off the cabinet face, on its glass supports.
const TUBE_STANDOFF := 0.075
const BLADE_HALF_T := 0.11  # half the blade's thickness

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
var _dead_mat: StandardMaterial3D
var _glow: OmniLight3D
var _letters: Array[Node3D] = []
var _boards: Array[Node3D] = []
var _bulb_mat: StandardMaterial3D
var _surge := 0.0
var _dropped := -1
var _drop_until := 0.0
## The letter whose transformer gave out years ago. Never lights, never
## flickers, and is still visibly a glass tube.
var _dead_letter := -1


func _build_visual() -> void:
	_tube_mat = StandardMaterial3D.new()
	_tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tube_mat.albedo_color = tint
	_tube_mat.emission_enabled = true
	_tube_mat.emission = tint
	_tube_mat.emission_energy_multiplier = TUBE_EMISSION
	# Unlit tube is not black - it is dusty glass with a phosphor coat.
	_dead_mat = StandardMaterial3D.new()
	_dead_mat.albedo_color = Color(0.36, 0.36, 0.34)
	_dead_mat.roughness = 0.42
	_dead_mat.metallic = 0.0

	var n: int = sign_text.length()
	_dead_letter = int(hash(name) % maxi(1, n * 3))
	if _dead_letter >= n:
		_dead_letter = -1

	if vertical:
		_build_blade(n)
	else:
		_build_wall_cabinet(n)

	_glow = OmniLight3D.new()
	_glow.light_color = tint
	_glow.light_energy = GLOW_ENERGY
	_glow.omni_range = GLOW_RANGE
	_glow.omni_attenuation = 1.6
	_glow.shadow_enabled = false
	_glow.position = Vector3(0, 0, 0.35 if not vertical else 0.78)
	add_child(_glow)


# ------------------------------------------------------------ the blade

## A double-sided board standing off the wall on a bracket, faces pointing
## along the street. Both faces carry the same text and both read the right
## way round, which falls out of the geometry: a viewer on either side has
## the glyph's +X running to their own right.
func _build_blade(n: int) -> void:
	var pitch: float = (5.0 + GAP_DOWN) * CELL
	var run: float = n * pitch
	var z0 := 0.34                      # clear of the wall for the bracket
	var z1 := z0 + 3.0 * CELL + 0.40    # glyph width plus border for bulbs
	var mid_z := (z0 + z1) * 0.5
	var half_y := run * 0.5 + 0.20

	var dark := _metal(Color(0.055, 0.055, 0.062), 0.45, 0.50)
	var edge := _metal(Color(0.105, 0.105, 0.115), 0.60, 0.42)
	var rust := _metal(Color(0.24, 0.115, 0.052), 0.10, 0.92)

	# cabinet body, and the rolled edge that closes it all the way round
	_box(Vector3(BLADE_HALF_T * 2.0, half_y * 2.0, z1 - z0),
			Vector3(0, 0, mid_z), dark)
	for sy in [-1.0, 1.0]:
		_box(Vector3(BLADE_HALF_T * 2.2, 0.075, z1 - z0 + 0.05),
				Vector3(0, sy * half_y, mid_z), edge)
	for sz in [z0, z1]:
		_box(Vector3(BLADE_HALF_T * 2.2, half_y * 2.0 + 0.075, 0.075),
				Vector3(0, 0, sz), edge)

	# the two lit faces
	for side in [-1.0, 1.0]:
		var board := Node3D.new()
		board.position = Vector3(side * BLADE_HALF_T, 0.0, mid_z)
		# Sign matters: the tube stands off its face by +Z in board space,
		# so the board on the -X face must rotate -90 to throw that -X.
		# Inverted, both faces pushed their tubing INTO the cabinet - the
		# sign washed the brick with colour and showed no letters at all.
		board.rotation.y = PI * 0.5 * side
		add_child(board)
		_boards.append(board)
		for i in n:
			var holder := Node3D.new()
			# stacked top-down, so the first letter sits highest
			holder.position = Vector3(0.0, run * 0.5 - (i + 0.5) * pitch, 0.0)
			board.add_child(holder)
			if side < 0.0:
				_letters.append(holder)
			var lit: bool = i != _dead_letter
			for stroke in GLYPHS.get(sign_text[i], []):
				_tube(holder, stroke, lit)

	# incandescent border: the half of the period vocabulary that is not gas
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bulb_mat.albedo_color = Color(1.0, 0.93, 0.76)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.88, 0.62)
	_bulb_mat.emission_energy_multiplier = 1.15
	var steps := int((half_y * 2.0) / 0.30)
	for i in steps + 1:
		var by: float = -half_y + float(i) * (half_y * 2.0 / steps)
		for sz2 in [z0, z1]:
			_bulb(Vector3(0.0, by, sz2), i % 9 != 4)

	_build_blade_bracket(half_y, z0, edge, rust)
	_build_transformer(Vector3(0.0, -half_y - 0.30, z0 + 0.24), dark, edge)
	# The two lit faces stay out of the merge: their tubes are switched
	# per letter when the building drops a glyph, and a merged mesh has
	# no letters left to switch.
	merge_static(self, _boards)


## Two arms into the brick with a diagonal strut under each, which is how a
## cantilevered blade actually stays up. Wall plates, lag bolts, and the
## rust that has been leaving them for a century.
func _build_blade_bracket(half_y: float, z0: float, edge: StandardMaterial3D,
		rust: StandardMaterial3D) -> void:
	for sy in [-1.0, 1.0]:
		var ay: float = sy * (half_y - 0.35)
		_box(Vector3(0.06, 0.09, z0 + 0.08), Vector3(0, ay, z0 * 0.5), edge)
		# wall plate and its four lags
		_box(Vector3(0.20, 0.30, 0.035), Vector3(0, ay, 0.018), edge)
		for bx in [-0.062, 0.062]:
			for bz in [-0.10, 0.10]:
				var lag := make_cyl(0.014, 0.014, 0.05,
						Vector3(bx, ay + bz, 0.045), Color(0.13, 0.13, 0.14),
						0.42, 0.7, self)
				lag.rotation_degrees = Vector3(90, 0, 0)
		# rust bleeding down the brick from every fixing
		_box(Vector3(0.11, 0.44, 0.006), Vector3(0, ay - 0.34, 0.006), rust)
	# diagonal struts, one per arm, taking the cantilever back to the wall
	for sy2 in [-1.0, 1.0]:
		var ay2: float = sy2 * (half_y - 0.35)
		var strut := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var length := sqrt(pow(z0 + 0.05, 2.0) + pow(0.55, 2.0))
		bm.size = Vector3(0.035, 0.035, length)
		strut.mesh = bm
		strut.material_override = edge
		strut.position = Vector3(0, ay2 - sy2 * 0.275, (z0 + 0.05) * 0.5)
		strut.rotation.x = sy2 * atan2(0.55, z0 + 0.05)
		add_child(strut)


# ---------------------------------------------------- the wall cabinet

## Flat on the masonry: a formed pan with a rolled edge, the tube standing
## off its face, and the transformer hung on the bottom rail.
func _build_wall_cabinet(n: int) -> void:
	var pitch: float = (3.0 + GAP_ACROSS) * CELL
	var run: float = n * pitch
	var half_x := run * 0.5 + 0.14
	var half_y := 2.5 * CELL + 0.16

	var dark := _metal(Color(0.055, 0.055, 0.062), 0.45, 0.50)
	var edge := _metal(Color(0.105, 0.105, 0.115), 0.60, 0.42)

	_box(Vector3(half_x * 2.0, half_y * 2.0, 0.10),
			Vector3(0, 0, -0.05), dark)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.065, half_y * 2.0 + 0.065, 0.13),
				Vector3(sx * half_x, 0, -0.03), edge)
	for sy in [-1.0, 1.0]:
		_box(Vector3(half_x * 2.0 + 0.065, 0.065, 0.13),
				Vector3(0, sy * half_y, -0.03), edge)

	for i in n:
		var holder := Node3D.new()
		holder.position = Vector3(-run * 0.5 + (i + 0.5) * pitch, 0.0, 0.0)
		add_child(holder)
		_letters.append(holder)
		var lit: bool = i != _dead_letter
		for stroke in GLYPHS.get(sign_text[i], []):
			_tube(holder, stroke, lit)

	_build_transformer(Vector3(half_x - 0.16, -half_y - 0.17, -0.12),
			dark, edge)
	merge_static(self, _letters)


# -------------------------------------------------------------- hardware

## The iron box, its cooling fins, and the run of rigid conduit back to an
## LB condulet at the wall. Fifteen thousand volts comes from somewhere.
func _build_transformer(at: Vector3, dark: StandardMaterial3D,
		edge: StandardMaterial3D) -> void:
	_box(Vector3(0.16, 0.20, 0.30), at, dark)
	for i in 5:
		_box(Vector3(0.185, 0.016, 0.28),
				at + Vector3(0, -0.075 + i * 0.037, 0), edge)
	# maker's plate
	_box(Vector3(0.085, 0.055, 0.004),
			at + Vector3(0.083, 0.02, 0.0), _metal(
					Color(0.42, 0.36, 0.20), 0.75, 0.44))
	# conduit: down off the box, then back to the wall on straps
	var drop := make_cyl(0.017, 0.017, 0.26,
			at + Vector3(0, -0.22, 0.0), Color(0.14, 0.14, 0.15), 0.44,
			0.65, self)
	drop.rotation_degrees = Vector3(0, 0, 0)
	var run_z: float = maxf(0.12, at.z)
	var back := make_cyl(0.017, 0.017, run_z,
			at + Vector3(0, -0.35, -run_z * 0.5 + at.z * 0.0),
			Color(0.14, 0.14, 0.15), 0.44, 0.65, self)
	back.rotation_degrees = Vector3(90, 0, 0)
	back.position = at + Vector3(0, -0.35, -at.z * 0.5)
	for s in [-0.28, 0.28]:
		var strap := make_cyl(0.024, 0.024, 0.012,
				at + Vector3(0, -0.35, at.z * 0.5 + s * 0.3),
				Color(0.16, 0.16, 0.17), 0.5, 0.6, self)
		strap.rotation_degrees = Vector3(90, 0, 0)
	# the LB condulet where it turns into the masonry
	_box(Vector3(0.075, 0.075, 0.11), Vector3(at.x, at.y - 0.35, 0.055),
			edge)


## One bent stroke of tube, standing off the face on its glass supports,
## with a porcelain electrode boot at each end.
func _tube(holder: Node3D, s: Array, lit: bool) -> void:
	var a := Vector3((float(s[0]) - 1.5) * CELL,
			(float(s[1]) - 2.5) * CELL, TUBE_STANDOFF)
	var b := Vector3((float(s[2]) - 1.5) * CELL,
			(float(s[3]) - 2.5) * CELL, TUBE_STANDOFF)
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TUBE_R
	cyl.bottom_radius = TUBE_R
	cyl.height = length + TUBE_R * 2.0
	cyl.radial_segments = 6
	mi.mesh = cyl
	mi.material_override = _tube_mat if lit else _dead_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = mid
	# CylinderMesh runs along +Y; aim it down the stroke
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.look_at_from_position(mid, mid + dir, Vector3.FORWARD)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	holder.add_child(mi)
	# a glass support at mid-span on anything long enough to sag
	if length > 0.30:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.008
		pm.bottom_radius = 0.010
		pm.height = TUBE_STANDOFF
		pm.radial_segments = 5
		post.mesh = pm
		post.material_override = _metal(Color(0.30, 0.31, 0.30), 0.2, 0.55)
		post.position = Vector3(mid.x, mid.y, TUBE_STANDOFF * 0.5)
		post.rotation_degrees = Vector3(90, 0, 0)
		holder.add_child(post)
	# electrode boots where the tube dives through the face
	for end_pt in [a, b]:
		var boot := MeshInstance3D.new()
		var bmesh := CylinderMesh.new()
		bmesh.top_radius = 0.021
		bmesh.bottom_radius = 0.026
		bmesh.height = 0.055
		bmesh.radial_segments = 6
		boot.mesh = bmesh
		boot.material_override = _metal(Color(0.74, 0.72, 0.66), 0.0, 0.55)
		boot.position = Vector3(end_pt.x, end_pt.y, TUBE_STANDOFF * 0.42)
		boot.rotation_degrees = Vector3(90, 0, 0)
		holder.add_child(boot)


func _bulb(at: Vector3, lit: bool) -> void:
	var socket := make_cyl(0.020, 0.024, 0.030, at,
			Color(0.13, 0.13, 0.14), 0.5, 0.5, self)
	socket.rotation_degrees = Vector3(0, 0, 90)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.026
	sphere.height = 0.052
	sphere.radial_segments = 6
	sphere.rings = 4
	mi.mesh = sphere
	mi.material_override = _bulb_mat if lit else _metal(
			Color(0.20, 0.19, 0.17), 0.0, 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	add_child(mi)


func _box(size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	add_child(mi)


func _metal(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


func _start_normal_function() -> void:
	state = PState.OPERATING


## Business hours for the tube. Unlit is not invisible: two percent of
## emission keeps the dead glass reading as glass, and the omni glow goes
## out entirely — a shop sign at 4 a.m., not a hole in the facade.
var _lit := true


func set_lit(on: bool) -> void:
	_lit = on


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
	var want := idle * (1.0 + _surge * 1.4) if _lit else 0.02
	_tube_mat.emission_energy_multiplier = lerpf(
			_tube_mat.emission_energy_multiplier, TUBE_EMISSION * want,
			delta * 14.0)
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = lerpf(
				_bulb_mat.emission_energy_multiplier, 1.15 * want,
				delta * 9.0)
	if _glow:
		_glow.light_energy = lerpf(_glow.light_energy, GLOW_ENERGY * want,
				delta * 14.0)
	_surge = maxf(0.0, _surge - delta * 3.2)
	if _dropped >= 0:
		var out: bool = now < _drop_until
		_letters[_dropped].visible = not out
		if not out:
			_dropped = -1
