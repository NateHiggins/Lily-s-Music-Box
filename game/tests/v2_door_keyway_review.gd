extends Node3D
## Focused visible-shell check. This is not a composed-world runtime receipt.
var failures: Array[String] = []
var checks := 0

func require(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _ready() -> void:
	var model := (preload("res://assets/props/door_knob_set.glb") as PackedScene).instantiate()
	var knob := (model.find_child("KnobSet", true, false) as MeshInstance3D).mesh
	model.free()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.18, .23, .28)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7, .8, 1)
	environment.environment.ambient_light_energy = .6
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -30, 0)
	light.light_energy = 1.4
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.near = .005
	camera.fov = 40
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://door_keyway_review"
	DirAccess.make_dir_recursive_absolute(directory)
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_domestic_door_leaves.json"))
	require(int(fixture.schema_version)==1,"native door family schema")
	require(FileAccess.get_sha256("res://assets/props/domestic_door_leaves.glb")==fixture.asset_sha256,"native door export matches family fixture")
	var specimens: Array[Dictionary]=[]
	var surface_auditor := preload("res://tests/orison_v2_surface_inventory.gd").new()
	for kind: String in ["apartment_entry","apartment_interior","service","exterior_service"]:
		specimens.append({"kind":kind,"label":kind,"width":.81,"height":2.03})
	for family: Dictionary in fixture.families:
		specimens.append({"kind":"apartment_interior","label":str(family.name),"width":family.width,"height":family.height,"triangles":family.triangles})
	for specimen: Dictionary in specimens:
		var kind: String=specimen.kind
		var door := OrisonV2FittedDoor.new()
		door.name = "KeywayReview_" + kind
		door.door_kind = kind
		door.width=float(specimen.width);door.height=float(specimen.height)
		door.knob_mesh = knob
		add_child(door)
		await get_tree().process_frame
		if specimen.has("triangles"):
			var family_mesh: Mesh=OrisonV2FittedDoor._joinery_meshes[str(specimen.label)]
			require(family_mesh.get_faces().size()==int(specimen.triangles)*3,"source-sized family retains all native faces")
			var audit: Dictionary=surface_auditor._mesh(family_mesh)
			for surface: Dictionary in audit.surfaces:
				require(not surface.missing_uv and int(surface.nonfinite_uv)==0 and int(surface.degenerate_uv_triangles)==0,"imported family retains finite noncollapsed UV charts")
		var triangles := PackedVector3Array()
		for draw: MeshInstance3D in door._body.find_children("*", "MeshInstance3D", true, false):
			for vertex: Vector3 in draw.mesh.get_faces(): triangles.append(draw.global_transform * vertex)
		for sample: Vector3 in [Vector3(door.width-.085,.892,0), Vector3(door.width-.085,.884,0)]:
			for face: float in [-1.0, 1.0]:
				var origin := door.to_global(sample + Vector3(0,0,face*.15))
				var direction := Vector3(0,0,-face)
				var clear := true
				for i in range(0, triangles.size(), 3):
					if Geometry3D.ray_intersects_triangle(origin,direction,triangles[i],triangles[i+1],triangles[i+2]) != null:
						clear = false
				require(clear, kind + " visible round/stem bore clears both faces")
		var shapes := door._body.find_children("*", "CollisionShape3D", true, false)
		require(shapes.size()==1 and shapes[0].shape is BoxShape3D, kind + " retains one physical leaf")
		camera.position = door.to_global(Vector3(door.width-.07,.922,.36))
		camera.look_at(door.to_global(Vector3(door.width-.085,.916,0)))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(str(specimen.label)+".png"))
		door.free()
	surface_auditor.free()
	var report := {"evidence_class":"INERT", "checks":checks,"failures":failures,
		"scope":"Four door kinds and six native size families; not composed-world or lock lifecycle proof"}
	var file := FileAccess.open(directory.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("DOOR KEYWAY REVIEW ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
