extends Area3D
## One physical Keys Cut counter. Permission and originals stay with DoorKeyring.
var size := Vector3.ONE
var player: PlayerController
var panel: PanelContainer
var box: VBoxContainer
var feedback: Label
var opened := false
var hours: PassageHoursDirector
var _pointer_before := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	add_to_group("key_copy_counter")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	for offset in [Vector3(-.10,-.15,.3),Vector3(.08,-.15,.3)]:
		var key := preload("res://assets/props/resident_key.glb").instantiate() as Node3D
		key.position = offset
		for mesh: MeshInstance3D in key.find_children("*","MeshInstance3D",true,false): mesh.material_override = MatLib.get_mat("brass_dull")
		add_child(key)
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",TelegramStyle.paper_panel(.97))
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	panel.hide()
	get_viewport().size_changed.connect(_fit)
	box.minimum_size_changed.connect(_fit)

func interact_prompt() -> String:
	if hours != null and hours.is_after_hours(): return "Keys Cut is closed"
	return "Authorized key copies"

func interact(user: Node) -> void:
	if opened or not user is PlayerController or user.call_locked: return
	if hours != null and hours.is_after_hours(): return
	player = user
	_pointer_before = Input.mouse_mode
	player.call_locked = true
	opened = true
	add_to_group("attention_maintenance")
	_rebuild()
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _rebuild() -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "KEYS CUT / AUTHORIZED SPARES"
	TelegramStyle.apply(title,20,true)
	box.add_child(title)
	var note := Label.new()
	note.text = "Ask the resident for permission first. Their original key stays with them."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TelegramStyle.apply(note,16,false,TelegramStyle.CARBON)
	box.add_child(note)
	var value := DoorKeyring.book()
	if not value.is_empty():
		for unit: String in value.permissions:
			var button := Button.new()
			button.text = unit+" / spare already held" if value.copies.has(unit) else "Make authorized spare for "+unit
			button.disabled = value.copies.has(unit)
			button.pressed.connect(func():
				if hours != null and hours.is_after_hours():
					feedback.text = "Keys Cut is closed. Return during opening hours."
				elif DoorKeyring.make_copy(unit):
					_rebuild()
					feedback.text = "Spare for "+unit+" added to your key ring."
				else: feedback.text = "No copy made. Permission or a writable save is required.")
			box.add_child(button)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TelegramStyle.apply(feedback,16,false,TelegramStyle.CARBON)
	feedback.text = "No permissions recorded yet." if value.is_empty() or value.permissions.is_empty() else "One spare per authorized apartment."
	box.add_child(feedback)
	var close_button := Button.new()
	close_button.text = "Close / Escape"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	_fit()
	for child in box.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func _fit() -> void:
	var viewport := get_viewport().get_visible_rect().size
	panel.position = Vector2(28,70)
	panel.size = Vector2(minf(520,viewport.x-56),minf(box.get_combined_minimum_size().y+32,viewport.y-140))

func _unhandled_input(event: InputEvent) -> void:
	if not opened: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_services"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("activity_commit"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and box.is_ancestor_of(focused) and not focused.disabled: focused.pressed.emit()
		get_viewport().set_input_as_handled()

func close() -> void:
	if not opened: return
	opened = false
	remove_from_group("attention_maintenance")
	panel.hide()
	if is_instance_valid(player):
		player.call_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.mouse_released else _pointer_before

func _exit_tree() -> void:
	close()
