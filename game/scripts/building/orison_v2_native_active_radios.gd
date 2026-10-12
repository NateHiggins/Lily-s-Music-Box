extends RefCounted
## Immutable native stock shared by the eighteen original receiver actors.
const PATH := "res://data/orison_v2/active_household_radios.json"
var families: Dictionary = {}
var speakers: Dictionary = {}
var errors: Array[String] = []
var _materials: Dictionary = {}
var _finishes: Dictionary = {}

func prepare() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1: return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("active receiver stock absent"); return false
	var model := packed.instantiate()
	for family: Dictionary in data.families:
		families[str(family.id)] = _parts(model, family.parts)
	for speaker: Dictionary in data.speakers:
		speakers[str(speaker.id)] = _parts(model, speaker.parts)
	model.free()
	return errors.is_empty()

func _parts(model: Node, rows: Array) -> Array:
	var result: Array = []
	for row: Dictionary in rows:
		var draw := model.find_child(str(row.name), true, false) as MeshInstance3D
		if draw == null: errors.append("receiver part missing: " + str(row.name)); continue
		var key := str(row.material)
		if not _materials.has(key):
			if key == "glassish":
				_materials[key] = preload("res://scripts/building/orison_v2_architectural_materials.gd").new().material_for("Glazing", "domestic")
			elif MatLib.SETS.has(key):
				var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				mat.uv1_triplanar = false; mat.normal_scale = .08
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				_materials[key] = mat
			else: errors.append("unregistered receiver finish: " + key); continue
		result.append({"name":str(row.name),"component":str(row.component),"key":key,"mesh":draw.mesh,"pose":draw.transform,"material":_materials[key]})
	return result

func mount_on(radio: DomesticRadioProp) -> bool:
	if not families.has(radio.family): return false
	var rows: Array = families[radio.family].duplicate()
	var kind := str(radio.radio_profile.get("speaker", ""))
	var condition := str(radio.radio_profile.get("condition", ""))
	for key: String in speakers:
		if kind.contains(key): rows.append_array(speakers[key])
	if rows.is_empty(): return false
	# Only visuals are retired. Keep the original tuning Node3D, emitter,
	# interaction/event owner and any original nonvisual child containers.
	for child: Node in radio.find_children("*", "MeshInstance3D", true, false):
		child.get_parent().remove_child(child); child.free()
	for row: Dictionary in rows:
		if row.component == "Back" and condition == "back_removed": continue
		if row.component == "Cover" and condition == "alignment_open": continue
		if row.component == "Repair" and condition != "speaker_cloth_repaired": continue
		if row.component == "Tag" and condition not in ["inventory_numbered", "provenance_tagged"]: continue
		var parent: Node3D = radio
		if row.component == "Tuning":
			if radio._tuning_knob == null: errors.append("original tuning pivot missing"); return false
			parent = radio._tuning_knob
		var draw := MeshInstance3D.new(); draw.name = row.name
		draw.mesh = row.mesh; draw.material_override = _finish(row, radio)
		parent.add_child(draw)
		draw.transform = row.pose if parent == radio else parent.transform.affine_inverse() * row.pose
		draw.set_meta("native_active_radio_part", row.name)
	radio.set_meta("v2_native_active_receiver", radio.family)
	if condition in ["inventory_numbered", "provenance_tagged"]:
		var label := Label3D.new(); label.name = "SourceInventoryLabel"
		label.text = radio.unit if condition == "inventory_numbered" else "MARCONIPHONE V2"
		label.font_size = 18; label.pixel_size = .00035; label.outline_size = 0
		label.modulate = Color(.10,.08,.06); label.rotation.y = PI
		label.position = Vector3(0,.014,-.0706) if condition == "inventory_numbered" else Vector3(.07,.015,-.1502)
		radio.add_child(label)
	return true

func _finish(row: Dictionary, radio: DomesticRadioProp) -> Material:
	if row.material is ShaderMaterial: return row.material
	var finish := str(radio.radio_profile.get("finish", ""))
	var condition := str(radio.radio_profile.get("condition", ""))
	var id := str(row.key) + "/" + finish + "/" + condition
	if not _finishes.has(id):
		var mat := row.material.duplicate() as StandardMaterial3D
		if row.key == "enamel_appliance" and radio.family == "atwater_kent_44": mat.albedo_color = Color(.14,.15,.15)
		if row.key == "wood_dark":
			if "mahogany" in finish: mat.albedo_color = Color(.65,.48,.40)
			if finish == "dark_mahogany": mat.albedo_color = Color(.48,.39,.34)
			if condition in ["immaculate", "performance_ready", "dial_polished"]: mat.roughness = .34
		if row.key == "leather_worn": mat.albedo_color = Color(.38,.28,.21)
		if row.key == "linen": mat.albedo_color = Color(.40,.32,.23)
		_finishes[id] = mat
	return _finishes[id]
