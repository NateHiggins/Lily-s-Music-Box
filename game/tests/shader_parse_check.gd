extends Node
## Loads every shader named in SHADER_PATHS and reports whether Godot's
## shader compiler accepted it (parse + semantic pass; runs headless). A
## shader that fails prints SHADER ERROR and the run exits non-zero.
##
##     godot --headless --path game res://tests/ShaderParseCheck.tscn

const SHADER_PATHS := [
	"res://shaders/orison_surface.gdshader",
	"res://shaders/orison_surface_cutout.gdshader",
	"res://shaders/dream_klimt.gdshader",
	"res://shaders/dream_fauna.gdshader",
	"res://shaders/dream_tentacle.gdshader",
	"res://shaders/dream_eye.gdshader",
	"res://shaders/dream_halo.gdshader",
	"res://shaders/dream_sucker.gdshader",
	"res://shaders/dream_membrane.gdshader",
	"res://shaders/dream_gold.gdshader",
	"res://shaders/dream_tendrils.gdshader",
	"res://shaders/dream_hero_skin.gdshader",
	"res://shaders/dream_palp.gdshader",
	"res://shaders/dream_residue.gdshader",
	"res://shaders/dream_critter.gdshader",
	"res://shaders/dream_crystal.gdshader",
	"res://shaders/dream_cilia.gdshader",
	"res://shaders/dream_eyelid.gdshader",
]


func _ready() -> void:
	var failed := 0
	for path in SHADER_PATHS:
		var shader: Shader = load(path)
		if shader == null:
			print("[PARSE] %s: FAILED TO LOAD" % path)
			failed += 1
			continue
		var uniforms := shader.get_shader_uniform_list()
		var samplers := 0
		for u in uniforms:
			if int(u.get("type", -1)) == TYPE_OBJECT:
				samplers += 1
		var m := ShaderMaterial.new()
		m.shader = shader
		print("[PARSE] %s: %d uniforms (%d samplers) code %d chars"
				% [path, uniforms.size(), samplers, shader.code.length()])
		if uniforms.is_empty():
			failed += 1
	print("[PARSE] %s" % ("PASS" if failed == 0 else "FAIL %d" % failed))
	get_tree().quit(0 if failed == 0 else 1)
