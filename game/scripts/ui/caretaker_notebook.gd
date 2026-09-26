extends CanvasLayer
## An inspection slip and pocket ledger. Physical controls remain the owners.
var player: PlayerController
var care: Node
var economy: Node
var debug: BuildingDebug
var subject: Node
var panel: PanelContainer
var box: VBoxContainer
var readout: Label
var feedback: Label
var opened := false
var tested := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _was_hot := false
var _was_cold := false
var _was_stopper := false
var _sample_level := 0.0
var _test_seconds := 0.0
var _testing := false
var _draining := false
var _request_page := 0
var _cabinet_phase := 0
var _cabinet_was_open := false

func _ready() -> void:
	add_to_group("caretaker_notebook")
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(28,70)
	panel.custom_minimum_size = Vector2(420,0)
	panel.add_theme_stylebox_override("panel",TelegramStyle.paper_panel(.97))
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	panel.hide()

func aimed_subject() -> Node:
	var origin := player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin,origin-player.camera.global_basis.z*2.1,1)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return care.find_subject(hit.collider) if not hit.is_empty() else null

func inspection_available() -> bool:
	return not opened and not player.call_locked and not is_instance_valid(player.seated_interaction) \
		and not get_tree().paused and player.camera.is_current() \
		and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED

func action_hint() -> String:
	return "[I] Inspect / care" if inspection_available() and aimed_subject()!=null else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and opened:
		close()
		get_viewport().set_input_as_handled()
	elif not opened and (event.is_action_pressed("inspect_care") or event.is_action_pressed("pocket_ledger")):
		if not inspection_available(): return
		var target: Node = aimed_subject() if event.is_action_pressed("inspect_care") else null
		if event.is_action_pressed("inspect_care") and target==null: return
		open(target)
		get_viewport().set_input_as_handled()

func open(target: Node) -> void:
	if opened or player.call_locked: return
	subject = target
	tested = false
	_testing = false
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	readout = Label.new()
	TelegramStyle.apply(readout,17,false,TelegramStyle.CARBON)
	box.add_child(readout)
	if subject!=null:
		if subject is TapProp:
			_was_hot = subject._hot
			_was_cold = subject._cold
			_was_stopper = subject._stopper
			_button("Hot valve",func(): subject.set_hot(not subject._hot))
			_button("Cold valve",func(): subject.set_cold(not subject._cold))
			_button("Drain stopper",func(): subject.set_stopper(not subject._stopper))
			if subject.fixture=="shower":
				_button("Shower curtain",func(): subject.set_curtain_open(not subject.is_curtain_open()))
			_button("Test flow, warmth and drainage",_test_water)
		else:
			_button("Exercise the cabinet",_test_cabinet)
		_button("Clear drain" if subject is TapProp else "Oil hinges" if subject is MedicineCabinetProp else "Brush and wax track",_service)
	else:
		_button("Pay $5.00 rent instalment",func(): feedback.text = "Rent paid." if economy.pay_rent() else "Keep saving for the next instalment.")
		_button("Next service requests",func(): _request_page += 1; _process(0))
		_button("Print pocket and request page",_print_pocket)
	feedback = Label.new()
	TelegramStyle.apply(feedback,14,false,TelegramStyle.CARBON)
	box.add_child(feedback)
	_button("Close / Escape",close)
	_mouse_before = Input.mouse_mode
	player.call_locked = true
	opened = true
	add_to_group("attention_maintenance")
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_process(0.0)

func _button(words: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = words
	button.pressed.connect(callback)
	box.add_child(button)

func _cabinet_open() -> bool:
	return subject.is_door_open() if subject is MedicineCabinetProp else subject.opened

func _set_cabinet_open(value: bool) -> void:
	if subject is MedicineCabinetProp: subject.set_door_open(value)
	elif subject.opened!=value: subject.interact(player)

func _cabinet_at_end(open: bool) -> bool:
	if subject is MedicineCabinetProp:
		return absf(subject._swing-(1.0 if open else 0.0))<.001
	return absf(subject._slide.position.x-(subject.TRAVEL if open else 0.0))<.001

func _test_cabinet() -> void:
	if _testing: return
	tested = false
	_testing = true
	_test_seconds = 0
	_cabinet_phase = 1
	_cabinet_was_open = _cabinet_open()
	_set_test_controls(true)
	_set_cabinet_open(false)
	feedback.text = "Closing the cabinet; checking its full travel..."

func _observe_cabinet(delta: float) -> void:
	_test_seconds += delta
	if _cabinet_at_end(_cabinet_phase==2):
		if _cabinet_phase==1:
			_cabinet_phase = 2
			_test_seconds = 0
			_set_cabinet_open(true)
			feedback.text = "Opening the cabinet; checking access to its mechanism..."
		else:
			_testing = false
			tested = true
			_set_test_controls(false)
			feedback.text = "Full travel checked. The mechanism is open for care."
	elif _test_seconds>=3:
		_testing = false
		_set_cabinet_open(_cabinet_was_open)
		_set_test_controls(false)
		feedback.text = "Travel did not finish; test incomplete. Check the cabinet and retry."

func _test_water() -> void:
	# Run the actual valves briefly, then observe the physical water-level fall.
	if _testing: return
	if subject.fixture=="shower" and not subject.is_curtain_open():
		feedback.text = "Open the curtain so you can watch the receptor drain."
		return
	tested = false
	_testing = true
	_draining = false
	_sample_level = 0
	_set_test_controls(true)
	_test_seconds = 0
	subject.set_hot(true)
	subject.set_cold(true)
	subject.set_stopper(true)
	feedback.text = "Running both valves; checking mixed warmth..."

func _process(delta: float) -> void:
	if not opened: return
	if subject!=null:
		readout.text = care.inspection(subject)
		if _testing and not subject is TapProp:
			_observe_cabinet(delta)
		elif _testing:
			_test_seconds += delta
			if not _draining and _test_seconds>=2:
				subject.set_hot(false)
				subject.set_cold(false)
				subject.set_stopper(false)
				_sample_level = subject._water_level
				_draining = true
				_test_seconds = 0
				feedback.text = "Valves shut. Watching the drain..."
			elif _draining and _test_seconds>=2:
				# A stationary pool is a valid blocked-drain diagnosis; an empty
				# sample is not evidence that the fixture passed its water test.
				tested = _sample_level>.01
				_testing = false
				_set_test_controls(false)
				if not tested:
					feedback.text = "No water collected; test incomplete. Check flow and try again."
				elif subject._water_level>=_sample_level-.001:
					feedback.text = "No drainage observed; strainer needs clearing."
				elif _sample_level-subject._water_level<minf(_sample_level,.24)*.75:
					feedback.text = "Water drains slowly; strainer needs clearing."
				else:
					feedback.text = "Flow, mixed warmth and drainage checked."
	else:
		var days := maxf(0.0,(float(economy.book().started)+(int(economy.book().rent_paid)+1)*economy.MONTH-economy.clock.elapsed_minutes())/1440.0)
		readout.text = "POCKET / %s\nRent: $5.00 / next instalment in %.1f days\nOverdue instalments: %d\nNo late fees. Pay when you can.\n\nI: inspect a fixture in reach\nP: pocket ledger" % [economy.money(int(economy.book().cash)),days,economy.rent_cycles_due()]
		var requests: Array[String] = care.request_lines()
		var pages := maxi(1,ceili(requests.size()/6.0))
		_request_page = posmod(_request_page,pages)
		readout.text += "\n\nSERVICE REQUESTS: %d / page %d of %d" % [requests.size(),_request_page+1,pages]
		for index in range(_request_page*6,mini(requests.size(),(_request_page+1)*6)):
			readout.text += "\n"+requests[index]

func _set_test_controls(running: bool) -> void:
	for child in box.get_children():
		if child is Button and child.text!="Close / Escape": child.disabled = running

func _print_card(card: Dictionary) -> bool:
	return is_instance_valid(player.carried_device) and player.carried_device.print_telegram_card(card)

func _print_pocket() -> void:
	if not opened or subject!=null: return
	_process(0)
	feedback.text = "Pocket copy sent to the carried set." if _print_card({
		"title":"POCKET COPY", "body":readout.text, "stamp":"LEDGER SNAPSHOT"}) \
		else "Switch on the carried set to print a pocket copy."

func _service() -> void:
	if not tested:
		feedback.text = "Test the mechanism first."
		return
	var result: Dictionary = care.service(subject,tested)
	feedback.text = str(result.get("note","Service unavailable."))
	if int(result.get("tip",0))>0: feedback.text += "  Tip: "+economy.money(int(result.tip))
	# Only a completed service result carries a tip field (including zero).
	# Repeated care and denied actions must not mint a second completion slip.
	if result.has("tip"):
		var paid := int(result.tip)
		var body: String = str(subject.get("unit"))+" / "+care.subject_title(subject)+"\n"+str(result.note)
		body += "\nTip: "+economy.money(paid) if paid>0 else "\nNo tip paid."
		if not _print_card({"title":"SERVICE COMPLETED", "body":body, "stamp":"CARE RECORD"}):
			feedback.text += "  Set off; no slip printed."
	_process(0)

func close() -> void:
	if not opened: return
	if is_instance_valid(subject) and subject is TapProp:
		subject.set_hot(_was_hot)
		subject.set_cold(_was_cold)
		subject.set_stopper(_was_stopper)
	if _testing and is_instance_valid(subject) and not subject is TapProp:
		_set_cabinet_open(_cabinet_was_open)
	_testing = false
	panel.hide()
	opened = false
	remove_from_group("attention_maintenance")
	player.call_locked = false
	var restore := Input.MOUSE_MODE_VISIBLE if player.mouse_released else _mouse_before
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_instance_valid(debug) and debug.defer_mouse_restore(restore) else restore

func _exit_tree() -> void:
	if is_instance_valid(player): close()
