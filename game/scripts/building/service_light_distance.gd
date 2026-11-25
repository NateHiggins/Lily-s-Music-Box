extends RefCounted
## Presentation only. Native fades hide the contribution before explicit culling
## avoids otherwise submitted shadow maps. No rays, target scans or saved facts.
const BEGIN_M:=4.
const LENGTH_M:=4.
const END_M:=BEGIN_M+LENGTH_M
const PAIRED_SHAFT_PRACTICALS := ["F02_SERVICE_HALL_CORE_OPENING", "F04_SERVICE_HALL_CORE_OPENING"]
var policy: Node
var world: Node3D
var enabled:=false
var originals: Array=[]
var switches:=0
var last_tick_usec:=0
var reflections: Node

func _init(owner_policy: Node) -> void:
	policy=owner_policy;world=policy.world
	reflections=world.get_node_or_null("V2RoomReflections")
	for source: Dictionary in policy.sources:
		var light: Light3D=source.light
		var row := {"source":source,"shadow":light.shadow_enabled,"fade":light.distance_fade_enabled,"begin":light.distance_fade_begin,"length":light.distance_fade_length,"shadow_distance":light.distance_fade_shadow}
		if light is OmniLight3D and source.shaft and source.adjacent_shadow_paraboloid:
			row.omni_mode = light.omni_shadow_mode
		originals.append(row)

func set_enabled(value: bool) -> void:
	if value==enabled:return
	enabled=value
	for row: Dictionary in originals:
		var light: Light3D=row.source.light
		if not is_instance_valid(light):continue
		light.distance_fade_enabled=true if value else row.fade
		light.distance_fade_begin=BEGIN_M if value else row.begin
		light.distance_fade_length=LENGTH_M if value else row.length
		light.distance_fade_shadow=BEGIN_M if value else row.shadow_distance
		if not value:light.shadow_enabled=row.shadow
	tick()

func _near(point: Vector3,eyes: Array[Vector3]) -> bool:
	for eye: Vector3 in eyes:
		if point.distance_squared_to(eye)<END_M*END_M:return true
	return false

## Near an eye that can see it: any storey for a source on a shaft, only its
## own storey for one sealed by slabs.
func _seen(source: Dictionary,eyes: Array[Vector3]) -> bool:
	var point: Vector3=source.light.global_position
	for eye: Vector3 in eyes:
		if point.distance_squared_to(eye)>=END_M*END_M:continue
		if source.shaft or policy.level_at(eye)==source.level:return true
	return false

## Use the measured two-pass map for these shaft lights when all observing
## cameras are on other storeys. A local player or mirror keeps the fitted map.
func _shaft_shadow_mode(light: OmniLight3D, row: Dictionary, shadow: bool,
		eyes: Array[Vector3]) -> void:
	var mode: int = row.omni_mode
	if enabled and shadow and policy.spaces.has(policy.context_room):
		var source: Dictionary = row.source
		var local_view := eyes.any(func(eye: Vector3) -> bool:
			return policy.level_at(eye) == source.level)
		if not local_view:
			mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	if light.omni_shadow_mode != mode:
		light.omni_shadow_mode = mode


func tick() -> void:
	var started: int=Time.get_ticks_usec()
	var shadow_eyes: Array[Vector3]=[]
	if enabled:
		var camera: Camera3D=world.get_viewport().get_camera_3d()
		if camera==null:camera=world.player.camera
		shadow_eyes.append(camera.global_position)
		if is_instance_valid(world.mirror_renderer):
			var reflected: Camera3D=world.mirror_renderer.active_camera()
			if reflected!=null:shadow_eyes.append(reflected.global_position)
	var color_eyes: Array[Vector3]=shadow_eyes.duplicate()
	if enabled and is_instance_valid(reflections):color_eyes.append_array(reflections.capture_positions())
	policy.visible_sources.clear()
	for row: Dictionary in originals:
		var source: Dictionary=row.source
		var light: Light3D=source.light
		if not is_instance_valid(light):continue
		var visible: bool=source.visible and source.graph_visible and (not enabled or _seen(source,color_eyes))
		var shadow: bool=row.shadow and (not enabled or (visible and _seen(source,shadow_eyes)))
		if light.visible!=visible:light.visible=visible;switches+=1
		if row.has("omni_mode"):
			_shaft_shadow_mode(light as OmniLight3D, row, shadow, shadow_eyes)
		if light.shadow_enabled!=shadow:light.shadow_enabled=shadow;switches+=1
		if visible:policy.visible_sources.append(source.id)
	last_tick_usec=Time.get_ticks_usec()-started
