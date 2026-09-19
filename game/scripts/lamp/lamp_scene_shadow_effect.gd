extends CompositorEffect
## GPU-only mesh visibility injection. Never reads or writes ecological state.
var field_ref: WeakRef
var rd: RenderingDevice
var shader := RID()
var pipeline := RID()
var sampler := RID()
var failed := ""
var passes := 0
var disposed := false
var last_upload := -1
var code := ""
var sets := {}
var params := PackedByteArray()
func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
	access_resolved_depth = true
	code = FileAccess.get_file_as_string("res://shaders/lamp_scene_shadow.compute")
	params.resize(16)
func _render_callback(_type: int, data: RenderData) -> void:
	if disposed or field_ref == null: return
	var field: RefCounted = field_ref.get_ref()
	if field == null or not field.ready or field._disposed or not field.enabled: return
	# The operation attenuates a freshly injected field. Never compound a
	# previous shadow when the simulation is paused or the owner stops updating.
	if last_upload == field.uploads: return
	if rd == null:
		rd = RenderingServer.get_rendering_device()
		var source := RDShaderSource.new()
		source.source_compute = code
		var spirv := rd.shader_compile_spirv_from_source(source)
		if not spirv.compile_error_compute.is_empty():
			failed = spirv.compile_error_compute
			return
		shader = rd.shader_create_from_spirv(spirv)
		pipeline = rd.compute_pipeline_create(shader)
		var state := RDSamplerState.new()
		state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler = rd.sampler_create(state)
	if not failed.is_empty(): return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null: return
	last_upload = field.uploads
	var depth := buffers.get_depth_layer(0)
	_inject(field,depth)
	if field.near_cascade != null: _inject(field.near_cascade,depth)
	passes += 1
func _inject(field: RefCounted, depth: RID) -> void:
	if not field.ready or field._disposed: return
	var id := field.get_instance_id()
	if not sets.has(id) or sets[id].depth != depth:
		sets[id] = {"depth":depth,"uniforms":_make_set(field,depth)}
	params.encode_float(0,field.NEAR)
	params.encode_float(4,field.range_m)
	params.encode_float(8,field.grid_far)
	params.encode_float(12,0)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list,pipeline)
	rd.compute_list_bind_uniform_set(list,sets[id].uniforms,0)
	rd.compute_list_set_push_constant(list,params,16)
	rd.compute_list_dispatch(list,ceili(field.dimensions.x/4.0),ceili(field.dimensions.y/4.0),ceili(field.dimensions.z/4.0))
	rd.compute_list_end()
func _make_set(field: RefCounted, depth: RID) -> RID:
	var radiance := RDUniform.new()
	radiance.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	radiance.binding = 0
	radiance.add_id(field._radiance_rid)
	var optics := RDUniform.new()
	optics.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	optics.binding = 1
	optics.add_id(field._optics_rid)
	var shadow := RDUniform.new()
	shadow.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	shadow.binding = 2
	shadow.add_id(sampler)
	shadow.add_id(depth)
	var uniforms: Array[RDUniform] = [radiance,optics,shadow]
	return UniformSetCacheRD.get_cache(shader,0,uniforms)
func dispose() -> void:
	disposed = true
	RenderingServer.call_on_render_thread(_dispose_rd)
func _dispose_rd() -> void:
	sets.clear()
	if rd != null:
		for rid in [pipeline,shader,sampler]:
			if rid.is_valid(): rd.free_rid(rid)
	pipeline = RID()
	shader = RID()
	sampler = RID()
	field_ref = null
