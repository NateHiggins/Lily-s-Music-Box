extends RefCounted
## Shared world, glove and case presentation. The XZ footprint is 23 by 13 cm;
## the origin is the centre of the underside on its support.
const Forge := preload("res://scripts/songbook/phonautogram_forge.gd")
const Office := preload("res://assets/props/house_office.glb")
const Chart := preload("res://scripts/building/v2_metre_box_uv.gd")
const SIZE := Vector3(.23, .0018, .13)
static var _envelope: Mesh
static var _sheet: Mesh
static var _lines := {}

static func make(id: String) -> Node3D:
	if not Forge.FOUND.has(id):
		return null
	var root := Node3D.new()
	var stock := MeshInstance3D.new()
	root.add_child(stock)
	if id in ["trace_1610", "trace_two_voices"]:
		if _envelope == null:
			var desk := Office.instantiate()
			var letter := desk.find_child("sorting_desk__Letter_ON_paper", true, false) as MeshInstance3D
			if letter != null:
				_envelope = letter.mesh
			desk.free()
		if _envelope == null:
			root.free()
			return null
		stock.mesh = _envelope
		# Native flap faces up, with its fold on the far edge.
		stock.rotation.x = PI / 2.0
		stock.position = Vector3(0, .002, -.065)
		stock.material_override = _paper(Color(.85, .72, .52), false)
		var pencil := Label3D.new()
		pencil.text = "WORS" if id == "trace_1610" else "for M."
		pencil.rotation.x = -PI / 2.0
		pencil.position = Vector3(-.038, .0052, .023)
		pencil.font_size = 40
		pencil.pixel_size = .00034
		pencil.outline_size = 0
		pencil.modulate = Color(.19, .15, .105)
		pencil.double_sided = false
		root.add_child(pencil)
	else:
		if _sheet == null:
			var cut := BoxMesh.new()
			cut.size = SIZE
			cut.material = _paper(Color(.20, .175, .15), true)
			_sheet = Chart.chart(cut)
		stock.mesh = _sheet
		stock.position.y = SIZE.y * .5
		var line := MeshInstance3D.new()
		if not _lines.has(id):
			_lines[id] = _scratch(id)
		line.mesh = _lines[id]
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(line)
	return root

static func _paper(tint: Color, in_metres: bool) -> StandardMaterial3D:
	var finish := MatLib.get_mat("paper", tint).duplicate() as StandardMaterial3D
	finish.uv1_triplanar = false
	finish.uv1_scale = Vector3.ONE / float(MatLib.SETS.paper[3]) if in_metres else Vector3.ONE
	return finish

## A bristle exposes an irregular, pale line in the lampblack. It carries
## texture and a proper UV/tangent frame just like the parent paper.
static func _scratch(id: String) -> ArrayMesh:
	var trace := SurfaceTool.new()
	trace.begin(Mesh.PRIMITIVE_TRIANGLES)
	trace.set_material(_paper(Color(.72, .61, .46), true))
	var pitch := 19.0 if id == "trace_room0" else 13.0
	for i in 161:
		var t := float(i) / 160.0
		var x := lerpf(-.10, .10, t)
		var z := sin(t * TAU * pitch + sin(t * 4.9)) * (.002 + .009 * pow(sin(t * PI * 2.0), 2))
		for edge in [-.00065, .00065]:
			var v := Vector3(x, SIZE.y + .00015, z + float(edge))
			trace.set_normal(Vector3.UP)
			trace.set_tangent(Plane(1, 0, 0, -1))
			trace.set_uv(Vector2(v.x, v.z))
			trace.add_vertex(v)
		if i > 0:
			var j := 2 * i
			for index in [j - 2, j, j - 1, j, j + 1, j - 1]:
				trace.add_index(index)
	return trace.commit()
