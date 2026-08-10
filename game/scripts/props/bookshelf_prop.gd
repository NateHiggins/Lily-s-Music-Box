class_name BookshelfProp
extends FunctionalProp
## Somebody's bookshelf, built from their actual books.
##
## Three bodies tell three different histories. Mae and Peter bought modular
## Globe-Wernicke sectionals, whose glass lifts rather than swings into the
## room. Iris, Nadia and Jonah inherited ordinary open oak cases. Mina, Sacha
## and Malcolm have repaired shelves made from boards and packing cases. None
## carries a signal: every mechanism and fastener is plausible in 1927.
##
## The books are two meshes, not a row of little draw calls. Cover colour,
## rubbed bands and page yellowing live in vertex colour, because tinting a
## material per book would make FunctionalProp._material_key split the batch
## back into one surface per spine.

var owner_name := ""
var unit := ""
var case_style := "plain"
var canonical_book := ""
var warehouse_open := false
var sorter := ShelfSort.new()

var _panel: Node
var _fixed: Node3D
var _books_at: Node3D
var _doors: Array[MeshInstance3D] = []
var _door_open := 0.0
var _door_target := 0.0
var _case_w := 0.72
var _case_h := 1.30
var _case_d := 0.28
var _book_y := 0.91
var _tap: AudioStreamPlayer3D


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "sectional case / Mae", "properties": {
			"owner_name": "Mae Kessler", "unit": "6C",
			"case_style": "sectional", "canonical_book": "prospectus"}},
		{"label": "open oak case / Iris", "properties": {
			"owner_name": "Iris Bell", "unit": "5C", "case_style": "plain"}},
		{"label": "repaired shelf / Mina", "properties": {
			"owner_name": "Mina Vale", "unit": "2A", "case_style": "repaired"}},
	]


func _derive() -> void:
	match case_style:
		"sectional":
			_case_w = 0.78
			_case_h = 1.34
			_case_d = 0.30
			_book_y = 0.91
		"repaired":
			_case_w = 0.68
			_case_h = 1.22
			_case_d = 0.25
			_book_y = 0.86
		_:
			_case_w = 0.72
			_case_h = 1.30
			_case_d = 0.28
			_book_y = 0.89


func _build_visual() -> void:
	_derive() # The warehouse calls no setup method; derivation belongs here.
	if owner_name == "":
		owner_name = "Mae Kessler"
	sorter.load_library()
	sorter.begin(owner_name, 0.45, hash("shelf:" + owner_name))
	# Redundant with library.json on purpose: the layout marker names the
	# evidence too, so a broken library handoff is visible rather than silent.
	if canonical_book != "" and not sorter.order.has(canonical_book):
		if sorter.order.is_empty():
			sorter.order.append(canonical_book)
		else:
			sorter.order[0] = canonical_book
	_fixed = Node3D.new()
	_fixed.name = "FixedCase"
	add_child(_fixed)
	_build_case()
	_books_at = Node3D.new()
	_books_at.name = "Books"
	add_child(_books_at)
	rebuild_books()
	merge_static(_fixed)
	_tap = make_emitter("tick", -20.0)
	if warehouse_open:
		_door_open = 1.0
		_door_target = 1.0
		_apply_doors()
	set_process(case_style == "sectional")


func _build_case() -> void:
	var oak := smat("oak_quartered", Color(0.48, 0.40, 0.30), 1.1)
	var dark := smat("wood_dark", Color(0.46, 0.39, 0.30), 1.2)
	var brass := smat("brass_dull", Color(0.78, 0.70, 0.50), 1.0)
	# Sectionals were sold in dark mahogany finishes; the quartered oak map is
	# reserved for the plainer inherited case, where its figure can be read.
	var wood := oak if case_style == "plain" else dark
	# Backs are deliberately thin. The depth comes from real side boards,
	# not a solid block whose shadow makes a 280 mm case read like a wardrobe.
	_box(_fixed, Vector3(_case_w, _case_h, 0.012),
			Vector3(0, _case_h * 0.5, -_case_d * 0.5), dark)
	if case_style == "repaired":
		# Salvaged boards disagree by centimetres but still land the active run
		# at hand height. Malcolm repaired function; Mina squared the contents.
		_box(_fixed, Vector3(0.036, _case_h, _case_d),
				Vector3(-_case_w * 0.5, _case_h * 0.5, 0), wood)
		_box(_fixed, Vector3(0.027, _case_h - 0.055, _case_d),
				Vector3(_case_w * 0.5, (_case_h - 0.055) * 0.5, 0.006), oak)
		for y in [0.08, 0.43, 0.82, 1.19]:
			_box(_fixed, Vector3(_case_w + 0.05, 0.027, _case_d),
					Vector3(0.012 if y == 0.43 else -0.006, y, 0), wood)
		for x in [-0.24, 0.23]:
			_box(_fixed, Vector3(0.022, 0.16, 0.018),
					Vector3(x, 0.47, _case_d * 0.5 + 0.012), brass)
	elif case_style == "sectional":
		_box(_fixed, Vector3(_case_w + 0.08, 0.10, _case_d + 0.04),
				Vector3(0, 0.05, 0), wood)
		_box(_fixed, Vector3(_case_w + 0.08, 0.085, _case_d + 0.04),
				Vector3(0, _case_h - 0.0425, 0), wood)
		for x in [-_case_w * 0.5, _case_w * 0.5]:
			_box(_fixed, Vector3(0.036, _case_h - 0.16, _case_d),
					Vector3(x, _case_h * 0.5, 0), wood)
		for y in [0.14, 0.53, 0.92, 1.26]:
			_box(_fixed, Vector3(_case_w, 0.026, _case_d), Vector3(0, y, 0), wood)
			if y < 1.20:
				_make_lift_door(y + 0.19)
		# The little maker's plate is hardware, not generated lettering.
		_box(_fixed, Vector3(0.12, 0.028, 0.008),
				Vector3(0, 0.10, _case_d * 0.5 + 0.008), brass)
	else:
		for x in [-_case_w * 0.5, _case_w * 0.5]:
			_box(_fixed, Vector3(0.034, _case_h, _case_d),
					Vector3(x, _case_h * 0.5, 0), wood)
		for y in [0.045, 0.45, 0.86, 1.275]:
			_box(_fixed, Vector3(_case_w + 0.04, 0.03, _case_d),
					Vector3(0, y, 0), wood)
		# Unequal feet are why this second-hand case has a folded paper shim.
		for x in [-0.27, 0.27]:
			_box(_fixed, Vector3(0.08, 0.08 if x < 0 else 0.075, 0.20),
					Vector3(x, 0.04, -0.01), wood)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = material
	parent.add_child(mi)
	return mi


func _make_lift_door(y: float) -> void:
	# One retained mesh per tier: opaque sash and translucent pane share a
	# vertex-coloured transparent material. merge_static never sees these.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer_w := _case_w - 0.07
	var outer_h := 0.32
	var rail := 0.030
	for dy in [-outer_h * 0.5 + rail * 0.5, outer_h * 0.5 - rail * 0.5]:
		_append_box(st, Vector3(outer_w, rail, 0.012),
				Vector3(0, y + dy, _case_d * 0.5 + 0.012),
				Color(0.40, 0.28, 0.15, 1.0))
	for dx in [-outer_w * 0.5 + rail * 0.5, outer_w * 0.5 - rail * 0.5]:
		_append_box(st, Vector3(rail, outer_h - rail * 2.0, 0.012),
				Vector3(dx, y, _case_d * 0.5 + 0.012),
				Color(0.40, 0.28, 0.15, 1.0))
	_append_box(st, Vector3(outer_w - rail * 2.0, outer_h - rail * 2.0, 0.006),
			Vector3(0, y, _case_d * 0.5 + 0.018), Color(0.54, 0.62, 0.60, 0.20))
	var door := MeshInstance3D.new()
	door.name = "LiftDoor%d" % _doors.size()
	door.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.52
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	door.material_override = mat
	add_child(door)
	_doors.append(door)


func _book_w(id: String) -> float:
	return 0.020 + float(absi(id.hash()) % 18) * 0.001


func _run_width() -> float:
	var width := 0.0
	for id in sorter.order:
		width += _book_w(str(id)) + 0.004
	return width


func rebuild_books() -> void:
	if _books_at == null:
		return
	for child in _books_at.get_children():
		child.queue_free()
	var covers := SurfaceTool.new()
	var pages := SurfaceTool.new()
	covers.begin(Mesh.PRIMITIVE_TRIANGLES)
	pages.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := -_run_width() * 0.5
	for i in sorter.order.size():
		var id := str(sorter.order[i])
		var book: Dictionary = sorter.book(id)
		var width := _book_w(id)
		if i == sorter.held:
			x += width + 0.004
			continue
		var height := clampf(float(book.get("height", 200)) / 1000.0, 0.15, 0.27)
		var hue := float(book.get("hue", 0)) / 360.0
		var cover := Color.from_hsv(hue, 0.38, 0.54 - height * 0.25)
		var centre := Vector3(x + width * 0.5, _book_y + height * 0.5, 0.025)
		_append_box(covers, Vector3(width, height, 0.145), centre, cover)
		# Rubbed head and tail bands are geometry in the same vertex-colour
		# surface, not another material and not illumination baked into cloth.
		var rub := cover.lightened(0.12)
		for dy in [-height * 0.5 + 0.012, height * 0.5 - 0.012]:
			_append_box(covers, Vector3(width + 0.001, 0.016, 0.147),
					centre + Vector3(0, dy, 0.001), rub)
		var yellow := 0.78 + float(absi(id.hash()) % 12) / 100.0
		_append_box(pages, Vector3(width * 0.80, height - 0.020, 0.125),
				centre + Vector3(0, 0, -0.006),
				Color(yellow, yellow * 0.96, yellow * 0.82))
		x += width + 0.004
	var cover_mesh := MeshInstance3D.new()
	cover_mesh.name = "BatchedCovers"
	cover_mesh.mesh = covers.commit()
	# MatLib returns shared cached materials. Vertex-colour support belongs to
	# this book batch only; mutating the cached linen previously changed every
	# later caller that requested the same key/tint/scale tuple.
	var cover_mat := smat("linen", Color.WHITE, 2.0).duplicate() as StandardMaterial3D
	cover_mat.vertex_color_use_as_albedo = true
	cover_mesh.material_override = cover_mat
	_books_at.add_child(cover_mesh)
	var page_mesh := MeshInstance3D.new()
	page_mesh.name = "BatchedPages"
	page_mesh.mesh = pages.commit()
	var page_mat := smat("paper", Color.WHITE, 2.0).duplicate() as StandardMaterial3D
	page_mat.vertex_color_use_as_albedo = true
	page_mesh.material_override = page_mat
	_books_at.add_child(page_mesh)


func _append_box(st: SurfaceTool, size: Vector3, centre: Vector3,
		color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, [Vector3(h.x,-h.y,-h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z)]],
		[Vector3.LEFT, [Vector3(-h.x,-h.y,h.z), Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z)]],
		[Vector3.UP, [Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z), Vector3(-h.x,h.y,h.z)]],
		[Vector3.DOWN, [Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z), Vector3(-h.x,-h.y,-h.z)]],
		[Vector3.FORWARD, [Vector3(h.x,-h.y,h.z), Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z)]],
		[Vector3.BACK, [Vector3(-h.x,-h.y,-h.z), Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z)]],
	]
	for face in faces:
		var points: Array = face[1]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(face[0])
			st.set_color(color)
			st.set_uv(Vector2(float(index == 1 or index == 2), float(index >= 2)))
			st.add_vertex(points[index] + centre)


func _process(delta: float) -> void:
	if case_style != "sectional" or is_equal_approx(_door_open, _door_target):
		return
	_door_open = move_toward(_door_open, _door_target, delta * 2.2)
	_apply_doors()


func _apply_doors() -> void:
	for i in _doors.size():
		# A Globe-Wernicke sash first lifts, then disappears into the pocket
		# above its section. It never swings through the player's knees.
		_doors[i].position = Vector3(0, _door_open * 0.27,
				-_door_open * 0.045)


func interact_prompt() -> String:
	if sorter.is_tidy():
		return "[E]  %s's books  —  in order" % owner_name.split(" ")[0]
	return "[E]  %s's books  —  wants tidying" % owner_name.split(" ")[0]


func interact(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _tap:
		_tap.play()
	if case_style == "sectional":
		_door_target = 1.0
	var script: GDScript = load("res://scripts/ui/bookshelf_panel.gd")
	_panel = script.new()
	_panel.open(player, self)
	get_tree().current_scene.add_child(_panel)


func panel_closed() -> void:
	_panel = null
	_door_target = 0.0
	rebuild_books()


func inspection_state() -> Dictionary:
	var meshes := 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if child is MeshInstance3D and child.mesh != null:
				meshes += 1
	return {
		"style": case_style,
		"mesh_count": meshes,
		"door_count": _doors.size(),
		"active_book_top": _book_y + 0.27,
		"has_canonical_book": canonical_book == "" or
				sorter.order.has(canonical_book),
		"book_mesh_count": _books_at.get_child_count() if _books_at else 0,
	}
