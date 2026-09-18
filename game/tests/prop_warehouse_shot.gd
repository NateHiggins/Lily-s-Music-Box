extends Node3D
## Every prop in the inspection shed, photographed one specimen at a time.
##
##     SHOT_DIR=<abs Windows path, must exist> godot --path game --audio-driver Dummy \
##         res://tests/PropWarehouseShot.tscn
##
## The warehouse (prop_warehouse.gd) already puts one of everything on a
## labelled grid under flat light. FreeCam can frame one FAMILY there. This
## harness goes one step further for the reference-comparison pass: it walks
## every specimen the shed built, hides its neighbours, and photographs it from
## four fixed bearings whose distance is derived from the specimen's own bounds,
## so a kettle and a boiler each fill the frame the same way and a reference
## photograph of either can be laid beside it.
##
## It also writes warehouse_manifest.json: per specimen the kind, the plinth
## label (which is the variant name), the mount the shed chose (floor, wall,
## ceiling), the authored bounds in metres, and a material census - how many
## surfaces carry an albedo texture versus a flat colour, and which shader or
## standard materials they use. That census is a texturing fact, not a picture,
## and tools/prop_reference reads it before anyone looks at a frame.
##
## Optional environment:
##   SHOT_WAREHOUSE_KIND=<kind>   the shed builds only that family (its own switch)
##   SHOT_WAREHOUSE_ONLY=a,b,c    photograph only these kinds from the full shed
##   SHOT_WAREHOUSE_BEARINGS=n    limit bearings per specimen (default all four)
##
## Needs a real window: headless writes nothing and exits 0, which is the
## silent-zero trap the toolchain notes warn about. Real exit codes: 0 only if
## at least one specimen was photographed and every requested frame saved.

const BuildingRootScript := preload("res://scripts/building/building_root.gd")
const WarehouseScript := preload("res://scripts/building/prop_warehouse.gd")

const RESOLUTION := Vector2i(1280, 960)
const FOV_DEG := 40.0
## Bearings are named for the comparison they serve. Azimuth is measured from
## the aisle side (+z, where the plinth label stands), elevation above the
## specimen's own centre. `margin` is the fraction of frame the bounding sphere
## may occupy; below 1.0 leaves air around the silhouette.
const BEARINGS := [
	{"name": "three_quarter", "azimuth": 35.0, "elevation": 16.0, "margin": 1.10},
	{"name": "front", "azimuth": 0.0, "elevation": 6.0, "margin": 1.10},
	{"name": "side", "azimuth": 90.0, "elevation": 6.0, "margin": 1.10},
	{"name": "high_quarter", "azimuth": 35.0, "elevation": 48.0, "margin": 1.05},
]

var _warehouse: Node3D
var _camera: Camera3D
var _fill: OmniLight3D
var _dir := ""
var _frames_written := 0
var _frames_failed := 0


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	if not DirAccess.dir_exists_absolute(_dir):
		printerr("[WAREHOUSE SHOT] SHOT_DIR does not exist: ", _dir)
		get_tree().quit(1)
		return
	get_viewport().size = RESOLUTION

	var env := WorldEnvironment.new()
	var settings := Environment.new()
	# The shed carries its own four shadowless omnis. The environment only
	# supplies a neutral ground so a black frame can never be mistaken for a
	# dark material - the same reasoning as arcade_prop_shot.gd.
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.16, 0.17, 0.19)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.46, 0.48, 0.52)
	settings.ambient_light_energy = 0.9
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)

	_warehouse = WarehouseScript.new()
	add_child(_warehouse)
	var built: int = _warehouse.build(BuildingRootScript.PROP_SCRIPTS)
	if built <= 0:
		printerr("[WAREHOUSE SHOT] the shed built nothing")
		get_tree().quit(1)
		return

	_camera = Camera3D.new()
	_camera.fov = FOV_DEG
	_camera.near = 0.03
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()
	# The shed's four ceiling lamps are "flat, even" over a twelve-metre hall,
	# not over the fourteen-row hall the full catalogue builds: the smoke run
	# photographed a kettle beside a lamp and a wall clock at the far end, and
	# the clock came back near-black. A comparison against a reference needs
	# every specimen lit the same, so the camera carries its own shadowless
	# fill for specimen frames and switches it off for the lineup, where the
	# shed's own light is the honest picture of the shed.
	_fill = OmniLight3D.new()
	_fill.light_energy = 1.4
	_fill.light_color = Color(1.0, 0.985, 0.96)
	_fill.omni_range = 14.0
	_fill.omni_attenuation = 0.9
	_fill.shadow_enabled = false
	_fill.visible = false
	# Off the lens axis, high and to the camera's left. A light on the axis
	# reflects straight back into the lens off any glossy face - the first
	# full run put a white hotspot in the middle of every clock dial - and a
	# key from upper-left is also the convention the reference photographs
	# were mostly taken under, which makes the comparison fairer.
	_fill.position = Vector3(-1.1, 1.4, 0.3)
	_camera.add_child(_fill)
	_run()


func _run() -> void:
	# Materials compile on first draw. A frame taken before that is the fallback
	# material photographed with confidence; give every specimen one full pass
	# through the renderer before hiding anything.
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout

	var only := _only_kinds()
	var specimens: Array[Node3D] = []
	for child in _warehouse.get_children():
		# A prop is the scripted Node3D the shed added; the shell, plinths,
		# soffits, lights and labels are plain engine nodes. Matching on the
		# "WH_" name the shed assigns lost six specimens on the first full run,
		# because a prop that names itself in _ready() (after its unit, its
		# door kind) overwrites that name and vanishes from a name filter.
		if child is Node3D and child.get_script() != null \
				and not (child is Label3D) and not (child is Light3D):
			var kind := _kind_of_prop(child as Node3D)
			if only.is_empty() or kind in only:
				specimens.append(child as Node3D)
	if specimens.is_empty():
		printerr("[WAREHOUSE SHOT] no specimens matched")
		get_tree().quit(1)
		return
	var labels := _labels()
	var bearing_limit := BEARINGS.size()
	var limit_env := OS.get_environment("SHOT_WAREHOUSE_BEARINGS")
	if limit_env.is_valid_int():
		bearing_limit = clampi(int(limit_env), 1, BEARINGS.size())

	var manifest := {
		"schema": "orison.prop-warehouse-shot.v1",
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"godot": Engine.get_version_info().get("string", ""),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"resolution": [RESOLUTION.x, RESOLUTION.y],
		"fov_deg": FOV_DEG,
		"shot_dir": _dir,
		"kind_filter": only,
		"specimen_count": specimens.size(),
		"specimens": [],
	}

	# The overview first, with everything visible and every label up: the
	# lineup is the comparison the shed exists for, and it is the frame that
	# shows a family sharing a silhouette.
	_camera.global_position = _warehouse.viewing_stand()
	_camera.look_at(_warehouse.position + Vector3(0.0, 0.9, 0.0))
	await _settle()
	manifest["lineup_frame"] = await _save("lineup.png")

	for specimen in specimens:
		var record := await _photograph(specimen, specimens, labels, bearing_limit)
		manifest["specimens"].append(record)

	manifest["frames_written"] = _frames_written
	manifest["frames_failed"] = _frames_failed
	var file := FileAccess.open(_dir + "/warehouse_manifest.json", FileAccess.WRITE)
	if file == null:
		printerr("[WAREHOUSE SHOT] cannot write the manifest")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	var ok := _frames_failed == 0 and _frames_written > 0
	print("[WAREHOUSE SHOT] %s: %d specimens, %d frames written, %d failed -> %s" % [
			"PASS" if ok else "FAIL", specimens.size(), _frames_written,
			_frames_failed, _dir])
	get_tree().quit(0 if ok else 1)


func _photograph(specimen: Node3D, all: Array[Node3D], labels: Array[Label3D],
		bearing_limit: int) -> Dictionary:
	var kind := _kind_of_prop(specimen)
	var local_box: AABB = _warehouse._content_bounds(specimen)
	var world_box := AABB()
	var has_box := local_box.size.length_squared() > 0.0
	if has_box:
		world_box = specimen.global_transform * local_box
	var record := {
		"node": String(specimen.name),
		"kind": kind,
		"label": _nearest_label(specimen, labels),
		"mount": _mount(specimen),
		"has_geometry": has_box,
		"bounds_size_m": [world_box.size.x, world_box.size.y, world_box.size.z] \
				if has_box else [0.0, 0.0, 0.0],
		"bounds_centre": [world_box.get_center().x, world_box.get_center().y,
				world_box.get_center().z] if has_box else [0.0, 0.0, 0.0],
		"plinth_position": [specimen.global_position.x, specimen.global_position.y,
				specimen.global_position.z],
		"rotation_y_deg": rad_to_deg(specimen.rotation.y),
		"materials": _material_census(specimen),
		"frames": {},
	}
	if not has_box:
		# A prop that drew nothing is a finding, not a frame. Record it and
		# move on rather than photographing an empty plinth as if it were art.
		record["frames"] = {}
		return record

	for other in all:
		other.visible = other == specimen
	for label in labels:
		label.visible = false
	_fill.visible = true

	var centre := world_box.get_center()
	var radius := maxf(world_box.size.length() * 0.5, 0.06)
	var half_fov := deg_to_rad(FOV_DEG * 0.5)
	var folder := _safe(String(specimen.name))
	DirAccess.make_dir_recursive_absolute(_dir + "/" + folder)
	for i in bearing_limit:
		var bearing: Dictionary = BEARINGS[i]
		var az := deg_to_rad(float(bearing.azimuth))
		var el := deg_to_rad(float(bearing.elevation))
		var direction := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
		# Sphere-fit distance for a vertical FOV, then the margin. A wall or
		# ceiling specimen keeps the same rule; the backer is behind it.
		var distance := radius / sin(half_fov) * float(bearing.margin)
		_camera.global_position = centre + direction * distance
		_camera.look_at(centre)
		await _settle()
		var path := folder + "/" + String(bearing.name) + ".png"
		record.frames[String(bearing.name)] = await _save(path)

	for other in all:
		other.visible = true
	for label in labels:
		label.visible = true
	_fill.visible = false
	return record


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


## Saves the current viewport and reports what happened rather than trusting
## save_png's silence. Returns the relative path on success or "" on failure.
func _save(relative: String) -> String:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_dir + "/" + relative)
	if err != OK:
		_frames_failed += 1
		printerr("[WAREHOUSE SHOT] save failed (%d): %s" % [err, relative])
		return ""
	_frames_written += 1
	print("[WAREHOUSE SHOT] saved ", relative)
	return relative


func _only_kinds() -> Array[String]:
	var out: Array[String] = []
	var raw := OS.get_environment("SHOT_WAREHOUSE_ONLY")
	for piece in raw.split(","):
		var kind := piece.strip_edges()
		if kind != "":
			out.append(kind)
	return out


## "WH_laundry_airer_03" -> "laundry_airer". The index suffix is the shed's
## display slot, and kinds may themselves contain underscores.
static func _kind_of(node_name: String) -> String:
	var body := node_name.trim_prefix("WH_")
	var cut := body.rfind("_")
	return body.substr(0, cut) if cut > 0 else body


## The kind a specimen was built as. The shed's name is authoritative when it
## survived; a prop that renamed itself still carries prop_type when its
## script serves several kinds, and otherwise its script maps back to exactly
## one registry key.
static func _kind_of_prop(prop: Node3D) -> String:
	var node_name := String(prop.name)
	if node_name.begins_with("WH_"):
		return _kind_of(node_name)
	if "prop_type" in prop:
		var typed := String(prop.get("prop_type"))
		if typed != "":
			return typed
	var script: Script = prop.get_script()
	for kind in BuildingRootScript.PROP_SCRIPTS:
		if BuildingRootScript.PROP_SCRIPTS[kind] == script:
			return String(kind)
	return "unknown:" + node_name


## The shed stands ceiling fixtures at SOFFIT_Y and wall fixtures at WALL_Y;
## everything else sits on the plinth. Read the lift back rather than re-deriving
## the bounds rule, so this stays true if the shed changes its constants.
func _mount(specimen: Node3D) -> String:
	var lift := specimen.position.y
	if is_equal_approx(lift, float(WarehouseScript.SOFFIT_Y)):
		return "ceiling"
	if is_equal_approx(lift, float(WarehouseScript.WALL_Y)):
		return "wall"
	return "floor"


func _labels() -> Array[Label3D]:
	var out: Array[Label3D] = []
	for child in _warehouse.get_children():
		if child is Label3D:
			out.append(child as Label3D)
	return out


## Plinth labels are siblings of the specimen, placed at the plinth's aisle
## edge. Nearest in plan is unambiguous at four-metre bays.
func _nearest_label(specimen: Node3D, labels: Array[Label3D]) -> String:
	var best := ""
	var best_d := INF
	var at := specimen.global_position
	for label in labels:
		var lp := label.global_position
		var d := Vector2(lp.x - at.x, lp.z - at.z).length()
		if d < best_d:
			best_d = d
			best = label.text
	return best if best_d < WarehouseScript.CELL * 0.6 else ""


## A texturing fact per specimen: how many drawn surfaces carry an albedo
## texture at all, and what they are made of. Flat colour is not wrong - the
## enamel appliance pilot ruled some finishes stay flat - but a specimen that
## is 100% flat colour and 20 primitives is a different brief from one that is
## textured and only wrongly proportioned.
func _material_census(root: Node3D) -> Dictionary:
	var surfaces := 0
	var textured := 0
	var normal_mapped := 0
	var shader := 0
	var meshes := 0
	var triangles := 0
	var names := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		meshes += 1
		var faces := mi.mesh.get_faces()
		triangles += int(faces.size() / 3)
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat == null:
				_bump(names, "(none)")
				continue
			if mat is ShaderMaterial:
				shader += 1
				var sh := (mat as ShaderMaterial).shader
				_bump(names, "shader:" + (sh.resource_path.get_file() if sh != null else "?"))
				continue
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				if bm.albedo_texture != null:
					textured += 1
				if bm.normal_enabled and bm.normal_texture != null:
					normal_mapped += 1
				var key := mat.resource_name if mat.resource_name != "" \
						else mat.resource_path.get_file()
				if key == "":
					# Anonymous materials are the norm for script-built props.
					# Name them by what they are: a mapped surface carries its
					# albedo map's file, a flat one its colour and response.
					if bm.albedo_texture != null:
						key = "tex:%s r%.2f m%.2f" % [
								bm.albedo_texture.resource_path.get_file(),
								bm.roughness, bm.metallic]
					else:
						key = "flat:#%s r%.2f m%.2f" % [
								bm.albedo_color.to_html(false), bm.roughness,
								bm.metallic]
				_bump(names, key)
	return {
		"mesh_instances": meshes,
		"triangles": triangles,
		"surfaces": surfaces,
		"textured_surfaces": textured,
		"normal_mapped_surfaces": normal_mapped,
		"shader_surfaces": shader,
		"flat_colour_share": (float(surfaces - textured - shader) / float(surfaces)) \
				if surfaces > 0 else 1.0,
		"materials": names,
	}


static func _bump(counter: Dictionary, key: String) -> void:
	counter[key] = int(counter.get(key, 0)) + 1


static func _safe(text: String) -> String:
	var out := text
	for bad in ["|", ":", "*", "?", "\"", "<", ">", "@", " ", "/", "\\"]:
		out = out.replace(bad, "_")
	return out
