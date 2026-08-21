extends Node3D
## CT-1 — the five fauna families photographed close, with and without their
## skin atlases, at two irradiance levels. A studio, not the dream: each
## family's part-kit mesh under the production fauna shader, fed a uniform
## exposure field (so the irradiance bands are chosen, not found), the lamp
## on the camera, one key light for the PBR term.
##
##     SHOT_DIR=<abs dir> godot --path game --resolution 1280x720 res://tests/DreamFaunaSkinShot.tscn

const FAUNA_SHADER := preload("res://shaders/dream_fauna.gdshader")
const FAMILIES := [
	{"key": "buttons", "mesh": "buttons", "motif": 0, "dir": "gilders_button",
			"color": Color(0.20, 0.025, 0.075), "jewel": Color(0.18, 0.404, 0.36), "repeat": Vector2(1, 1)},
	{"key": "tessellates", "mesh": "tessellates", "motif": 1, "dir": "tessellate",
			"color": Color(0.20, 0.025, 0.075), "jewel": Color(0.18, 0.404, 0.36), "repeat": Vector2(1, 1)},
	{"key": "anemones", "mesh": "anemones", "motif": 2, "dir": "wine_anemone",
			"color": Color(0.22, 0.03, 0.09), "jewel": Color(0.30, 0.36, 0.20), "repeat": Vector2(2, 1)},
	{"key": "ribbonettes", "mesh": "ribbonettes", "motif": 3, "dir": "ribbonette",
			"color": Color(0.20, 0.025, 0.075), "jewel": Color(0.42, 0.30, 0.16), "repeat": Vector2(3, 1)},
	{"key": "loupe", "mesh": "loupe", "motif": 4, "dir": "the_loupe",
			"color": Color(0.18, 0.02, 0.07), "jewel": Color(0.62, 0.18, 0.12), "repeat": Vector2(1, 1)},
]
const LEVELS := [{"key": "oblique", "g": 0.50}, {"key": "molten", "g": 0.92}]

var _dir := ""
var cam: Camera3D
var subject: MeshInstance3D
var key_light: OmniLight3D


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.01, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.30, 0.12, 0.22)
	e.ambient_light_energy = 0.35
	env.environment = e
	add_child(env)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.make_current()
	key_light = OmniLight3D.new()
	key_light.light_energy = 2.4
	key_light.light_color = Color(1.0, 0.86, 0.62)
	key_light.omni_range = 6.0
	add_child(key_light)
	subject = MeshInstance3D.new()
	add_child(subject)
	_run()


func _exposure_tex(g: float) -> ImageTexture3D:
	var imgs: Array[Image] = []
	for z in 2:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.fill(Color(0.45, g, 0.0))
		imgs.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, 2, 2, 2, false, imgs)
	return tex


func _material(family: Dictionary, level: Dictionary, skin: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FAUNA_SHADER
	m.set_shader_parameter("base_color", Vector3(family.color.r, family.color.g, family.color.b))
	m.set_shader_parameter("jewel_color", Vector3(family.jewel.r, family.jewel.g, family.jewel.b))
	m.set_shader_parameter("gold_color", Vector3(0.72, 0.40, 0.09))
	m.set_shader_parameter("family_motif", float(family.motif))
	m.set_shader_parameter("vertex_channels_ready", 1.0)
	m.set_shader_parameter("gait_amount", 0.0)
	m.set_shader_parameter("exposure_tex", _exposure_tex(float(level.g)))
	m.set_shader_parameter("exposure_extent", 48.0)
	m.set_shader_parameter("exposure_height", 4.0)
	m.set_shader_parameter("lamp_origin", cam.global_position)
	m.set_shader_parameter("lamp_dir", -cam.global_transform.basis.z)
	m.set_shader_parameter("lamp_energy", 1.0)
	var skin_dir := "res://assets/dream/fauna_skins/%s/" % family.dir
	if skin and ResourceLoader.exists(skin_dir + "albedo.png"):
		m.set_shader_parameter("skin_albedo", load(skin_dir + "albedo.png"))
		m.set_shader_parameter("skin_normal", load(skin_dir + "normal.png"))
		m.set_shader_parameter("skin_mask", load(skin_dir + "mask.png"))
		m.set_shader_parameter("skin_ready", 1.0)
		m.set_shader_parameter("skin_repeat", family.repeat)
	return m


static func _mesh_for(name: String) -> ArrayMesh:
	match name:
		"buttons": return DreamFaunaParts.buttons()
		"tessellates": return DreamFaunaParts.tessellates()
		"anemones": return DreamFaunaParts.anemones()
		"ribbonettes": return DreamFaunaParts.ribbonettes()
		_: return DreamFaunaParts.loupe()


func _run() -> void:
	await get_tree().create_timer(0.4).timeout
	for family in FAMILIES:
		var mesh: ArrayMesh = _mesh_for(str(family.mesh))
		subject.mesh = mesh
		var aabb := mesh.get_aabb()
		var centre := aabb.get_center()
		var radius := maxf(aabb.size.length() * 0.5, 0.05)
		subject.position = -centre
		var dist := radius / tan(deg_to_rad(cam.fov * 0.5)) * 1.15
		cam.position = Vector3(dist * 0.35, dist * 0.28, dist * 0.88)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		key_light.position = cam.position + Vector3(0.4 * dist, 0.5 * dist, 0.1 * dist)
		for level in LEVELS:
			for skin in [false, true]:
				var m := _material(family, level, skin)
				mesh.surface_set_material(0, m)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var path := _dir.path_join("%s__%s__%s.png" % [family.key, level.key, "skin" if skin else "plain"])
				var err := get_viewport().get_texture().get_image().save_png(path)
				print("[FAUNA SKIN SHOT] %s %s" % [path, "ok" if err == OK else "SAVE FAILED %d" % err])
	print("[FAUNA SKIN SHOT] DONE")
	get_tree().quit(0)
