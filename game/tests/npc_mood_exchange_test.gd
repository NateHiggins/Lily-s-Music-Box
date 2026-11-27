extends Node3D
## Mood reading in a native authored exchange (ruling npc_face_mood_source_20261124; Codex's intake of PR 540):
##   - a rebuilt resident in a real ResidentConversations exchange: the face shows the reading and a permitted
##     gesture clip actually plays and then gives back the idle it interrupted;
##   - the same resident seated: the same exchange never takes the body out of its seated clip;
##   - Mina through her own animation owner: declined outside an owned conversation, a one-shot inside it that
##     returns to her held clip;
##   - Harukiya staff: the visible expression follows the reading and the show pose's hands do not move.
## Headless: clip state, blend shape values and bone poses are read directly.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const StaffBody := preload("res://scripts/characters/harukiya_staff_body.gd")
const HarukiyaCast := preload("res://scripts/characters/harukiya_cast.gd")

var conversations: ResidentConversations
var panel: CaseDialoguePanel
var player_unit := ""
var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	print("MOOD EXCHANGE CHECK: ", text, " = ", ok)
	if not ok:
		failures.append(text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	RealityState.persistence_enabled = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 1.5, 3.0)
	camera.make_current()
	panel = CaseDialoguePanel.new()
	add_child(panel)
	conversations = ResidentConversations.new()
	add_child(conversations)
	conversations.setup(panel, func() -> String: return player_unit, func(_resident: String) -> bool: return true)
	CastBodies.set_for_test(["jonah_price", "mina_vale"])
	await _resident_standing()
	await _resident_seated()
	await _mina()
	await _staff()
	await _choice_reactions()
	CastBodies.set_for_test()
	print("MOOD EXCHANGE RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _resident(seated: bool) -> Node3D:
	var jonah := Presentation.new()
	jonah.setup("Jonah Price", "jonah_price", "2B", CastBodies.model_for("jonah_price"))
	jonah.externally_driven = true
	add_child(jonah)
	return jonah


func _open(resident_id: String) -> bool:
	if panel.attention_active():
		panel.close()
	var ok := conversations.start(resident_id)
	await frames(3)
	return ok


func _close() -> void:
	panel.close()
	conversations.conversation_ended.emit(conversations.get("_active_resident"))
	await frames(2)


func _resident_standing() -> void:
	var jonah := _resident(false)
	await frames(8)
	var player: AnimationPlayer = jonah.get("_animation_player")
	var speech: Node = jonah.get_node_or_null("CastSpeech")
	check(jonah.cast_body != null and player != null and speech != null, "Jonah wears his rebuilt body with clips and a speech hook")
	if player == null or speech == null:
		jonah.queue_free()
		return
	jonah.call("_play_named", "idle")
	await frames(2)
	var idle := str(player.current_animation)
	check(idle in jonah.STANDING_CLIPS, "he stands in a standing idle (%s)" % idle)
	check(await _open("jonah_price"), "his authored conversation opens")
	var reading: Dictionary = speech.get("last_reading")
	print("  Jonah's line: ", panel.displayed_line().text.left(80), " -> ", JSON.stringify(reading))
	check(not reading.is_empty() and reading.expression != "interest", "his opening line is read as a feeling (%s)" % str(reading.get("expression", "")))
	var face: Node = jonah.cast_body.face
	for index in 40:
		face.step(1.0 / 60.0)
	check(face.expression() == str(reading.get("expression", "")), "his face shows that feeling (%s)" % face.expression())
	var emote := str(reading.get("emote", ""))
	check(emote != "" and str(player.current_animation) == emote, "the permitted gesture plays on his body (%s, playing %s)" % [emote, player.current_animation])
	var length := player.get_animation(emote).length if emote != "" and player.has_animation(emote) else 0.0
	await get_tree().create_timer(length + 0.4).timeout
	check(str(player.current_animation) == idle, "and his idle comes back when it is done (%s)" % player.current_animation)
	await _close()
	jonah.queue_free()
	await frames(2)


func _resident_seated() -> void:
	var jonah := _resident(true)
	await frames(8)
	var player: AnimationPlayer = jonah.get("_animation_player")
	var speech: Node = jonah.get_node_or_null("CastSpeech")
	check(bool(jonah.call("play_seated")), "Jonah sits")
	await frames(2)
	check(await _open("jonah_price"), "the same conversation opens while he sits")
	var reading: Dictionary = speech.get("last_reading")
	check(str(reading.get("emote", "")) != "", "the reading asks for a gesture (%s)" % str(reading.get("emote", "")))
	var held := true
	for index in 90:
		await get_tree().process_frame
		held = held and str(player.current_animation) == "clip_06"
	check(held, "seated, he never leaves his seated clip for a standing gesture")
	check(not bool(jonah.call("stage_emote", "finger_wag_no")) and str(player.current_animation) == "clip_06", "a gesture asked for directly is declined and the seat is kept")
	await _close()
	jonah.queue_free()
	await frames(2)


func _mina() -> void:
	var mina := Presentation.new()
	mina.setup("Mina Vale", "mina_vale", "3A", CastBodies.model_for("mina_vale"))
	mina.externally_driven = true
	add_child(mina)
	await frames(8)
	var behaviour: MinaAnimationBehavior = mina.mina_animation
	check(behaviour != null, "Mina has her own animation owner")
	if behaviour == null:
		mina.queue_free()
		return
	var before := str(behaviour.player.current_animation)
	check(not bool(mina.call("stage_emote", "mina_recognition")) and not behaviour.conversation_active
			and str(behaviour.player.current_animation) == before, "outside a conversation her owner holds, a gesture is declined and nothing latches")
	check(not bool(mina.call("stage_emote", "agree_gesture")), "a gesture that is not one of her roles is declined")
	behaviour.speak("talk")
	await frames(2)
	check(bool(mina.call("stage_emote", "mina_recognition")) and str(behaviour.player.current_animation) == "mina_recognition", "inside her conversation her recognition plays")
	var length := behaviour.player.get_animation("mina_recognition").length
	for index in int((length + 0.5) * 60.0):
		behaviour.update(1.0 / 60.0)
		await get_tree().process_frame
	check(str(behaviour.player.current_animation) != "mina_recognition", "and gives way when it is done (%s)" % behaviour.player.current_animation)
	behaviour.speak("idle")
	await frames(2)
	check(not behaviour.conversation_active, "her owner still releases her")
	mina.queue_free()
	await frames(2)


func _hands(actor: Node) -> Dictionary:
	var skeleton: Skeleton3D = actor.get("skeleton")
	var poses: Dictionary = {}
	for bone_name in ["LeftHand", "RightHand", "LeftForeArm", "RightForeArm"]:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			poses[bone_name] = skeleton.get_bone_global_pose(bone)
	return poses


func _staff() -> void:
	var actor := StaffBody.new()
	actor.configure("stacy", "res://assets/characters/stacy/stacy.gltf", HarukiyaCast.PARTS, "at_ease")
	add_child(actor)
	await frames(4)
	check(bool(actor.ready_ok), "Stacy's staff body is ready")
	if not bool(actor.ready_ok):
		actor.queue_free()
		return
	actor.set_active(true)
	await frames(10)
	check(actor.find_children("*", "AnimationPlayer", true, false).is_empty(), "staff carry no clip player to gesture with")
	var cast: Node3D = HarukiyaCast.new()
	cast.set("conversations", conversations)
	cast.set("actors", {"stacy": actor})
	var hands := _hands(actor)
	check(await _open("stacy"), "Stacy's authored conversation opens")
	cast.call("_on_started", "stacy", "")
	cast.call("_on_node_shown", "")
	var line := str(panel.displayed_line().text)
	var expected: Dictionary = preload("res://scripts/characters/cast_resident_speech.gd").reader().read("stacy", line, int(RealityState.resident_trust("stacy")))
	var face: Node = actor.face
	for index in 40:
		face.step(1.0 / 60.0)
		await get_tree().process_frame
	print("  Stacy's line: ", line.left(80), " -> ", JSON.stringify(expected))
	check(face.expression() == str(expected.expression), "her visible expression follows the reading (%s)" % face.expression())
	var shown := 0.0
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/face_performance.json"))
	for row: Dictionary in data.expressions:
		if str(row.name) == str(expected.expression):
			for pair: Array in row.shapes:
				shown = maxf(shown, float(face.value_of(str(pair[0]))))
	check(str(expected.expression) == "neutral" or shown > 0.05, "and it is on her face, not just named (%.2f)" % shown)
	var after := _hands(actor)
	var still := not hands.is_empty()
	for bone_name: String in hands:
		still = still and (hands[bone_name] as Transform3D).origin.distance_to((after[bone_name] as Transform3D).origin) < 0.002
	check(still, "her hands stay in the show pose")
	# Stacy's shipped bar tree has no evidence choices. Exercise the same
	# panel-to-staff path with a small fixture, without changing her dialogue.
	var probe := {"meta": {"speaker_default": "STACY"}, "nodes": {
		"open": {"line": "Well.", "choices": [{"label": "Show it.", "evidence": "fixture", "goto": "reply"}]},
		"reply": {"line": "Well.", "choices": [{"label": "Leave."}]}}}
	panel.run_tree(probe, "open", Callable())
	cast.call("_on_started", "stacy", "")
	panel.node_shown.connect(Callable(cast, "_on_node_shown"))
	panel.choose(0)
	var staff_reader: RefCounted = preload("res://scripts/characters/cast_resident_speech.gd").reader()
	var staff_expected: Dictionary = staff_reader.read("stacy", "Well.", int(RealityState.resident_trust("stacy")), {"evidence": true})
	for index in 40:
		face.step(1.0 / 60.0)
	check(panel.current_node_id == "reply" and face.expression() == str(staff_expected.expression),
			"the staff face reads the selected evidence on the next line")
	panel.run_tree(probe, "open", Callable())
	check(panel.displayed_line().exchange.is_empty(), "restarting even the same tree clears the last selection")
	panel.choose(0)
	panel.present("Elsewhere", "Another voice.", [])
	check(panel.displayed_line().exchange.is_empty(), "standalone takeover clears the selected evidence")
	panel.run_tree(probe, "open", Callable())
	panel.choose(0)
	panel.close()
	check(panel.displayed_line().exchange.is_empty(), "early close clears evidence before the next owner")
	# Reuse the loaded staff face to check Adela's two real caption owners.
	cast.set("performers", {"adela_voss": actor})
	var shop: Dictionary = conversations.trees["adela_voss"]
	panel.run_tree(shop, "ad_int_open", Callable())
	cast.call("_on_started", "adela_voss", "")
	check(face.is_speaking(), "Adela's short caption voices her mixed opening in the shop")
	panel.choose(0)
	check(not face.is_speaking() and panel.displayed_line().text == shop.nodes.ad_int_beat.line
			and panel.displayed_line().delivery == "silent", "the lamp action stays visible and stops her active jaw")
	panel.choose(0)
	check(face.is_speaking(), "Adela speaks again after the silent action")
	var dated: Dictionary = conversations.mystery["adela_voss"]
	panel.run_tree(dated, "av_f5", Callable())
	check(face.is_speaking() and panel.displayed_line().speaker == "ADELA VOSS",
			"her full mystery caption speaks the words following a stage direction")
	panel.choose_silence()
	check(panel.displayed_line().speaker == "LILY" and not face.is_speaking(), "Adela never mouths Lily's reply")
	panel.node_shown.disconnect(Callable(cast, "_on_node_shown"))
	await _close()
	cast.free()
	actor.queue_free()
	await frames(2)

func _choice_reactions() -> void:
	RealityState.reset_campaign_for_tests()
	var jonah := _resident(false)
	await frames(4)
	var speech: Node = jonah.get_node_or_null("CastSpeech")
	if speech == null:
		check(false, "Jonah has a speech hook for the authored choice exchange")
		jonah.queue_free()
		return
	var evidence_label := "The bed faces the desk. Last thing you see is the page. [the bed]"
	check(await _open("jonah_price"), "Jonah opens his first conversation outside the flat")
	check(not panel.offered_labels().has(evidence_label) and panel.displayed_line().exchange.is_empty(),
			"unavailable bedroom evidence is never offered or conveyed")
	panel.close()
	panel._end_tree()
	player_unit = conversations.unit_of("jonah_price")
	check(await _open("jonah_price"), "the same conversation opens inside his flat")
	var evidence_index := panel.offered_labels().find(evidence_label)
	check(evidence_index >= 0 and panel.displayed_line().exchange.is_empty(),
			"offering eligible evidence leaves the opening reaction empty")
	if evidence_index >= 0:
		panel.choose(evidence_index)
		_check_reaction(speech, "jp_bed", {"evidence": true}, 0)
		var inferred := panel.offered_labels().find("You've arranged the room so you can't be let off.")
		check(inferred >= 0, "Jonah offers the authored inference")
		if inferred >= 0:
			var prior := int(RealityState.resident_trust("jonah_price"))
			panel.choose(inferred)
			_check_reaction(speech, "jp_let_off", {"inferred": true}, int(RealityState.resident_trust("jonah_price")) - prior)
			panel.choose_silence()
			check(panel.current_node_id == "jp_would_have" and panel.displayed_line().exchange.is_empty(),
					"silence does not inherit the inference")
	panel.close()
	check(panel.displayed_line().exchange.is_empty(), "closing clears visible reaction metadata")
	panel._end_tree()
	player_unit = ""
	jonah.queue_free()
	await frames(2)


func _check_reaction(speech: Node, node_id: String, metadata: Dictionary, delta: int) -> void:
	var snapshot := panel.displayed_line()
	check(panel.current_node_id == node_id and snapshot.exchange == metadata,
			"selected authored reply reaches only " + node_id)
	var exchange := metadata.duplicate()
	exchange["trust_delta"] = delta
	var expected: Dictionary = preload("res://scripts/characters/cast_resident_speech.gd").reader().read(
			"jonah_price", str(snapshot.text), int(RealityState.resident_trust("jonah_price")), exchange)
	check(speech.get("last_reading") == expected, "the live walking resident reads the selected reply")
