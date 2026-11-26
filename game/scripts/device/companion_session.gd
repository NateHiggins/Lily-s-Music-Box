extends Node
## Connects the existing offline parser to the native keyboard and printer.
## This node owns correspondence only. It cannot execute a parsed world action.
const Conversation = preload("res://scripts/device/companion_conversation.gd")
const Campaign = preload("res://scripts/device/companion_campaign_state.gd")
const OWNER_GROUP := "companion_correspondence_owner"
var retired := false
var dialogue := Conversation.new()
var draft := ""
var visited: Array[String] = []
var typing := false
var opening := false
var suspended := false
var context_provider: Callable
var calendar_provider: Callable
var _carrier: Node
var _player: PlayerController
var _edit: LineEdit
var _campaign: Dictionary
var _bound_temporal_loop: Node
var _delivering := false
# A coda belongs to the accepted, player-requested copy. Never replay one
# from history or an interrupted print, even if the same text is on the paper.
const REPLY_GESTURES := {
	"sing_request": [&"good_side", &"companion_encore"],
	"compliment_first": [&"good_side", &""],
	"joke_request": [&"vaudeville_wink", &""],
}
var _gesture_line := ""
var _gesture_serial := 0
var _practice_line := ""
var _echo := ""
var _echo_until := 0
var _voice_gap := 0.0
var _speaking := false
var lexicon := preload("res://scripts/device/companion_lexicon.gd").new()
var _gesture_started := false
var _gesture_source: StringName
var _english_source: StringName
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _events: Array[Dictionary] = []
var _cooldown := 0.0
var _opening_seconds := 0.0
var chatter_enabled := true
@export_range(35.0, 72.0) var reading_fov := 40.0
var _zoom_applied := false
var _fov_before := 72.0
## A line her own hands type (S01): the player sends it and cannot edit it.
const SCRIPTED_KEY_SECONDS := 0.07
var _scripted := ""
var _scripted_shown := 0
var _scripted_seconds := 0.0
## Slips the loop sent while the paper was busy or out of reach. They are its
## news (a correction, a received copy), so they wait rather than drop. The
## queue is kept in the temporal ledger's outbox, in the same commit as the
## loop's own record that it was sent, so a save made before the paper takes
## it carries it across Continue.
var _loop_slips: Array[String] = []
const OUTBOX_LIMIT := 8

func setup(carrier: Node, player: PlayerController) -> void:
	_carrier = carrier; _player = player
	_gesture_source = StringName("companion_output:own_babble:correspondence:%d" % get_instance_id())
	_english_source = StringName("companion_output:learned_english:%d" % get_instance_id())
	var previous := get_tree().get_first_node_in_group(OWNER_GROUP)
	if previous != null and previous != self: previous.retire()
	add_to_group(OWNER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_edit = LineEdit.new()
	_edit.name = "CompanionCorrespondence"
	_edit.max_length = 512
	# A native focus/IME/virtual-keyboard surface. Its visible counterpart is the
	# physical paper; no second text HUD or clickable miniature key requirement.
	_edit.modulate.a = 0.0
	_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit.size = Vector2(1, 1)
	add_child(_edit)
	_edit.text_changed.connect(_typed)
	_edit.text_submitted.connect(submit)
	_edit.gui_input.connect(_editor_input)
	_carrier.device.teletype.card_presenting.connect(_paper_requested)
	_carrier.device.power_changed.connect(_power_changed)
	RealityState.snapshot_preparing.connect(_snapshot)
	RealityState.state_changed.connect(_state_changed)
	_restore()

func _exit_tree() -> void:
	_end_reply_gesture()
	if is_instance_valid(_player): _player.release_text_input(self)
	if is_instance_valid(_player) and is_instance_valid(_player.camera): _restore_reading_view()

func retire() -> void:
	_end_reply_gesture()
	# Overlapping waking roots share one campaign. Transfer the last draft
	# before the new session reads it; old save callbacks then become inert.
	close()
	_snapshot()
	bind_temporal_loop(null)
	retired = true
	_events.clear()
	_restore_reading_view()
	remove_from_group(OWNER_GROUP)
	_carrier.set_capture_hidden(true)
	for area: Area3D in _carrier.find_children("*", "Area3D", true, false):
		area.collision_layer = 0; area.collision_mask = 0

func available() -> bool:
	return not retired and is_instance_valid(_carrier) and _carrier.world_ready and _carrier.device.radio_powered \
		and not _carrier.arm_busy() \
		and not _carrier.device.incoming_call and not get_tree().paused \
		and not _player.protected_input_active() and not _player.mouse_released \
		and (not is_instance_valid(_player.text_input_owner) or _player.text_input_owner==self) \
		and _carrier._sleep_onset <= .8 \
		and (_player.telegram_hud == null or not _player.telegram_hud._conversation_active) \
		and not _foreign_editor_active() \
		and _player.camera.is_current() and not _carrier.is_capture_hidden() \
		and not _player.inspecting() and not _player._grab.active()

func begin() -> bool:
	if typing or opening or not available() or not _carrier.reading or _carrier.device.teletype.printing: return false
	if not _player.acquire_text_input(self): return false
	_mouse_before = Input.mouse_mode
	opening = true
	_opening_seconds = 0.0
	if suspended:
		suspended = false
		queue_event("typing_resumed")
	_carrier.motion.recall()
	_carrier.motion.request_behavior(&"type")
	return true

func _process(delta: float) -> void:
	if retired: return
	_update_reading_view()
	if not _gesture_line.is_empty(): _advance_reply_gesture()
	if (typing or opening) and (not available() or _player.text_input_owner != self):
		suspend(); return
	if get_tree().paused: return
	_advance_speech(delta)
	if opening:
		_opening_seconds += delta
		if _opening_seconds > 8.0:
			suspend(); return
		_carrier.rig.request_keyboard(_carrier.motion.steady_for_input())
	_cooldown = maxf(0.0, _cooldown - delta)
	if opening and _carrier.motion.steady_for_input() and _carrier.rig.typing_ready():
		opening = false; typing = true
		var loop := _temporal_loop()
		_scripted = loop.arc_draft() if loop != null else ""
		_scripted_shown = 0
		_scripted_seconds = 0.0
		_edit.text = draft if _scripted.is_empty() else ""
		_edit.grab_focus()
		# A held direction can focus a LineEdit without entering edit mode.
		# Deploying this keyboard is an explicit request to type on it.
		_edit.edit()
		_edit.caret_column = draft.length()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_carrier.motion.hold_for_hand(true)
		_carrier.device.teletype.show_draft(draft, _edit.caret_column)
	elif typing:
		if not _edit.has_focus():
			suspend(); return
		_type_scripted(delta)
		_carrier.device.teletype.show_draft(_edit.text, _edit.caret_column)
	if not _loop_slips.is_empty() and not typing and not opening and available() 			and not _carrier.device.teletype.printing:
		if _print({"text": _loop_slips[0]}):
			_loop_slips.pop_front()
			_keep_slips()
			RealityState.commit_background()
	elif chatter_enabled and not typing and not opening and _cooldown <= 0.0 and available() and not _carrier.device.teletype.printing:
		while not _events.is_empty():
			var pending: Dictionary = _events.pop_front()
			if float(pending.expires) >= Time.get_ticks_msec():
				if deliver_event(str(pending.id)): break

func _update_reading_view() -> void:
	var allowed: bool = _carrier.reading and not _player.protected_input_active() \
		and not get_tree().paused and not _carrier.is_capture_hidden() and _player.camera.is_current() \
		and not _carrier.device.incoming_call and _carrier._sleep_onset <= .8 \
		and (_player.telegram_hud == null or not _player.telegram_hud._conversation_active) \
		and (not _player.inspecting() or _player.inspect_owner == _carrier)
	allowed = allowed and not _foreign_editor_active()
	if allowed and not _zoom_applied:
		_fov_before = _player.camera.fov
		_player.camera.fov = minf(_fov_before, reading_fov)
		_zoom_applied = true
	elif not allowed and _zoom_applied:
		_restore_reading_view()

func _restore_reading_view() -> void:
	# A cutscene/another inspection may have changed the camera meanwhile.
	if _zoom_applied and is_equal_approx(_player.camera.fov, minf(_fov_before, reading_fov)):
		_player.camera.fov = _fov_before
	_zoom_applied = false

func _foreign_editor_active() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != _edit and (focus is LineEdit or focus is TextEdit)

func _type_scripted(delta: float) -> void:
	if _scripted.is_empty() or _scripted_shown >= _scripted.length(): return
	_scripted_seconds += delta
	while _scripted_seconds >= SCRIPTED_KEY_SECONDS and _scripted_shown < _scripted.length():
		_scripted_seconds -= SCRIPTED_KEY_SECONDS
		_carrier.rig.pulse_key(_scripted[_scripted_shown])
		_scripted_shown += 1
	_show_scripted()

func _show_scripted() -> void:
	_edit.set_block_signals(true)
	_edit.text = _scripted.left(_scripted_shown)
	_edit.caret_column = _scripted_shown
	_edit.set_block_signals(false)

func _typed(value: String) -> void:
	if not _scripted.is_empty():
		_show_scripted(); return
	var previous := draft
	draft = value.left(512)
	if draft.length() > previous.length():
		var start := maxi(0, _edit.caret_column - (draft.length() - previous.length()))
		for character in draft.substr(start, mini(16, draft.length() - previous.length())):
			_carrier.rig.pulse_key(character)
	# The snapshot owner captures the draft on save; avoid copying the entire
	# bounded conversation history for every keypress.

func _editor_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_edit.accept_event(); close()

func _input(event: InputEvent) -> void:
	if not (typing or opening): return
	# The player polls Interact as well as receiving events. Controller A can
	# submit this editor and release its lease before that poll runs. Releasing
	# the action still leaves just_pressed set for this frame and grabs whatever
	# is behind the console. Retire only this editor-owned press; the next
	# physical press is still an ordinary world interaction.
	if event.is_action_pressed("interact"):
		Input.action_release("interact")
		_player.retire_interact_press()
	if typing and event is InputEventKey and event.pressed:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code == KEY_BACKSPACE: _carrier.rig.pulse_key("BACKSPACE")
	if event is InputEventJoypadButton and event.is_action_pressed("companion_type"):
		if typing: submit(_edit.text)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("companion_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_services"):
		# Relinquish only our lease before the ordinary pause owner takes focus.
		close()
		if is_instance_valid(_player.pause_services): _player.pause_services.open()
		get_viewport().set_input_as_handled()

func submit(value: String) -> void:
	if not typing or not available() or not _carrier.rig.typing_ready(): return
	_carrier.rig.pulse_key("ENTER")
	if value.strip_edges().is_empty(): return
	if not _scripted.is_empty() and _scripted_shown < _scripted.length(): return
	# A scripted line is her hands', not the player's: the player's own draft
	# is left exactly as it was whether the paper takes the line or not.
	var scripted := not _scripted.is_empty()
	var before := dialogue.memory.snapshot()
	var context: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	context = context.duplicate()
	context["has_spoken_words"] = not lexicon.practice().is_empty()
	var calendar: Dictionary = calendar_provider.call() if calendar_provider.is_valid() else {}
	# The temporal loop's typed commands (leads, jump, again, home, bank) are
	# answered on the same paper; anything else is ordinary correspondence.
	var loop := _temporal_loop()
	var reply: Dictionary = loop.command(value) if loop != null else {}
	if reply.is_empty():
		reply = dialogue.respond_calendar(value, context, calendar.get("clock"),
			str(calendar.get("source", "")), calendar.get("conditions", {}),
			calendar.get("catalog"), calendar.get("read_issue", {}))
	close()
	if not _print(reply):
		dialogue.memory.restore(before)
		if not scripted: draft = value.left(512)
	else:
		if not scripted:
			draft = ""
			var line_id := str(reply.get("line_id", ""))
			if REPLY_GESTURES.has(line_id) or line_id in ["speech_practice", "speech_babble"]:
				_gesture_line = line_id
				_gesture_serial = _carrier.device.teletype._serial
				_practice_line = lexicon.practice() if line_id == "speech_practice" else ""
		var printed: Variant = reply.get("on_printed")
		if printed is Callable and (printed as Callable).is_valid(): (printed as Callable).call()
		if str(reply.get("intent", "")) in ["silence", "leave"]:
			chatter_enabled = false
			_events.clear()
		else: chatter_enabled = true
		if bool(reply.get("end_conversation", false)): _carrier.reading = false
	_snapshot()
	# Correspondence is autosaved through the same validated transaction as
	# household changes. Snapshot bytes are frozen before returning input;
	# explicit Save, Load and exit still settle every queued generation.
	RealityState.commit_background()

func close() -> void:
	if not typing and not opening: return
	var owned_focus := _edit.has_focus()
	typing = false; opening = false
	_scripted = ""
	_edit.release_focus()
	_player.release_text_input(self)
	_carrier.rig.request_keyboard(false)
	_carrier.motion.hold_for_hand(false)
	_carrier.device.teletype.hide_draft()
	if owned_focus and not _player.protected_input_active() and not get_tree().paused \
			and (_player.telegram_hud == null or not _player.telegram_hud._conversation_active) \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = _mouse_before
	_snapshot()

func suspend() -> void:
	if not typing and not opening: return
	suspended = true
	close()
	queue_event("typing_interrupted")

## A resumed world can send an arc copy before the player opens the keyboard.
func bind_temporal_loop(loop: Node) -> void:
	if retired or loop == _bound_temporal_loop:
		return
	if is_instance_valid(_bound_temporal_loop):
		_bound_temporal_loop.slip.disconnect(_temporal_slip)
	_bound_temporal_loop = loop
	if loop != null:
		loop.slip.connect(_temporal_slip)


## Read the existing visit clock. A rerun returns the machine to its eager
## starting hover without creating a second loop counter or save field.
func flight_steadiness() -> float:
	if not is_instance_valid(_bound_temporal_loop) or not _bound_temporal_loop.in_visit():
		return 1.0
	var elapsed: float = _bound_temporal_loop.loop_minutes()
	var remaining: float = _bound_temporal_loop.loop_minutes_left()
	return lerpf(1.12, .48, smoothstep(0.0, maxf(elapsed + remaining, 1.0), elapsed))

func _temporal_loop() -> Node:
	if not is_instance_valid(_bound_temporal_loop) and is_inside_tree():
		bind_temporal_loop(get_tree().get_first_node_in_group("temporal_loop"))
	return _bound_temporal_loop if is_instance_valid(_bound_temporal_loop) else null


## A slip the loop sends unasked: a deduction drawn, the hours beginning again.
func _temporal_slip(title: String, body: String) -> void:
	var text := body if title.is_empty() else title + ": " + body
	# Only the arc's slips (untitled: copies, releases, the correction) wait; ordinary advice
	# that finds the paper busy is dropped as before.
	var kept := title.is_empty()
	if kept and not _loop_slips.is_empty():
		if _loop_slips.size() < OUTBOX_LIMIT: _loop_slips.append(text)
		_keep_slips()
		return
	if not available() or typing or opening or _carrier.device.teletype.printing or not _print({"text": text}):
		if kept and _loop_slips.size() < OUTBOX_LIMIT: _loop_slips.append(text)
		if kept: _keep_slips()


## Take custody before the source records delivery. That source commits the
## pending text and its delivery marker together.
func accept_temporal_slip(ledger: Dictionary, text: String) -> bool:
	if retired or not is_same(_campaign, RealityState.data) or not is_same(ledger, _campaign.get("temporal")):
		return false
	if _loop_slips.size() >= OUTBOX_LIMIT or text.is_empty() or text.length() > 4096:
		return false
	_loop_slips.append(text)
	_keep_slips()
	return true


## Mirror the waiting slips into the temporal ledger. The loop commits right
## after it sends, so the slip and the record of sending it save together.
func _keep_slips() -> void:
	if retired or not is_same(_campaign, RealityState.data): return
	var temporal: Variant = RealityState.data.get("temporal")
	if temporal is not Dictionary: return
	if _loop_slips.is_empty(): (temporal as Dictionary).erase("outbox")
	else: temporal["outbox"] = _loop_slips.duplicate()


func queue_event(id: String, seconds := 20.0) -> void:
	if retired: return
	for pending: Dictionary in _events:
		if pending.id == id: return
	if _events.size() >= 8: return
	_events.append({"id":id, "expires":Time.get_ticks_msec() + seconds * 1000.0})

func deliver_event(id: String) -> bool:
	if not available() or typing or opening or _carrier.device.teletype.printing: return false
	var before := dialogue.memory.snapshot()
	var reply := dialogue.event(id)
	if reply.is_empty(): return false
	if not _print(reply):
		dialogue.memory.restore(before); return false
	_snapshot()
	return true

func _print(reply: Dictionary) -> bool:
	if not available() or str(reply.get("text", "")).is_empty(): return false
	_delivering = true
	var accepted: bool = _carrier.device.print_telegram_card(
		{"title":"CORRESPONDENCE", "body":str(reply.text)}, true, _carrier.device.teletype.FACE_COPY_ROWS)
	_delivering = false
	if accepted: _cooldown = 45.0
	return accepted

func _paper_requested(_card: Dictionary, _serial: int) -> void:
	_end_reply_gesture()
	if not _delivering:
		suspend()
		_cooldown = 45.0 # Field copies and calls have priority over idle remarks.

func _power_changed(powered: bool) -> void:
	if not powered:
		_end_reply_gesture()
		suspend()

func _advance_reply_gesture() -> void:
	if not _carrier.reading or typing or opening or not available() or _carrier.story_pose_active() or _carrier.is_story_absent() or _carrier.device.teletype._reviewing or _carrier.device.teletype._serial != _gesture_serial:
		_end_reply_gesture()
		return
	var gesture: Array = REPLY_GESTURES.get(_gesture_line, [&"", &""])
	var rig: Node = _carrier.rig
	if _gesture_started:
		if (gesture[0] == &"" or rig.reaction_player.current != gesture[0]) and AudioPolicy.active_voice(_gesture_source) == null and not _speaking:
			_end_reply_gesture()
		return
	if not _carrier.device.teletype.copy_delivered() or rig.keyboard_open > .05: return
	# An already-playing face or a denied sound gets no late encore.
	_gesture_started = true
	if gesture[0] != &"": rig.play_reaction(gesture[0])
	if _gesture_line == "speech_practice":
		_say(_practice_line)
	elif _gesture_line == "speech_babble":
		AudioPolicy.present_3d(&"companion_babble_acknowledgement", _carrier.motion.global_position, 1.0, _gesture_source)
	elif gesture[1] != &"":
		AudioPolicy.present_3d(gesture[1], _carrier.motion.global_position, 1.0, _gesture_source)

func _end_reply_gesture() -> void:
	if _gesture_started:
		if is_instance_valid(_carrier) and is_instance_valid(_carrier.rig) and is_instance_valid(_carrier.rig.reaction_player):
			var face: Node = _carrier.rig.reaction_player
			if REPLY_GESTURES.has(_gesture_line) and face.current == REPLY_GESTURES[_gesture_line][0]: face.cancel()
		AudioPolicy.release_source(_gesture_source)
	_gesture_line = ""
	_practice_line = ""
	_gesture_started = false
	_stop_english()

func hears_resident(panel: CaseDialoguePanel) -> bool:
	return not retired and is_same(_campaign, RealityState.data) and is_instance_valid(_player) \
		and panel._player == _player and panel.attention_active() and _player.camera.is_current() \
		and _carrier.world_ready and _carrier.device.radio_powered and not _carrier.is_capture_hidden() \
		and not _carrier.is_story_absent() and not _carrier.story_pose_active() and _carrier._sleep_onset <= .8 \
		and not get_tree().paused and _player.camera.global_position.distance_to(_carrier.motion.global_position) <= 4.0

func hear_resident_word(word: String, source: String, panel: CaseDialoguePanel) -> void:
	if not hears_resident(panel) or not lexicon.learn(word, source): return
	_snapshot()
	if chatter_enabled and word in ["hello", "help", "here", "again", "okay", "oh", "yes", "no"] and lexicon.can_say(word):
		_echo = word
		_echo_until = Time.get_ticks_msec() + 24000

func _say(line: String) -> void:
	if not lexicon.can_say(line): return
	_speaking = AudioPolicy.present_3d(StringName("companion_say_" + line), _carrier.motion.global_position, 1.0, _english_source)
	if _speaking: _voice_gap = 45.0

func _stop_english() -> void:
	if _speaking: AudioPolicy.release_source(_english_source)
	_speaking = false
	_echo = ""

func _advance_speech(delta: float) -> void:
	_voice_gap = maxf(0.0, _voice_gap - delta)
	if _echo.is_empty() and not _speaking: return
	var observing := false
	for panel: Node in get_tree().get_nodes_in_group("attention_people"):
		if panel.attention_active():
			observing = true
			break
	var free: bool = available() and not observing and not _carrier.is_story_absent() and not _carrier.story_pose_active()
	if _speaking:
		if not free:
			_stop_english()
		elif AudioPolicy.active_voice(_english_source) == null: _speaking = false
	if Time.get_ticks_msec() > _echo_until or not chatter_enabled: _echo = ""
	if not free or typing or opening or _gesture_line != "" or _voice_gap > 0 or _echo.is_empty(): return
	if _carrier.device.teletype.printing or _carrier.arm_busy(): return
	var word := _echo
	_echo = ""
	_say(word)

func _snapshot() -> void:
	if retired or not is_same(_campaign, RealityState.data): return
	RealityState.data[Campaign.KEY] = {"version":2, "heard":lexicon.heard.duplicate(), "memory":dialogue.memory.snapshot(),
		"draft":draft, "visited":visited.duplicate()}

func _state_changed() -> void:
	if retired: return
	if not is_same(_campaign, RealityState.data): _restore()

func _restore() -> void:
	_end_reply_gesture()
	close()
	_campaign = RealityState.data
	var value: Dictionary = _campaign.get(Campaign.KEY, Campaign.fresh())
	dialogue = Conversation.new()
	lexicon.heard.clear()
	_voice_gap = 0.0
	if Campaign.valid(value):
		lexicon.heard = value.get("heard", {}).duplicate()
		dialogue.memory.restore(value.memory)
		draft = value.draft
		visited.assign(value.visited)
	else:
		draft = ""; visited.clear()
	chatter_enabled = dialogue.memory.history.is_empty() or str(dialogue.memory.history.back().intent) not in ["silence", "leave"]
	# Live witnesses and queued circumstances cannot be revived from old prose.
	dialogue.memory.pending_ids.clear()
	_events.clear(); suspended = false; _cooldown = 45.0
	# The loop's waiting slips are authored copy the save already vouched for.
	_loop_slips.clear()
	var temporal: Variant = _campaign.get("temporal")
	if temporal is Dictionary and temporal.get("outbox") is Array:
		for slip: Variant in temporal.outbox:
			if slip is String and _loop_slips.size() < OUTBOX_LIMIT: _loop_slips.append(slip)
