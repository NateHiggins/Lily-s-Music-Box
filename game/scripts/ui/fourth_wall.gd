class_name FourthWallLayer
extends CanvasLayer
## The part of the haunting that is not in the building.
##
## Eternal Darkness worked because its sanity effects attacked the things a
## player believes are outside the fiction: the volume, the save file, the
## television. You cannot be frightened by a monster you have already agreed
## to be frightened by, but you can absolutely be frightened by your own save
## data appearing to delete itself.
##
## Two rules keep that from being a cheap trick here.
##
## First, every effect is a sentence about a specific resident's wound, not a
## generic prank. Noel's grief preserved his family into a museum, so his
## effect accessions the game itself. Mae cannot hold two family histories at
## once, so hers puts two irreconcilable origins on the save file and keeps
## both. Sacha needs documentation before experience is real, so theirs tells
## the player exactly how long they have been playing and then points out
## that nobody has verified it. The meta layer is where each wound stops
## being about a resident and becomes about the person holding the controller.
##
## Second — and this is not negotiable — nothing here touches anything real.
## No file is written, no setting is changed, no input is actually rebound,
## nothing is actually deleted. Every effect is a picture of a catastrophe.
## They all self-clear on a timer even if the game is paused mid-effect,
## because an effect that can strand a player is a bug wearing a costume.

signal effect_finished(effect: String)

## Nothing may hold the screen longer than this, ever, whatever it claims to
## be doing. A fake save-corruption that outlives the player's patience stops
## being frightening and becomes a support ticket.
const HARD_CEILING := 7.0

var enabled := true
## What ran, in order. The director reads this to avoid repeating itself and
## the tests read it to prove effects self-clear.
var history: Array[String] = []

var _root: Control
var _active := ""
var _clear_at := 0.0
var _rng := RandomNumberGenerator.new()
var _session_started := 0


func _ready() -> void:
	layer = 40          # above the call interface, below nothing
	_session_started = Time.get_ticks_msec()
	_rng.randomize()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	set_process(true)


func _process(_delta: float) -> void:
	# Wall-clock, not frame-accumulated: an effect that fires during a stall
	# still has to end on schedule.
	if _active != "" and Time.get_ticks_msec() >= _clear_at:
		_finish()


func minutes_played() -> int:
	return int((Time.get_ticks_msec() - _session_started) / 60000.0)


func is_busy() -> bool:
	return _active != ""


## Fire an effect by name. Returns false if the layer is already showing
## something — overlapping meta effects read as a rendering bug rather than
## as a haunting, and the whole illusion depends on each one looking like the
## only thing that has gone wrong.
func play(effect: String, argument: String = "") -> bool:
	if not enabled or is_busy():
		return false
	_clear()
	var seconds := 3.0
	match effect:
		"volume_drop": seconds = _volume_drop()
		"save_corrupt": seconds = _save_corrupt()
		"session_time": seconds = _session_time()
		"second_operator": seconds = _second_operator()
		"violation_notice": seconds = _banner(
				"CITY OF RECORD — NOTICE OF VIOLATION",
				"OCCUPANCY EXCEEDED. THIS FLOOR HAS NO SECOND EXIT.\n" +
				"CORRECT WITHIN 30 DAYS.", Color(0.75, 0.16, 0.12), 4.0)
		"unrepairable_notice": seconds = _banner(
				"WORK ORDER CLOSED",
				"DECLARED UNREPAIRABLE.\nNo further attempts are authorised.",
				Color(0.42, 0.25, 0.10), 3.6)
		"accession": seconds = _banner(
				"ACCESSION 1927.4C.1",
				"DOMESTIC LIFE — UNUSED — EXCELLENT CONDITION\n" +
				"PLEASE DO NOT HANDLE.", Color(0.40, 0.33, 0.23), 3.8)
		"provenance": seconds = _banner(
				"SAVE ORIGIN DISPUTED",
				"Two histories on file for this building.\n" +
				"Both retained. Neither verified.",
				Color(0.36, 0.30, 0.42), 4.0)
		"checkout": seconds = _banner(
				"YOUR STAY HAS BEEN EXTENDED INDEFINITELY",
				"No action is required.\nNo action is possible.",
				Color(0.44, 0.25, 0.18), 3.6)
		"consent_form": seconds = _banner(
				"FORM 11-B — PROCEEDING WITHOUT COMPLETE INFORMATION",
				"By continuing you acknowledge that you do not have enough\n" +
				"information to continue.        [ ACKNOWLEDGED ]",
				Color(0.32, 0.34, 0.27), 4.4)
		"graded": seconds = _graded()
		"alarm": seconds = _banner(
				"CALL BELL — ROOM UNASSIGNED",
				"Not every alarm is yours.", Color(0.19, 0.35, 0.31), 3.2)
		"mic_hot": seconds = _banner(
				"● INPUT LEVEL",
				"Your microphone has been open this entire time.",
				Color(0.40, 0.12, 0.32), 3.4)
		"previous_session": seconds = _banner(
				"RESUMING PLAYBACK",
				"…from a session that has not happened.",
				Color(0.16, 0.29, 0.37), 3.4)
		"audience": seconds = _banner(
				"VIEWERS: 1",
				"Creation need not perform.", Color(0.16, 0.30, 0.62), 3.0)
		"stillness": seconds = _banner(
				"YOU HAVE STOPPED MOVING",
				"Weight can be shared. You can put it down.",
				Color(0.12, 0.34, 0.48), 3.2)
		"unfinished": seconds = _unfinished()
		"unravel_ui": seconds = _unravel()
		"replay_last": seconds = _banner(
				"◀◀  REPLAYING THE LAST PART",
				"one more time. just the last part.",
				Color(0.19, 0.39, 0.20), 3.4)
		"photo_behind": seconds = _photo_behind()
		_:
			return false
	_active = effect
	_clear_at = Time.get_ticks_msec() + int(minf(seconds, HARD_CEILING) * 1000.0)
	history.append(effect)
	_root.visible = true
	print("[FOURTH WALL] %s" % effect)
	return true


func _finish() -> void:
	var was := _active
	_active = ""
	_clear()
	_root.visible = false
	effect_finished.emit(was)


func _clear() -> void:
	for child in _root.get_children():
		child.queue_free()


# ------------------------------------------------------------- effects

## A system volume overlay, sliding to zero on its own. It is convincing
## because it is the one piece of UI a player is certain the game does not
## own — and because the game's audio really does duck with it, so the ears
## confirm what the eyes are being told.
func _volume_drop() -> float:
	var panel := _panel(Vector2(360, 74), Vector2(0.5, 0.86))
	var label := Label.new()
	label.text = "🔊"
	label.position = Vector2(16, 20)
	label.add_theme_font_size_override("font_size", 26)
	panel.add_child(label)
	var bar := ProgressBar.new()
	bar.position = Vector2(58, 28)
	bar.size = Vector2(280, 18)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	panel.add_child(bar)
	var tween := create_tween()
	tween.tween_property(bar, "value", 0.0, 2.1).set_delay(0.5)
	return 3.4


## The one that makes people put the controller down. Nothing is written,
## nothing is read, nothing is deleted — and it says so a second later, which
## is the joke and also the mercy.
func _save_corrupt() -> float:
	var panel := _panel(Vector2(560, 128), Vector2(0.5, 0.5))
	var title := _line(panel, "SAVE DATA CORRUPT", Vector2(24, 20), 18,
			Color(0.85, 0.24, 0.20))
	title.add_theme_font_size_override("font_size", 18)
	_line(panel, "Deleting ORISON APARTMENTS — do not turn off the system.",
			Vector2(24, 52), 13, Color(0.86, 0.86, 0.86))
	var bar := ProgressBar.new()
	bar.position = Vector2(24, 84)
	bar.size = Vector2(510, 16)
	bar.show_percentage = false
	panel.add_child(bar)
	var tween := create_tween()
	tween.tween_property(bar, "value", 100.0, 2.4)
	tween.tween_callback(func():
		if is_instance_valid(title):
			title.text = "SAVE DATA RESTORED"
			title.modulate = Color(0.55, 0.85, 0.6))
	return 4.6


## Sacha's wound aimed at the player: the game proves it has been watching by
## producing a fact only a stopwatch could know, then undermines the proof.
func _session_time() -> float:
	var panel := _panel(Vector2(600, 96), Vector2(0.5, 0.42))
	_line(panel, "You have been on the line for %d minutes."
			% minutes_played(), Vector2(24, 24), 16, Color(0.92, 0.9, 0.86))
	_line(panel, "Nobody has verified that.", Vector2(24, 56), 13,
			Color(0.6, 0.62, 0.66))
	return 4.0


func _second_operator() -> float:
	var panel := _panel(Vector2(520, 82), Vector2(0.5, 0.14))
	_line(panel, "ANOTHER OPERATOR HAS JOINED THIS CHANNEL",
			Vector2(20, 18), 15, Color(0.95, 0.72, 0.35))
	_line(panel, "They are already answering.", Vector2(20, 48), 13,
			Color(0.7, 0.7, 0.7))
	return 3.6


## Evelyn grades the frame itself. The red pen is the point: the player has
## done nothing wrong and is being corrected anyway, which is precisely what
## she cannot stop doing to the people she loves.
func _graded() -> float:
	var panel := _panel(Vector2(300, 110), Vector2(0.82, 0.22))
	_line(panel, "B−", Vector2(24, 14), 44, Color(0.82, 0.16, 0.14))
	_line(panel, "SEE ME.", Vector2(120, 44), 20, Color(0.82, 0.16, 0.14))
	return 3.2


## Jonah's sentences lose their endings while you are reading them.
func _unfinished() -> float:
	var panel := _panel(Vector2(640, 92), Vector2(0.5, 0.78))
	var text := _line(panel,
			"and then he put the letter down and never did finish",
			Vector2(20, 30), 15, Color(0.9, 0.88, 0.82))
	var full: String = text.text
	var tween := create_tween()
	for i in range(full.length() - 1, 8, -3):
		tween.tween_callback(func():
			if is_instance_valid(text):
				text.text = full.substr(0, i)).set_delay(0.075)
	return 4.4


## Lena's wound applied to the interface: it comes apart, and it can be
## mended, and the mend shows.
func _unravel() -> float:
	var panel := _panel(Vector2(420, 90), Vector2(0.5, 0.7))
	var line := _line(panel, "████████████████████████████",
			Vector2(20, 30), 16, Color(0.55, 0.16, 0.12))
	var tween := create_tween()
	tween.tween_callback(func():
		if is_instance_valid(line):
			line.text = "███████  ████   ██     █").set_delay(1.1)
	tween.tween_callback(func():
		if is_instance_valid(line):
			line.text = "a visible repair is still a repair"
			line.modulate = Color(0.85, 0.8, 0.7)).set_delay(1.2)
	return 4.0


## Sacha again, at the rung below: a camera flash and a thumbnail of a room
## the player is not looking at. The frame is empty. That is worse.
func _photo_behind() -> float:
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(flash)
	create_tween().tween_property(flash, "color",
			Color(1, 1, 1, 0.0), 0.45)
	var panel := _panel(Vector2(260, 176), Vector2(0.86, 0.78))
	var shot := ColorRect.new()
	shot.position = Vector2(12, 12)
	shot.size = Vector2(236, 128)
	shot.color = Color(0.04, 0.05, 0.06)
	panel.add_child(shot)
	_line(panel, "BEHIND YOU — 1 FRAME", Vector2(12, 146), 12,
			Color(0.7, 0.72, 0.75))
	return 3.4


## The workhorse. Most per-resident meta effects are a title and a line of
## body text in that resident's accent colour, styled like a notice issued by
## an institution that has no idea it is talking to a person.
func _banner(title: String, body: String, tint: Color,
		seconds: float) -> float:
	var panel := _panel(Vector2(620, 122), Vector2(0.5, 0.34))
	var heading := _line(panel, title, Vector2(22, 18), 17, tint)
	heading.add_theme_font_size_override("font_size", 17)
	var text := _line(panel, body, Vector2(22, 52), 13,
			Color(0.86, 0.86, 0.84))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(576, 48)
	text.size = Vector2(576, 48)
	return seconds


# ------------------------------------------------------------- helpers

func _panel(size: Vector2, anchor: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.055, 0.065, 0.94)
	style.border_color = Color(0.22, 0.24, 0.28)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	# Anchored by fraction so it sits sensibly on a phone as well as 1440p.
	var view := get_viewport().get_visible_rect().size
	panel.position = Vector2(view.x * anchor.x - size.x * 0.5,
			view.y * anchor.y - size.y * 0.5)
	return panel


func _line(parent: Control, text: String, at: Vector2, font_size: int,
		tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = tint
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Test hook: run an effect to completion immediately rather than waiting out
## its timer, so a suite can prove the layer always clears itself.
func force_finish() -> void:
	if _active != "":
		_finish()
