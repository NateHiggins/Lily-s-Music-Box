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

const MEMBRANE_SHADER := preload("res://shaders/waking_colony_membrane.gdshader")
const TARDI_NORMAL := "res://assets/dream/microscopy/tardigrade_membrane/normal.png"
const CYTOPLASM_WEB := "res://assets/dream/waking_colony/cytoplasm_web.png"
## How far the skin bows across the doorway's depth, metres either side of the wall's mid-plane.
const DEPTH_M := 0.07
## Grid of the pillow, across and up.
const GRID := Vector2i(12, 24)

var material: ShaderMaterial
var _mesh: ArrayMesh
var _membranes: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	name = "ThresholdMembranes"
	material = ShaderMaterial.new()
	material.shader = MEMBRANE_SHADER
	material.set_shader_parameter("tardi_normal", load(TARDI_NORMAL))
	material.set_shader_parameter("cytoplasm_web", load(CYTOPLASM_WEB))
	_mesh = _pillow()


func _process(delta: float) -> void:
	_time += delta
	material.set_shader_parameter("cell_time", _time)


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


func count() -> int:
	return _membranes.size()


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
