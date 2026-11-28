extends Node
## The world is more real in Adela's presence (Lily 2026-11-28; rulings
## adela_presence_rule_20261128 "Live" and adela_presence_turn_20261128 "slow
## bleed"). In the comic world a round aura of the real render sits on her on
## screen. Close enough to speak with her and centred on her, her figure and a
## circle round her are real and the frame's edges are comic, with a soft
## radial fade between (her direction, 2026-11-28).
##
## Presence is live: she must be on stage in the player's scene, near, and in
## clear sight. It bleeds in and out over BLEED_SECONDS, never a cut, and the
## aura grows out from her as it bleeds in. This node reads her body's
## position only; it never moves, poses, schedules or speaks for her.

const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const BODY_PATTERN := "*adela_voss*"
const BLEED_SECONDS := 1.5
const NEAR_M := 3.0          # full presence at or inside this distance
const FAR_M := 9.0           # no presence beyond this distance
const FOCUS_RISE_M := 1.35   # the aura centres on her chest and face
const RADIUS_M := 0.70       # fully real out to this far round her
const FEATHER_M := 1.2       # then the fade to the comic world
const BLEED_GROWTH := 0.35   # the aura starts at this share of its size
const SIGHT_SLACK_M := 0.6
const REFIND_SECONDS := 2.0

var camera: Camera3D
var presence := 0.0
var target_presence := 0.0
var adela: Node3D
var _refind := 0.0


func _ready() -> void:
	process_priority = 170


func _process(delta: float) -> void:
	_refind -= delta
	if _refind <= 0.0 or not is_instance_valid(adela) or not adela.is_visible_in_tree():
		adela = _find_adela()
		_refind = REFIND_SECONDS
	target_presence = _measure()
	presence = move_toward(presence, target_presence, delta / BLEED_SECONDS)


## Her whole cast body (a cast model presentation) while it is on stage.
func _find_adela() -> Node3D:
	for node: Node in get_tree().root.find_children(BODY_PATTERN, "Node3D", true, false):
		if node is CastModel and (node as Node3D).is_visible_in_tree():
			return node as Node3D
	return null


func focus() -> Vector3:
	return adela.global_position + Vector3.UP * FOCUS_RISE_M


func _measure() -> float:
	if not is_instance_valid(camera) or not is_instance_valid(adela) or not adela.is_visible_in_tree():
		return 0.0
	var head := focus()
	var eye := camera.global_position
	var distance := eye.distance_to(head)
	if distance >= FAR_M:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(eye, head)
	query.exclude = _own_bodies()
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit.position as Vector3).distance_to(head) > SIGHT_SLACK_M:
		var collider: Object = hit.collider
		if not (collider is Node and adela.is_ancestor_of(collider as Node)):
			return 0.0
	return 1.0 - smoothstep(NEAR_M, FAR_M, distance)


func _own_bodies() -> Array[RID]:
	var found: Array[RID] = []
	var node: Node = camera
	while node != null:
		if node is CollisionObject3D:
			found.append((node as CollisionObject3D).get_rid())
		node = node.get_parent()
	return found


## The aura in screen terms for the comic filter: centre in uv, radius and
## feather in frame heights, and its strength 0..1.
func aura() -> Dictionary:
	var none := {"center": Vector2(0.5, 0.5), "radius": 0.0, "feather": 0.3, "strength": 0.0}
	if presence <= 0.0005 or not is_instance_valid(camera) or not is_instance_valid(adela):
		return none
	var point := focus()
	if camera.is_position_behind(point):
		return none
	var depth := -(camera.global_transform.affine_inverse() * point).z
	if depth <= 0.01:
		return none
	var view := camera.get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return none
	var frame_height := 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		frame_height *= view.y / view.x
	var grown := lerpf(BLEED_GROWTH, 1.0, smoothstep(0.0, 1.0, presence))
	var on_screen := camera.unproject_position(point) / view
	return {"center": on_screen, "radius": RADIUS_M / frame_height * grown,
		"feather": FEATHER_M / frame_height * grown, "strength": smoothstep(0.0, 1.0, presence)}
