class_name SwcFormats
extends RefCounted

## Readers for the engine-independent package formats.
##
## The counterpart of shared/swcformats/ on the Python side. Format parity between
## the two implementations is covered by tests/test_format_parity.py plus the
## headless conformance check in runtime/tools/verify_runtime.gd.
##
## Everything here is plain deserialisation. No geometry is invented at load time:
## a World Package contains baked assets, and the whole point of compiling offline
## is that runtime does conventional work.

const MESH_FORMAT := "swcmesh/1"
const MATERIAL_FORMAT := "swcmat/1"


static func read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SwcFormats: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return ""
	var text := file.get_as_text()
	file.close()
	return text


static func read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SwcFormats: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return PackedByteArray()
	var data := file.get_buffer(file.get_length())
	file.close()
	return data


static func read_json(path: String) -> Variant:
	return parse_json_bytes(read_bytes(path), path)


static func parse_json_bytes(data: PackedByteArray, label: String = "") -> Variant:
	if data.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	if parsed == null:
		push_error("SwcFormats: %s is not valid JSON" % label)
	return parsed


## swcmesh/1 -> {mesh: ArrayMesh, slots: Array[String], attachments: Dictionary}
static func load_mesh(path: String) -> Dictionary:
	return parse_mesh(read_bytes(path), path)


static func parse_mesh(data: PackedByteArray, label: String = "") -> Dictionary:
	var path := label
	var doc: Variant = parse_json_bytes(data, label)
	if typeof(doc) != TYPE_DICTIONARY:
		return {}
	if doc.get("format", "") != MESH_FORMAT:
		push_error("SwcFormats: %s has unsupported mesh format '%s'" % [path, doc.get("format", "")])
		return {}

	var mesh := ArrayMesh.new()
	var slots: Array[String] = []

	for surface_variant in doc.get("surfaces", []):
		var surface: Dictionary = surface_variant
		var positions: Array = surface.get("positions", [])
		var indices: Array = surface.get("indices", [])
		if positions.is_empty() or indices.is_empty():
			continue

		var vertex_count := positions.size() / 3
		var vertices := PackedVector3Array()
		vertices.resize(vertex_count)
		for i in range(vertex_count):
			vertices[i] = Vector3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2])

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices

		var normal_source: Array = surface.get("normals", [])
		if normal_source.size() == positions.size():
			var normals := PackedVector3Array()
			normals.resize(vertex_count)
			for i in range(vertex_count):
				normals[i] = Vector3(
					normal_source[i * 3], normal_source[i * 3 + 1], normal_source[i * 3 + 2]
				)
			arrays[Mesh.ARRAY_NORMAL] = normals

		var uv_source: Array = surface.get("uvs", [])
		if uv_source.size() == vertex_count * 2:
			var uvs := PackedVector2Array()
			uvs.resize(vertex_count)
			for i in range(vertex_count):
				uvs[i] = Vector2(uv_source[i * 2], uv_source[i * 2 + 1])
			arrays[Mesh.ARRAY_TEX_UV] = uvs

		# swcmesh/1 winds front faces counter-clockwise (the glTF/OpenGL
		# convention). Godot wants clockwise, so each triangle is reversed here.
		# The engine quirk stays inside the engine; the format stays neutral.
		var packed_indices := PackedInt32Array()
		packed_indices.resize(indices.size())
		var triangle_count := indices.size() / 3
		for t in range(triangle_count):
			packed_indices[t * 3] = int(indices[t * 3])
			packed_indices[t * 3 + 1] = int(indices[t * 3 + 2])
			packed_indices[t * 3 + 2] = int(indices[t * 3 + 1])
		arrays[Mesh.ARRAY_INDEX] = packed_indices

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		slots.append(String(surface.get("material_slot", "main")))

	var attachments := {}
	for point_variant in doc.get("attachment_points", []):
		var point: Dictionary = point_variant
		var position: Array = point.get("position", [0, 0, 0])
		attachments[String(point.get("name", ""))] = Vector3(position[0], position[1], position[2])

	return {"mesh": mesh, "slots": slots, "attachments": attachments}


## swcmat/1 -> StandardMaterial3D, with its albedo texture resolved relative to
## the package root.
static func load_material(path: String, package_root: String) -> StandardMaterial3D:
	return parse_material(read_bytes(path), path, func(rel: String) -> PackedByteArray:
		return read_bytes(package_root.path_join(rel))
	)


## `texture_reader` resolves a package-relative texture path to bytes, so the
## material parser never needs to know whether it is reading a folder or an archive.
static func parse_material(
	data: PackedByteArray, label: String, texture_reader: Callable
) -> StandardMaterial3D:
	var path := label
	var doc: Variant = parse_json_bytes(data, label)
	if typeof(doc) != TYPE_DICTIONARY:
		return null
	if doc.get("format", "") != MATERIAL_FORMAT:
		push_error("SwcFormats: %s has unsupported material format" % path)
		return null

	var material := StandardMaterial3D.new()
	material.resource_name = String(doc.get("name", "material"))

	var base: Array = doc.get("base_color", [0.8, 0.8, 0.8])
	material.albedo_color = Color(base[0], base[1], base[2], float(doc.get("alpha", 1.0)))
	material.roughness = float(doc.get("roughness", 0.7))
	material.metallic = float(doc.get("metallic", 0.0))

	var emission_strength := float(doc.get("emission_strength", 0.0))
	if emission_strength > 0.0:
		var emission: Array = doc.get("emission_color", [0, 0, 0])
		material.emission_enabled = true
		material.emission = Color(emission[0], emission[1], emission[2])
		material.emission_energy_multiplier = emission_strength

	var uv_scale := float(doc.get("uv_scale", 1.0))
	material.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)

	if String(doc.get("blend_mode", "opaque")) == "alpha":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match String(doc.get("cull_mode", "back")):
		"front":
			material.cull_mode = BaseMaterial3D.CULL_FRONT
		"disabled":
			material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var textures: Dictionary = doc.get("textures", {})
	if textures.has("albedo"):
		var texture := parse_texture(texture_reader.call(String(textures["albedo"])))
		if texture != null:
			material.albedo_texture = texture

	return material


static func load_texture(path: String) -> ImageTexture:
	return parse_texture(read_bytes(path))


static func parse_texture(data: PackedByteArray) -> ImageTexture:
	if data.is_empty():
		return null
	var image := Image.new()
	# Decoded from a buffer rather than by path: it behaves identically in an
	# exported build, where the package lives outside the project directory.
	if image.load_png_from_buffer(data) != OK:
		push_error("SwcFormats: texture is not a readable PNG")
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## 16-bit PCM WAV -> AudioStreamWAV. Parsed by hand so the runtime does not depend
## on the editor's import pipeline for files that only exist at runtime.
static func load_wav(path: String, loop: bool = false) -> AudioStreamWAV:
	return parse_wav(read_bytes(path), loop, path)


static func parse_wav(
	data: PackedByteArray, loop: bool = false, path: String = ""
) -> AudioStreamWAV:
	if data.size() < 44:
		return null
	if data.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_error("SwcFormats: %s is not a RIFF file" % path)
		return null
	if data.slice(8, 12).get_string_from_ascii() != "WAVE":
		push_error("SwcFormats: %s is not a WAVE file" % path)
		return null

	var position := 12
	var mix_rate := 22050
	var channels := 1
	var bits := 16
	var samples := PackedByteArray()

	while position + 8 <= data.size():
		var chunk_id := data.slice(position, position + 4).get_string_from_ascii()
		var size := int(data.decode_u32(position + 4))
		var body_start := position + 8
		if chunk_id == "fmt " and size >= 16:
			channels = data.decode_u16(body_start + 2)
			mix_rate = int(data.decode_u32(body_start + 4))
			bits = data.decode_u16(body_start + 14)
		elif chunk_id == "data":
			samples = data.slice(body_start, min(body_start + size, data.size()))
		position = body_start + size + (size % 2)

	if samples.is_empty() or bits != 16:
		push_error("SwcFormats: %s is not 16-bit PCM with a data chunk" % path)
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = channels >= 2
	stream.data = samples
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size() / (2 * channels)
	return stream


static func color_from_hex(value: String, fallback: Color = Color.WHITE) -> Color:
	if value.length() == 7 and value.begins_with("#"):
		return Color.from_string(value, fallback)
	return fallback
