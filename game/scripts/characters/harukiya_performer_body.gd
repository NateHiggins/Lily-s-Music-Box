extends "res://scripts/characters/harukiya_staff_body.gd"
## A measured cast presentation with the existing resident conversation entry.
## The area is a ray target, not a blocking body or a new dialogue owner.
var presence_query: Callable
var conversation_owner: ResidentConversations
var interaction: Area3D

func _ready() -> void:
	super._ready()
	if not ready_ok:return
	interaction=Area3D.new()
	interaction.name="Interaction"
	interaction.collision_layer=1 if _active else 0
	interaction.collision_mask=0
	interaction.monitoring=false
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.43
	capsule.height=1.72
	shape.shape=capsule
	shape.position.y=.86
	interaction.add_child(shape)
	add_child(interaction)

func set_active(enabled: bool) -> void:
	super.set_active(enabled)
	if is_instance_valid(interaction):interaction.collision_layer=1 if enabled else 0

func _available() -> bool:
	return _active and ready_ok and presence_query.is_valid() and bool(presence_query.call())

func interact_prompt() -> String:
	if not _available():return ""
	var performances:=get_tree().get_first_node_in_group("loop_performances")
	if performances!=null:
		var prompt:=str(performances.conversation_prompt(person_id))
		if not prompt.is_empty():return prompt
	return "[E]  Speak with Adela"

func interact(_player: Node) -> void:
	# This is the existing stationary-staff admission path. It already offers
	# earned performances/music and the authored tree without inventing a case.
	if _available() and conversation_owner!=null:conversation_owner.start(person_id)
