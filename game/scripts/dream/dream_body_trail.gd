extends MeshInstance3D
## INSIDE THE CELL, second round (Lily's ruling on the first film: "keep it; next add the cell's rainbow trail on the
## floor where you have walked and twitching fibres round the door frames").
##
## Where the dream body has stood, the waking cell's own trail follows it: soft discs stamped every few centimetres
## at the feet, each shown by the approved waking_colony_trail shader as the surface's own negative under a
## rippling spectrum, settling to an afterimage and then back to the bare surface. On a course that means the tops
## of the furniture you crossed (and the boards you grazed in the half second before you woke), so the way you came
## stays on the room for a while. Presentation only: nothing here collides, and nothing reads it.

const Renderer := preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const TRAIL_SHADER := preload("res://shaders/waking_colony_trail.gdshader")
## Metres of travel between discs, the disc radius, seconds from laid to gone, and the most kept at once.
const STEP_M := 0.09
const RADIUS_M := 0.24
const FADE_S := 45.0
const MAX_MARKS := 260

## The body whose feet lay the trail; set by the owner before the node enters the tree.
var body: CharacterBody3D
var _material: ShaderMaterial
var _marks: Array[Dictionary] = []
var _time := 0.0
var _dirty := false


func _ready() -> void:
	name = "BodyTrail"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_material = ShaderMaterial.new()
	_material.shader = TRAIL_SHADER
	_material.set_shader_parameter("cloud_tex", load(Renderer.WAKING_RECIPE_DIR + "cytoplasm_web.png"))
	_material.set_shader_parameter("fade_s", FADE_S)
	_material.set_shader_parameter("stain_color", Renderer.WAKING_VAPOR_COLOR)
	_material.render_priority = -1
	material_override = _material
	mesh = ArrayMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-400.0, -20.0, -400.0), Vector3(800.0, 60.0, 800.0))


func marks() -> int:
	return _marks.size()


func _physics_process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("cell_time", _time)
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var feet := body.global_position
	_material.set_shader_parameter("cell_at", feet)
	if body.is_on_floor() or _grounded(feet):
		var last: Dictionary = _marks[-1] if not _marks.is_empty() else {}
		if last.is_empty() or (last.at as Vector3).distance_to(feet) >= STEP_M:
			var way := Vector2.ZERO
			if not last.is_empty() and absf(float((last.at as Vector3).y) - feet.y) < 0.05:
				var d := feet - (last.at as Vector3)
				way = Vector2(d.x, d.z).normalized()
			_marks.append({"at": feet, "born": _time, "way": way})
			_dirty = true
	while not _marks.is_empty() and (_time - float(_marks[0].born) > FADE_S or _marks.size() > MAX_MARKS):
		_marks.pop_front()
		_dirty = true
	if _dirty:
		_rebuild()


## Something solid just under the feet (the body may be carried by a script, with its own physics asleep).
func _grounded(feet: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.05, feet + Vector3.DOWN * 0.06)
	query.exclude = [body.get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _rebuild() -> void:
	_dirty = false
	var arrays_mesh := mesh as ArrayMesh
	arrays_mesh.clear_surfaces()
	if _marks.is_empty():
		return
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var stamps := PackedVector2Array()
	var ways := PackedColorArray()
	var indices := PackedInt32Array()
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for mark: Dictionary in _marks:
		var first := points.size()
		var at: Vector3 = mark.at
		var way: Vector2 = mark.way
		for corner: Vector2 in corners:
			# Later discs lie a hair above earlier ones so they never fight.
			points.append(Vector3(at.x + (corner.x * 2.0 - 1.0) * RADIUS_M, at.y + 0.004 + 0.00002 * float(first),
					at.z + (corner.y * 2.0 - 1.0) * RADIUS_M))
			normals.append(Vector3.UP)
			tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			uvs.append(corner)
			stamps.append(Vector2(float(mark.born), RADIUS_M))
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
	arrays_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
