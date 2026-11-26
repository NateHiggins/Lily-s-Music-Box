class_name SongbookPanel
extends CanvasLayer
## The Songbook, on the terminal's screen. Phase 1 of the brief, end to
## end: write words into the phrase slots, sing them over the backing
## with the words moving in time, then keep the take or throw it away.
##
## THE ONE RULE THIS FILE EXISTS TO OBEY. The brief is emphatic that
## there are no canonical lyrics to anything in the Songbook — a song is
## a shape with holes in it, and whatever the last person sang is as
## legitimate as whatever the first did. So the editor ADVISES and never
## refuses: the syllable map shows the shape the melody expects, the
## count goes amber when a line runs long, and the line is accepted
## exactly as typed regardless. The only mode that may refuse a line is
## STRICT METER, which is Phase 2 and which the player has to choose.
##
## Laid out as the terminal's own screen rather than as a game menu:
## green phosphor on near-black, one column, no mouse. A rented karaoke
## box from the 80s has a numeric keypad and four buttons, and the whole
## interface has to survive being read across a bar.

const OriginalCustody := preload("res://scripts/songbook/player_original_custody.gd")
## SongSynth renders exactly this arrangement. The catalogue filename is last_train_home.
const SYNTH_BACKING_ID := "track_018"
const RECOVERY_PAGE_SIZE := 6
const TraceCustody := preload("res://scripts/songbook/found_trace_custody.gd")
const TraceForge := preload("res://scripts/songbook/phonautogram_forge.gd")

const GREEN := Color(0.42, 0.94, 0.58)
const GREEN_DIM := Color(0.24, 0.52, 0.34)
const AMBER := Color(0.96, 0.74, 0.28)
const IVORY := Color(0.90, 0.94, 0.88)
const BG := Color(0.035, 0.055, 0.042, 0.97)

enum Mode { MENU, EDIT, MIC_CONSENT, CLAP, PERFORM, REVIEW, READING, OLD, ORIGINALS, SLEEVE, RECOVERY, RECOVERY_SLEEVE }

var song: SongResource
var mode: int = Mode.MENU
## slot id -> the words written for it. The brief's shape exactly: the
## song owns the holes, a version owns the words.
var lyrics: Dictionary = {}
var cursor := 0
var play_time := 0.0

var _player: Node
var _terminal: Node
var _root: Control
var _body: VBoxContainer
var _status: Label
var _edit: LineEdit
var _edit_slot := ""
var _backing: AudioStreamPlayer
var _guide: AudioStreamPlayer
var _mic: MicRecorder
var _clap_start: Timer
var _keep_attempt: SongbookStore.KeepAttempt
var _take: AudioStreamWAV
## End of this performance in native backing seconds, before the house varispeed.
var _take_end_seconds := -1.0
var _saved_end_seconds := -1.0
var _reader: AudioStreamPlayer
## The speed this reading committed to. Drawn fresh every time, which is why
## the same trace can come back as a different person - see
## PhonautogramReader and ORISON_BIBLE III.2.
var _read_speed := 1.0
var _read_t := 0.0
## Where the reading came from, so lifting the stylus goes back there. Reading
## a found trace and landing on a review screen for a take you never made is
## the machine claiming you sang something you did not.
var _read_from_old := false
## Preserve the identity shown on each numbered row until the list is redrawn.
var _trace_rows: Array[String] = []
var _original_rows: Array[String] = []
var _legacy_ids: Array[String] = []
var _legacy_page := 0
var _legacy_campaign: Dictionary = {}
var _legacy_path := ""
var _legacy_missing_id := ""
var _read_original_id := ""
var _saved_lyrics: Dictionary = {}
var _saved_phrase: Label
## TASKS.md G1a: true while READING plays a found trace through the guessing
## reader; false while it plays the take's immutable composite reconstruction.
var _read_is_trace := true
var _rendered: Dictionary = {}
var _rendered_arrangement := SongSynth.ARRANGEMENT_V1


func open(s: SongResource, player: Node, terminal: Node) -> void:
	song = s
	_player = player
	_terminal = terminal
	layer = 12
	for slot in song.slots:
		lyrics[str(slot.id)] = ""
	_build()
	_show_menu()
	# The player is standing at a machine with both hands on it.
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	_clap_start = Timer.new()
	_clap_start.one_shot = true
	_clap_start.timeout.connect(_clap_finished)
	add_child(_clap_start)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 90)
	frame.add_theme_constant_override("margin_right", 90)
	frame.add_theme_constant_override("margin_top", 54)
	frame.add_theme_constant_override("margin_bottom", 54)
	_root.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	frame.add_child(col)

	var head := Label.new()
	head.text = "THE SONGBOOK   ·   %s   ·   %s   ·   %d BPM" % [
			song.title.to_upper(), song.key, int(song.bpm)]
	head.add_theme_color_override("font_color", GREEN_DIM)
	head.add_theme_font_size_override("font_size", 15)
	col.add_child(head)

	var rule := ColorRect.new()
	rule.color = GREEN_DIM
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)

	_status = Label.new()
	_status.add_theme_color_override("font_color", GREEN_DIM)
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)


func _clear() -> void:
	if _edit != null:
		# Native text_changed is deferred. Take the last keystroke with us if
		# the player turns the page or leaves the editor in the same frame.
		lyrics[_edit_slot] = _edit.text
		_edit = null
		_edit_slot = ""
	for c in _body.get_children():
		c.queue_free()


func _line(text: String, colour: Color, size := 17) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	l.add_theme_font_size_override("font_size", size)
	_body.add_child(l)
	return l


# ---------------------------------------------------------------- MENU
func _show_menu() -> void:
	mode = Mode.MENU
	_clear()
	_line("", GREEN)
	_line("1    WRITE THE WORDS", GREEN)
	_line("2    SING IT", GREEN if _has_any_words() else GREEN_DIM)
	_line("3    YOUR ORIGINALS IN THE VALISE   (%d)" % _carried_editions().size(), GREEN_DIM)
	_line("4    TRACES IN THE VALISE   (%d)"
			% TraceCustody.held_ids().size(), GREEN_DIM)
	_line("", GREEN)
	var written := 0
	for k in lyrics:
		if str(lyrics[k]).strip_edges() != "":
			written += 1
	_line("%d of %d phrases have words in them."
			% [written, song.slots.size()], GREEN_DIM, 14)
	_status.text = "Press a number.   ESC to step away from the machine."


func _has_any_words() -> bool:
	for k in lyrics:
		if str(lyrics[k]).strip_edges() != "":
			return true
	return false


## Only campaign-held originals for this installed backing are reachable. Keep
## the version ID behind each displayed row so a moved sheet cannot change a pick.
func _carried_editions() -> Dictionary:
	var editions := {}
	if song.id != SYNTH_BACKING_ID:
		return editions
	for id in OriginalCustody.packed_ids():
		if OriginalCustody.song_id(id) != song.id or not OriginalCustody.is_packed(id):
			continue
		var row := SongbookStore.private_edition(id, song.id)
		if not row.is_empty():
			editions[id] = row
	return editions


func _show_originals() -> void:
	mode = Mode.ORIGINALS
	_clear()
	_read_original_id = ""
	_saved_lyrics = {}
	_saved_end_seconds = -1.0
	_saved_phrase = null
	_legacy_ids.clear()
	_legacy_campaign = {}
	_legacy_path = ""
	_legacy_missing_id = ""
	_line("YOUR ORIGINALS IN THE VALISE.", GREEN, 22)
	var editions := _carried_editions()
	_original_rows.assign(editions.keys())
	_original_rows.sort()
	if _original_rows.is_empty():
		_line("No private originals for this backing in the valise.", GREEN_DIM, 15)
	for i in _original_rows.size():
		var id := _original_rows[i]
		_line("%d    %s" % [i + 1, _edition_label(id, editions[id])], GREEN, 16)
	if song.id == SYNTH_BACKING_ID:
		_line("R    LOOK FOR OLDER PRIVATE RECORDINGS", GREEN_DIM, 15)
	_status.text = "Press a number to play.   ESC for the menu."


func _edition_label(id: String, row: Dictionary) -> String:
	var opening := ""
	for slot: Dictionary in song.slots:
		opening = str(row.lyrics.get(slot.id, "")).strip_edges()
		if not opening.is_empty():
			break
	return "%s    %s" % [id.trim_prefix(song.id + "_"), opening.left(48)]


func _open_recovery(page := 0) -> void:
	if song.id != SYNTH_BACKING_ID:
		_show_originals()
		return
	_legacy_ids.clear()
	_legacy_campaign = RealityState.data
	_legacy_path = RealityState.save_path
	for id in SongbookStore.legacy_ids(song.id):
		if OriginalCustody.song_id(id).is_empty():
			_legacy_ids.append(id)
	_draw_recovery(page)


func _draw_recovery(page: int) -> void:
	if not _same_recovery_campaign():
		_show_originals()
		return
	mode = Mode.RECOVERY
	_clear()
	_legacy_missing_id = ""
	var pages := maxi(1, ceili(float(_legacy_ids.size()) / RECOVERY_PAGE_SIZE))
	_legacy_page = clampi(page, 0, pages - 1)
	_line("PRIVATE RECORDINGS FROM BEFORE THE TRAY.", GREEN, 20)
	if _legacy_ids.is_empty():
		_line("No older originals are waiting here.", GREEN_DIM, 15)
	else:
		_line("Page %d of %d" % [_legacy_page + 1, pages], GREEN_DIM, 15)
	var start := _legacy_page * RECOVERY_PAGE_SIZE
	for i in range(start, mini(start + RECOVERY_PAGE_SIZE, _legacy_ids.size())):
		var id := _legacy_ids[i]
		var row := SongbookStore.private_edition(id, song.id)
		var label := "Unavailable"
		if not row.is_empty() and not row.has(SongbookStore.PHYSICAL_EDITION_KEY):
			label = _edition_label(id, row)
		_line("%d    %s" % [i - start + 1, label], GREEN, 16)
	_status.text = "Number puts one original in the tray.   LEFT / RIGHT turns the page.   ESC returns."


func _same_recovery_campaign() -> bool:
	return song.id == SYNTH_BACKING_ID and is_same(RealityState.data, _legacy_campaign) and RealityState.save_path == _legacy_path


func _retrieve_legacy(id: String) -> void:
	if not _same_recovery_campaign():
		_show_originals()
		_status.text = "Reopen the older recordings for this campaign."
		return
	if not _legacy_ids.has(id) or not OriginalCustody.song_id(id).is_empty():
		_open_recovery(_legacy_page)
		_status.text = "This sheet is no longer waiting here."
		return
	var row := SongbookStore.private_playback(id, song.id, true)
	if row.is_empty():
		_open_recovery(_legacy_page)
		_status.text = "This older recording is unavailable."
		return
	if not row.vocal_stem.is_empty() and row.vocal == null and _legacy_missing_id != id:
		mode = Mode.RECOVERY_SLEEVE
		_legacy_missing_id = id
		_clear()
		_line("THE VOCAL IS UNAVAILABLE.", AMBER, 22)
		_line(_edition_label(id, row), GREEN_DIM, 16)
		_status.text = "ENTER to recover the written sleeve alone.   ESC returns."
		return
	if not OriginalCustody.admit(row):
		_status.text = "The tray is jammed. Try this sheet again."
		return
	_show_originals()
	_status.text = "Your original is in the output tray."


func _read_original(id: String) -> void:
	if song.id != SYNTH_BACKING_ID or OriginalCustody.song_id(id) != song.id or not OriginalCustody.is_packed(id):
		_show_originals()
		_status.text = "That sheet is no longer in the valise."
		return
	var record := SongbookStore.private_playback(id, song.id)
	if record.is_empty():
		_show_originals()
		_status.text = "This original cannot be read."
		return
	_clear()
	_read_original_id = id
	_saved_lyrics = record.lyrics
	_saved_end_seconds = record.get(SongbookStore.PERFORMED_SECONDS, -1.0)
	var arrangement: Variant = record.get("backing_arrangement", SongSynth.ARRANGEMENT_V1)
	var sleeve_reason := ""
	if _saved_end_seconds == 0.0:
		sleeve_reason = "THE MUSIC HADN'T STARTED."
	elif not record.vocal_stem.is_empty() and record.vocal == null:
		sleeve_reason = "THE VOCAL IS UNAVAILABLE."
	elif arrangement is not String or not _load_arrangement(arrangement):
		sleeve_reason = "THE BACKING IS UNAVAILABLE."
	if not sleeve_reason.is_empty():
		mode = Mode.SLEEVE
		_line(sleeve_reason, AMBER, 22)
		var sleeve := RichTextLabel.new()
		sleeve.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sleeve.focus_mode = Control.FOCUS_ALL
		sleeve.add_theme_color_override("default_color", IVORY)
		var phrases := PackedStringArray()
		for slot: Dictionary in song.slots:
			var words := str(_saved_lyrics.get(slot.id, "")).strip_edges()
			if not words.is_empty():
				phrases.append(words)
		sleeve.text = "\n\n".join(phrases)
		_body.add_child(sleeve)
		sleeve.grab_focus()
		_status.text = "The words are on the sleeve.   ESC to return."
		return
	_play_composite(record.vocal, record.playback_ratio, _saved_end_seconds)
	_line("THE RECONSTRUCTION.", GREEN, 22)
	if not record.has("reconstruction_ratio"):
		_line("Speed unmarked. Using the first fixed setting (%.3f times)." % record.playback_ratio, GREEN_DIM, 15)
	_line("Words and backing." if record.vocal == null else "Voice and backing.", GREEN_DIM, 15)
	_saved_phrase = _line("", IVORY, 22)
	_saved_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_saved_phrase(0.0)
	_status.text = "Any key to lift the stylus."


func _update_saved_phrase(source_time: float) -> void:
	var slot := song.slot_at(source_time)
	if slot.is_empty():
		slot = song.next_slot_after(source_time)
		if _saved_end_seconds >= 0.0 and float(slot.get("start_time", 0.0)) >= _saved_end_seconds:
			slot = {}
	_saved_phrase.text = str(_saved_lyrics.get(slot.get("id", ""), ""))


# ---------------------------------------------------------------- EDIT
## The lyric editor. One phrase at a time, with the syllable map drawn
## above the line — the shape the melody is expecting, as underscores
## grouped in fours so a long phrase stays countable by eye.
func _show_edit() -> void:
	mode = Mode.EDIT
	_clear()
	var slot: Dictionary = song.slots[cursor]
	var want := int(slot.get("suggested_syllables", 0))
	_line("PHRASE %d OF %d      %s" % [cursor + 1, song.slots.size(),
			str(slot.get("section", "")).to_upper()], GREEN_DIM, 14)
	_line("", GREEN, 8)
	# The melodic shape, in words rather than notation: the brief wants
	# a writer to know what the tune does without reading music.
	var shape := str(slot.get("melodic_shape", ""))
	if shape != "":
		_line("the tune here:  %s" % shape, GREEN_DIM, 14)
	_line(SongResource.syllable_map(want), GREEN_DIM, 20)
	_line("", GREEN, 6)          # the map's descenders, off the box
	_edit = LineEdit.new()
	_edit_slot = str(slot.id)
	_edit.text = str(lyrics.get(_edit_slot, ""))
	_edit.placeholder_text = "sing something"
	_edit.add_theme_color_override("font_color", IVORY)
	_edit.add_theme_font_size_override("font_size", 20)
	_edit.custom_minimum_size = Vector2(0, 38)
	_edit.text_changed.connect(_on_typed.bind(_edit))
	_body.add_child(_edit)
	_edit.grab_focus()
	_edit.edit()
	_edit.caret_column = _edit.text.length()
	_line("", GREEN, 8)
	_count_line(want)
	_status.text = ("ENTER next phrase   ·   UP/DOWN move   ·   "
			+ "ESC back to the menu")


func _count_line(want: int) -> void:
	var l := _line("", GREEN_DIM, 14)
	l.name = "count"
	_refresh_count(want)


func _refresh_count(want: int) -> void:
	var l := _body.get_node_or_null("count") as Label
	if l == null or _edit == null:
		return
	var got := SongResource.syllables(_edit.text)
	if _edit.text.strip_edges() == "":
		l.text = "the melody has room for about %d." % want
		l.add_theme_color_override("font_color", GREEN_DIM)
		return
	# ADVISORY, ALWAYS. Amber is a remark, not a refusal — the line is
	# accepted exactly as typed either way, which is the whole argument
	# of the brief.
	var diff := got - want
	if absi(diff) <= 1:
		l.text = "%d syllables. that will sit." % got
		l.add_theme_color_override("font_color", GREEN)
	elif diff > 0:
		l.text = ("%d syllables against about %d — you will be hurrying. "
				+ "sing it anyway if you mean it.") % [got, want]
		l.add_theme_color_override("font_color", AMBER)
	else:
		l.text = ("%d syllables against about %d — room to hold a note."
				) % [got, want]
		l.add_theme_color_override("font_color", AMBER)


func _on_typed(text: String, source: LineEdit) -> void:
	if source == _edit:
		lyrics[_edit_slot] = text
		_refresh_count(int(song.slots[cursor].get("suggested_syllables", 0)))


func _move(step: int) -> void:
	cursor = clampi(cursor + step, 0, song.slots.size() - 1)
	_show_edit()


# ---------------------------------------------------------- CLAP CHECK
func _show_mic_consent() -> void:
	mode = Mode.MIC_CONSENT
	_clear()
	_line("", GREEN)
	_line("BEFORE THE MIC CHECK.", GREEN, 22)
	_line("", GREEN, 10)
	_line("the Songbook will record your microphone and keep the take on this machine.",
			IVORY, 15)
	_line("nothing is uploaded. you can perform without recording.", GREEN_DIM, 15)
	_status.text = "1  use microphone     2  not this time"


func _discard_microphone() -> void:
	if is_instance_valid(_clap_start):
		_clap_start.stop()
	if is_instance_valid(_mic):
		_mic.set_process(false)
		_mic.stop_recording()
		_mic.stop_input()
		_mic.queue_free()
	_mic = null


func _perform_without_microphone() -> void:
	_discard_microphone()
	_start_perform()


func _cancel_microphone_to_menu() -> void:
	_discard_microphone()
	_show_menu()


## Latency check before any take. The brief calls for it and it is also
## the most diegetic possible calibration: you clap once into the mic,
## the machine hears when it actually arrived, and everything after is
## shifted by the difference. No slider, no numbers.
func _show_clap() -> void:
	_discard_microphone()
	mode = Mode.CLAP
	_clear()
	_line("", GREEN)
	_line("CLAP ONCE, LOUDLY.", GREEN, 22)
	_line("", GREEN, 10)
	_line("the machine needs to hear how late it is hearing you.",
			GREEN_DIM, 15)
	_status.text = "Listening for one clap. ESC cancels microphone setup."
	_mic = MicRecorder.new()
	add_child(_mic)
	_mic.calibrated.connect(_on_calibrated.bind(_mic), CONNECT_ONE_SHOT)
	if not _mic.begin_clap_check():
		# No microphone: the brief still wants the song singable, so the
		# take is simply silent and the words are what survive.
		_line("", GREEN, 8)
		_line("no microphone. you can still sing it to yourself.",
				AMBER, 15)
		_clap_start.start(1.6)


func _on_calibrated(offset_ms: float, recorder: MicRecorder) -> void:
	if mode != Mode.CLAP or recorder != _mic or not is_instance_valid(recorder):
		return
	_status.text = "Microphone latency measured: %d ms. Timing compensation is active." % int(offset_ms)
	_clap_start.start(0.9)


func _clap_finished() -> void:
	if mode == Mode.CLAP and not is_queued_for_deletion():
		_start_perform()


# ------------------------------------------------------------- PERFORM
func _start_perform() -> void:
	if mode != Mode.MIC_CONSENT and mode != Mode.CLAP:
		return
	_take = null
	_take_end_seconds = -1.0
	_keep_attempt = null
	mode = Mode.PERFORM
	play_time = 0.0
	_clear()
	if not _load_arrangement(SongSynth.current_arrangement(song.id)):
		_discard_microphone()
		_show_menu()
		_status.text = "This arrangement is unavailable."
		return
	BarPA.ensure_bus()
	if _backing == null:
		_backing = AudioStreamPlayer.new()
		_backing.finished.connect(_stop_perform.bind(true))
		add_child(_backing)
	_backing.stream = _rendered["backing"]
	_backing.pitch_scale = 1.0
	_backing.bus = BarPA.BUS
	if _guide == null:
		_guide = AudioStreamPlayer.new()
		add_child(_guide)
	_guide.stream = _rendered["guide"]
	_guide.bus = BarPA.BUS
	_guide.volume_db = -14.0
	_backing.play()
	_guide.play()
	if _mic:
		_mic.start_recording()
	_status.text = "ESC stops the take."


## The karaoke display. Three lines: what is being sung now, large; what
## is coming, dim; and a bar that fills across the phrase so a singer
## knows how long they have without counting.
func _draw_perform() -> void:
	_clear()
	var here := song.slot_at(play_time)
	var section := song.section_at(play_time)
	_line(section.to_upper(), GREEN_DIM, 14)
	_line("", GREEN, 6)
	if here.is_empty():
		var nxt := song.next_slot_after(play_time)
		if nxt.is_empty():
			_line("(the last train has gone)", GREEN_DIM, 20)
		else:
			var wait := float(nxt.start_time) - play_time
			_line("...", GREEN_DIM, 20)
			_line("", GREEN, 6)
			_line(_words_or_blank(nxt), GREEN_DIM, 20)
			_status.text = "in %0.1f" % wait
		return
	_line(_words_or_blank(here), IVORY, 30)
	# How far through the phrase, as a filled bar.
	var span := maxf(0.001, float(here.end_time) - float(here.start_time))
	var frac := clampf((play_time - float(here.start_time)) / span,
			0.0, 1.0)
	var cells := 42
	var lit := int(frac * cells)
	_line("[" + "=".repeat(lit) + " ".repeat(cells - lit) + "]",
			GREEN, 16)
	_line("", GREEN, 6)
	var after := song.next_slot_after(play_time)
	if not after.is_empty():
		_line(_words_or_blank(after), GREEN_DIM, 18)


func _words_or_blank(slot: Dictionary) -> String:
	var w := str(lyrics.get(str(slot.id), "")).strip_edges()
	if w != "":
		return w
	# An unwritten phrase is not an error. It is a hole, and the display
	# shows its shape so a singer can improvise into it — which is what
	# the Blind Read mode in Addendum A is built on.
	return SongResource.syllable_map(
			int(slot.get("suggested_syllables", 4)))


func _stop_perform(completed := false) -> void:
	if mode != Mode.PERFORM:
		return
	if _backing:
		var base := _backing.stream as AudioStreamWAV
		if base != null:
			# finished fires after the playback cursor has been released. On
			# manual release, capture the cursor before stop() clears it.
			var length := base.get_length()
			var seconds := length if completed else _backing.get_playback_position()
			var frames := roundi(clampf(seconds, 0.0, length) * base.mix_rate)
			_take_end_seconds = float(frames) / base.mix_rate
		_backing.stop()
	if _guide:
		_guide.stop()
	if _mic:
		_take = _mic.stop_recording()
		_discard_microphone()
	_show_review()


# -------------------------------------------------------------- REVIEW
func _show_review() -> void:
	mode = Mode.REVIEW
	_clear()
	_line("", GREEN)
	_line("THAT IS A TAKE.", GREEN, 22)
	_line("", GREEN, 8)
	var sung := 0
	for k in lyrics:
		if str(lyrics[k]).strip_edges() != "":
			sung += 1
	_line("%d phrases with words. %s" % [sung,
			"a vocal is on it." if _take != null
			else "no vocal — the words are what survive."],
			GREEN_DIM, 15)
	_line("", GREEN, 10)
	_line("1    KEEP IT", GREEN)
	_line("2    SING IT AGAIN", GREEN)
	_line("3    THROW IT AWAY", GREEN_DIM)
	if _take != null or _take_end_seconds > 0.0:
		_line("4    READ IT BACK", GREEN_DIM)
	_status.text = "Nothing is saved unless you choose KEEP IT. Nothing is uploaded."


func _keep() -> void:
	if mode != Mode.REVIEW:
		return
	if _keep_attempt == null:
		_keep_attempt = SongbookStore.begin_keep_attempt(song)
	var rec: Dictionary = {}
	if _keep_attempt != null:
		rec = SongbookStore.save_version(song, lyrics, _take, "PRIVATE", "", "you", false, _keep_attempt, _take_end_seconds)
	if rec.is_empty():
		_status.text = "Could not keep this take. Press 1 to try again."
		return
	if not OriginalCustody.admit(rec):
		_status.text = "Your take is on file. The tray is jammed. Press 1 to try again."
		return
	_clear()
	_line("", GREEN)
	_line("KEPT.", GREEN, 22)
	_line("", GREEN, 8)
	_line("filed as %s." % str(rec.version_id), GREEN_DIM, 15)
	_line("Pick up your original from the output tray.", GREEN_DIM, 15)
	_status.text = "ESC to step away."
	mode = Mode.MENU


## THE TRACES THAT WERE ALREADY HERE (ORISON_BIBLE III.2). Nobody in the bar
## knows who sang them. The sleeves say almost nothing and the pencil on them is
## not evidence of anything - somebody wrote "for M." on one, and there are four
## residents whose name starts with M.
func _show_old() -> void:
	mode = Mode.OLD
	_clear()
	_line("", GREEN)
	_line("TRACES IN THE VALISE.", GREEN, 22)
	_line("", GREEN, 8)
	_trace_rows = TraceCustody.held_ids()
	if _trace_rows.is_empty():
		_line("The valise holds no traces.", GREEN_DIM, 15)
		_status.text = "ESC to go back."
		return
	for i in _trace_rows.size():
		_line("%d    %s" % [i + 1, TraceForge.label_of(_trace_rows[i])],
				GREEN_DIM, 15)
	_line("", GREEN, 10)
	_line("none of these have a name on them.", GREEN_DIM, 14)
	_status.text = "Press a number.   ESC to go back."


func _read_found(trace_id: String) -> void:
	if not TraceCustody.is_packed(trace_id):
		_show_old()
		return
	_take = TraceForge.forge(trace_id)
	_read_back()
	_read_from_old = true
	# Overwrite the closing line: reading somebody else's trace is a different
	# sentence from reading your own.
	_line("nobody alive remembers singing this.", GREEN_DIM, 15)


## Read a FOUND trace. NOT playback - the machine never held a recording, only
## a line in soot, and what comes out is that line interpreted. It does not
## know how fast the crank was turned, so it guesses, and the guess is drawn
## fresh every time. Somebody reading the same trace twice can hear two
## different people, which is exactly what happened to Scott in 2008.
## TASKS.md G1a: this guessing reader serves found traces ONLY - the player's
## own take auditions through _read_back_take(), the immutable reconstruction.
func _read_back() -> void:
	mode = Mode.READING
	_read_t = 0.0
	_read_from_old = false
	_read_is_trace = true
	BarPA.ensure_bus()
	if _reader == null:
		_reader = AudioStreamPlayer.new()
		add_child(_reader)
	_reader.stream = _take
	_reader.bus = BarPA.BUS
	_reader.volume_db = 0.0
	_read_speed = PhonautogramReader.attach_stream(_reader, "take_%d" % Time.get_ticks_msec())
	_reader.play()

	_clear()
	_line("", GREEN)
	_line("READING THE TRACE.", GREEN, 22)
	_line("", GREEN, 8)
	# The machine says what it assumed, because a reading that hid its
	# assumption would be a lie rather than a limitation.
	var claim := "the crank was steady."
	if _read_speed < 0.8:
		claim = "the crank was turned SLOWLY. it is guessing."
	elif _read_speed > 1.2:
		claim = "the crank was turned FAST. it is guessing."
	elif not is_equal_approx(_read_speed, 1.0):
		claim = "the crank wandered. it is guessing."
	_line(claim, GREEN_DIM, 15)
	_line("", GREEN, 10)
	_line("the paper kept the voice.", GREEN_DIM, 15)
	_line("nobody wrote down the speed.", GREEN_DIM, 15)
	_status.text = "any key to lift the stylus."


## TASKS.md G1b: READ IT BACK auditions the same composite reconstruction
## recipients get - the stable backing plus the recorded vocal, both varisped
## together at the song's one immutable ratio. No fresh guess, no wow, no
## skips: every reading of a version agrees with every other, which is the
## entire difference between a published version and a found trace. The dry
## mic stem stays local (it is assembly material, never the shared artifact),
## and per G1c the review is non-positional at the machine.
func _play_composite(vocal: AudioStreamWAV, ratio: float, end_seconds := -1.0) -> void:
	mode = Mode.READING
	_read_t = 0.0
	_read_from_old = false
	_read_is_trace = false
	var backing := _performed_prefix(_rendered.backing, end_seconds)
	var voice := _performed_prefix(vocal, end_seconds)
	BarPA.ensure_bus()
	if _reader == null:
		_reader = AudioStreamPlayer.new()
		add_child(_reader)
	if backing == null:
		_reader.stop()
		_reader.stream = null
		return
	var mix := AudioStreamSynchronized.new()
	mix.stream_count = 1 if voice == null else 2
	mix.set_sync_stream(0, backing)
	if voice != null:
		mix.set_sync_stream(1, voice)
	_reader.stream = mix
	_reader.bus = BarPA.BUS
	_reader.volume_db = 0.0
	_read_speed = ratio
	_reader.pitch_scale = ratio
	_reader.play()


## Both sources supply unlooped 8/16-bit PCM. Each playback copy ends on the
## nearest frame at its own native rate; the stored master retains every sample.
func _performed_prefix(wave: AudioStreamWAV, end_seconds: float) -> AudioStreamWAV:
	if wave == null or end_seconds < 0.0 or end_seconds >= wave.get_length():
		return wave
	var frames := roundi(end_seconds * wave.mix_rate)
	if frames <= 0:
		return null
	var stride := (2 if wave.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wave.stereo else 1)
	var excerpt := AudioStreamWAV.new()
	excerpt.format = wave.format
	excerpt.mix_rate = wave.mix_rate
	excerpt.stereo = wave.stereo
	excerpt.data = wave.data.slice(0, frames * stride)
	return excerpt


func _load_arrangement(arrangement: String) -> bool:
	if not _rendered.is_empty() and _rendered_arrangement == arrangement:
		return true
	var streams := SongSynth.render(arrangement)
	if streams.is_empty():
		return false
	_rendered = streams
	_rendered_arrangement = arrangement
	return true


func _read_back_take() -> void:
	if not _load_arrangement(SongSynth.current_arrangement(song.id)):
		_status.text = "This arrangement is unavailable."
		return
	_play_composite(_take, song.return_ratio, _take_end_seconds)

	_clear()
	_line("", GREEN)
	_line("THE RECONSTRUCTION.", GREEN, 22)
	_line("", GREEN, 8)
	_line("the machine reads the whole take back too fast.", GREEN_DIM, 15)
	_line("the same amount every time. it does not guess.", GREEN_DIM, 15)
	_line("", GREEN, 10)
	_line("this is what everyone else hears.", GREEN_DIM, 15)
	_status.text = "any key to lift the stylus."


func _stop_reading() -> void:
	if _reader:
		_reader.stop()
		_reader.pitch_scale = 1.0
		_reader.volume_db = 0.0
		_reader.stream = null
	if not _read_original_id.is_empty():
		_show_originals()
	elif _read_from_old:
		_take = null      # it was never yours; do not offer to keep it
		_show_old()
	else:
		_show_review()


# --------------------------------------------------------------- INPUT
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		match mode:
			Mode.PERFORM: _stop_perform()
			Mode.CLAP: _cancel_microphone_to_menu()
			Mode.READING: _stop_reading()
			Mode.SLEEVE, Mode.RECOVERY: _show_originals()
			Mode.RECOVERY_SLEEVE: _draw_recovery(_legacy_page)
			Mode.EDIT, Mode.MIC_CONSENT, Mode.REVIEW, Mode.OLD, Mode.ORIGINALS: _show_menu()
			_: close()
		get_viewport().set_input_as_handled()
		return
	match mode:
		Mode.MENU:
			if key == KEY_1:
				cursor = 0
				_show_edit()
			elif key == KEY_2 and _has_any_words():
				_show_mic_consent()
			elif key == KEY_3:
				_show_originals()
				get_viewport().set_input_as_handled()
			elif key == KEY_4:
				_show_old()
		Mode.RECOVERY:
			var pick := key - KEY_1
			var index := _legacy_page * RECOVERY_PAGE_SIZE + pick
			if key == KEY_LEFT or key == KEY_RIGHT:
				_draw_recovery(_legacy_page + (1 if key == KEY_RIGHT else -1))
				get_viewport().set_input_as_handled()
			elif pick >= 0 and pick < RECOVERY_PAGE_SIZE and index < _legacy_ids.size():
				_retrieve_legacy(_legacy_ids[index])
				get_viewport().set_input_as_handled()
		Mode.RECOVERY_SLEEVE:
			if key == KEY_ENTER or key == KEY_KP_ENTER:
				_retrieve_legacy(_legacy_missing_id)
				get_viewport().set_input_as_handled()
		Mode.ORIGINALS:
			if key == KEY_R:
				_open_recovery()
				get_viewport().set_input_as_handled()
				return
			var pick := key - KEY_1
			if pick >= 0 and pick < _original_rows.size():
				_read_original(_original_rows[pick])
				get_viewport().set_input_as_handled()
		Mode.OLD:
			var pick := key - KEY_1
			if pick >= 0 and pick < _trace_rows.size():
				_read_found(_trace_rows[pick])
				get_viewport().set_input_as_handled()
		Mode.EDIT:
			if key == KEY_ENTER or key == KEY_KP_ENTER:
				if cursor >= song.slots.size() - 1:
					_show_menu()
				else:
					_move(1)
				get_viewport().set_input_as_handled()
			elif key == KEY_UP:
				_move(-1)
				get_viewport().set_input_as_handled()
			elif key == KEY_DOWN:
				_move(1)
				get_viewport().set_input_as_handled()
		Mode.REVIEW:
			if key == KEY_1:
				_keep()
			elif key == KEY_2:
				_show_mic_consent()
			elif key == KEY_3:
				_show_menu()
			elif key == KEY_4 and (_take != null or _take_end_seconds > 0.0):
				_read_back_take()
		Mode.MIC_CONSENT:
			if key == KEY_1:
				_show_clap()
			elif key == KEY_2:
				_perform_without_microphone()
		Mode.READING:
			_stop_reading()


func _process(delta: float) -> void:
	if mode in [Mode.READING, Mode.SLEEVE] and not _read_original_id.is_empty() \
			and not OriginalCustody.is_packed(_read_original_id):
		_stop_reading()
		return
	if mode == Mode.READING:
		_read_t += delta
		if _read_is_trace:
			if _reader and _reader.playing:
				PhonautogramReader.wow_stream(_reader, _read_speed, _read_t)
				# A skip is SILENT, not quiet: the bristle lifted and nothing
				# was written, so there is nothing there to make quieter.
				_reader.volume_db = -60.0 if PhonautogramReader.skipped(_read_t) else 0.0
			elif _reader and not _reader.playing:
				_stop_reading()
		elif not _reader.playing:
			_stop_reading()
		elif not _read_original_id.is_empty():
			_update_saved_phrase(_reader.get_playback_position())
		return
	if mode != Mode.PERFORM:
		return
	play_time = _backing.get_playback_position()
	_draw_perform()


func close() -> void:
	_discard_microphone()
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _terminal and _terminal.has_method("panel_closed"):
		_terminal.panel_closed()
	queue_free()
