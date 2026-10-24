extends Node3D
## The retained pavement works and eastern expansion dogleg share
## the same normalized front-door frame as the street and Passage.
const Detail := preload("res://scripts/building/v2_street_end_details.gd")
const SOURCE := "res://data/orison_v2/exterior/construction_shed.json"
const NATIVE := "res://assets/props/construction_shed.glb"
const NATIVE_ORIGIN := Vector3(22.25,0,0)
var detail: ExteriorDetailPass
var startup_failed:=false
var _programmes: Variant

func configure(programmes: Variant) -> bool:
	if is_inside_tree() or programmes==null:return false
	_programmes=programmes
	return true

static func valid_source_header(source: Variant) -> bool:
	if source is not Dictionary: return false
	var version: Variant = source.get("schema_version")
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and float(version) == 1.0 \
			and source.get("frame") == "ORISON_FRONT_DOOR_THRESHOLD" \
			and source.get("boxes") is Array and source.get("lights") is Array

func _ready() -> void:
	if _programmes==null:_programmes=preload("res://scripts/building/orison_v2_public_region_programmes.gd").load_default()
	if _programmes==null:startup_failed=true;push_error("Construction public programme is invalid");return
	var registered: Transform3D=_programmes.body_transform("StreetBoundaries")
	if not registered.origin.is_finite():startup_failed=true;push_error("Construction frame is invalid");return
	transform=registered
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not valid_source_header(source):
		push_error("Street boundaries require the supported front-door source frame")
		return
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	if section.is_empty():
		push_error("Invalid street coordinate frame")
		return
	detail = Detail.new()
	detail.name = "RetainedStreetEnds"
	detail.position.z = -float(section.source_threshold_z)
	add_child(detail)
	detail.build_boundaries_only(detail, true)
	_mount_native_stock()
	for record: Dictionary in source.boxes:
		# The native recipe replaces quartered oak with raw site timber, while
		# the notice retains paper. A source-stock change requires a new native
		# recipe/export; silently binding the old wood to masonry is invalid.
		var expected_stock := "paper" if str(record.id)=="ClosureNoticeBoard" else "oak_quartered"
		assert(str(record.material)==expected_stock,"Construction source stock requires a matching native recipe: "+str(record.id))
		var body := StaticBody3D.new()
		body.name = record.id
		body.position = Vector3(record.center[0], record.center[1], record.center[2])
		body.rotation_degrees.z = float(record.get("roll_degrees", 0.0))
		var size := Vector3(record.size[0], record.size[1], record.size[2])
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		if record.id == "ShedTemporaryClosure":
			_mount_closure_notice(body, size.z)
	for record: Dictionary in source.lights:
		var light := LightFixtureProp.new()
		light.prop_type = "cage_bulb"
		light.name = record.id
		light.position = Vector3(record.center[0], record.center[1], record.center[2])
		light.range_clamp = 5.0
		light.energy_scale = 0.65
		light.navigation_light = true
		light.standby_scale = 0.35
		add_child(light)

func _mount_native_stock() -> void:
	# Visual stock has metre UVs and real lapped joints. Existing source boxes
	# remain the collision authority; no imported mesh collision is generated.
	var model := (load(NATIVE) as PackedScene).instantiate() as Node3D
	model.name="NativeConstructionStock"
	model.position=NATIVE_ORIGIN
	var finishes := {}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			var imported := draw.get_active_material(surface)
			assert(imported!=null and imported.resource_name.begins_with("CATALOG_"),"Construction stock requires a catalogue partition")
			var key := imported.resource_name.trim_prefix("CATALOG_")
			assert(MatLib.SETS.has(key),"Unknown construction finish: "+key)
			if not finishes.has(key):
				var stock := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				stock.uv1_triplanar=false;stock.uv2_triplanar=false
				stock.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if key.begins_with("site_softwood"):
					stock.texture_repeat=false
					stock.uv1_scale=Vector3.ONE
				stock.set_meta("v2_surface_stock",key)
				finishes[key]=stock
			draw.set_surface_override_material(surface,finishes[key])
	add_child(model)

func _mount_closure_notice(closure: StaticBody3D, depth: float) -> void:
	# Lettering belongs to the collision-bearing panel, including relocation
	# and rotation. Keep the existing 45 mm clearance from its front face.
	var notice := Label3D.new()
	notice.name = "ContractorClosureNotice"
	notice.text = "SIDEWALK CLOSED\nWORK IN PROGRESS"
	notice.position = Vector3(0, 0.35, depth * 0.5 + 0.045)
	notice.font_size = 40
	notice.pixel_size = 0.0015
	notice.modulate = Color(0.1, 0.08, 0.05)
	notice.outline_size = 0
	notice.no_depth_test = false
	closure.add_child(notice)
