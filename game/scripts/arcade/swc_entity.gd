class_name SwcEntity
extends Node3D

## One gameplay object in the world, and the only place presentation is allowed to
## attach itself.
##
## The node layout is the architectural rule made physical (spec §11):
##
##     SwcEntity
##      |- GameplayCollision      <- authoritative, built from the semantic scene
##      |- InteractionLogic       <- authoritative, gameplay scripts
##      |- SwcGraybox                <- readable fallback, always available
##      +- PresentationAnchor     <- the ONLY node a World Package may populate
##
## Swapping worlds replaces the contents of PresentationAnchor and nothing else.
## Because the first three are siblings rather than children of it, no skin can
## reach them.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_PROP := 8
const LAYER_TRIGGER := 16

var semantic_id: String = ""
var semantic_type: String = ""
var data: Dictionary = {}

## Set for entities whose visual should swing/move independently of the entity
## origin (a door leaf rotates about its hinge). Presentation and graybox both
## live under it, so a skin inherits the motion for free.
var motion_root: Node3D = null

var graybox_root: Node3D = null
var presentation_anchor: Node3D = null
var collision_root: Node3D = null
var label: Label3D = null

## Filled by the package binder; read by gameplay for sound events.
var audio_streams: Dictionary = {}

## What the currently loaded world calls this object. Presentation only - it never
## affects behaviour, and it resets to the semantic type when no package is loaded.
var display_label: String = ""

## True when the presentation anchor holds a template, not a placement.
var prototype_only: bool = false


func setup(entity: Dictionary) -> void:
	data = entity
	semantic_id = String(entity.get("semantic_id", ""))
	semantic_type = String(entity.get("type", ""))
	name = semantic_id

	position = SwcScene.position_of(entity)
	rotation_degrees = Vector3(0.0, SwcScene.yaw_of(entity), 0.0)
	scale = SwcScene.scale_of(entity)

	motion_root = self

	collision_root = Node3D.new()
	collision_root.name = "GameplayCollision"
	add_child(collision_root)

	graybox_root = Node3D.new()
	graybox_root.name = "SwcGraybox"
	graybox_root.add_to_group(SwcViewModes.GROUP_GRAYBOX)
	add_child(graybox_root)

	presentation_anchor = Node3D.new()
	presentation_anchor.name = "PresentationAnchor"
	presentation_anchor.add_to_group(SwcViewModes.GROUP_PRESENTATION)
	add_child(presentation_anchor)


## Marks this entity's skin as a template rather than something to draw here.
## Used by enemy_spawn, whose binding dresses the enemies it produces.
func make_prototype_only() -> void:
	prototype_only = true
	presentation_anchor.remove_from_group(SwcViewModes.GROUP_PRESENTATION)
	presentation_anchor.visible = false


## Re-parent the visual and collision roots under a pivot, so a moving part
## rotates about a gameplay-defined axis rather than about its own centre.
func install_motion_pivot(pivot_offset: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "MotionPivot"
	pivot.position = pivot_offset
	add_child(pivot)

	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = -pivot_offset
	pivot.add_child(leaf)

	for child: Node3D in [collision_root, graybox_root, presentation_anchor]:
		remove_child(child)
		leaf.add_child(child)

	motion_root = pivot
	return pivot


func build_graybox() -> void:
	for instance in SwcGraybox.build_mesh_instances(data):
		graybox_root.add_child(instance)


func clear_presentation() -> void:
	for child in presentation_anchor.get_children():
		presentation_anchor.remove_child(child)
		child.queue_free()
	audio_streams.clear()
	display_label = ""


func label_or_type() -> String:
	return display_label if not display_label.is_empty() else semantic_type


func has_presentation() -> bool:
	return presentation_anchor.get_child_count() > 0


func ensure_label(text: String) -> void:
	if label != null:
		label.text = text
		return
	label = Label3D.new()
	label.name = "SemanticLabel"
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0032
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = SwcGraybox.color_for(semantic_type)
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.85)
	var size := SwcScene.size_of(data)
	label.position = SwcScene.bounds_offset_of(data) + Vector3(0.0, size.y * 0.5 + 0.24, 0.0)
	label.add_to_group(SwcViewModes.GROUP_LABELS)
	add_child(label)


func play_sound(event: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = audio_streams.get(event)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = "Interaction"
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 8.0
	player.max_distance = 40.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func param(key: String, fallback: Variant) -> Variant:
	return SwcScene.params_of(data).get(key, fallback)


## Walk up from a collider to the semantic entity that owns it.
## Gameplay code always resolves a hit back to its semantic identity rather than
## to whatever node the physics engine reported.
static func owning_entity(node: Node) -> SwcEntity:
	var current := node
	while current != null:
		if current is SwcEntity:
			return current
		current = current.get_parent()
	return null
