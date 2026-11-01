extends Node
## Isolated production street owner. Composed access is tested separately.
const Streets = preload("res://scripts/building/orison_v2_city_streets.gd")
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var sources: Dictionary = {}
var directory: String

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func _ready() -> void:
    call_deferred("run")

func digest(path: String) -> String:
    if path.get_extension() in ["gd", "tscn", "json", "gdshader", "gdshaderinc", "import"]:
        return FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
    return FileAccess.get_sha256(path)

func run() -> void:
    directory = OS.get_environment("SHOT_DIR")
    if directory.is_empty() or DisplayServer.get_name() == "headless":
        get_tree().quit(1)
        return
    DirAccess.make_dir_recursive_absolute(directory)
    RealityState.persistence_enabled = false
    RealityState.reset_campaign_for_tests()
    CampaignTime.set_frozen_for_tests(true)
    var city := Node3D.new()
    add_child(city)
    var owner := Streets.mount(city)
    var draws: Array[MeshInstance3D] = []
    var bounds := AABB()
    var witness: MeshInstance3D
    var largest := 0
    for draw: MeshInstance3D in owner.find_children("*", "MeshInstance3D", true, false):
        draw.visible = str(draw.name).begins_with("Street_Western")
        if not draw.visible:
            continue
        draws.append(draw)
        var box: AABB = draw.global_transform * draw.get_aabb()
        bounds = box if draws.size() == 1 else bounds.merge(box)
        var count: int = draw.mesh.surface_get_array_index_len(0)
        if str(draw.name).ends_with("__road") and count > largest:
            witness = draw
            largest = count
    check(draws.size() == 168 and witness != null, "all 168 Western partitions and road witness installed")
    for path: String in [get_script().resource_path, "res://tests/V2CityWesternStreetLOD.tscn", "res://scripts/building/orison_v2_city_streets.gd", "res://scripts/building/orison_v2_city_transport.gd", Streets.FINISHES, "res://assets/props/city_streets.glb", "res://assets/props/city_streets_lod1.glb", "res://scripts/material_library.gd", "res://data/runtime_material_sets.json", "res://scripts/building/surface_pass.gd", "res://shaders/orison_surface.gdshader", "res://shaders/orison_surface.gdshaderinc", "res://shaders/queens_surface_wetness.gdshaderinc"]:
        sources[path] = digest(path)
    for draw in draws:
        var material: Material = draw.material_override
        var stock: StandardMaterial3D = material.get_meta("v2_weather_source", material)
        for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ROUGHNESS]:
            var texture := stock.get_texture(slot)
            check(texture != null, "loaded material map")
            if texture != null:
                sources[texture.resource_path] = digest(texture.resource_path)
                sources[texture.resource_path + ".import"] = digest(texture.resource_path + ".import")
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(.32, .38, .44)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_energy = .7
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-40, -25, 0)
    sun.light_energy = 2.8
    add_child(sun)
    var camera := Camera3D.new()
    camera.far = 20000.
    add_child(camera)
    camera.make_current()
    var viewport := get_viewport()
    check(viewport.get_visible_rect().size == Vector2(3440, 1440), "native resolution")
    viewport.use_taa = false
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
    camera.fov = 72.
    camera.global_position = bounds.get_center() + Vector3(0, 1, .15).normalized() * 245.
    camera.look_at(bounds.get_center())
    var family: Array[Dictionary] = []
    for threshold in [0., 10000., 0.]:
        viewport.mesh_lod_threshold = threshold
        family.append(await sample(camera, "family_" + str(family.size())))
    check(int(family[1].primitives) < int(family[0].primitives) and family[2].primitives == family[0].primitives, "actual family replacement reduction and return")
    for draw in draws:
        draw.visible = draw == witness
    viewport.mesh_lod_threshold = 1.
    var arrays: Array = witness.mesh.surface_get_arrays(0)
    var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var target := witness.global_position
    var broad := 0.
    for i in range(0, indices.size(), 3):
        var a := points[indices[i]]
        var b := points[indices[i + 1]]
        var c := points[indices[i + 2]]
        var face := (b-a).cross(c-a)
        if face.y > broad:
            broad = face.y
            target = witness.global_transform * ((a+b+c)/3.)
    check(broad > .4, "natural witness aims at actual broad road surface")
    var natural: Array[Dictionary] = []
    for spec in [{"distance":3., "fov":72.}, {"distance":120., "fov":72.}, {"distance":120., "fov":2.}, {"distance":3., "fov":72.}]:
        camera.fov = spec.fov
        camera.global_position = target + Vector3(0, 1, .1).normalized() * float(spec.distance)
        camera.look_at(target)
        natural.append(await sample(camera, "natural_" + str(natural.size())))
    check(natural[1].primitives < natural[0].primitives and natural[2].primitives >= natural[0].primitives and natural[3].primitives == natural[0].primitives, "distance reduction, optical recovery and inward return")
    for row in natural:
        check(int(row.draws) == 1 and int(row.primitives) > 0, "natural witness remains rendered")
    for path: String in sources:
        check(FileAccess.file_exists(path) and digest(path) == sources[path], "frozen source " + path)
    var record := {"schema_version":2, "evidence_kind":"runtime_contract", "selector":"v2", "production_runtime":true, "scope":"Isolated production Western street family: forced near/lower/return and one broad road part distance/FOV/return. Fixed diagnostic lighting, TAA off. No composed access, saves, global performance or artistic acceptance.", "execution":{"completed":true, "exit_code":0 if failures.is_empty() else 1, "timed_out":false}, "checks":checks, "failures":failures, "source":{"test_path":"game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256":FileAccess.get_sha256(get_script().resource_path), "runtime_inputs_sha256":JSON.stringify(sources).sha256_text()}, "contracts":{"western_street_lods":{"executed":observations.size() == 7, "passed":failures.is_empty()}}, "source_hashes":sources, "observations":observations, "witness":str(witness.name)}
    var file := FileAccess.open(directory.path_join("western_lod.runtime.json"), FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(record, "\t"))
        file.close()
    get_tree().quit(0 if failures.is_empty() and file != null else 1)

func sample(_camera: Camera3D, identity: String) -> Dictionary:
    var viewport := get_viewport()
    var samples: Array[Dictionary] = []
    var previous := Time.get_ticks_usec()
    for frame in 150:
        await RenderingServer.frame_post_draw
        var now := Time.get_ticks_usec()
        samples.append({"phase":"transition" if frame < 30 else "warm", "wall_ms":(now-previous)/1000., "gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()), "cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())})
        previous = now
    var row := {"id":identity, "draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME), "primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME), "samples":samples, "image":identity + ".png"}
    check(viewport.get_texture().get_image().save_png(directory.path_join(row.image)) == OK, "capture " + identity)
    observations.append(row)
    return row
