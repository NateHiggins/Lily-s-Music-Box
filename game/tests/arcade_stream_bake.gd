extends Node
## Lane entry point. Bake the verified detached geometry before actor publication.
const Host := preload("res://scripts/building/orison_v2_passage_region.gd")
const Bundle := preload("res://scripts/building/orison_v2_arcade_runtime_bundle.gd")
const Manifest := preload("res://scripts/building/orison_v2_arcade_bake_manifest.gd")
const Service := preload("res://scripts/game/v2_maintenance_shop_service.gd")
const TARGET_NODES := 150
const TARGET_GEOMETRY_BYTES := 18 * 1024 * 1024
const SPLIT_CELLS := ["shop_hardware_paint","shop_funeral_parlour","shop_otis_son","shop_radio_service"]

var _directory: String
var _cell: Node3D
var _pieces: Array[Dictionary]
var _costs: Dictionary[Node, Vector2i] = {}
var _error := ""

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_directory = OS.get_environment("ORISON_ARCADE_BAKE_DIR")
	if _directory.is_empty() or not _directory.is_absolute_path() \
		or DirAccess.dir_exists_absolute(_directory):
		_finish("An unused absolute bake directory is required")
		return
	var before := Manifest.source_digests()
	if before.is_empty() or DirAccess.make_dir_recursive_absolute(_directory) != OK:
		_finish("Bake inputs unavailable or output directory could not be created")
		return
	var host := Host.new()
	var service := Service.new()
	var root: Node3D
	if host.configure(service) and host.configure_prepared(Bundle.load_prepared()):
		var builder: RefCounted = host.begin_prepared_geometry()
		if builder != null:
			var result: Error = builder.advance_build()
			while result == ERR_BUSY: result = builder.advance_build()
			if result == OK: root = builder.take_build()
	host.free()
	service.free()
	if root == null:
		_finish("Source-bound detached arcade assembly refused")
		return
	var cells := {}
	for cell: Node3D in root.get_children():
		_cell = cell
		_pieces = [{}]
		_costs.clear()
		var cost := _measure(cell)
		if cost.y > TARGET_GEOMETRY_BYTES or str(cell.name) in SPLIT_CELLS:
			_split_children(cell)
		_pieces[0] = _store(cell,0)
		cells[str(cell.name)] = _pieces
	root.free()
	var manifest := {"schema":Manifest.SCHEMA,"sources":before,"cells":cells}
	if not _error.is_empty() or not Manifest.check_shape(manifest, Host.CELLS) \
		or Manifest.source_digests() != before:
		_finish("Bake output or frozen source invalid: " + _error)
		return
	var file := FileAccess.open(_directory.path_join(Manifest.MANIFEST), FileAccess.WRITE)
	if file == null:
		_finish("Could not publish completed bake manifest")
		return
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	_finish("")

## Estimate upload/decode work independently of the compressed scene size.
## Keep scripted or typed subtrees intact even when one exceeds a target.
func _measure(node: Node) -> Vector2i:
	var bytes := 0
	var mesh: ArrayMesh
	if node is MeshInstance3D:
		mesh = node.mesh as ArrayMesh
	elif node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh as ArrayMesh
		bytes += node.multimesh.instance_count * 64
	elif node is CollisionShape3D and node.shape is ConcavePolygonShape3D:
		bytes += node.shape.get_faces().size() * 12
	if mesh != null:
		for surface in mesh.get_surface_count():
			bytes += mesh.surface_get_array_len(surface) * 64 + mesh.surface_get_array_index_len(surface) * 4
	var cost := Vector2i(1, bytes)
	for child: Node in node.get_children():
		cost += _measure(child)
	_costs[node] = cost
	return cost

func _over_target(cost: Vector2i) -> bool:
	return cost.x > TARGET_NODES or cost.y > TARGET_GEOMETRY_BYTES

func _split_children(parent: Node) -> void:
	var children := parent.get_children()
	var batch: Array[Node] = []
	var positions: Array[int] = []
	var batch_cost := Vector2i.ZERO
	for index in children.size():
		var child: Node = children[index]
		var cost := _costs[child]
		var split := _over_target(cost) and child.get_script() == null and child.get_class() == "Node3D"
		if split or _over_target(batch_cost + cost):
			_write_piece(parent,batch,positions)
			batch.clear()
			positions.clear()
			batch_cost = Vector2i.ZERO
		if split:
			_split_children(child)
		else:
			batch.append(child)
			positions.append(index)
			batch_cost += cost
	_write_piece(parent,batch,positions)

func _write_piece(parent: Node, children: Array[Node], positions: Array[int]) -> void:
	if children.is_empty(): return
	var batch := Node3D.new()
	for child in children:
		child.owner = null
		parent.remove_child(child)
		batch.add_child(child)
	var row := _store(batch,_pieces.size())
	row["parent"] = str(_cell.get_path_to(parent))
	row["positions"] = positions.duplicate()
	_pieces.append(row)
	batch.free()

func _store(node: Node3D, index: int) -> Dictionary:
	node.scene_file_path = ""
	for child: Node in node.find_children("*","Node",true,false):
		child.scene_file_path = ""
		child.owner = node
	var scene := PackedScene.new()
	var name := Manifest.filename(str(_cell.name),index)
	var path := _directory.path_join(name)
	if scene.pack(node) != OK or ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS) != OK:
		_error = "Cannot write " + name
		return {}
	return {"file":name,"bytes":FileAccess.get_size(path),"sha256":FileAccess.get_sha256(path)}

func _finish(reason: String) -> void:
	if reason.is_empty():
		print("ARCADE BAKE: completed " + _directory)
	else:
		push_error("ARCADE BAKE: " + reason)
	get_tree().quit(0 if reason.is_empty() else 1)
