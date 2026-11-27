class_name AnimatedResident
extends Node3D
## Rigged resident actor. Mina's supplied batch has its own playback owner;
## isolated manifestations retain the short, contained pacing behavior.

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
var preferred_idle := ""
var preferred_walk := ""
var face_interacting_player := false
## Some authored encounters admit only the topic installed with this body.
var installed_topic := ""
var topic_is_present: Callable
## Stationary scenes can keep the fitted stand pose instead of a walking-rig idle.
var use_cast_stand_pose := false
var mina_animation: MinaAnimationBehavior
## Distance matching on the generic path (NPC repair pilot, order w3473eaaf58a9): the walk is measured on the
## rebuilt body and played each frame at the rate that keeps its planted foot on the floor. Residents join in
## batches once the pilot qualifies; the rest keep the plain 1x walk.
const GAIT_PILOT := ["malcolm_reed",
		"evelyn_marsh", "teresa_vale", "peter_wren", "noel_price",
		"lena_ortiz", "juno_kells", "rhea_sato", "cal_dwyer", "jonah_price", "transient_guests",
		"cam_ortiz", "iris_bell", "mae_kessler", "nadia_quell", "omar_bell", "sacha_reed"]
var walk_gait: ClipGait
## The male cast base's long shin: its shared walk may slow further on stairs (ClipGait.STAIR_MIN_SCALE). A route
## slope this steep or steeper is a stair; the house's run 0.16 m in 0.285 m.
const LONG_SHIN := 0.40
const STAIR_SLOPE := 0.3
var long_legged := false
var _route_slope := 0.0
## Walking foot placement (Lily's ruling npc_generic_stairs_20261124): feet land on the tread under them. The two
## pilot bodies first, one per cast base; then batches (batch one by her ruling npc_feet_descent_backswing_20261124,
## "widen to more residents"): two more of each base; batch two, three more of each; batch three, the last six.
## Every regular resident is now in both gates. Adela (staff, not a resident) stays outside them.
const FEET_PILOT := ["mina_vale", "malcolm_reed",
		"evelyn_marsh", "teresa_vale", "peter_wren", "noel_price",
		"lena_ortiz", "juno_kells", "rhea_sato", "cal_dwyer", "jonah_price", "transient_guests",
		"cam_ortiz", "iris_bell", "mae_kessler", "nadia_quell", "omar_bell", "sacha_reed"]
const WalkingFeet := preload("res://scripts/characters/walking_feet.gd")
var walking_feet: Node
var _ground_speed := 0.0
## The one owner of where this resident looks; null on a body with no rig profile.
var attention: Node
## The rebuilt body's presentation when this resident wears one (CastBodies), else null.
var cast_body: Node3D

const CastPresentation := preload("res://scripts/characters/cast_model_presentation.gd")
const WardrobeRules := preload("res://scripts/characters/wardrobe_rules.gd")


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
	# A resident on the cast list wears the rebuilt body (CastBodies). If it is refused, the old body stands in
	# its place: a refusal is logged, never an empty place.
	if CastBodies.is_cast_path(model_path) and not _build_cast_body():
		push_warning("Resident %s: rebuilt body refused, old body used" % resident_id)
		model_path = CastBodies.old_model(resident_id)
	if cast_body == null:
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
	if _animation_player == null and cast_body == null:
		ResidentMovesLibrary.apply(_model)
		_animation_player = _find_animation_player(_model)
	if resident_id == "mina_vale":
		var behavior := preload("res://scripts/characters/mina_animation_behavior.gd").new()
		var gait_skeleton: Skeleton3D = cast_body.skeleton if cast_body != null else null
		if behavior.install(_animation_player, gait_skeleton, CastBodies.cast_person(resident_id)):
			mina_animation = behavior
			preferred_idle = "mina_idle_calm"
			preferred_walk = "mina_walk"
		else:
			push_error("Mina Gray Resolve batch is incomplete")
	elif resident_id in GAIT_PILOT and cast_body != null and _animation_player != null and _animation_player.has_animation(preferred_walk):
		walk_gait = ClipGait.measure(_animation_player, cast_body.skeleton, preferred_walk, CastBodies.cast_person(resident_id))
		long_legged = _shin_length(cast_body.skeleton) >= LONG_SHIN
	if resident_id in FEET_PILOT and cast_body != null:
		var owner_of_attention: Node = cast_body.get("attention")
		if owner_of_attention != null and owner_of_attention.pipeline != null:
			walking_feet = WalkingFeet.install(self, owner_of_attention.pipeline)
	# The rebuilt body brings its own attention owner; a second one would fight it.
	if cast_body == null:
		attention = preload("res://scripts/characters/resident_attention.gd").install(self, _model, resident_id)
	_build_interaction()
	_build_nameplate()
	RealityCases.case_changed.connect(_on_case_changed)
	_play_named("idle")
	_refresh_nameplate()


## The rebuilt body: the cast presentation (clothes, face, hair, attention) dressed by the wardrobe rules for
## an ordinary day at home, with the shared cast clips as its base pose. Changing clothes through the day is a
## later step. Its own materials stay: no atlas and no presence wash (decided from a night comparison later).
func _build_cast_body() -> bool:
	var who := CastBodies.cast_person(resident_id)
	var probe: RefCounted = CastPresentation.Wardrobe.new()
	probe.person_id = who
	probe.read_wardrobe(model_path.get_base_dir())
	var rules := WardrobeRules.new()
	if not rules.load_table():
		return false
	var at_home := {"place": "home", "activity": "rest"}
	var parts: Array = rules.parts_for(who, rules.choose(who, at_home), probe.notes, "", at_home).parts
	var body: Node3D = CastPresentation.new()
	body.name = "CastBody"
	body.configure(who, model_path, parts)
	add_child(body)
	var player: AnimationPlayer = body.drive_with_clips() if body.ready_ok and not use_cast_stand_pose else null
	if not body.ready_ok or (player == null and not use_cast_stand_pose):
		remove_child(body)
		body.queue_free()
		return false
	cast_body = body
	_model = body.model
	_animation_player = player
	attention = body.attention
	var speech: Node = preload("res://scripts/characters/cast_resident_speech.gd").new()
	speech.name = "CastSpeech"
	speech.body = body
	speech.resident_id = resident_id
	add_child(speech)
	return true


var _rules: RefCounted


## Change into what the wardrobe rules name for a dressing (Lily 2026-11-12: clothes change by the rules,
## out of sight; the caller makes sure nobody is looking). True when the clothes changed. A refused change
## leaves the person as they were.
func dress_for(dressing: Dictionary) -> bool:
	var parts := outfit_change_for(dressing)
	if parts.is_empty():
		return false
	var asked := _outfit_key
	var changed := bool(cast_body.wear(parts))
	# A wear that leaves the worn parts as they were (refused, or the outfit folds a part into another slot)
	# would only repeat itself: not again until the dressing or the worn parts change.
	var worn: Array = (cast_body.worn_parts() as Array).duplicate()
	worn.sort()
	if var_to_str([dressing, worn]) == asked:
		_outfit_parts = []
	return changed


var _outfit_key := ""
var _outfit_parts: Array = []

## The parts the wardrobe rules want for a dressing, or none when they are worn already or nothing applies.
## The rules are a table lookup on the dressing alone, so the answer is kept until the dressing or the worn
## parts change (frame time, 24 Nov: every resident asked on the same tick twice a second).
func outfit_change_for(dressing: Dictionary) -> Array:
	if cast_body == null or not bool(cast_body.ready_ok):
		return []
	if _rules == null:
		_rules = WardrobeRules.new()
		if not _rules.load_table():
			_rules = null
			return []
	var worn: Array = (cast_body.worn_parts() as Array).duplicate()
	worn.sort()
	var key := var_to_str([dressing, worn])
	if key != _outfit_key:
		var who := CastBodies.cast_person(resident_id)
		var outfit: String = _rules.choose(who, dressing)
		var parts: Array = _rules.parts_for(who, outfit, cast_body.wardrobe.notes, str(dressing.get("date", "")), dressing).parts
		var wanted := parts.duplicate()
		wanted.sort()
		_outfit_parts = [] if parts.is_empty() or wanted == worn else parts.duplicate()
		_outfit_key = key
	return _outfit_parts.duplicate()


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


const NAMEPLATE_GAP := 0.14
## Where an unmeasurable body's plate sits: a little above the tallest old body.
const NAMEPLATE_FALLBACK := 1.88


## The top of the body as built (head, hair, hat), in the actor's own space, from its meshes' rest bounds: the
## rebuilt cast runs 1.52-1.81 m and one fixed height floated the developer plate 35 cm above the shortest.
func _top_of_body() -> float:
	var top := -INF
	if _model != null and is_inside_tree():
		var to_actor := global_transform.affine_inverse()
		for node in _model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
				continue
			top = maxf(top, ((to_actor * mesh_node.global_transform) * mesh_node.get_aabb()).end.y)
	if top < 0.5:
		return NAMEPLATE_FALLBACK - NAMEPLATE_GAP
	return top


func _build_nameplate() -> void:
	if not GameBoot.developer_overlays_enabled():
		return
	_nameplate = Label3D.new()
	_nameplate.name = "DeveloperResidentNameplate"
	_nameplate.position.y = _top_of_body() + NAMEPLATE_GAP
	_nameplate.font_size = 34
	_nameplate.pixel_size = 0.002
	_nameplate.modulate = Color(0.82, 0.84, 0.80, 0.72)
	_nameplate.outline_modulate = Color(0.02, 0.025, 0.03, 0.9)
	_nameplate.outline_size = 8
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(_nameplate)


func _process(delta: float) -> void:
	if mina_animation:
		mina_animation.update(delta)
	_match_ground()
	if externally_driven:
		return
	if mina_animation and (mina_animation.conversation_active or mina_animation.route_busy): return
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
	_ground_speed = 0.48 if _walking else 0.0
	if _walking:
		rotation.y = lerp_angle(rotation.y,
				PI * 0.5 if _pace_direction > 0 else -PI * 0.5,
				minf(1.0, delta * 7.0))


func _set_walking(on: bool) -> void:
	if mina_animation:
		_walking = on
		mina_animation.set_motion(on)
		return
	if walking_feet != null:
		walking_feet.walking = on
	if _walking == on:
		return
	_walking = on
	if not on and walk_gait != null and _animation_player != null:
		_animation_player.speed_scale = 1.0
	_play_named("walk" if on else "idle")


## While a measured walk plays, its speed scale follows the clip's own planted-foot speed at its current point in
## the cycle, so the foot stays where it landed.
func _match_ground() -> void:
	if walk_gait == null or not _walking or _ground_speed <= 0.0 or _animation_player == null:
		return
	if str(_animation_player.current_animation) != preferred_walk:
		return
	var lowest := ClipGait.STAIR_MIN_SCALE if long_legged and absf(_route_slope) >= STAIR_SLOPE else ClipGait.MIN_SCALE
	_animation_player.speed_scale = walk_gait.scale_for(_animation_player.current_animation_position, _ground_speed, lowest)


## The rest length of the left shin. Measured 2026-11-25 on all seventeen generic bodies: the male base 0.405-0.486 m
## (Cam shortest), the female 0.377-0.397 m. LONG_SHIN sits in that gap; NpcPilotGenericGaitTest holds the split.
static func _shin_length(skeleton: Skeleton3D) -> float:
	var knee := skeleton.find_bone("LeftLeg")
	var ankle := skeleton.find_bone("LeftFoot")
	if knee < 0 or ankle < 0:
		return 0.0
	return skeleton.get_bone_global_rest(knee).origin.distance_to(skeleton.get_bone_global_rest(ankle).origin)


func set_route_motion(on: bool, slope: float, metres_per_second: float) -> void:
	if walking_feet != null:
		walking_feet.walking = on
	if mina_animation:
		_walking = on
		mina_animation.set_motion(on, slope, metres_per_second)
	else:
		_set_walking(on)
		_ground_speed = metres_per_second if on else 0.0
		_route_slope = slope if on else 0.0


## Case beats may borrow the actor: the dialogue tree asks for roles like
## 'strained' or 'recognition' at its deeper layers. Returns false while
## the named clip hasn't shipped, so cases can request roles ahead of the
## animation set arriving from the prompt sheet.
func play_case_role(fragment: String) -> bool:
	if mina_animation:
		return mina_animation.speak(fragment)
	if _animation_player == null:
		return false
	for animation_name in _animation_player.get_animation_list():
		if fragment.to_lower() in str(animation_name).to_lower():
			_animation_player.play(animation_name, 0.35)
			return true
	return false


## Standing poses a stage gesture may interrupt: relaxed, fretting, attentive and glancing (resident_routines.gd).
## Seated, busy, reaching and looking-up clips belong to other owners and are never interrupted.
const STANDING_CLIPS: Array[String] = ["clip_01", "clip_02", "clip_03", "clip_05"]


## A stage gesture while talking (ruling npc_face_mood_source_20261124). Only standing still in a standing idle,
## only a clip this body has, and the clip it was playing comes back when the gesture is done. When it declines
## nothing is touched: the pose that was playing keeps playing. False when nothing was played.
func stage_emote(clip: String) -> bool:
	if mina_animation:
		# Mina's own owner plays her clips. Only her one-shot roles, and only inside a conversation her owner
		# already holds, so the gesture never latches her into a conversation nobody will release.
		var role := clip.trim_prefix("mina_")
		var named := str(MinaAnimationBehavior.ROLES.get(role, ""))
		if named.is_empty() or bool(MinaAnimationBehavior.CLIPS.get(named, true)) 				or not mina_animation.conversation_active or mina_animation.moving or mina_animation.route_busy:
			return false
		return mina_animation.speak(role)
	if not _emote_allowed() or not _animation_player.has_animation(clip):
		return false
	var resume := str(_animation_player.current_animation)
	_animation_player.play(clip, 0.3)
	var length := _animation_player.get_animation(clip).length
	get_tree().create_timer(maxf(length - 0.3, 0.3)).timeout.connect(func() -> void:
		if is_instance_valid(_animation_player) and str(_animation_player.current_animation) == clip and not _walking:
			_animation_player.play(resume, 0.3))
	return true


func _emote_allowed() -> bool:
	if _walking or cast_body == null or _animation_player == null or not _animation_player.is_playing():
		return false
	return str(_animation_player.current_animation) in STANDING_CLIPS


func _play_named(fragment: String) -> void:
	if mina_animation:
		if fragment == "walk": mina_animation.set_motion(true)
		elif fragment == "idle": mina_animation.set_motion(false)
		return
	if _animation_player == null:
		return
	var preferred := preferred_idle if fragment == "idle" else preferred_walk if fragment == "walk" else ""
	if not preferred.is_empty() and _animation_player.has_animation(preferred):
		_animation_player.play(preferred,0.22)
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
	if not is_inside_tree():
		return ""
	var speak := "[E]  Speak with %s" % display_name
	var talk := get_tree().get_first_node_in_group("resident_conversations") as ResidentConversations
	if not installed_topic.is_empty():
		if _installed_topic_present() and talk != null and talk.can_offer_body_mystery(resident_id, false, installed_topic):
			return speak
		return ""
	if talk != null and talk.can_offer_body_mystery(resident_id, true):
		return speak
	var performances := get_tree().get_first_node_in_group("loop_performances")
	if performances != null:
		var topic := str(performances.conversation_prompt(resident_id))
		if not topic.is_empty():
			return topic
	var music := get_tree().get_first_node_in_group("music_director")
	if music != null and not music.body_music_anecdote(resident_id).is_empty():
		return speak
	return speak if _has_enabled_case() else ""


func _has_enabled_case() -> bool:
	var case_id := RealityCases.case_for_resident(resident_id)
	return case_id != "" and bool(RealityCases.definition(case_id).get("enabled", false))



func key_prompt() -> String:
	return DoorKeyring.copy_prompt(resident_id)


func interact_key(_player: Node) -> Dictionary:
	return DoorKeyring.request_copy(resident_id)


func _installed_topic_present() -> bool:
	return topic_is_present.is_valid() and bool(topic_is_present.call())


func interact(_player: Node) -> void:
	if not installed_topic.is_empty() and not _installed_topic_present():
		return
	if face_interacting_player and _player is Node3D:
		var toward: Vector3 = _player.global_position - global_position
		if Vector2(toward.x,toward.z).length_squared() > .001:
			var target := global_rotation.y + wrapf(atan2(toward.x,toward.z)-global_rotation.y,-PI,PI)
			create_tween().tween_property(self,"global_rotation:y",target,.35)
	# A thread marked "spoken" is said to this body in person (S15, Nadia on the
	# last night); the rest of the mystery threads stay where they are read. It
	# comes before the ambient work line, which would otherwise answer first.
	var talk := get_tree().get_first_node_in_group("resident_conversations")
	if not installed_topic.is_empty():
		if talk is ResidentConversations:
			(talk as ResidentConversations).start_mystery(resident_id, false, installed_topic)
		return
	if talk is ResidentConversations and (talk as ResidentConversations).start_mystery(resident_id, true):
		return
	var loop_performances := get_tree().get_first_node_in_group("loop_performances")
	if loop_performances != null and loop_performances.try_conversation(resident_id, _player):
		return
	var music := get_tree().get_first_node_in_group("music_director")
	if music and music.try_music_conversation(resident_id):
		return
	# Only an enabled case hears an ordinary interaction (the rule ResidentConversations.start keeps): speaking
	# to a body must never open a case that is switched off (order w715d783b50d8).
	if _has_enabled_case():
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
