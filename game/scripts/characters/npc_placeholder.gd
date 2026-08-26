class_name NPCPlaceholder
extends Node3D
## Temporary resident actor made from the approved character concept sheet.
## It faces the camera around Y only, remains grounded, casts a cutout shadow,
## and reserves roughly the same footprint as the eventual rigged character.

var display_name := ""
var texture_path := ""
var resident_id := ""
var unit := ""
var _nameplate: Label3D


func setup(character_name: String, source_texture: String,
		character_id := "", apartment_unit := "") -> void:
	display_name = character_name
	texture_path = source_texture
	resident_id = character_id if character_id != "" \
			else character_name.to_snake_case()
	unit = apartment_unit


func _ready() -> void:
	name = "NPC_" + display_name.to_snake_case()
	add_to_group("resident_placeholders")
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("NPC sprite missing: %s" % texture_path)
		return
	var sprite := Sprite3D.new()
	sprite.name = "CharacterSprite"
	sprite.texture = texture
	sprite.pixel_size = 1.72 / float(texture.get_height())
	sprite.position.y = 0.86
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.18
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(sprite)

	# The footprint is reserved but NOT collidable, and that is deliberate.
	# Placeholders are dropped at the centre of each resident's main room,
	# which is exactly where the route from the unit door to the bedroom
	# door runs — Mina stood squarely in 2A's and WalkTest could no longer
	# walk a capsule to the bed. Reachability in this building is proven by
	# physics and gated by the generator's movement audit, and that audit
	# authors furniture positions with clearances; it knows nothing about
	# actors placed later in Godot. Solid residents therefore have to come
	# from gen_layout, so the same pass that guarantees the route is the one
	# that puts a person on it. Until then they are scenery: visible,
	# shadow-casting, and walk-through.
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 0
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.55
	collision.shape = capsule
	collision.position.y = 0.775
	body.add_child(collision)
	add_child(body)

	var interaction := Area3D.new()
	interaction.name = "Interaction"
	var interaction_shape := CollisionShape3D.new()
	var interaction_capsule := CapsuleShape3D.new()
	interaction_capsule.radius = 0.42
	interaction_capsule.height = 1.72
	interaction_shape.shape = interaction_capsule
	interaction_shape.position.y = 0.86
	interaction.add_child(interaction_shape)
	add_child(interaction)

	if GameBoot.developer_overlays_enabled():
		_nameplate = Label3D.new()
		_nameplate.name = "DeveloperResidentNameplate"
		_nameplate.position.y = 1.88
		_nameplate.font_size = 34
		_nameplate.pixel_size = 0.002
		_nameplate.modulate = Color(0.82, 0.84, 0.80, 0.72)
		_nameplate.outline_modulate = Color(0.02, 0.025, 0.03, 0.9)
		_nameplate.outline_size = 8
		_nameplate.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_nameplate.no_depth_test = false
		add_child(_nameplate)
	RealityCases.case_changed.connect(_on_case_changed)
	_refresh_nameplate()


func interact_prompt() -> String:
	return "[E]  Speak with %s" % display_name


func interact(_player: Node) -> void:
	var music := get_tree().get_first_node_in_group("music_director")
	if music and music.try_music_conversation(resident_id):
		return
	RealityCases.interact_with_resident(resident_id)


func _on_case_changed(case_id: String, _state: Dictionary) -> void:
	if RealityCases.case_for_resident(resident_id) == case_id:
		_refresh_nameplate()


func _refresh_nameplate() -> void:
	if _nameplate == null:
		return
	var case_id := RealityCases.case_for_resident(resident_id)
	var state: Dictionary = RealityState.case_state(case_id)
	var stage: String = state.get("stage", "unseen")
	var suffix := ""
	if stage in ["active", "reopened", "integration_ready"]:
		suffix = "\n[%s]" % stage.replace("_", " ").to_upper()
	elif stage == "resolved":
		suffix = "\n[STABLE]"
	_nameplate.text = "%s · %s%s" % [display_name, unit, suffix]
