extends RefCounted
const Projector := preload("res://scripts/building/orison_v2_projector_prop.gd")
const PATH := "res://data/orison_v2/domestic_projectors.json"
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source, adapter): return false
	for record: Dictionary in source.projectors:
		var prop := Projector.new()
		prop.setup_v2(str(record.unit),str(record.reel))
		prop.name = str(record.id)
		prop.position = Vector3(record.position[0],record.position[1],record.position[2])
		prop.rotation.y = float(record.yaw)
		adapter.resolve(str(record.support)).add_child(prop)
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("projectors") is not Array or source.projectors.size() != 3:
		errors.append("incomplete apartment projector source")
		return false
	var seen: Dictionary = {}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/video/clips/clips.json"))
	var clips: Array[String] = []
	for clip: Dictionary in manifest.get("clips", []): clips.append(str(clip.get("id", "")))
	for record: Variant in source.projectors:
		if record is not Dictionary or record.get("unit") not in ["2A", "3B", "4B"]:
			errors.append("invalid projector household")
			continue
		var unit_id := str(record.unit)
		if seen.has(unit_id) or record.get("id") != unit_id + "_tv" \
				or record.get("support") != unit_id + "_projector_stand":
			errors.append("invalid or duplicate projector identity/support")
		seen[unit_id] = true
		if adapter == null or not adapter.resolve(str(record.get("support", ""))) is StaticBody3D \
				or adapter.resolve(str(record.get("id", ""))) != null:
			errors.append("missing stand or duplicate projector")
		var at: Variant = record.get("position")
		if at is not Array or at.size() != 3:
			errors.append("invalid projector position")
		else:
			for i in 3:
				if typeof(at[i]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(at[i])) \
						or not is_equal_approx(float(at[i]), .745 if i == 1 else 0.0):
					errors.append("projector must rest on its validated stand")
		if typeof(record.get("yaw")) not in [TYPE_FLOAT,TYPE_INT] or record.yaw != 0:
			errors.append("projector must face its validated throw")
		var clip_id: Variant = record.get("reel")
		if clip_id is not String or clip_id not in clips or not clip_id.is_valid_filename() \
				or not ResourceLoader.exists("res://assets/video/clips/%s.ogv" % clip_id):
			errors.append("projector reel is absent from the installed library")
	return errors.is_empty()
