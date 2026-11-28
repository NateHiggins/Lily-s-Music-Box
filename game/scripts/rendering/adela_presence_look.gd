extends Node
## Prototype (Lily 2026-11-28; rulings adela_presence_rule_20261128 "Live" and
## adela_presence_turn_20261128 "slow bleed"). The world is drawn as a comic
## everywhere, and real around Adela while she is in the scene with the
## player: the filter's realism bubble follows her body, grows as the player
## nears her, needs a clear line of sight, and bleeds in and out over
## BLEED_SECONDS. It reads her body's position only; it never moves, poses or
## schedules her.

const FILTER := preload("res://shaders/comic_cel_preview.gdshader")
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const BLEED_SECONDS := 1.5
const NEAR_M := 2.5        # full presence at or inside this distance
const FAR_M := 12.0        # no presence beyond this distance
const HEAD_RISE_M := 1.5
const REFIND_SECONDS := 2.0

var camera: Camera3D
var exclude: Array[RID] = []
var presence := 0.0
var target_presence := 0.0
var adela: Node3D
var _quad: MeshInstance3D
var _material: ShaderMaterial
var _refind := 0.0


func attach(view: Camera3D, excluded: Array[RID] = []) -> void:
	camera = view
	exclude = excluded
	_quad = MeshInstance3D.new()
	_quad.name = "ComicLook"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_quad.mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = FILTER
	_quad.material_override = _material
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mask := camera.cull_mask
	_quad.layers = mask & -mask if mask != 0 else 1
	camera.add_child(_quad)
	_quad.position = Vector3(0, 0, -0.5)


func set_enabled(on: bool) -> void:
	if _quad != null:
		_quad.visible = on


func _find_adela() -> Node3D:
	# Her whole cast body (a cast model presentation), never one of its parts.
	for node: Node in get_tree().root.find_children("*adela_voss*", "Node3D", true, false):
		if node is CastModel and (node as Node3D).is_visible_in_tree():
			return node as Node3D
	return null


func _process(delta: float) -> void:
	if camera == null or _material == null:
		return
	_refind -= delta
	if _refind <= 0.0 or not is_instance_valid(adela) or not adela.is_visible_in_tree():
		adela = _find_adela()
		_refind = REFIND_SECONDS
	target_presence = _measure_presence()
	presence = move_toward(presence, target_presence, delta / BLEED_SECONDS)
	_material.set_shader_parameter("presence", presence)
	if is_instance_valid(adela):
		_material.set_shader_parameter("adela_world", adela.global_position + Vector3.UP * HEAD_RISE_M * 0.6)


func _measure_presence() -> float:
	if not is_instance_valid(adela) or not adela.is_visible_in_tree():
		return 0.0
	var head := adela.global_position + Vector3.UP * HEAD_RISE_M
	var eye := camera.global_position
	var distance := eye.distance_to(head)
	if distance >= FAR_M:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(eye, head)
	query.exclude = exclude
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit.position as Vector3).distance_to(head) > 0.6:
		var collider: Object = hit.collider
		if not (collider is Node and adela.is_ancestor_of(collider as Node)):
			return 0.0
	return 1.0 - smoothstep(NEAR_M, FAR_M, distance)
