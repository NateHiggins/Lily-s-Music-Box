extends CompositorEffect
## Camera-local atmospheric refraction; no gameplay state or scene mutation.
## An opaque snapshot protects transparent contributions after the final MSAA
## resolve. Immutable colour inputs prevent neighbouring-pixel read/write races.
class OpaqueCapture extends CompositorEffect:
	var parent_ref: WeakRef
	func _init(parent: CompositorEffect) -> void:
		parent_ref=weakref(parent);enabled=false
		effect_callback_type=EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT;access_resolved_color=true
	func _render_callback(_type: int,data: RenderData) -> void:
		var parent: CompositorEffect=parent_ref.get_ref()
		if parent!=null and parent.enabled:parent.capture_opaque(data)

var capture: CompositorEffect
var camera_ref: WeakRef
var previous: Compositor
var installed: Compositor
var rd: RenderingDevice
var shader := RID()
var pipeline := RID()
var copy_shader := RID()
var copy_pipeline := RID()
var sampler := RID()
var source := RID()
var opaque := RID()
var opaque_valid := false
var dimensions := Vector2i.ZERO
var failed := ""
var passes := 0
var disposed := false
var lock := Mutex.new()
var state := Vector4.ZERO
var code := ""
var last_projection_parameters := PackedFloat32Array()

func _init() -> void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color=true;access_resolved_depth=true;enabled=false
	capture=OpaqueCapture.new(self)
	code=FileAccess.get_file_as_string("res://shaders/skywatch_mirage.compute")
	# Compile at world preparation, not the first rare inversion frame.
	RenderingServer.call_on_render_thread(_prepare)

func publish(level: float,bearing: float,seconds: float) -> void:
	lock.lock();state=Vector4(clampf(level,0.,1.),bearing,fposmod(seconds,256.),80.);lock.unlock()
	enabled=level>.001 and camera_ref!=null and camera_ref.get_ref()!=null
	capture.enabled=enabled

func bind_camera(camera: Camera3D) -> void:
	if camera_ref!=null and camera_ref.get_ref()==camera:return
	_detach()
	if camera==null:return
	camera_ref=weakref(camera);previous=camera.compositor
	installed=previous.duplicate() as Compositor if previous!=null else Compositor.new()
	var effects := installed.compositor_effects.duplicate();effects.append(capture);effects.append(self)
	installed.compositor_effects=effects;camera.compositor=installed
	lock.lock();var level := state.x;lock.unlock();enabled=level>.001
	capture.enabled=enabled

func _detach() -> void:
	var camera: Camera3D=camera_ref.get_ref() if camera_ref!=null else null
	if camera!=null and camera.compositor!=null:
		var current := camera.compositor
		var effects := current.compositor_effects.duplicate();effects.erase(self);effects.erase(capture)
		var prior: Array=previous.compositor_effects.duplicate() if previous!=null else []
		if current==installed and effects==prior:camera.compositor=previous
		else:current.compositor_effects=effects
	camera_ref=null;previous=null;installed=null;enabled=false
	capture.enabled=false;opaque_valid=false

func _prepare() -> void:
	if disposed or shader.is_valid():return
	rd=RenderingServer.get_rendering_device()
	if rd==null:return
	var text := RDShaderSource.new();text.source_compute=code
	var spirv := rd.shader_compile_spirv_from_source(text)
	if not spirv.compile_error_compute.is_empty():failed=spirv.compile_error_compute;return
	shader=rd.shader_create_from_spirv(spirv);pipeline=rd.compute_pipeline_create(shader)
	text.source_compute=code.replace("#version 450","#version 450\n#define COPY_IMAGE")
	spirv=rd.shader_compile_spirv_from_source(text)
	if not spirv.compile_error_compute.is_empty():failed=spirv.compile_error_compute;return
	copy_shader=rd.shader_create_from_spirv(spirv);copy_pipeline=rd.compute_pipeline_create(copy_shader)
	var sampling := RDSamplerState.new()
	sampling.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;sampling.mag_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
	sampling.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;sampling.repeat_v=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler=rd.sampler_create(sampling)

func _size_images(size: Vector2i) -> void:
	if size!=dimensions:
		if source.is_valid():rd.free_rid(source)
		if opaque.is_valid():rd.free_rid(opaque)
		var format := RDTextureFormat.new();format.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		format.width=size.x;format.height=size.y
		format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		source=rd.texture_create(format,RDTextureView.new())
		opaque=rd.texture_create(format,RDTextureView.new());dimensions=size

func _copy_set(output: RID,input: RID) -> RID:
	# Render buffers are sampleable/storage images, not guaranteed transfer
	# sources. A compute copy preserves their declared usage and immutable input.
	var copy_out := RDUniform.new();copy_out.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;copy_out.binding=0;copy_out.add_id(output)
	var copy_in := RDUniform.new();copy_in.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;copy_in.binding=1;copy_in.add_id(sampler);copy_in.add_id(input)
	return UniformSetCacheRD.get_cache(copy_shader,0,[copy_out,copy_in])

func capture_opaque(data: RenderData) -> void:
	if disposed or not failed.is_empty() or not copy_pipeline.is_valid():return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers==null or buffers.get_view_count()!=1:return
	var size := buffers.get_internal_size()
	if size.x==0 or size.y==0:return
	_size_images(size)
	var list := rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,copy_pipeline)
	rd.compute_list_bind_uniform_set(list,_copy_set(opaque,buffers.get_color_layer(0)),0)
	rd.compute_list_dispatch(list,ceili(size.x/8.),ceili(size.y/8.),1);rd.compute_list_end()
	opaque_valid=true

func _render_callback(_type: int,data: RenderData) -> void:
	if disposed or not failed.is_empty() or not pipeline.is_valid() or not opaque_valid:return
	opaque_valid=false
	lock.lock();var weather := state;lock.unlock()
	if weather.x<.001:return
	var scene := data.get_render_scene_data()
	var projection := scene.get_cam_projection()
	if not is_zero_approx(projection.w.w):return # orthographic tooling cameras
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers==null or buffers.get_view_count()!=1:return
	var size := buffers.get_internal_size()
	if size!=dimensions:return
	var output := buffers.get_color_layer(0)
	var image := RDUniform.new();image.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;image.binding=0;image.add_id(output)
	var colour := RDUniform.new();colour.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;colour.binding=1;colour.add_id(sampler);colour.add_id(source)
	var depth := RDUniform.new();depth.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;depth.binding=2;depth.add_id(sampler);depth.add_id(buffers.get_depth_layer(0))
	var guard := RDUniform.new();guard.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;guard.binding=3;guard.add_id(sampler);guard.add_id(opaque)
	var uniforms := UniformSetCacheRD.get_cache(shader,0,[image,colour,depth,guard])
	var inverse := projection.inverse();var frame: Basis=scene.get_cam_transform().basis
	var values := PackedFloat32Array()
	for column: Vector4 in [inverse.x,inverse.y,inverse.z,inverse.w,Vector4(frame.x.x,frame.x.y,frame.x.z,0.),Vector4(frame.y.x,frame.y.y,frame.y.z,0.),Vector4(frame.z.x,frame.z.y,frame.z.z,0.),weather]:
		values.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
	last_projection_parameters=values
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list,copy_pipeline);rd.compute_list_bind_uniform_set(list,_copy_set(source,output),0)
	rd.compute_list_dispatch(list,ceili(size.x/8.),ceili(size.y/8.),1);rd.compute_list_add_barrier(list)
	rd.compute_list_bind_compute_pipeline(list,pipeline)
	rd.compute_list_bind_uniform_set(list,uniforms,0);rd.compute_list_set_push_constant(list,values.to_byte_array(),128)
	rd.compute_list_dispatch(list,ceili(size.x/8.),ceili(size.y/8.),1);rd.compute_list_end();passes+=1

func dispose() -> void:
	_detach();disposed=true;RenderingServer.call_on_render_thread(_dispose_rd)

func _dispose_rd() -> void:
	if rd!=null:
		for handle in [source,opaque,pipeline,shader,copy_pipeline,copy_shader,sampler]:
			if handle.is_valid():rd.free_rid(handle)
	source=RID();pipeline=RID();shader=RID();sampler=RID()
	opaque=RID()
	copy_pipeline=RID();copy_shader=RID()
