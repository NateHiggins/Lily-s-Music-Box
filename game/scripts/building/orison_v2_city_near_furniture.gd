extends Node3D
## Street furniture on the near city's kerbs (Lily's ruling city_complete_next_20261117): hydrants, mailboxes, police
## call boxes and ash cans from the mid-ground's own stock, and telegraph poles with their wires along the side
## streets. Placed by art/blender/scripts/place_city_near_furniture.py from a kerb survey of the installed streets,
## and accepted spot by spot in the running world (game/tests/v2_near_furniture_probe.gd): nothing within 0.5 m, the
## Orison, bodega and arcade frontage, tram supports and every crossing kept clear. Additive: it edits no installed
## owner and carries no lamp, route, access, shop or save authority. Collision: a simple body per piece.
const DATA := "res://data/orison_v2/exterior/city_near_furniture.json"
const STOCK := "res://assets/props/city_midground.glb"
const POLES := "res://assets/props/city_near_furniture.glb"
## Collision boxes per kind (width, height, depth), as the probe judged them.
const SIGN_FONT := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const SIGN_RANGE := 45.0
const SIZES := {"signpost": Vector3(0.3, 3.6, 0.3), "hydrant": Vector3(0.4, 0.8, 0.4), "mailbox": Vector3(0.5, 1.5, 0.5), "callbox": Vector3(0.4, 1.7, 0.4),
	"ashcan": Vector3(0.6, 0.8, 0.6), "telegraph_pole": Vector3(0.3, 9.0, 0.3)}
## Catalogue finishes these parts name; UV0 is metric, so the catalogue tile scale stands and triplanar is off.
const FINISHES := ["fire_cabinet_enamel", "door_paint", "cast_iron", "zinc_liner", "site_softwood", "iron_neutral",
	"glass_cut", "iron_blackened", "enamel"]
## Beyond this the pieces are too small to read; the wires and poles go a little further.
const VISIBLE_M := 140.0
const WIRES_VISIBLE_M := 220.0

var data: Dictionary = {}
var _materials: Dictionary = {}


static func mount(parent: Node3D) -> Node3D:
	if not FileAccess.file_exists(DATA):
		return null
	var owner_node := new()
	owner_node.name = "CityNearFurniture"
	owner_node.data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	# Schema 1, world frame: items are world positions, written by build_city_near_furniture.py.
	if int(owner_node.data.get("schema", 0)) != 1 or str(owner_node.data.get("frame", "")) != "WORLD":
		push_error("city near furniture: unexpected schema or frame in " + DATA)
		owner_node.free()
		return null
	parent.add_child(owner_node)
	owner_node._build()
	return owner_node


func _build() -> void:
	var stock := _parts(load(STOCK) as PackedScene, "furn_")
	var poles := _parts(load(POLES) as PackedScene, "furn_telegraph_pole")
	for group: Dictionary in data.get("furniture", []):
		var kind := str(group.kind)
		_instance(stock.get(kind, []), group["items"], kind, VISIBLE_M)
	_instance(poles.get("telegraph_pole", []), data.get("poles", []), "telegraph_pole", WIRES_VISIBLE_M)
	var scene := (load(POLES) as PackedScene).instantiate()
	for draw: MeshInstance3D in scene.find_children("near_wires__*", "MeshInstance3D", true, false):
		var wires := MeshInstance3D.new()
		wires.name = "Wires"
		wires.mesh = draw.mesh
		wires.material_override = _finish(str(draw.name).get_slice("__", 1))
		wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wires.visibility_range_end = WIRES_VISIBLE_M
		add_child(wires)
	scene.free()
	_build_signs()
	# The holders only carried meshes into the MultiMeshes; none entered the tree.
	for source: Dictionary in [stock, poles]:
		for kind: String in source:
			for holder: Node in source[kind]:
				holder.free()


## The stock meshes by kind: furn_<kind>__<finish> nodes, one per finish.
func _parts(packed: PackedScene, prefix: String) -> Dictionary:
	var out := {}
	var scene := packed.instantiate()
	for draw: MeshInstance3D in scene.find_children(prefix + "*", "MeshInstance3D", true, false):
		var name_parts := str(draw.name).split("__")
		var kind := name_parts[0].trim_prefix("furn_")
		var holder := MeshInstance3D.new()
		holder.name = str(draw.name)
		holder.mesh = draw.mesh
		holder.set_meta("finish", name_parts[1] if name_parts.size() > 1 else "")
		out.get_or_add(kind, []).append(holder)
	scene.free()
	return out


func _instance(parts: Array, items: Array, kind: String, range_m: float) -> void:
	if parts.is_empty() or items.is_empty():
		return
	for part: MeshInstance3D in parts:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = part.mesh
		multimesh.instance_count = items.size()
		for i in items.size():
			var item: Array = items[i]
			multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(item[3])), Vector3(item[0], item[1], item[2])))
		var draw := MultiMeshInstance3D.new()
		draw.name = "Near_" + str(part.name)
		draw.multimesh = multimesh
		draw.material_override = _finish(str(part.get_meta("finish")))
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind == "telegraph_pole" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visibility_range_end = range_m
		add_child(draw)
	var size: Vector3 = SIZES[kind]
	var body := StaticBody3D.new()
	body.name = "Near_%s_collision" % kind
	body.collision_layer = 1
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = size
	for item: Array in items:
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.transform = Transform3D(Basis(Vector3.UP, float(item[3])), Vector3(item[0], float(item[1]) + size.y * 0.5, item[2]))
		body.add_child(shape)
	add_child(body)


func _finish(key: String) -> Material:
	if not _materials.has(key):
		assert(key in FINISHES, "unmapped near-furniture finish " + key)
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = material
	return _materials[key]


## 1929 corner signs, as the mid-ground letters them (rulings midground_sign_mapping, near_street_names_20261117): two
## dark enamel blades on the post, the new name in white capitals and the old name small beneath, lettered with
## Label3D on both faces (no lettering in textures, RUL-008).
func _build_signs() -> void:
	var enamel := _finish("enamel").duplicate() as StandardMaterial3D
	enamel.albedo_color = Color(0.07, 0.1, 0.2)
	for sign: Dictionary in data.get("signs", []):
		var at := Vector3(sign.x, sign.y, sign.z)
		_sign_blade(at + Vector3(0, 3.22, 0), 0.0, sign.avenue, enamel)
		_sign_blade(at + Vector3(0, 2.92, 0), PI * 0.5, sign.street, enamel)


func _sign_blade(at: Vector3, yaw: float, names: Array, material: Material) -> void:
	var blade := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.24, 0.025)
	blade.mesh = box
	blade.material_override = material
	blade.position = at
	blade.rotation.y = yaw
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade.visibility_range_end = SIGN_RANGE
	add_child(blade)
	for face: float in [0.0, PI]:
		var lines: Array = [[str(names[0]), 0.035, 0.0013, 52], [str(names[1]), -0.07, 0.0008, 40]]
		for line: Array in lines:
			if str(line[0]).is_empty():
				continue
			var label := Label3D.new()
			label.text = str(line[0])
			label.font = SIGN_FONT
			label.font_size = int(line[3])
			label.pixel_size = float(line[2])
			label.modulate = Color(0.96, 0.95, 0.9)
			label.outline_size = 0
			label.double_sided = false
			label.position = Vector3(0, float(line[1]) + (0.03 if str(names[1]).is_empty() else 0.0), 0.014)
			label.visibility_range_end = SIGN_RANGE
			var holder := Node3D.new()
			holder.rotation.y = face
			holder.add_child(label)
			blade.add_child(holder)
