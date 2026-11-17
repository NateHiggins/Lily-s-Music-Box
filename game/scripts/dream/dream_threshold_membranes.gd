class_name DreamThresholdMembranes
extends Node3D
## INSIDE THE CELL, first round (order wc0265c4a2ba0, Lily's ruling dream_v2_direction_20261116, step 3).
##
## The dream's rooms are architecture the being has taken in, and you pass between them through its skin: every
## open doorway in the live pocket is spanned by a membrane wearing the waking cell's own approved shader (lensing
## opal film, milky cytoplasm web, the shared 0.42 Hz pull), so the dream and the waking encroachment read as one
## being, as Bible §IX's biology ruling asks. Nothing here collides or changes a route: the membrane is something a
## body walks through, never a wall. One material serves every doorway, so the whole pocket breathes together.
##
## The lens is a pillow exactly the size of the aperture: flush with the frame at its edges and bowed through the
## doorway's depth in the middle. (A first round overfilled the opening with an ellipsoid for the wall to hide, but
## the dream's walls draw in the transparent pass with their decay holes, so its rim glowed through them.) Doors
## arrive twice in the plan (once from each side) and are kept once by position.
##
## Second round (Lily: "twitching fibres round the door frames"): the waking cell's own jointed cilia grow from both
## faces of every open door frame, up each jamb and across the head, leaning out into the room and in over the
## opening. They wear the approved cilium shader with the cell standing still, so they never walk: the old ripple
## runs round each frame, a quick stroke and a lifted return, and the whole fringe breathes on the cell's beat.

const MEMBRANE_SHADER := preload("res://shaders/waking_colony_membrane.gdshader")
const TARDI_NORMAL := "res://assets/dream/microscopy/tardigrade_membrane/normal.png"
const CYTOPLASM_WEB := "res://assets/dream/waking_colony/cytoplasm_web.png"
## How far the skin bows across the doorway's depth, metres either side of the wall's mid-plane.
const DEPTH_M := 0.07
## Grid of the pillow, across and up.
const GRID := Vector2i(12, 24)
const Renderer := preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const CILIUM_SHADER := preload("res://shaders/waking_colony_cilium.gdshader")
## Metres of frame between fibres, how far they stand off the opening onto the frame, and their size range
## (the cell's limb is 0.124 m straightened at scale one).
const FIBRE_SPACING_M := 0.085
const FIBRE_INSET_M := 0.03
const FIBRE_SCALE := Vector2(1.5, 2.6)

var material: ShaderMaterial
var _mesh: ArrayMesh
var _membranes: Dictionary = {}
var _time := 0.0
var fibre_material: ShaderMaterial
var _fibres: MultiMeshInstance3D
var _cilium_mesh: Mesh


func _ready() -> void:
	name = "ThresholdMembranes"
	material = ShaderMaterial.new()
	material.shader = MEMBRANE_SHADER
	material.set_shader_parameter("tardi_normal", load(TARDI_NORMAL))
	material.set_shader_parameter("cytoplasm_web", load(CYTOPLASM_WEB))
	_mesh = _pillow()
	_cilium_mesh = _load_cilium()
	fibre_material = ShaderMaterial.new()
	fibre_material.shader = CILIUM_SHADER
	for pair: Array in [["albedo_tex", "albedo"], ["rough_tex", "roughness"], ["normal_tex", "normal"]]:
		fibre_material.set_shader_parameter(pair[0], load("%s%s_%s.png" % [Renderer.WAKING_RECIPE_DIR, Renderer.WAKING_CILIUM_RECIPE, pair[1]]))
	fibre_material.set_shader_parameter("uv_tile", Renderer.WAKING_CILIUM_TILE)
	fibre_material.set_shader_parameter("pull_rate", Renderer.WAKING_PULL_RATE)
	fibre_material.set_shader_parameter("pull_waves", Renderer.WAKING_PULL_WAVES)
	fibre_material.set_shader_parameter("work_color", Renderer.WAKING_WORK_COLOR)
	fibre_material.set_shader_parameter("strike_color", Renderer.WAKING_STRIKE_COLOR)
	fibre_material.set_shader_parameter("cohorts", Renderer.WAKING_COHORTS)
	fibre_material.set_shader_parameter("base_color", Renderer.WAKING_LIMB_COLOR)
	# Standing, never walking: the ripple is the twitch, a little quicker and fuller than the cell's own.
	fibre_material.set_shader_parameter("effort", 0.0)
	fibre_material.set_shader_parameter("ripple", 0.9)
	fibre_material.set_shader_parameter("ripple_rate", 3.1)
	fibre_material.set_shader_parameter("ripple_waves", 5.0)
	_fibres = MultiMeshInstance3D.new()
	_fibres.name = "FrameFibres"
	_fibres.material_override = fibre_material
	_fibres.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fibres.extra_cull_margin = 0.6
	add_child(_fibres)


func _process(delta: float) -> void:
	_time += delta
	material.set_shader_parameter("cell_time", _time)
	fibre_material.set_shader_parameter("cell_time", _time)


## Make the membranes match the plan's open doors: one per aperture, new ones built, gone ones freed.
func sync(plan: Dictionary) -> void:
	var wanted := {}
	for door: Dictionary in plan.get("doors", []):
		var a: Array = door.aperture
		var key := "%d_%d" % [roundi((float(a[0]) + float(a[2])) * 50.0), roundi((float(a[1]) + float(a[3])) * 50.0)]
		if wanted.has(key):
			continue
		wanted[key] = door
	for key: String in _membranes.keys():
		if not wanted.has(key):
			(_membranes[key] as Node).queue_free()
			_membranes.erase(key)
	for key: String in wanted:
		if not _membranes.has(key):
			_membranes[key] = _build(wanted[key])
	_grow_fibres(wanted)


func count() -> int:
	return _membranes.size()


func fibre_count() -> int:
	return 0 if _fibres.multimesh == null else _fibres.multimesh.instance_count


## The fibre roots of every kept doorway, as {"at", "out", "around"}; `out` is the way the fibre leans.
func fibre_roots(door: Dictionary) -> Array[Dictionary]:
	var a: Array = door.aperture
	var span_x := absf(float(a[2]) - float(a[0]))
	var span_z := absf(float(a[3]) - float(a[1]))
	var along_z := span_z > span_x
	var width := float(door.get("width", maxf(span_x, span_z)))
	var height := float(door.get("height", 2.13))
	var centre := Vector3((float(a[0]) + float(a[2])) * 0.5, 0.0, (float(a[1]) + float(a[3])) * 0.5)
	var across := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var normal := Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)
	var depth := minf(span_x, span_z) * 0.5
	var half := width * 0.5 + FIBRE_INSET_M
	var top := height + FIBRE_INSET_M
	# The frame's run: up the near jamb, across the head, down the far jamb; `around` is the place along it.
	var run := 2.0 * top + 2.0 * half
	var roots: Array[Dictionary] = []
	var count_along := maxi(8, int(run / FIBRE_SPACING_M))
	for face: float in [1.0, -1.0]:
		for i in count_along:
			var t := (float(i) + 0.5) / float(count_along)
			var d := t * run
			var at: Vector3
			var inward: Vector3
			if d < top:
				at = centre - across * half + Vector3.UP * d
				inward = across
			elif d < top + 2.0 * half:
				at = centre - across * half + across * (d - top) + Vector3.UP * top
				inward = Vector3.DOWN
			else:
				at = centre + across * half + Vector3.UP * (run - d)
				inward = -across
			if at.y < 0.12:
				continue
			at += normal * face * depth
			var out := (normal * face * 0.75 + inward * 0.5).normalized()
			roots.append({"at": at, "out": out, "inward": inward, "around": t})
	return roots


func _grow_fibres(wanted: Dictionary) -> void:
	if _cilium_mesh == null:
		return
	var roots: Array[Dictionary] = []
	for key: String in wanted:
		roots.append_array(fibre_roots(wanted[key]))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _cilium_mesh
	multimesh.instance_count = roots.size()
	for i in roots.size():
		var root: Dictionary = roots[i]
		var own := fposmod(sin(float(i) * 12.9898 + (root.at as Vector3).x * 78.233) * 43758.5453, 1.0)
		var length_axis: Vector3 = root.out
		var inward: Vector3 = root.inward
		var curl := inward - length_axis * inward.dot(length_axis)
		curl = curl.normalized() if curl.length() > 0.01 else Vector3.UP
		var basis := Basis(length_axis.cross(curl), length_axis, curl).rotated(length_axis, (own - 0.5) * 0.8)
		var size := lerpf(FIBRE_SCALE.x, FIBRE_SCALE.y, own)
		multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * size), root.at))
		multimesh.set_instance_custom_data(i, Color(float(root.around), own, 0.0, 1.0))
	_fibres.multimesh = multimesh


## The waking cell's own limb, taken from its glTF (the renderer draws the same mesh as the cell's cilia).
func _load_cilium() -> Mesh:
	var packed := load(Renderer.WAKING_CELL) as PackedScene
	if packed == null:
		return null
	var cell := packed.instantiate()
	var found: Mesh = null
	for mi: Node in cell.find_children("Cilium", "MeshInstance3D", true, false):
		found = (mi as MeshInstance3D).mesh
		break
	cell.free()
	return found


func _build(door: Dictionary) -> MeshInstance3D:
	var a: Array = door.aperture
	var span_x := absf(float(a[2]) - float(a[0]))
	var span_z := absf(float(a[3]) - float(a[1]))
	var width := float(door.get("width", maxf(span_x, span_z)))
	var height := float(door.get("height", 2.13))
	var skin := MeshInstance3D.new()
	skin.name = "Membrane"
	skin.mesh = _mesh
	skin.material_override = material
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skin.position = Vector3((float(a[0]) + float(a[2])) * 0.5, height * 0.5, (float(a[1]) + float(a[3])) * 0.5)
	# The doorway is wide along whichever axis its aperture is longer on; the skin's own x lies along it.
	if span_z > span_x:
		skin.rotation.y = PI * 0.5
	skin.scale = Vector3(width, height, DEPTH_M)
	add_child(skin)
	return skin


## A unit pillow: x and y in -0.5..0.5, both faces bowed to z = +/-1 at the centre and flat at the rim.
func _pillow() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [1.0, -1.0]:
		for j in GRID.y:
			for i in GRID.x:
				var quad: Array[Vector2] = [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
				var order: Array = [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
				for k in order:
					var u := quad[k].x / float(GRID.x)
					var v := quad[k].y / float(GRID.y)
					var x := u - 0.5
					var y := v - 0.5
					var bow := (1.0 - 4.0 * x * x) * (1.0 - 4.0 * y * y)
					st.set_uv(Vector2(u, 1.0 - v))
					st.add_vertex(Vector3(x, y, side * bow))
	st.generate_normals()
	return st.commit()
