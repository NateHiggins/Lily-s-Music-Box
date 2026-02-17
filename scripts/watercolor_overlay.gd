extends ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 0.06)
	material = ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type canvas_item;\nuniform float grain = 0.08;\nfloat rand(vec2 c){return fract(sin(dot(c,vec2(12.9898,78.233)))*43758.5453);}\nvoid fragment(){float n=rand(UV*vec2(400.0,700.0));COLOR=vec4(vec3(1.0), (n-0.5)*grain + 0.05); }"
