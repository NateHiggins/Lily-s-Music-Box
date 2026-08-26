class_name AnimatedResident
extends Node3D
## Rigged resident actor. Mina uses a short, route-safe pacing behavior during
## active manifestations so both baked IK clips are exercised in game.

var display_name := ""
var resident_id := ""
var unit := ""
var model_path := ""
var _model: Node3D
var _animation_player: AnimationPlayer
var _nameplate: Label3D
var _home := Vector3.ZERO
var _pace_direction := 1.0
var _pace_clock := 0.0
var _walking := false
## ResidentRoutines owns building navigation once the actor is registered.
## The local Mina-era pacing behavior remains available for isolated tests.
var externally_driven := false


func setup(character_name: String, character_id: String,
		apartment_unit: String, source_model: String) -> void:
	display_name = character_name
	resident_id = character_id
	unit = apartment_unit
	model_path = source_model


func _ready() -> void:
	name = "NPC_" + display_name.to_snake_case()
	add_to_group("resident_placeholders")
	add_to_group("animated_residents")
	_home = position
	var scene := load(model_path) as PackedScene
	if scene == null:
		push_warning("Animated resident model missing: " + model_path)
		return
	_model = scene.instantiate()
	_model.name = "RiggedCharacter"
	add_child(_model)
	_apply_presence_glow(_model)
	_animation_player = _find_animation_player(_model)
	# Hero-pipeline models ship motion-free by contract; their clips come
	# from the shared library, or from a personal <model>_moves.glb bake
	# when the rig is a newer Meshy generation (mina_vale is the first).
	# The old generated cast carries its own baked player and skips this.
	if _animation_player == null:
		ResidentMovesLibrary.apply(_model)
		_animation_player = _find_animation_player(_model)
	_build_interaction()
	_build_nameplate()
	RealityCases.case_changed.connect(_on_case_changed)
	_play_named("idle")
	_refresh_nameplate()


## Restored at half strength (ruled 2026-08-05). A resident is never a
## pure void in the dark, but the wash has to stay under the ambient
## floor or the cast lights itself again - which is the bug this session
## removed from the models. Flat colour, no texture: gl_compatibility
## adds an emission TEXTURE at near-full strength whatever the emission
## colour says.
const PRESENCE_GLOW := Color(0.0275, 0.035, 0.056)


func _apply_presence_glow(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		for s in range(mesh_node.get_surface_override_material_count()):
			_glow_material(mesh_node.get_active_material(s))
	for child in node.get_children():
		_apply_presence_glow(child)


func _glow_material(material: Material) -> void:
	var standard := material as StandardMaterial3D
	if standard == null:
		return
	# Meshy hero exports omit metallicFactor, and glTF defaults it to 1.0:
	# a fully metallic body reflects the room's one warm light away from
	# the eye and renders as a black cutout inside a visibly lit room (the
	# 2026-08-15 walkthrough's black-resident family — same physics as the
	# kitchen flat-metal lesson). People are cloth and skin: dielectric.
	if standard.metallic > 0.5:
		standard.metallic = 0.0
		standard.roughness = maxf(standard.roughness, 0.65)
	standard.emission_enabled = true
	standard.emission = PRESENCE_GLOW
	standard.emission_energy_multiplier = 1.0


func _build_interaction() -> void:
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
	interaction_capsule.radius = 0.43
	interaction_capsule.height = 1.72
	interaction_shape.shape = interaction_capsule
	interaction_shape.position.y = 0.86
	interaction.add_child(interaction_shape)
	add_child(interaction)


func _build_nameplate() -> void:
	if not GameBoot.developer_overlays_enabled():
		return
	_nameplate = Label3D.new()
	_nameplate.name = "DeveloperResidentNameplate"
	_nameplate.position.y = 1.88
	_nameplate.font_size = 34
	_nameplate.pixel_size = 0.002
	_nameplate.modulate = Color(0.82, 0.84, 0.80, 0.72)
	_nameplate.outline_modulate = Color(0.02, 0.025, 0.03, 0.9)
	_nameplate.outline_size = 8
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(_nameplate)


func _process(delta: float) -> void:
	if externally_driven:
		return
	var case_id := RealityCases.case_for_resident(resident_id)
	var state: Dictionary = RealityState.case_state(case_id)
	var active: bool = state.get("stage", "unseen") in ["active", "reopened"]
	if not active:
		position = position.lerp(_home, minf(1.0, delta * 1.8))
		_set_walking(false)
		return
	_pace_clock += delta
	# A hesitant three-step pace contained to 70 cm around the authored spot.
	var target := _home + Vector3(_pace_direction * 0.35, 0, 0)
	var before := position
	position = position.move_toward(target, delta * 0.48)
	if position.distance_to(target) < 0.025:
		_pace_direction *= -1.0
		_pace_clock = 0.0
	_set_walking(position.distance_to(before) > 0.0001)
	if _walking:
		rotation.y = lerp_angle(rotation.y,
				PI * 0.5 if _pace_direction > 0 else -PI * 0.5,
				minf(1.0, delta * 7.0))


func _set_walking(on: bool) -> void:
	if _walking == on:
		return
	_walking = on
	_play_named("walk" if on else "idle")


## Case beats may borrow the actor: the dialogue tree asks for roles like
## 'strained' or 'recognition' at its deeper layers. Returns false while
## the named clip hasn't shipped, so cases can request roles ahead of the
## animation set arriving from the prompt sheet.
func play_case_role(fragment: String) -> bool:
	if _animation_player == null:
		return false
	for animation_name in _animation_player.get_animation_list():
		if fragment.to_lower() in str(animation_name).to_lower():
			_animation_player.play(animation_name, 0.35)
			return true
	return false


func _play_named(fragment: String) -> void:
	if _animation_player == null:
		return
	for animation_name in _animation_player.get_animation_list():
		if fragment.to_lower() in str(animation_name).to_lower():
			_animation_player.play(animation_name, 0.22)
			return


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


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
