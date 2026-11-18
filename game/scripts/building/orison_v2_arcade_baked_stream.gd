extends RefCounted
## Reads a verified bake one piece at a time. Only complete cells leave this owner.
const Manifest := preload("res://scripts/building/orison_v2_arcade_bake_manifest.gd")

var _root: String
var _jobs: Array[Dictionary] = []
var _cursor := 0
var _requested := ""
var _cell: Node3D
var _ready_cell: Node3D

static func open(cell_ids: Array) -> RefCounted:
	var root := Manifest.ROOT
	if OS.has_feature("editor") and not FileAccess.file_exists(root.path_join(Manifest.MANIFEST)):
		root = OS.get_environment("ORISON_ARCADE_BAKE_DIR")
	if root.is_empty() or not FileAccess.file_exists(root.path_join(Manifest.MANIFEST)):
		return null
	var data := Manifest.Bundle.read(root.path_join(Manifest.MANIFEST))
	if not Manifest.check_shape(data,cell_ids): return null
	if root != Manifest.ROOT and data.get("sources") != Manifest.source_digests(): return null
	var stream = load("res://scripts/building/orison_v2_arcade_baked_stream.gd").new()
	stream._root = root
	for cell: String in cell_ids:
		var pieces: Array = data.cells[cell]
		for index in pieces.size():
			var row: Dictionary = pieces[index].duplicate()
			if FileAccess.get_size(root.path_join(str(row.file))) != int(row.bytes):
				return null
			row["cell"] = cell
			row["first"] = index == 0
			row["final"] = index == pieces.size()-1
			stream._jobs.append(row)
	return stream

func rewind() -> void:
	_cursor = 0

func advance() -> Error:
	if _ready_cell != null: return ERR_UNAVAILABLE
	if _cursor == _jobs.size(): return OK
	var row: Dictionary = _jobs[_cursor]
	if _requested.is_empty():
		return _request_piece(row)
	var status := ResourceLoader.load_threaded_get_status(_requested)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return ERR_BUSY
	var packed := ResourceLoader.load_threaded_get(_requested) as PackedScene
	_requested = ""
	if status != ResourceLoader.THREAD_LOAD_LOADED or packed == null: return ERR_INVALID_DATA
	var piece := packed.instantiate() as Node3D
	if piece == null: return ERR_INVALID_DATA
	if row.first:
		if str(piece.name) != str(row.cell):
			piece.free()
			return ERR_INVALID_DATA
		_cell = piece
	else:
		var attached := _attach(piece,row)
		piece.free()
		if not attached: return ERR_INVALID_DATA
	if row.final:
		_ready_cell = _cell
		_cell = null
	_cursor += 1
	if _cursor == _jobs.size(): return OK
	# Keep at most one request outstanding and instantiate one piece per step.
	# The next load can run between this step and the next frame.
	return _request_piece(_jobs[_cursor])

func _request_piece(row: Dictionary) -> Error:
	var path := _root.path_join(str(row.file))
	var result := ResourceLoader.load_threaded_request(path, "PackedScene")
	if result != OK: return result
	_requested = path
	return ERR_BUSY

func _attach(piece: Node3D, row: Dictionary) -> bool:
	var receiver := _cell.get_node_or_null(NodePath(str(row.parent)))
	if receiver == null or piece.get_child_count() != row.positions.size(): return false
	for index in row.positions.size():
		if int(row.positions[index]) > receiver.get_child_count()+index: return false
		if receiver.has_node(NodePath(str(piece.get_child(index).name))): return false
	for position: Variant in row.positions:
		var child := piece.get_child(0)
		child.owner = null
		piece.remove_child(child)
		receiver.add_child(child)
		receiver.move_child(child,int(position))
	return true

func take_cell() -> Node3D:
	var cell := _ready_cell
	_ready_cell = null
	return cell

## Cancellation drains just the one issued request. Queued pieces never load.
func close(wait: bool) -> bool:
	if _cell != null:
		_cell.free()
		_cell = null
	if _ready_cell != null:
		_ready_cell.free()
		_ready_cell = null
	if not _requested.is_empty():
		if not wait and ResourceLoader.load_threaded_get_status(_requested) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
		ResourceLoader.load_threaded_get(_requested)
		_requested = ""
	return true
