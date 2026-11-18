class_name DreamMossColonyRenderer
extends Node3D
## Bounded presentation of one DreamMossColony: the waking cell. This node owns
## meshes, motion and visibility only. Every ecological quantity is read from
## the colony record owned by DreamEcologyDirector.
##
## The older procedural moss presentation (heart, plasmodial fans, vascular
## network, cilia bed and carpet, ether motes, report pulse, membrane proteins)
## is retired by Lily's ruling dream_tissue_look_20261115 (2026-11-15: "drop
## the moss colony, its an older design, use the waking cell").

var colony = null
## The colony is drawn from the Blender-authored cell in
## res://assets/dream/waking_colony (Lily, 2026-11-09): an opalescent, lensing
## membrane over genuinely interior organelles that stream around the cell, and
## a fringe of jointed cilia that step in a metachronal wave. Every renderer is
## the waking cell; the flag stays for callers that still set it.
var waking_style := true
## The goo the cell leaves where it crawls and where its cilia touch
## (design/DREAM_SALIVA_DIRECTION.md). Optional; set before setup.
var residue: DreamResidue = null
const WAKING_CELL := "res://assets/dream/waking_colony/waking_colony.glb"
const WAKING_CILIA := 150
var _waking: Node3D
var _waking_materials: Array[ShaderMaterial] = []
var _waking_skeleton: MeshInstance3D
## The waking cell crawls and feels (Lily, 2026-11-13: "slowly crawl around
## the floor with the cilia touching objects in its reach ... exploratively").
## Presentation only: the colony record, its source point and everything the
## ecology reads stay where the colony is rooted. The drawn cell wanders on a
## leash around that point, keeps to open floor, and its cilia reach out to
## whatever the feelers find near its rim.
## Her ruling on the first film (waking_cell_crawl_film_20261113): roam the
## room faster and farther, more cilia touching with a longer reach, stronger
## colour, and the cilia deliberate, like a hive mind.
const WAKING_CRAWL_SPEED := 0.06         # metres a second at full pace
const WAKING_CRAWL_LEASH := 3.5          # metres from where it is rooted
const WAKING_BODY_RADIUS := 0.26
const WAKING_TOUCH_REACH := 0.32         # metres beyond the membrane
const WAKING_FEELERS := 24
const WAKING_LIMB_LENGTH := 0.124        # a cilium's reach, straightened, at scale one
const WAKING_LIMB_STRETCH := 2.3         # how far a reaching limb may lengthen
var crawl_enabled := true
## The room it may roam, in world X and Z; empty means the leash alone.
var crawl_bounds := Rect2()
var _crawl_target := Vector3.ZERO
var _crawl_rest := 0.0
var _crawl_check := 0.0
var _crawl_travelled := 0.0
var _crawl_effort := 0.0
var _crawl_heading := Vector2.ZERO
var _crawl_rng := RandomNumberGenerator.new()
var _feel_clock := 0.0
var _feel_hits: Array[Dictionary] = []
## What the whole cell is attending to: every cilium on that side turns to it.
var _attend_point := Vector3.ZERO
var _attend_want := 0.0
var _attend := 0.0
var _attend_shown := 0.0
var _study_cooldown := 0.0
var _waking_cilia: MultiMeshInstance3D
var _cilia_roots: Array[Dictionary] = []
var _cilia_rest_basis: Array[Basis] = []
var _cilia_rest_scale := PackedFloat32Array()
var _cilia_touch := PackedFloat32Array()
var _cilia_want := PackedFloat32Array()
var _cilia_aim: Array[Vector3] = []
var _organelles: Array[Dictionary] = []
var _clock := 0.0
var _refresh_clock := 0.0
var _report_presentations := 0


func setup(owner_colony) -> void:
	colony = owner_colony
	name = "MossColony_%s" % str(colony.source_id)
	_build_waking()
	_refresh()


## An ecology report reaching the colony. The old moss drew it as a pulse; the
## waking cell has no report pulse, so it is counted for the census only.
func present_report(_from: Vector3, value: float) -> void:
	if colony == null or value <= 0.0:
		return
	_report_presentations += 1


func _process(delta: float) -> void:
	if colony == null:
		visible = false
		return
	_clock += delta
	_refresh_clock -= delta
	if _refresh_clock <= 0.0:
		_refresh()
		_refresh_clock = 0.20
	if _waking != null:
		_animate_waking()
		_animate_touch(delta)



func _physics_process(delta: float) -> void:
	if _waking == null or not crawl_enabled or not is_visible_in_tree():
		return
	_waking_arc(delta)


## Rise, sweep, sink. Under the floor it waits; it comes up where there is
## room; out, it sweeps the room and feels what it meets; if something moves
## fast near it, it lets go of whatever it holds and goes back into the floor,
## to come up again later, somewhere else.
func _waking_arc(delta: float) -> void:
	if not arc_enabled:
		_arc = WakingArc.ROAMING
		_arc_out = 1.0
	match _arc:
		WakingArc.SUBMERGED:
			_arc_clock -= delta
			if _arc_clock <= 0.0:
				_surface()
		WakingArc.EMERGING:
			_arc_out = move_toward(_arc_out, 1.0, delta / WAKING_EMERGE_S)
			if _arc_out >= 1.0:
				_arc = WakingArc.ROAMING
		WakingArc.ROAMING:
			_crawl(delta)
			_feel_clock -= delta
			if _feel_clock <= 0.0:
				_feel_clock = 0.3
				_feel()
				if arc_enabled and _is_disturbed():
					_arc = WakingArc.SUBMERGING
					_attend_want = 0.0
					for i in _cilia_want.size():
						_cilia_want[i] = 0.0
		WakingArc.SUBMERGING:
			_crawl_effort = move_toward(_crawl_effort, 0.0, delta * 2.0)
			_arc_out = move_toward(_arc_out, 0.0, delta / WAKING_SUBMERGE_S)
			if _arc_out <= 0.0:
				_arc = WakingArc.SUBMERGED
				_arc_clock = _crawl_rng.randf_range(10.0, 20.0)
				_feel_hits.clear()
	_shape_body(delta)


## Come up: where it went down the first time, and after that at some other
## open place in the room it may roam.
func _surface() -> void:
	if _arc_emergences > 0:
		for attempt in 16:
			var angle := _crawl_rng.randf() * TAU
			var far := sqrt(_crawl_rng.randf()) * WAKING_CRAWL_LEASH
			var place := Vector3(cos(angle) * far, 0.0, sin(angle) * far)
			if _crawl_clear(place):
				_waking.position = place
				break
	_crawl_target = _waking.position
	_crawl_rest = 0.0
	_crawl_effort = 0.0
	_arc_emergences += 1
	_arc = WakingArc.EMERGING


## Something moving fast close by: a person walking at it, a thing thrown.
func _is_disturbed() -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var near := SphereShape3D.new()
	near.radius = WAKING_STARTLE_REACH
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = near
	query.transform = Transform3D(Basis.IDENTITY, _waking.global_position + Vector3.UP * 0.4)
	query.collide_with_areas = false
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 12):
		var body: Object = hit.collider
		var speed := 0.0
		if body is CharacterBody3D:
			speed = (body as CharacterBody3D).velocity.length()
		elif body is RigidBody3D:
			speed = (body as RigidBody3D).linear_velocity.length()
		if speed >= WAKING_STARTLE_SPEED:
			return true
	return false


## The body's shape: drawn out along its way while it travels, gathered into
## a regular mass when it stands or attends to something, and flattened into
## the floor while it rises or sinks. One transform for the whole cell, so
## everything in it and on it goes with it.
func _shape_body(delta: float) -> void:
	var want := _crawl_effort if (_arc == WakingArc.ROAMING and _attend_want == 0.0) else 0.0
	_stretch = move_toward(_stretch, want, delta * (0.45 if want > _stretch else 0.8))
	var along := 1.0 + WAKING_STRETCH * _stretch
	var across := 1.0 / sqrt(along)
	var out := smoothstep(0.0, 1.0, _arc_out)
	var up := maxf(0.001, (1.0 - 0.08 * _stretch) * out)
	var wide := lerpf(0.5, 1.0, out)
	var way := Vector3(_crawl_heading.x, 0.0, _crawl_heading.y)
	way = way.normalized() if way.length() > 0.05 else Vector3.RIGHT
	var side := Vector3.UP.cross(way)
	# Stretch along `way`, squeeze along `side`, scale up: a symmetric shape
	# change with no turn in it, so the cell's own axes stay the room's.
	var columns: Array[Vector3] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		columns.append(way * way.dot(axis) * along * wide + side * side.dot(axis) * across * wide + Vector3.UP * Vector3.UP.dot(axis) * up)
	_waking.basis = Basis(columns[0], columns[1], columns[2])
	_waking.visible = _arc_out > 0.0


func _refresh() -> void:
	visible = colony != null and colony.phase != colony.Phase.CLEARED
	if visible:
		global_position = colony.origin if colony.origin != Vector3.INF else Vector3.ZERO


func census() -> Dictionary:
	var presented := visible and is_inside_tree()
	return {"colony_source": colony.source_id if colony != null else -1,
			"owns_simulation": false, "nodes": get_child_count() + 1,
			"waking_visible": presented and _waking != null and _waking.visible,
			"cilia_touching": waking_touching() if presented else 0,
			"trail_marks": _trail_marks.size(),
			"residue_laid": _residue_laid,
			"report_presentations": _report_presentations}



static func _hash01(value: int) -> float:
	return float(posmod(value * 1103515245 + 12345, 65521)) / 65520.0


# ------------------------------------------------------------------ waking

# region, pigment, glow colour, glow, glassy, recipe, uv_tile. The recipe is a
# registered material (waking_colony_<recipe>, RUL-012) whose three maps
# art/tools/build_waking_colony_maps.py writes; uv_tile is the mesh's metres
# per UV unit over the recipe's meters_per_tile. Sphere-projected organelles
# take whole repeats around so the seam closes.
const ORGANELLE_LOOK := {
	"Nucleus": [1.0, Color(0.55, 0.18, 0.42), Color(0.9, 0.4, 0.8), 0.22, 0.0, "chromatin", Vector2(4.0, 2.0)],
	"Nucleolus": [2.0, Color(0.30, 0.05, 0.25), Color(1.0, 0.5, 0.9), 0.5, 0.0, "chromatin", Vector2(2.0, 1.0)],
	"Vacuole": [3.0, Color(0.55, 0.78, 0.85), Color(0.6, 0.9, 1.0), 0.08, 1.0, "vesicle", Vector2(2.0, 1.0)],
	"Mito": [4.0, Color(0.85, 0.45, 0.20), Color(1.0, 0.6, 0.3), 0.3, 0.0, "cristae", Vector2(2.0, 2.0)],
	"Granules": [5.0, Color(0.95, 0.85, 0.40), Color(1.0, 0.9, 0.5), 0.4, 0.0, "granule", Vector2(4.0, 4.0)],
	"Filaments": [6.0, Color(0.60, 0.30, 0.75), Color(0.8, 0.5, 1.0), 0.2, 0.0, "fibre", Vector2(12.0, 12.0)],
}
const WAKING_RECIPE_DIR := "res://assets/dream/waking_colony/"
const WAKING_CILIUM_RECIPE := "cuticle"
const WAKING_CILIUM_TILE := Vector2(1.0, 6.0)
## The cytoskeleton's fibres carry authored UVs: one turn around, and metres
## along over the recipe's tile, so the repeat is one.
const WAKING_TUBULE_RECIPE := "tubule"
const WAKING_TUBULE_TILE := Vector2(1.0, 1.0)
## One beat and one palette for the fibres, the limbs tied to them and the
## milky web: a pull shows the same colour, at the same moment, in all three.
const WAKING_PULL_RATE := 0.42
const WAKING_PULL_WAVES := 2.0
const WAKING_WORK_COLOR := Color(0.72, 0.36, 0.92)
const WAKING_STRIKE_COLOR := Color(1.0, 0.62, 0.38)
## The cilia step in this many companies around the cell, each as one.
const WAKING_COHORTS := 12.0
## The bank of vapour round the cell's foot (Lily, 2026-11-13): the
## encroachment's purple, in level sheets from the floor up.
const WAKING_VAPOR_COLOR := Color(0.50, 0.28, 0.70)
const WAKING_VAPOR_SHEETS := 11
const WAKING_VAPOR_TOP := 0.17          # metres
const WAKING_VAPOR_REACH := 0.80        # metres from the middle
## Where the cell has been (Lily, 2026-11-13: "colour the floor where it's
## traveled in a negative spectral trail that ripples in normal map reverting
## back to the floor texture"): a soft disc laid every few centimetres of its
## way, each stamped with when, shown by the trail shader as the floor's own
## negative and let go after a while.
const WAKING_TRAIL_STEP := 0.07         # metres between discs
const WAKING_TRAIL_RADIUS := 0.40       # metres
const WAKING_TRAIL_FADE := 95.0         # seconds from laid to gone
const WAKING_TRAIL_MAX := 180           # discs kept at most
## Its life in the room (Lily, 2026-11-13: "emerge up through the floor, move
## around like a roomba then submerge again when disturbed"), and its body
## ("deform towards its movement destination like an amoeba, elongating and
## stretching while traveling, congealing into a more regular mass when
## stationary feeling an obstacle").
enum WakingArc { SUBMERGED, EMERGING, ROAMING, SUBMERGING }
const WAKING_EMERGE_S := 3.5            # seconds to rise out of the floor
const WAKING_SUBMERGE_S := 1.6          # seconds to go back into it
const WAKING_STRETCH := 0.40            # how much longer it draws out along its way
const WAKING_STARTLE_REACH := 1.3       # metres within which something moving disturbs it
const WAKING_STARTLE_SPEED := 0.8       # metres a second
var arc_enabled := true
var _arc := WakingArc.SUBMERGED
var _arc_clock := 0.0                   # seconds left under the floor
var _arc_out := 0.0                     # 0 under the floor .. 1 fully out
var _stretch := 0.0                     # 0 gathered .. 1 drawn out
var _arc_emergences := 0
var _trail: MeshInstance3D
var _trail_material: ShaderMaterial
var _trail_marks: Array[Dictionary] = []
var _trail_dirty := false
const WAKING_LIMB_COLOR := Color(0.62, 0.42, 0.72)
var _waking_cilium_root_mesh: Mesh
## The residue it leaves (Lily, 2026-11-15: "add the residue to the waking
## cells behavior, integrate it with the current trail"). On the trail a patch
## the width of the cell's underside; where a cilium lands, a small one. The
## hero's richer patch is 0.16 m at full intensity (§28).
const WAKING_RESIDUE_STEP := 0.16       # metres of trail between patches
const WAKING_RESIDUE_RADIUS := 0.17     # metres
const WAKING_RESIDUE_INTENSITY := 0.7
const WAKING_RESIDUE_LIFE := 4.0        # seconds from laid to eroded
const WAKING_TOUCH_RESIDUE_RADIUS := 0.05
const WAKING_TOUCH_RESIDUE_INTENSITY := 0.5
const WAKING_TOUCH_RESIDUE_LIFE := 3.4
const WAKING_TOUCH_RESIDUE_GAP := 0.8   # seconds between touch patches
var _residue_last := Vector3.INF
var _residue_laid := 0
var _residue_touch_clock := 0.0
var _cilia_aim_normal: Array[Vector3] = []


## Binds one registered recipe's three maps to a colony material.
func _bind_waking_recipe(material: ShaderMaterial, recipe: String, tile: Vector2) -> void:
	for pair: Array in [["albedo_tex", "albedo"], ["rough_tex", "roughness"], ["normal_tex", "normal"]]:
		var path := "%s%s_%s.png" % [WAKING_RECIPE_DIR, recipe, pair[1]]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("waking colony recipe map missing: " + path)
			continue
		material.set_shader_parameter(pair[0], texture)
	material.set_shader_parameter("uv_tile", tile)
	material.set_meta("recipe", "waking_colony_" + recipe)


## The shared beat and palette; a shader ignores the ones it does not declare.
func _bind_waking_work(material: ShaderMaterial) -> void:
	material.set_shader_parameter("pull_rate", WAKING_PULL_RATE)
	material.set_shader_parameter("pull_waves", WAKING_PULL_WAVES)
	material.set_shader_parameter("work_color", WAKING_WORK_COLOR)
	material.set_shader_parameter("strike_color", WAKING_STRIKE_COLOR)
	material.set_shader_parameter("limb_color", WAKING_LIMB_COLOR)
	material.set_shader_parameter("cohorts", WAKING_COHORTS)
	material.set_shader_parameter("vapor_color", WAKING_VAPOR_COLOR)


func _build_waking() -> void:
	var packed := load(WAKING_CELL) as PackedScene
	if packed == null:
		push_error("waking colony cell missing: " + WAKING_CELL)
		return
	_waking = packed.instantiate() as Node3D
	_waking.name = "WakingCell"
	add_child(_waking)
	var membrane_shader := preload("res://shaders/waking_colony_membrane.gdshader")
	var organelle_shader := preload("res://shaders/waking_colony_organelle.gdshader")
	var cilium_mesh: Mesh = null
	var root_mesh: Mesh = null
	for mi: MeshInstance3D in _waking.find_children("*", "MeshInstance3D", true, false):
		var key := str(mi.name)
		if key == "Cilium":
			# The cilium is drawn by the WakingCilia multimesh; its source node leaves the tree.
			cilium_mesh = mi.mesh
			mi.get_parent().remove_child(mi)
			mi.queue_free()
			continue
		if key == "CiliumRoots":
			# Never drawn: each triangle says where one cilium starts and which way is out. Kept as data only.
			root_mesh = mi.mesh
			_waking_cilium_root_mesh = root_mesh
			mi.get_parent().remove_child(mi)
			mi.queue_free()
			continue
		var material := ShaderMaterial.new()
		if key == "Membrane":
			material.shader = membrane_shader
			material.set_shader_parameter("tardi_normal", load("res://assets/dream/microscopy/tardigrade_membrane/normal.png"))
			material.set_shader_parameter("cytoplasm_web", load(WAKING_RECIPE_DIR + "cytoplasm_web.png"))
			_bind_waking_work(material)
		elif key == "Cytoskeleton":
			# The microtubule canopy is fixed to the cell: it works in place
			# and does not stream with the organelles.
			material.shader = preload("res://shaders/waking_colony_tubule.gdshader")
			_bind_waking_recipe(material, WAKING_TUBULE_RECIPE, WAKING_TUBULE_TILE)
			_bind_waking_work(material)
			_waking_skeleton = mi
		else:
			material.shader = organelle_shader
			var look: Array = ORGANELLE_LOOK.get(key.get_slice("_", 0), ORGANELLE_LOOK.Nucleus)
			material.set_shader_parameter("region", look[0])
			material.set_shader_parameter("base_color", look[1])
			material.set_shader_parameter("glow_color", look[2])
			material.set_shader_parameter("glow", look[3])
			material.set_shader_parameter("glassy", look[4])
			_bind_waking_recipe(material, str(look[5]), look[6])
			# Cyclosis: each organelle streams around the cell at its own pace,
			# on its own ellipse, so the interior keeps rearranging under the lens.
			var h := _hash01(key.hash() + int(colony.seed))
			_organelles.append({"node": mi, "rest": mi.position,
				"speed": (0.05 + 0.12 * h) * (1.0 if h > 0.3 else -1.0), "bob": 0.004 + 0.006 * h, "phase": h * TAU})
		mi.material_override = material
		_waking_materials.append(material)
	if cilium_mesh != null:
		_build_waking_cilia(cilium_mesh, _waking_cilium_roots(root_mesh))
	_build_waking_vapor()
	_build_waking_trail()


## The floor the cell has crossed. It is this node's child, not the cell's: it
## stays where it was laid while the cell moves on.
func _build_waking_trail() -> void:
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = preload("res://shaders/waking_colony_trail.gdshader")
	_trail_material.set_shader_parameter("cloud_tex", load(WAKING_RECIPE_DIR + "cytoplasm_web.png"))
	_trail_material.set_shader_parameter("fade_s", WAKING_TRAIL_FADE)
	_trail_material.set_shader_parameter("stain_color", WAKING_VAPOR_COLOR)
	# Before the membrane and the vapour, which lie over it.
	_trail_material.render_priority = -1
	_waking_materials.append(_trail_material)
	_trail = MeshInstance3D.new()
	_trail.name = "WakingTrail"
	_trail.mesh = ArrayMesh.new()
	_trail.material_override = _trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.custom_aabb = AABB(Vector3(-WAKING_CRAWL_LEASH - 1.0, -0.05, -WAKING_CRAWL_LEASH - 1.0),
			Vector3(2.0 * WAKING_CRAWL_LEASH + 2.0, 0.2, 2.0 * WAKING_CRAWL_LEASH + 2.0))
	add_child(_trail)


## Lay a disc where the cell is if it has moved a step on from the last one,
## and let go of the ones whose time is up.
func _mark_trail() -> void:
	if _trail == null:
		return
	var at := _waking.position
	if _trail_marks.is_empty() or (_trail_marks[-1].at as Vector3).distance_to(at) >= WAKING_TRAIL_STEP:
		# Each mark remembers the way the cell was going when it laid it, so
		# its ripples can run after the cell; the first has none.
		var way := Vector2.ZERO
		if not _trail_marks.is_empty():
			var from: Vector3 = _trail_marks[-1].at
			way = Vector2(at.x - from.x, at.z - from.z).normalized()
		_trail_marks.append({"at": Vector3(at.x, 0.0, at.z), "born": _clock, "way": way})
		_trail_dirty = true
		_lay_trail_residue(Vector3(at.x, 0.0, at.z))
	while not _trail_marks.is_empty() and (_clock - float(_trail_marks[0].born) > WAKING_TRAIL_FADE
			or _trail_marks.size() > WAKING_TRAIL_MAX):
		_trail_marks.pop_front()
		_trail_dirty = true
	if _trail_dirty:
		_rebuild_trail()


## The goo on the trail. Where the cell's underside has crossed the floor it
## leaves the residue's frost, which crystallises and erodes in a few seconds
## (design/DREAM_SALIVA_DIRECTION.md) and gives way to the trail's long stain
## underneath. One patch every WAKING_RESIDUE_STEP of the way, and only while
## the cell is out on the floor, so a cell under it leaves nothing.
func _lay_trail_residue(at: Vector3) -> void:
	if residue == null or _arc_out < 0.5:
		return
	if _residue_last != Vector3.INF and _residue_last.distance_to(at) < WAKING_RESIDUE_STEP:
		return
	_residue_last = at
	residue.lay(to_global(at), global_basis.y.normalized(), WAKING_RESIDUE_RADIUS,
			WAKING_RESIDUE_INTENSITY, WAKING_RESIDUE_LIFE)
	_residue_laid += 1


func _rebuild_trail() -> void:
	_trail_dirty = false
	var mesh := _trail.mesh as ArrayMesh
	mesh.clear_surfaces()
	if _trail_marks.is_empty():
		return
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var stamps := PackedVector2Array()
	var ways := PackedColorArray()
	var indices := PackedInt32Array()
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for mark: Dictionary in _trail_marks:
		var first := points.size()
		var at: Vector3 = mark.at
		for corner: Vector2 in corners:
			# Later discs lie a hair above earlier ones so they never fight.
			points.append(Vector3(at.x + (corner.x * 2.0 - 1.0) * WAKING_TRAIL_RADIUS,
					0.003 + 0.00002 * float(first), at.z + (corner.y * 2.0 - 1.0) * WAKING_TRAIL_RADIUS))
			normals.append(Vector3.UP)
			tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			uvs.append(corner)
			stamps.append(Vector2(float(mark.born), WAKING_TRAIL_RADIUS))
			var way: Vector2 = mark.way
			ways.append(Color(way.x * 0.5 + 0.5, way.y * 0.5 + 0.5, 0.0, 1.0))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = stamps
	arrays[Mesh.ARRAY_COLOR] = ways
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Where the drawn cell is now, in the world. The encroachment's field grows
## from here, so the purple follows the cell as it roams.
func waking_cell_position() -> Vector3:
	return _waking.global_position if _waking != null else global_position


## Level sheets round the cell's foot; the shader shapes them into a bank that
## hides where the membrane and the cilia meet the floor.
func _build_waking_vapor() -> void:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for sheet in WAKING_VAPOR_SHEETS:
		var rise := float(sheet) / float(WAKING_VAPOR_SHEETS - 1)
		var y := 0.004 + rise * (WAKING_VAPOR_TOP - 0.004)
		var first := points.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(Vector3(corner.x * WAKING_VAPOR_REACH, y, corner.y * WAKING_VAPOR_REACH))
			colors.append(Color(rise, 0.0, 0.0, 1.0))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/waking_colony_vapor.gdshader")
	material.set_shader_parameter("cloud_tex", load(WAKING_RECIPE_DIR + "cytoplasm_web.png"))
	material.set_shader_parameter("sheets", float(WAKING_VAPOR_SHEETS))
	_bind_waking_work(material)
	# After the membrane, which is drawn in the same pass and keeps depth: the
	# vapour in front of the dome must lie over it.
	material.render_priority = 1
	_waking_materials.append(material)
	var vapor := MeshInstance3D.new()
	vapor.name = "WakingVapor"
	vapor.mesh = mesh
	vapor.material_override = material
	vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_waking.add_child(vapor)


## The basal bodies the Blender build placed just inside the membrane: for each
## cilium its position, the way out through the membrane, and its place around
## the cell with two fixed random numbers. One triangle of CiliumRoots each.
func _waking_cilium_roots(mesh: Mesh) -> Array[Dictionary]:
	var roots: Array[Dictionary] = []
	if mesh == null or mesh.get_surface_count() == 0:
		return roots
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in points.size():
			indices.append(i)
	for t in range(0, indices.size() - 2, 3):
		var a := points[indices[t]]
		var b := points[indices[t + 1]]
		var c := points[indices[t + 2]]
		var centre := (a + b + c) / 3.0
		# Godot winds front faces clockwise; the outward side is the one that
		# faces away from the middle of the cell.
		var out := (b - a).cross(c - a).normalized()
		if out.dot(Vector3(centre.x, 0.0, centre.z)) < 0.0:
			out = -out
		var data := colors[indices[t]] if indices[t] < colors.size() else Color(float(t) / float(indices.size()), 0.5, 0.5)
		roots.append({"position": centre, "out": out, "around": data.r, "a": data.g, "b": data.b})
	roots.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.around) < float(q.around))
	return roots


func _build_waking_cilia(mesh: Mesh, roots: Array[Dictionary]) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/waking_colony_cilium.gdshader")
	_bind_waking_recipe(material, WAKING_CILIUM_RECIPE, WAKING_CILIUM_TILE)
	_bind_waking_work(material)
	material.set_shader_parameter("base_color", WAKING_LIMB_COLOR)
	_waking_materials.append(material)
	var cilia := MultiMeshInstance3D.new()
	cilia.name = "WakingCilia"
	cilia.material_override = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	# Each cilium starts at its basal body inside the cell and leaves through
	# the membrane; its curl turns down toward the floor, like a resting leg.
	multimesh.instance_count = roots.size()
	for i in roots.size():
		var root: Dictionary = roots[i]
		var out: Vector3 = root.out
		var length_axis := (out * 0.8 + Vector3.UP * 0.2).normalized()
		var curl := (Vector3.DOWN - length_axis * Vector3.DOWN.dot(length_axis)).normalized()
		# The cilium's own frame: length along +Y, the rest curl toward +Z.
		var basis := Basis(length_axis.cross(curl), length_axis, curl)
		basis = basis.rotated(length_axis, (float(root.b) - 0.5) * 0.5)
		var size := 0.9 + 0.5 * float(root.a)
		_cilia_rest_basis.append(basis)
		_cilia_rest_scale.append(size)
		_cilia_aim.append(Vector3.ZERO)
		_cilia_aim_normal.append(Vector3.UP)
		multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * size), root.position))
		multimesh.set_instance_custom_data(i, Color(float(root.around), float(root.a), 0.0, 1.0))
	_cilia_roots = roots
	_cilia_touch.resize(roots.size())
	_cilia_want.resize(roots.size())
	_waking_cilia = cilia
	_crawl_rng.seed = int(colony.seed) * 7919 + 13 if colony != null else 13
	# It begins under the floor and comes up in its own time.
	_arc = WakingArc.SUBMERGED
	_arc_out = 0.0
	_arc_clock = _crawl_rng.randf_range(0.5, 2.0)
	_waking.visible = false
	cilia.multimesh = multimesh
	cilia.custom_aabb = AABB(Vector3(-0.7, -0.05, -0.7), Vector3(1.4, 0.5, 1.4))
	_waking.add_child(cilia)


# ------------------------------------------------------------ crawl and touch

## Is there room for the cell here, on the same floor? `at` is in this node's
## own space. It must be inside the room it may roam, a flat cylinder the size
## of the cell must be free of every collider, and the floor must be under it
## at the height it is rooted on.
func _crawl_clear(at: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	var here := to_global(at)
	if crawl_bounds.has_area() and not crawl_bounds.grow(-WAKING_BODY_RADIUS).has_point(Vector2(here.x, here.z)):
		return false
	var body := CylinderShape3D.new()
	body.radius = WAKING_BODY_RADIUS
	body.height = 0.12
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.transform = Transform3D(Basis.IDENTITY, here + Vector3.UP * 0.10)
	query.collide_with_areas = false
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var down := PhysicsRayQueryParameters3D.create(here + Vector3.UP * 0.25, here + Vector3.DOWN * 0.15)
	var floor_hit := space.intersect_ray(down)
	return not floor_hit.is_empty() and absf(float(floor_hit.position.y) - here.y) < 0.04


## The whole way to a place is open, a body's width at a time.
func _crawl_way_clear(from: Vector3, to: Vector3) -> bool:
	var steps := maxi(1, int(ceil(from.distance_to(to) / 0.3)))
	for step in range(1, steps + 1):
		if not _crawl_clear(from.lerp(to, float(step) / float(steps))):
			return false
	return true


func _choose_crawl_target() -> void:
	# Like a sweeper: turn by some chance amount from the way it was going,
	# then go straight until something stops it.
	var here := _waking.position
	var was := atan2(_crawl_heading.y, _crawl_heading.x) if _crawl_heading.length() > 0.1 else _crawl_rng.randf() * TAU
	for attempt in 12:
		var turn := _crawl_rng.randf_range(deg_to_rad(55.0), deg_to_rad(180.0)) * (1.0 if _crawl_rng.randf() < 0.5 else -1.0)
		var angle := was + (turn if _crawl_travelled > 0.0 else _crawl_rng.randf() * TAU)
		var way := Vector3(cos(angle), 0.0, sin(angle))
		var reach := 0.0
		while reach < 3.0:
			var next := here + way * (reach + 0.3)
			if next.length() > WAKING_CRAWL_LEASH or not _crawl_clear(next):
				break
			reach += 0.3
		if reach >= 0.3:
			_crawl_target = here + way * reach
			return
	# Hemmed in: stay, and look again in a while.
	_crawl_target = here
	_crawl_rest = 2.5


func _crawl(delta: float) -> void:
	var going := 0.0
	if _crawl_rest > 0.0:
		_crawl_rest -= delta
	else:
		var here := _waking.position
		var ahead := Vector3(_crawl_target.x - here.x, 0.0, _crawl_target.z - here.z)
		if ahead.length() < 0.03:
			# Arrived: stand a while, then choose somewhere else.
			_crawl_rest = _crawl_rng.randf_range(1.0, 3.5) if _crawl_travelled > 0.0 else 0.0
			_choose_crawl_target()
		else:
			var way := ahead.normalized()
			_crawl_check -= delta
			var open := true
			if _crawl_check <= 0.0:
				_crawl_check = 0.2
				open = _crawl_clear(here + way * (0.08 + WAKING_BODY_RADIUS * WAKING_STRETCH * _stretch))
			if not open:
				# Something is in the way now (a chair moved, someone stands there).
				_crawl_rest = 1.0
				_choose_crawl_target()
			else:
				# It moves in surges, not at a glide.
				going = 0.55 + 0.45 * sin(_clock * 0.9)
				var step := way * WAKING_CRAWL_SPEED * going * delta
				_waking.position = here + step
				_crawl_travelled += step.length()
				# The cell's own frame is this node's: it does not turn.
				_crawl_heading = _crawl_heading.lerp(Vector2(way.x, way.z), minf(1.0, delta * 3.0))
	# The cilia take up and lay down the work together, never at a snap.
	_crawl_effort = move_toward(_crawl_effort, going, delta * (1.6 if going > _crawl_effort else 0.9))


## Feelers: low rays out from the rim at two heights, turning slowly so the
## cell sweeps the space between them. Each hit is something to reach for.
func _feel() -> void:
	_feel_hits.clear()
	_study_cooldown = maxf(0.0, _study_cooldown - 0.3)
	var world := get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	var rx := 0.27
	var rz := 0.23
	var nearest := INF
	for k in WAKING_FEELERS:
		var angle := (float(k) / float(WAKING_FEELERS)) * TAU + _clock * 0.07
		var way := Vector3(cos(angle), 0.0, sin(angle))
		var rim := 1.0 / sqrt(pow(way.x / rx, 2.0) + pow(way.z / rz, 2.0))
		for height: float in [0.07, 0.17]:
			var from := _waking.to_global(way * rim * 0.6 + Vector3.UP * height)
			var to := _waking.to_global(way * (rim + WAKING_TOUCH_REACH) + Vector3.UP * height)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
			if hit.is_empty():
				continue
			var point: Vector3 = _waking.to_local(hit.position)
			_feel_hits.append({"angle": angle, "point": point, "normal": hit.normal})
			var far := Vector2(point.x, point.z).length() - rim
			if far < nearest:
				nearest = far
				_attend_point = point
			break
	# One mind: the whole cell attends to the nearest thing it has found, and
	# stops to study a new find before it moves on.
	_attend_want = 0.0 if _feel_hits.is_empty() else 1.0
	if not _feel_hits.is_empty() and _study_cooldown <= 0.0 and _crawl_rest <= 0.0 and _crawl_travelled > 0.0:
		_crawl_rest = 3.0
		_study_cooldown = 9.0
	# Which cilia answer: nearly all on that side whose reach covers the thing.
	var turn := int(floor(_clock / 4.0))
	for i in _cilia_roots.size():
		_cilia_want[i] = 0.0
		if _feel_hits.is_empty():
			continue
		var root_at: Vector3 = _cilia_roots[i].position
		var side := atan2(root_at.z, root_at.x)
		for hit: Dictionary in _feel_hits:
			if absf(angle_difference(side, float(hit.angle))) > TAU / float(WAKING_FEELERS) * 1.1:
				continue
			# Each cilium takes its own spot on the thing, a little off the ray.
			var spot: Vector3 = hit.point + Vector3(0.0, (_hash01(i * 37 + turn) - 0.4) * 0.07, 0.0) \
					+ Vector3(-sin(side), 0.0, cos(side)) * (_hash01(i * 53 + turn) - 0.5) * 0.05
			var far := root_at.distance_to(spot)
			if far < 0.05 or far > WAKING_LIMB_LENGTH * WAKING_LIMB_STRETCH:
				continue
			if _hash01(i * 71 + turn * 13) < 0.15:
				continue
			_cilia_want[i] = 1.0
			_cilia_aim[i] = spot
			_cilia_aim_normal[i] = hit.normal
			break


## Where cilium `i` is now. At rest it stands on its root; while the cell
## attends to something, limbs on that side turn toward it; a limb that is
## feeling is turned onto its spot and lengthened so its straightened tip
## lands there.
func waking_cilium_pose(i: int) -> Transform3D:
	var root_at: Vector3 = _cilia_roots[i].position
	var basis := _cilia_rest_basis[i]
	var length := _cilia_rest_scale[i]
	var width := length
	if _attend > 0.0:
		var to_thing := _attend_point - root_at
		to_thing.y = 0.0
		var outward := Vector3(root_at.x, 0.0, root_at.z)
		if to_thing.length() > 0.01 and outward.length() > 0.01:
			# Only limbs that face the thing turn; the far side stands as it was.
			var facing := maxf(0.0, outward.normalized().dot(to_thing.normalized()))
			var axis := basis.y.cross(to_thing.normalized())
			if axis.length() > 0.01:
				basis = basis.rotated(axis.normalized(), 0.30 * _attend * facing)
	var now := _cilia_touch[i]
	if now > 0.0:
		var to_spot := _cilia_aim[i] - root_at
		var along := to_spot.normalized()
		var curl := Vector3.DOWN - along * Vector3.DOWN.dot(along)
		curl = curl.normalized() if curl.length() > 0.01 else basis.z
		var aim := Basis(along.cross(curl), along, curl).orthonormalized()
		var ease := smoothstep(0.0, 1.0, now)
		basis = basis.orthonormalized().slerp(aim, ease)
		length = lerpf(length, clampf(to_spot.length() / WAKING_LIMB_LENGTH, 0.8, WAKING_LIMB_STRETCH), ease)
		# A long reach is a longer limb, not a fatter one.
		width = minf(length, 1.3)
	return Transform3D(basis * Basis.from_scale(Vector3(width, length, width)), root_at)


## Ease each cilium between standing, attending and feeling.
func _animate_touch(delta: float) -> void:
	if _waking_cilia == null:
		return
	_attend = move_toward(_attend, _attend_want, delta * 0.8)
	var attending := not is_equal_approx(_attend, _attend_shown)
	_attend_shown = _attend
	var multimesh := _waking_cilia.multimesh
	_residue_touch_clock = maxf(0.0, _residue_touch_clock - delta)
	for i in _cilia_roots.size():
		var now := _cilia_touch[i]
		var want := _cilia_want[i]
		if now == want and now == 0.0 and not attending:
			continue
		_cilia_touch[i] = move_toward(now, want, delta * (0.7 if want > now else 1.1))
		if now < 0.95 and _cilia_touch[i] >= 0.95:
			_lay_touch_residue(i)
		var root: Dictionary = _cilia_roots[i]
		multimesh.set_instance_transform(i, waking_cilium_pose(i))
		multimesh.set_instance_custom_data(i, Color(float(root.around), float(root.a), _cilia_touch[i], 1.0))


## A cilium has landed on the thing it reached for: it leaves a small patch of
## the goo there, on that surface, at most one every WAKING_TOUCH_RESIDUE_GAP.
func _lay_touch_residue(i: int) -> void:
	if residue == null or _residue_touch_clock > 0.0:
		return
	_residue_touch_clock = WAKING_TOUCH_RESIDUE_GAP
	residue.lay(_waking.to_global(_cilia_aim[i]), _cilia_aim_normal[i], WAKING_TOUCH_RESIDUE_RADIUS,
			WAKING_TOUCH_RESIDUE_INTENSITY, WAKING_TOUCH_RESIDUE_LIFE)
	_residue_laid += 1


## How many cilia are reaching for something now (for tests and the census).
func waking_touching() -> int:
	var count := 0
	for value in _cilia_touch:
		if value > 0.5:
			count += 1
	return count


func _animate_waking() -> void:
	for material in _waking_materials:
		material.set_shader_parameter("cell_time", _clock)
		material.set_shader_parameter("effort", _crawl_effort)
		material.set_shader_parameter("heading", _crawl_heading)
		material.set_shader_parameter("stretch", _stretch)
	if _trail_material != null:
		_trail_material.set_shader_parameter("cell_at", _waking.position)
		_mark_trail()
	var rx := 0.27
	var rz := 0.23
	for row: Dictionary in _organelles:
		var rest: Vector3 = row.rest
		# Rotate on the cell's own ellipse: normalise, turn, scale back, so a
		# streaming organelle never leaves the membrane.
		var nx := rest.x / rx
		var nz := rest.z / rz
		var ang: float = _clock * float(row.speed) + float(row.phase) * 0.0
		var c := cos(ang)
		var s := sin(ang)
		var node: Node3D = row.node
		node.position = Vector3((nx * c - nz * s) * rx, rest.y + float(row.bob) * sin(_clock * 0.7 + float(row.phase)),
				(nx * s + nz * c) * rz)
		node.rotation.y = ang
