extends Node
## Viewport-local presentation. The second camera sees only tagged native subjects,
## and its resolved depth is compared with the scene depth so walls still occlude them.
##
## It draws the world look GameBoot.world_look() names (Lily 2026-11-28):
##   "stock"  the render as it is
##   "cel"    the soft palette (shaders/cel_style.compute)
##   "comic"  ink on manila (shaders/comic_world.compute): tone bands with a dim
##            night band, halftone shade, ink lines, lettering kept real, the
##            real render in Adela's aura, and only the lamp casting shadows
## A further look (the finale's neon) adds an effect class, a LOOKS entry and
## a branch in _effect_for() and _set_look(); a look that is named but not
## built falls back to "comic" with a warning.

const NATIVE_LAYER := 1 << 25
const DEVICE_NATIVE_LAYER := 1 << 26
const DEVICE_WORLD_LAYER := 1 << 1
const COMPUTE := "res://shaders/cel_style.compute"
const COMIC_COMPUTE := "res://shaders/comic_world.compute"
const LOOKS := ["stock", "cel", "comic"]
const ShadowPolicy := preload("res://scripts/rendering/shadow_policy.gd")
const AdelaPresence := preload("res://scripts/rendering/adela_presence.gd")
## Lettering is drawn with Label3D. In the comic look it joins the native
## layer, so the mask keeps it real and tone bands never flatten print.
const LABEL_META := &"comic_native_label"

class NativeDepth extends CompositorEffect:
	var depth := RID()

	func _init() -> void:
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
		access_resolved_depth = true

	func _render_callback(_type: int, data: RenderData) -> void:
		var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
		depth = buffers.get_depth_layer(0) if buffers != null else RID()


class Palette extends CompositorEffect:
	var native: NativeDepth
	var rd: RenderingDevice
	var sampler := RID()
	var copy_shader := RID()
	var copy_pipeline := RID()
	var palette_shader := RID()
	var palette_pipeline := RID()
	var scratch := RID()
	var dimensions := Vector2i.ZERO
	var failed := false
	var passes := 0
	var stopped := false
	var code := ""

	func _init(mask: NativeDepth, shader_code: String) -> void:
		native = mask
		code = shader_code
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
		access_resolved_depth = true
		access_resolved_color = true

	func _prepare() -> bool:
		rd = RenderingServer.get_rendering_device()
		if rd == null:
			return false
		copy_shader = _compile(code.replace("#version 450", "#version 450\n#define COPY_IMAGE"))
		palette_shader = _compile(code)
		if not copy_shader.is_valid() or not palette_shader.is_valid():
			failed = true
			return false
		copy_pipeline = rd.compute_pipeline_create(copy_shader)
		palette_pipeline = rd.compute_pipeline_create(palette_shader)
		sampler = rd.sampler_create(RDSamplerState.new())
		return copy_pipeline.is_valid() and palette_pipeline.is_valid()

	func _compile(text: String) -> RID:
		var source := RDShaderSource.new()
		source.source_compute = text
		var result := rd.shader_compile_spirv_from_source(source)
		if not result.compile_error_compute.is_empty():
			push_error("Cel palette: " + result.compile_error_compute)
			return RID()
		return rd.shader_create_from_spirv(result)

	func _resize(size: Vector2i) -> void:
		if size == dimensions:
			return
		if scratch.is_valid():
			rd.free_rid(scratch)
		var format := RDTextureFormat.new()
		format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		format.width = size.x
		format.height = size.y
		format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		scratch = rd.texture_create(format, RDTextureView.new())
		dimensions = size

	func _binding(index: int, texture: RID, sample: bool) -> RDUniform:
		var uniform := RDUniform.new()
		uniform.binding = index
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE if sample else RenderingDevice.UNIFORM_TYPE_IMAGE
		if sample:
			uniform.add_id(sampler)
		uniform.add_id(texture)
		return uniform

	func _render_callback(_type: int, data: RenderData) -> void:
		if stopped or failed or not native.depth.is_valid():
			return
		if not palette_pipeline.is_valid() and not _prepare():
			return
		var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
		if buffers == null or buffers.get_view_count() != 1:
			return
		var size := buffers.get_internal_size()
		if size.x <= 0 or size.y <= 0:
			return
		_resize(size)
		var target := buffers.get_color_layer(0)
		var copy_set := UniformSetCacheRD.get_cache(copy_shader, 0, [
			_binding(0, scratch, false), _binding(1, target, true)])
		var filter_set := UniformSetCacheRD.get_cache(palette_shader, 0, [
			_binding(0, target, false), _binding(1, scratch, true),
			_binding(2, buffers.get_depth_layer(0), true), _binding(3, native.depth, true)])
		var x := ceili(float(size.x) / 8.0)
		var y := ceili(float(size.y) / 8.0)
		var list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list, copy_pipeline)
		rd.compute_list_bind_uniform_set(list, copy_set, 0)
		rd.compute_list_dispatch(list, x, y, 1)
		rd.compute_list_add_barrier(list)
		rd.compute_list_bind_compute_pipeline(list, palette_pipeline)
		rd.compute_list_bind_uniform_set(list, filter_set, 0)
		rd.compute_list_dispatch(list, x, y, 1)
		rd.compute_list_end()
		passes += 1

	func dispose() -> void:
		stopped = true
		RenderingServer.call_on_render_thread(_dispose_rd)

	func _dispose_rd() -> void:
		if rd != null:
			for rid: RID in [scratch, copy_pipeline, palette_pipeline, copy_shader, palette_shader, sampler]:
				if rid.is_valid():
					rd.free_rid(rid)


## The comic world. Same copy-then-filter passes as the palette, with the
## camera and the look's tuning in push constants.
class Comic extends Palette:
	var near := 0.05
	var far := 4000.0
	var focal := Vector2(1.0, 1.0)
	# Adela's aura: centre in uv, radius and feather in frame heights, 0..1.
	var aura_center := Vector2(0.5, 0.5)
	var aura_radius := 0.0
	var aura_feather := 0.3
	var aura_strength := 0.0
	# Ink on manila, measured against Lily's daily strips.
	var paper := Color(1.0, 0.93, 0.76)
	var saturation := 0.55
	var ink := Color(0.055, 0.042, 0.030)
	var halftone_px := 6.0
	var detail := 0.55
	var line_px := 2.3
	var depth_break := 0.035
	var crease_break := 0.30

	func _constants(size: Vector2i) -> PackedByteArray:
		var values := PackedFloat32Array([
			near, far, focal.x, focal.y,
			aura_center.x, aura_center.y, aura_radius, aura_feather,
			aura_strength, float(size.x) / float(size.y), float(size.y) / 1440.0, 0.0,
			paper.r, paper.g, paper.b, saturation,
			ink.r, ink.g, ink.b, halftone_px,
			detail, line_px, depth_break, crease_break])
		return values.to_byte_array()

	func _render_callback(_type: int, data: RenderData) -> void:
		if stopped or failed or not native.depth.is_valid():
			return
		if not palette_pipeline.is_valid() and not _prepare():
			return
		var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
		if buffers == null or buffers.get_view_count() != 1:
			return
		var size := buffers.get_internal_size()
		if size.x <= 0 or size.y <= 0:
			return
		var scene := data.get_render_scene_data()
		if scene != null:
			var projection := scene.get_cam_projection()
			near = projection.get_z_near()
			far = projection.get_z_far()
			focal = Vector2(absf(projection.x.x), absf(projection.y.y))
		_resize(size)
		var target := buffers.get_color_layer(0)
		var copy_set := UniformSetCacheRD.get_cache(copy_shader, 0, [
			_binding(0, scratch, false), _binding(1, target, true)])
		var filter_set := UniformSetCacheRD.get_cache(palette_shader, 0, [
			_binding(0, target, false), _binding(1, scratch, true),
			_binding(2, buffers.get_depth_layer(0), true), _binding(3, native.depth, true)])
		var constants := _constants(size)
		var x := ceili(float(size.x) / 8.0)
		var y := ceili(float(size.y) / 8.0)
		var list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list, copy_pipeline)
		rd.compute_list_bind_uniform_set(list, copy_set, 0)
		rd.compute_list_dispatch(list, x, y, 1)
		rd.compute_list_add_barrier(list)
		rd.compute_list_bind_compute_pipeline(list, palette_pipeline)
		rd.compute_list_bind_uniform_set(list, filter_set, 0)
		rd.compute_list_set_push_constant(list, constants, constants.size())
		rd.compute_list_dispatch(list, x, y, 1)
		rd.compute_list_end()
		passes += 1


var _mask: SubViewport
var _mask_camera: Camera3D
var _effect: Palette
var _comic: Comic
var _active: Palette
var _look := "stock"
var _lamp_only_set := false
var _labels_watched := false
## Adela's presence, measured while the comic look is drawn.
var presence: Node
var _camera: Camera3D
var _prior: Compositor
var _installed: Compositor


static func preserve(root: Node, layer_mask := NATIVE_LAYER) -> void:
	if root is GeometryInstance3D:
		root.layers |= layer_mask
	for draw: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		draw.layers |= layer_mask


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 180
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		set_process(false)


func _make_mask(view: Viewport) -> void:
	_mask = SubViewport.new()
	_mask.name = "CelNativeDepth"
	_mask.world_3d = view.find_world_3d()
	_mask.gui_disable_input = true
	_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mask.positional_shadow_atlas_size = 0
	add_child(_mask)
	_mask_camera = Camera3D.new()
	_mask_camera.cull_mask = NATIVE_LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	_mask_camera.environment = env
	var mask := NativeDepth.new()
	var mask_compositor := Compositor.new()
	mask_compositor.compositor_effects = [mask]
	_mask_camera.compositor = mask_compositor
	_mask.add_child(_mask_camera)
	_mask_camera.make_current()
	_effect = Palette.new(mask, FileAccess.get_file_as_string(COMPUTE))
	_comic = Comic.new(mask, FileAccess.get_file_as_string(COMIC_COMPUTE))


func _process(_delta: float) -> void:
	var view := get_viewport()
	var camera := view.get_camera_3d()
	var look := _wanted_look()
	if look != _look:
		_set_look(look)
	if look == "stock" or not is_instance_valid(camera):
		if is_instance_valid(_camera):
			_detach()
		if is_instance_valid(_mask) and _mask.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if not is_instance_valid(_mask):
		_make_mask(view)
	if _mask.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var size := Vector2i(view.get_visible_rect().size)
	if size.x > 0 and size.y > 0 and size != _mask.size:
		_mask.size = size
	# The framed companion is composited separately above the world. Only
	# include the native rig in this depth pass when this camera can see it.
	var visible_layers := NATIVE_LAYER | (DEVICE_NATIVE_LAYER if camera.cull_mask & DEVICE_WORLD_LAYER else 0)
	if _mask_camera.cull_mask != visible_layers:
		_mask_camera.cull_mask = visible_layers
	if _mask_camera.keep_aspect != camera.keep_aspect:
		_mask_camera.keep_aspect = camera.keep_aspect
	if _mask_camera.projection != camera.projection or _mask_camera.near != camera.near or _mask_camera.far != camera.far:
		_mask_camera.near = camera.near
		_mask_camera.far = camera.far
		_mask_camera.projection = camera.projection
	if _mask_camera.fov != camera.fov:
		_mask_camera.fov = camera.fov
	if _mask_camera.size != camera.size:
		_mask_camera.size = camera.size
	if _mask_camera.frustum_offset != camera.frustum_offset:
		_mask_camera.frustum_offset = camera.frustum_offset
	_mask_camera.global_transform = camera.get_camera_transform()
	var effect := _effect_for(look)
	if camera != _camera or effect != _active:
		_detach()
		_camera = camera
		_active = effect
		_prior = camera.compositor
		_installed = _prior.duplicate() as Compositor if _prior != null else Compositor.new()
		var effects := _installed.compositor_effects.duplicate()
		effects.append(effect)
		_installed.compositor_effects = effects
		camera.compositor = _installed
		effect.enabled = true
	if effect == _comic:
		_feed_aura(camera)


## The look to draw (GameBoot.world_look(); ORISON_WORLD_LOOK pins one).
func _wanted_look() -> String:
	var look: String = GameBoot.world_look()
	if not (look in LOOKS):
		push_warning("World look %s is not built; drawing the comic world" % look)
		look = "comic"
	return look


func _effect_for(look: String) -> Palette:
	return _comic if look == "comic" else _effect


## The current look, for tests and captures.
func look() -> String:
	return _look


## Everything a look owns outside the compositor: lamp-only shadows, lettering
## kept real, and Adela's presence.
func _set_look(look_name: String) -> void:
	_look = look_name
	var comic := look_name == "comic"
	if comic != _lamp_only_set:
		_lamp_only_set = comic
		ShadowPolicy.set_lamp_only(get_tree(), comic)
	_watch_labels(comic)
	if comic and presence == null:
		presence = AdelaPresence.new()
		presence.name = "AdelaPresence"
		add_child(presence)
	elif not comic and presence != null:
		presence.queue_free()
		presence = null


func _feed_aura(camera: Camera3D) -> void:
	if presence == null:
		_comic.aura_strength = 0.0
		return
	presence.camera = camera
	var aura: Dictionary = presence.aura()
	_comic.aura_center = aura.center
	_comic.aura_radius = aura.radius
	_comic.aura_feather = aura.feather
	_comic.aura_strength = aura.strength


func _watch_labels(on: bool) -> void:
	if on == _labels_watched:
		return
	_labels_watched = on
	var tree := get_tree()
	if on:
		tree.node_added.connect(_on_node_added)
	elif tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	for node: Node in tree.root.find_children("*", "Label3D", true, false):
		_keep_label(node as Label3D, on)


func _on_node_added(node: Node) -> void:
	if node is Label3D:
		_keep_label(node as Label3D, true)


func _keep_label(label: Label3D, on: bool) -> void:
	if on and not (label.layers & NATIVE_LAYER):
		label.layers |= NATIVE_LAYER
		label.set_meta(LABEL_META, true)
	elif not on and label.has_meta(LABEL_META):
		label.layers &= ~NATIVE_LAYER
		label.remove_meta(LABEL_META)


func _detach() -> void:
	if is_instance_valid(_camera) and _camera.compositor != null:
		var current := _camera.compositor
		var effects := current.compositor_effects.duplicate()
		effects.erase(_active)
		var prior_effects: Array = _prior.compositor_effects if _prior != null else []
		if current == _installed and effects == prior_effects:
			_camera.compositor = _prior
		else:
			current.compositor_effects = effects
	if _active != null:
		_active.enabled = false
	_camera = null
	_active = null
	_prior = null
	_installed = null


func _exit_tree() -> void:
	_detach()
	if _lamp_only_set:
		_lamp_only_set = false
		ShadowPolicy.set_lamp_only(get_tree(), false)
	_watch_labels(false)
	_look = "stock"
	if _effect != null:
		_effect.dispose()
	if _comic != null:
		_comic.dispose()
