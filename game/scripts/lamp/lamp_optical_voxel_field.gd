extends RefCounted
## Isolated instantaneous optical authority. No ecology, switch logic or save writes.
const TIERS := [Vector3i(48,48,64),Vector3i(96,96,128)]
const NEAR := 0.005
const HERO_FOCUS_RANGE := 0.6
var near_cascade: RefCounted
var focus_range := 0.0
var grid_far := 9.0
var _timestamp_prefix := "lamp_mid"
const MAX_BLOCKERS := 8
const MAX_RANGE_M := 1.0e12
const MAX_RADIANCE := 65504.0
const MATERIAL_OWNER_META := &"_lamp_optical_field_owner"
var dimensions := TIERS[0]
var radiance := Texture3DRD.new()
var optics := Texture3DRD.new()
var ready := false
var failed := ""
var last_observation_error := ""
var rejected_observations := 0
var _applied_scattering := -1.0
var updates := 0
var uploads := 0
var readbacks := 0
var gpu_samples_us: Array[float] = []
var construction_us: Array[float] = []
var submission_us: Array[float] = []
var profiling := false
var pose := Transform3D.IDENTITY
var _world_to_local := Transform3D.IDENTITY
var range_m := 8.0
var outer := 0.7
var inner_cos := 0.9
var outer_cos := 0.8
var color := Color.WHITE
var energy := 0.0
var stability := 1.0
var rate_of_change := 0.0
var enabled := false
var scattering := 0.05
var blockers: Array[AABB] = []
var extinction: Array[float] = []
var opacity: Array[float] = []
var _materials: Array[ShaderMaterial] = []
var _output := {}
var _parameters := PackedByteArray()
var _mutex := Mutex.new()
var _queued := false
var _disposed := false
var _initialized := false
var texture_bindings := 0
var transform_bindings := 0
var resource_allocations := 0
var _code := ""
var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _buffer := RID()
var _set := RID()
var _radiance_rid := RID()
var _optics_rid := RID()
var _inject_call: Callable
var _last_timestamp_frame := -1
var _geometry_revision := 0
var _applied_geometry := -1

func initialize(tier := 0, focused_range := 0.0) -> void:
	if _initialized or _disposed:return
	_initialized=true
	var focus_gpu:=Vector2(focused_range,NEAR)
	if tier<0 or tier>=TIERS.size() or not is_finite(focused_range) or focused_range<0.0 or (focused_range>0.0 and focus_gpu.x<=focus_gpu.y) or focused_range>MAX_RANGE_M:
		failed="Invalid optical tier or focus range"
		return
	focus_range=focused_range
	dimensions = TIERS[clampi(tier,0,1)]
	if tier==1 and focused_range<=0.0:
		dimensions=TIERS[0]
		near_cascade=get_script().new()
		near_cascade.initialize(1,HERO_FOCUS_RANGE)
	if focused_range>0.0:_timestamp_prefix="lamp_near"
	_parameters.resize(368)
	_code = FileAccess.get_file_as_string("res://shaders/lamp_field.compute")
	_inject_call = Callable(self,"_inject")
	RenderingServer.call_on_render_thread(_initialize_rd)

func _initialize_rd() -> void:
	if _disposed:return
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		failed = "RenderingDevice required (Forward+ or Mobile)"
		return
	var source := RDShaderSource.new()
	source.source_compute = _code
	var spirv := _rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():
		failed = spirv.compile_error_compute
		return
	if near_cascade!=null and not near_cascade.failed.is_empty():
		failed="Near cascade: "+near_cascade.failed
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		failed="Compute shader creation failed"
		return
	_pipeline = _rd.compute_pipeline_create(_shader)
	var format := RDTextureFormat.new()
	format.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.width=dimensions.x;format.height=dimensions.y;format.depth=dimensions.z
	format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_radiance_rid=_rd.texture_create(format,RDTextureView.new(),[])
	_optics_rid=_rd.texture_create(format,RDTextureView.new(),[])
	_buffer=_rd.storage_buffer_create(368,_parameters)
	var uniforms: Array[RDUniform] = []
	for index in 3:
		var uniform := RDUniform.new()
		uniform.binding=index
		uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER if index==2 else RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.add_id(_buffer if index==2 else _radiance_rid if index==0 else _optics_rid)
		uniforms.append(uniform)
	_set=_rd.uniform_set_create(uniforms,_shader,0)
	for rid in [_pipeline,_radiance_rid,_optics_rid,_buffer,_set]:
		if not rid.is_valid():
			failed="Optical GPU resource creation failed"
			return
	resource_allocations=6
	radiance.texture_rd_rid=_radiance_rid
	optics.texture_rd_rid=_optics_rid
	ready=true

func set_occluders(boxes: Array[AABB], absorption: Array[float], opaque: Array[float]) -> bool:
	if _disposed or boxes.size()>MAX_BLOCKERS or absorption.size()!=boxes.size() or opaque.size()!=boxes.size():return false
	for i in boxes.size():
		if not boxes[i].position.is_finite() or not boxes[i].size.is_finite() or not is_finite(opaque[i]) or boxes[i].size.x<=0 or boxes[i].size.y<=0 or boxes[i].size.z<=0 or not is_finite(absorption[i]) or absorption[i]<0 or opaque[i]<0 or opaque[i]>1:return false
	blockers=boxes.duplicate();extinction=absorption.duplicate();opacity=opaque.duplicate()
	if near_cascade!=null:near_cascade.set_occluders(boxes,absorption,opaque)
	_geometry_revision+=1
	return true

func observe(lamp: Node3D, force := false) -> bool:
	if not ready or _disposed:return false
	var start := Time.get_ticks_usec()
	if not is_instance_valid(lamp) or not lamp.is_inside_tree() or lamp.state==null:
		return _reject_observation("Lamp or state is unavailable")
	var raw_pose:=lamp.global_transform
	if not raw_pose.origin.is_finite() or not raw_pose.basis.is_finite() or not is_finite(raw_pose.basis.determinant()) or raw_pose.basis.determinant()==0.0:
		return _reject_observation("Lamp transform is nonfinite or singular")
	var range_gpu:=Vector2(lamp.range_m,NEAR)
	if not is_finite(lamp.range_m) or range_gpu.x<=range_gpu.y or lamp.range_m>MAX_RANGE_M:
		return _reject_observation("Lamp range is outside the supported numeric domain")
	if not is_finite(lamp.base_energy) or lamp.base_energy<0.0 or not is_finite(scattering) or scattering<0.0 or scattering>1.0:
		return _reject_observation("Invalid energy or scattering")
	lamp.state.write_output(_output)
	var new_pose := raw_pose.orthonormalized()
	var new_energy: float = float(_output.intensity)*lamp.base_energy if lamp.state.switched_on else 0.0
	var angle:=float(_output.cone_angle_deg)
	var new_color: Color = _output.color
	var new_stability := float(_output.temporal_stability)
	var spectral:=Vector3(new_color.r,new_color.g,new_color.b)
	if not is_finite(new_energy) or new_energy<0.0 or new_energy>MAX_RADIANCE or not spectral.is_finite() or minf(spectral.x,minf(spectral.y,spectral.z))<0.0 or new_energy*maxf(spectral.x,maxf(spectral.y,spectral.z))>MAX_RADIANCE:
		return _reject_observation("Spectral energy cannot be represented by the optical texture")
	if not is_finite(angle) or angle<=0.0 or angle>=89.0 or not is_finite(new_stability) or new_stability<0.0 or new_stability>1.0 or not is_finite(lamp.state.intensity_rate):
		return _reject_observation("Invalid accepted optical output")
	var new_outer := tan(deg_to_rad(angle))
	last_observation_error=""
	if near_cascade!=null:
		near_cascade.scattering=scattering
		near_cascade.profiling=profiling
		var child_start:=Time.get_ticks_usec()
		near_cascade.observe(lamp,force)
		start+=Time.get_ticks_usec()-child_start
	var pose_changed := pose != new_pose
	var moved: bool = pose_changed or range_m!=lamp.range_m or absf(outer-new_outer)>0.00001
	if not force and not moved and enabled==(new_energy>0.0) and absf(energy-new_energy)<0.00001 and color==new_color and absf(stability-new_stability)<0.00001 and absf(rate_of_change-absf(lamp.state.intensity_rate))<0.00001 and scattering==_applied_scattering and _geometry_revision==_applied_geometry:return false
	var was_enabled := enabled
	_mutex.lock()
	pose=new_pose;range_m=lamp.range_m;outer=new_outer
	if pose_changed:_world_to_local=pose.affine_inverse()
	grid_far=minf(range_m,focus_range) if focus_range>0.0 else range_m
	outer_cos=cos(atan(outer));inner_cos=cos(atan(outer)*0.78)
	energy=new_energy;color=new_color;stability=new_stability
	rate_of_change=absf(lamp.state.intensity_rate)
	enabled=energy>0.0
	_write4(0,pose.origin,range_m)
	_write4(16,pose.basis.x,outer)
	_write4(32,pose.basis.y,inner_cos)
	_write4(48,-pose.basis.z,outer_cos)
	_write4(64,Vector3(color.r,color.g,color.b)*energy,stability)
	_write4(80,Vector3(NEAR,scattering,1.0 if enabled else 0.0),float(blockers.size()))
	_write4(96,Vector3(grid_far,rate_of_change,0),0)
	for i in blockers.size():
		_write4(112+i*32,blockers[i].position,extinction[i])
		_write4(128+i*32,blockers[i].end,opacity[i])
	_applied_scattering=scattering
	_applied_geometry=_geometry_revision
	var schedule := not _queued
	_queued=true
	_mutex.unlock()
	if pose_changed:
		for material in _materials:_bind_transform(material)
	elif moved or was_enabled!=enabled:
		for material in _materials:_bind_shape(material)
	if profiling:construction_us.append(float(Time.get_ticks_usec()-start))
	if schedule:RenderingServer.call_on_render_thread(_inject_call)
	updates+=1
	return true

## Reject bad observations without retaining the previous frame's light. The
## last valid transform remains bound, disabled, until valid input recovers.
func _reject_observation(reason: String) -> bool:
	last_observation_error=reason
	rejected_observations+=1
	if near_cascade!=null:near_cascade._reject_observation(reason)
	energy=0.0;enabled=false
	_applied_geometry=-1
	_mutex.lock()
	_parameters.encode_float(88,0.0)
	var schedule:=not _queued
	_queued=true
	_mutex.unlock()
	for material in _materials:_bind_shape(material)
	if schedule:RenderingServer.call_on_render_thread(_inject_call)
	updates+=1
	return false

func _write4(offset: int, xyz: Vector3, w: float) -> void:
	_parameters.encode_float(offset,xyz.x);_parameters.encode_float(offset+4,xyz.y)
	_parameters.encode_float(offset+8,xyz.z);_parameters.encode_float(offset+12,w)

func _inject() -> void:
	if _disposed:return
	var start := Time.get_ticks_usec()
	_mutex.lock()
	_rd.buffer_update(_buffer,0,368,_parameters)
	_queued=false
	_mutex.unlock()
	if profiling:
		_collect_timestamps()
		_rd.capture_timestamp(_timestamp_prefix+"_begin")
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,_set,0)
	_rd.compute_list_dispatch(list,ceili(dimensions.x/4.0),ceili(dimensions.y/4.0),ceili(dimensions.z/4.0))
	_rd.compute_list_end()
	if profiling:
		_rd.capture_timestamp(_timestamp_prefix+"_end")
		submission_us.append(float(Time.get_ticks_usec()-start))
	uploads+=1

func _collect_timestamps() -> void:
	var frame := _rd.get_captured_timestamps_frame()
	if frame==_last_timestamp_frame:return
	_last_timestamp_frame=frame
	var begin := -1
	for i in _rd.get_captured_timestamps_count():
		var label := _rd.get_captured_timestamp_name(i)
		if label==_timestamp_prefix+"_begin":begin=_rd.get_captured_timestamp_gpu_time(i)
		if label==_timestamp_prefix+"_end" and begin>=0:gpu_samples_us.append(float(_rd.get_captured_timestamp_gpu_time(i)-begin)/1000.0)

func bind_material(material: ShaderMaterial) -> void:
	if _disposed or material==null:return
	var previous_id:=int(material.get_meta(MATERIAL_OWNER_META,0))
	if previous_id==get_instance_id() and _materials.has(material):return
	# Transfer ownership at binding time. A stale owner must never clear a
	# replacement field's textures during its later teardown.
	if previous_id!=0 and previous_id!=get_instance_id():
		var previous:=instance_from_id(previous_id)
		if previous != null and previous.get_script() == get_script():previous.unbind_material(material)
	if not _materials.has(material):_materials.append(material)
	material.set_meta(MATERIAL_OWNER_META,get_instance_id())
	material.set_shader_parameter("lamp_optical_bound",true)
	texture_bindings+=2
	material.set_shader_parameter("lamp_radiance",radiance)
	material.set_shader_parameter("lamp_optics",optics)
	material.set_shader_parameter("lamp_near_radiance",near_cascade.radiance if near_cascade!=null else null)
	material.set_shader_parameter("lamp_near_optics",near_cascade.optics if near_cascade!=null else null)
	if near_cascade!=null:texture_bindings+=2
	_bind_transform(material)

func unbind_material(material: ShaderMaterial) -> void:
	if material==null:return
	_materials.erase(material)
	if int(material.get_meta(MATERIAL_OWNER_META,0))!=get_instance_id():return
	material.remove_meta(MATERIAL_OWNER_META)
	material.set_shader_parameter("lamp_optical_bound",false)
	material.set_shader_parameter("lamp_volume_shape",Vector4(NEAR,range_m,outer,0))
	material.set_shader_parameter("lamp_radiance",null)
	material.set_shader_parameter("lamp_optics",null)
	material.set_shader_parameter("lamp_near_radiance",null)
	material.set_shader_parameter("lamp_near_optics",null)
	material.set_shader_parameter("lamp_near_shape",Vector4.ZERO)

func _bind_transform(material: ShaderMaterial) -> void:
	transform_bindings+=1
	material.set_shader_parameter("lamp_world_to_local",_world_to_local)
	_bind_shape(material)

func _bind_shape(material: ShaderMaterial) -> void:
	material.set_shader_parameter("lamp_physical_range",range_m)
	material.set_shader_parameter("lamp_near_shape",Vector4(NEAR,near_cascade.grid_far,outer,1) if near_cascade!=null else Vector4.ZERO)
	material.set_shader_parameter("lamp_volume_shape",Vector4(NEAR,grid_far,outer,1.0 if enabled else 0.0))

## Explicit diagnostic readback only; never called by observe/update.
## A valid receiver gets exactly one deferred completion. Empty data means
## unavailable/cancelled; a destroyed receiver is skipped without engine errors.
func debug_readback(callback: Callable, optical_channels := false) -> void:
	if not callback.is_valid():return
	if not ready or _disposed:
		_defer_capture_result(callback,PackedByteArray())
		return
	readbacks+=1
	RenderingServer.call_on_render_thread(func():
		var data:=PackedByteArray()
		if not _disposed and ready:
			data=_rd.texture_get_data(_optics_rid if optical_channels else _radiance_rid,0)
		_defer_capture_result(callback,data))

func _defer_capture_result(callback: Callable, data: PackedByteArray) -> void:
	# The queued lambda retains this owner only until completion, so dropping
	# the field after dispose cannot silently lose an already requested result.
	var deliver:=func():
		if callback.is_valid():callback.call(PackedByteArray() if _disposed else data)
	deliver.call_deferred()

func dispose() -> void:
	if _disposed:return
	while not _materials.is_empty():unbind_material(_materials[-1])
	if near_cascade!=null:near_cascade.dispose()
	_disposed=true
	radiance.texture_rd_rid=RID();optics.texture_rd_rid=RID()
	RenderingServer.call_on_render_thread(_dispose_rd)

func _dispose_rd() -> void:
	for rid in [_set,_pipeline,_shader,_buffer,_radiance_rid,_optics_rid]:
		if rid.is_valid() and _rd!=null:_rd.free_rid(rid)
	_set=RID();_pipeline=RID();_shader=RID();_buffer=RID();_radiance_rid=RID();_optics_rid=RID()
	ready=false
	_inject_call=Callable()
