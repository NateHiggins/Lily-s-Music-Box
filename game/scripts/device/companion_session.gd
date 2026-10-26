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
var _delivering := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _events: Array[Dictionary] = []
var _cooldown := 0.0
var _opening_seconds := 0.0
var chatter_enabled := true
@export_range(35.0, 72.0) var reading_fov := 40.0
var _zoom_applied := false
var _fov_before := 72.0

func setup(carrier: Node, player: PlayerController) -> void:
	_carrier = carrier; _player = player
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
	if is_instance_valid(_player): _player.release_text_input(self)
	if is_instance_valid(_player) and is_instance_valid(_player.camera): _restore_reading_view()

func retire() -> void:
	# Overlapping waking roots share one campaign. Transfer the last draft
	# before the new session reads it; old save callbacks then become inert.
	close()
	_snapshot()
	retired = true
	_events.clear()
	_restore_reading_view()
	remove_from_group(OWNER_GROUP)
	_carrier.set_capture_hidden(true)
	for area: Area3D in _carrier.find_children("*", "Area3D", true, false):
		area.collision_layer = 0; area.collision_mask = 0

func available() -> bool:
	return not retired and is_instance_valid(_carrier) and _carrier.world_ready and _carrier.device.radio_powered \
		and not _carrier.device.incoming_call and not get_tree().paused \
		and not _player.protected_input_active() and not _player.mouse_released \
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
	if (typing or opening) and (not available() or _player.text_input_owner != self):
		suspend(); return
	if get_tree().paused: return
	if opening:
		_opening_seconds += delta
		if _opening_seconds > 8.0:
			suspend(); return
		_carrier.rig.request_keyboard(_carrier.motion.steady_for_input())
	_cooldown = maxf(0.0, _cooldown - delta)
	if opening and _carrier.motion.steady_for_input() and _carrier.rig.typing_ready():
		opening = false; typing = true
		_edit.text = draft
		_edit.grab_focus()
		_edit.caret_column = draft.length()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_carrier.motion.hold_for_hand(true)
		_carrier.device.teletype.show_draft(draft, _edit.caret_column)
	elif typing:
		if not _edit.has_focus():
			suspend(); return
		_carrier.device.teletype.show_draft(_edit.text, _edit.caret_column)
	if chatter_enabled and not typing and not opening and _cooldown <= 0.0 and available() and not _carrier.device.teletype.printing:
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

func _typed(value: String) -> void:
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
	var before := dialogue.memory.snapshot()
	var context: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	var calendar: Dictionary = calendar_provider.call() if calendar_provider.is_valid() else {}
	var reply: Dictionary = dialogue.respond_calendar(value, context, calendar.get("clock"),
		str(calendar.get("source", "")), calendar.get("conditions", {}),
		calendar.get("catalog"), calendar.get("read_issue", {}))
	close(true)
	if not _print(reply):
		dialogue.memory.restore(before)
		draft = value.left(512)
	else:
		draft = ""
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

func close(keep_keyboard_open := false) -> void:
	if not typing and not opening: return
	var owned_focus := _edit.has_focus()
	typing = false; opening = false
	_edit.release_focus()
	_player.release_text_input(self)
	_carrier.rig.request_keyboard(keep_keyboard_open and _carrier.reading)
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
	var accepted: bool = _carrier.device.print_telegram_card({"title":"CORRESPONDENCE", "body":str(reply.text)})
	_delivering = false
	if accepted: _cooldown = 45.0
	return accepted

func _paper_requested(_card: Dictionary, _serial: int) -> void:
	if not _delivering:
		suspend()
		_cooldown = 45.0 # Field copies and calls have priority over idle remarks.

func _power_changed(powered: bool) -> void:
	if not powered: suspend()

func _snapshot() -> void:
	if retired or not is_same(_campaign, RealityState.data): return
	RealityState.data[Campaign.KEY] = {"version":1, "memory":dialogue.memory.snapshot(),
		"draft":draft, "visited":visited.duplicate()}

func _state_changed() -> void:
	if retired: return
	if not is_same(_campaign, RealityState.data): _restore()

func _restore() -> void:
	close()
	_campaign = RealityState.data
	var value: Dictionary = _campaign.get(Campaign.KEY, Campaign.fresh())
	dialogue = Conversation.new()
	if Campaign.valid(value):
		dialogue.memory.restore(value.memory)
		draft = value.draft
		visited.assign(value.visited)
	else:
		draft = ""; visited.clear()
	chatter_enabled = dialogue.memory.history.is_empty() or str(dialogue.memory.history.back().intent) not in ["silence", "leave"]
	# Live witnesses and queued circumstances cannot be revived from old prose.
	dialogue.memory.pending_ids.clear()
	_events.clear(); suspended = false; _cooldown = 45.0
