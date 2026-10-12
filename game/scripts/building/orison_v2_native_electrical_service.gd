extends RefCounted
## Fixed conductor enclosure fabric; FusePanelProp retains all circuit authority.
const PATH := "res://data/orison_v2/electrical_service.json"
var errors: Array[String] = []
var meshes: Dictionary = {}
var stations: Dictionary = {}
var installed: Array[MeshInstance3D] = []
var bearings: Array[Vector3] = []
var data: Dictionary
var _root: Node3D
var _scale_stock := preload("res://scripts/building/orison_v2_native_fire_service.gd").new()
const WALL_BASIS := Basis(Vector3.UP,-PI*.5)

func mount(adapter: RefCounted) -> bool:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1: return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("missing electrical native stock"); return false
	var model := packed.instantiate()
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count():
			var key := str(mesh.surface_get_material(i).resource_name)
			if not MatLib.SETS.has(key): errors.append("electrical finish " + key); continue
			var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			mat.uv1_triplanar = false; mat.uv1_scale = Vector3.ONE / .65
			mat.normal_scale = .15; mat.metallic = .75
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if key == "iron_neutral": mat.albedo_color = Color(.35,.37,.39)
			if key == "brass_dull":
				mat.metallic = .65
				mat.albedo_texture = load("res://assets/building/textures/mailbank/T_mailbank_brass_albedo.png")
				mat.roughness_texture = load("res://assets/building/textures/mailbank/T_mailbank_brass_rough.png")
			mesh.surface_set_material(i,mat)
		meshes[str(node.name)] = mesh
	model.free()
	if meshes.size() != 12 or not errors.is_empty(): return false
	var reservation := adapter.root.find_child(str(data.riser),true,false) as MeshInstance3D
	if reservation == null: errors.append("electrical reservation missing"); return false
	reservation.mesh = null
	_root = Node3D.new(); _root.name = "NativeElectricalService"; adapter.root.add_child(_root)
	var low := float(data.from_y)
	for row: Dictionary in data.stations:
		var y := float(row.y)
		_segment(low,y-.12); low = y+.12
		var at := Vector3(data.axis[0],y,data.axis[1])
		var owner := Node3D.new(); owner.name = str(row.id); _root.add_child(owner)
		owner.transform = Transform3D(WALL_BASIS,at); stations[str(row.id)] = weakref(owner)
		for key: String in ["JunctionCasting","JunctionCover","CoverScrews","EntryBushUpper","EntryBushLower"]:
			_draw(key,owner,Vector3.ZERO,Basis.IDENTITY)
		# Physical fixed enclosure; no new interactive areas or circuit state.
		var body := StaticBody3D.new(); owner.add_child(body)
		var collider := CollisionShape3D.new(); var box := BoxShape3D.new()
		box.size = Vector3(.16,.24,.079); collider.shape = box; body.add_child(collider)
		for h: float in [y-1.50,y+.80]:
			var bearing := Vector3(data.axis[0],h,data.axis[1]); bearings.append(bearing)
			_draw("WallSaddle",_root,bearing); _draw("SaddleScrews",_root,bearing)
			_draw("ThreadedCoupling",_root,bearing+Vector3.UP*.1)
	_segment(low,float(data.to_y))
	for y: float in [float(data.from_y)-.004,float(data.to_y)+.004]:
		_draw("ConduitCap",_root,Vector3(data.axis[0],y,data.axis[1]))
	for y: float in data.slab_centres:
		_draw("FloorSleeve",_root,Vector3(data.axis[0],y,data.axis[1]))
		for offset: float in [-.102,.102]:
			_draw("FloorEscutcheon",_root,Vector3(data.axis[0],y+offset,data.axis[1]))
	return errors.is_empty()

func _draw(key: String,parent: Node3D,at: Vector3,basis: Basis = WALL_BASIS) -> MeshInstance3D:
	var draw := MeshInstance3D.new(); draw.name = key; draw.mesh = meshes[key]
	parent.add_child(draw); draw.transform = Transform3D(basis,at)
	draw.set_meta("native_electrical_part",key); installed.append(draw); return draw

func _segment(low: float,high: float) -> void:
	if high <= low: errors.append("electrical span reversed"); return
	if data.has("feed_tee_y"):
		var y := float(data.feed_tee_y)
		if y > low+.055 and y < high-.055:
			_segment(low,y-.055); _segment(y+.055,high); return
	var draw := _draw("ConduitUnit",_root,Vector3(data.axis[0],(low+high)*.5,data.axis[1]))
	draw.mesh = _scale_stock._length_mesh(meshes.ConduitUnit,high-low)
	var body := StaticBody3D.new(); draw.add_child(body)
	var collider := CollisionShape3D.new(); var shape := CylinderShape3D.new()
	shape.radius = .0225; shape.height = high-low; collider.shape = shape; body.add_child(collider)
