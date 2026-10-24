extends RefCounted
## Bounded world-owned cache of immutable passive collision resources.
## Scene nodes, imported meshes and transaction surfaces still retire normally.
## Retaining collision acceleration trades bounded CPU memory for reload latency.
const MAX_FACE_BYTES := 96*1024*1024
var max_face_bytes := MAX_FACE_BYTES
var paths: Dictionary = {}
var shapes: Dictionary = {}
var seed_ms := 0.0
var cache_bytes := 0
var _connections: Dictionary = {}

static func _invalidate(reference: WeakRef, key: String) -> void:
	var owner: RefCounted=reference.get_ref()
	if owner!=null and owner.paths.has(key): owner.paths[key]["shape_rid"]=0

static func mesh_signature(mesh: Mesh) -> String:
	if mesh is not ArrayMesh or mesh.get_blend_shape_count()!=0: return ""
	return surfaces_signature(mesh.get("_surfaces"))

static func surfaces_signature(surfaces: Array) -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	for surface: Dictionary in surfaces:
		for key: String in ["format","primitive","vertex_count","index_count","aabb"]:
			digest.update(var_to_bytes(surface.get(key)))
		for key: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shape_data"]:
			var bytes: Variant=surface.get(key)
			# Hash the same complete buffers without serializing/copying tens of
			# megabytes into a temporary Variant encoding on every reconstruction.
			if bytes is PackedByteArray:
				digest.update(var_to_bytes([key,bytes.size()]))
				if not bytes.is_empty():digest.update(bytes)
			else:digest.update(var_to_bytes([key,bytes]))
	return digest.finish().hex_encode()

static func face_signature(shape: ConcavePolygonShape3D) -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	digest.update(shape.get_faces().to_byte_array())
	return digest.finish().hex_encode()

class SignatureJob extends RefCounted:
	## Identical complete SHA256 byte stream, bounded PackedByteArray updates.
	## Only cooperative callers use this; the original synchronous API stays intact.
	const CHUNK_BYTES := 256*1024
	const HEADERS := ["format","primitive","vertex_count","index_count","aabb"]
	const BUFFERS := ["vertex_data","attribute_data","skin_data","index_data","blend_shape_data"]
	var done := false
	var result := ""
	var largest_buffer_update := 0
	var buffer_updates := 0
	var _surfaces: Array
	var _digest := HashingContext.new()
	var _surface := 0
	var _field := 0
	var _buffer: PackedByteArray
	var _offset := 0
	var _buffer_active := false

	func _init(surfaces: Array) -> void:
		# Freeze dictionary/header values; packed buffers retain copy-on-write storage.
		_surfaces=surfaces.duplicate(true)
		_digest.start(HashingContext.HASH_SHA256)

	func advance(budget_usec: int) -> void:
		if done:return
		var started:=Time.get_ticks_usec()
		while not done:
			_step()
			if budget_usec>0 and Time.get_ticks_usec()-started>=budget_usec:return

	func copy_surfaces() -> Array:
		# The local mesh copy receives exactly the frozen bytes that were hashed.
		return _surfaces if done else []

	func _step() -> void:
		if _buffer_active:
			var end:=mini(_offset+CHUNK_BYTES,_buffer.size())
			if end>_offset:
				_digest.update(_buffer.slice(_offset,end))
				largest_buffer_update=maxi(largest_buffer_update,end-_offset)
				buffer_updates+=1
			_offset=end
			if _offset>=_buffer.size():
				_buffer=PackedByteArray();_buffer_active=false;_field+=1
			return
		if _surface>=_surfaces.size():
			result=_digest.finish().hex_encode();done=true
			return
		var surface: Dictionary=_surfaces[_surface]
		if _field<HEADERS.size():
			_digest.update(var_to_bytes(surface.get(HEADERS[_field])));_field+=1
		elif _field<HEADERS.size()+BUFFERS.size():
			var key: String=BUFFERS[_field-HEADERS.size()]
			var bytes: Variant=surface.get(key)
			if bytes is PackedByteArray:
				_digest.update(var_to_bytes([key,bytes.size()]))
				_buffer=bytes;_offset=0;_buffer_active=true
			else:
				_digest.update(var_to_bytes([key,bytes]));_field+=1
		else:
			_surface+=1;_field=0

func seed(cells: Dictionary) -> bool:
	var started := Time.get_ticks_usec()
	for cell: Node3D in cells.values():
		for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
			var key := str(draw.get_meta("native_collision_key",""))
			if key.is_empty() or paths.has(key): continue
			var collisions := draw.find_children("*","CollisionShape3D",true,false)
			if collisions.size()!=1 or collisions[0].shape is not ConcavePolygonShape3D: dispose();return false
			var shape:=collisions[0].shape as ConcavePolygonShape3D
			cache_bytes+=shape.get_faces().size()*12
			if cache_bytes>max_face_bytes: dispose();return false
			var signature:=mesh_signature(draw.mesh)
			if signature.is_empty(): dispose();return false
			paths[key]={"mesh_hash":signature,"face_hash":face_signature(shape),"shape_rid":shape.get_rid().get_id()}
			shapes[key]=shape
			var callback:=_invalidate.bind(weakref(self),key)
			shape.changed.connect(callback)
			_connections[key]=callback
	seed_ms=float(Time.get_ticks_usec()-started)/1000.0
	return not paths.is_empty()

func dispose() -> void:
	for key: String in _connections:
		var shape: ConcavePolygonShape3D=shapes.get(key)
		if shape!=null and shape.changed.is_connected(_connections[key]): shape.changed.disconnect(_connections[key])
	_connections.clear()
	paths.clear()
	shapes.clear()
	cache_bytes=0
