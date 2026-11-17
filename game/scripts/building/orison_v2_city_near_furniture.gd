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
const SIZES := {"hydrant": Vector3(0.4, 0.8, 0.4), "mailbox": Vector3(0.5, 1.5, 0.5), "callbox": Vector3(0.4, 1.7, 0.4),
	"ashcan": Vector3(0.6, 0.8, 0.6), "telegraph_pole": Vector3(0.3, 9.0, 0.3)}
## Catalogue finishes these parts name; UV0 is metric, so the catalogue tile scale stands and triplanar is off.
const FINISHES := ["fire_cabinet_enamel", "door_paint", "cast_iron", "zinc_liner", "site_softwood", "iron_neutral",
	"glass_cut", "iron_blackened"]
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
