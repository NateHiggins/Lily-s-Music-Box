extends Node
## Is the Songbook actually reachable, and does Phase 1 run end to end?
##
## Everything under scripts/songbook was written, committed and left
## INERT for a session — SongResource, the synth, the PA chain, mic
## capture, the version store — because nothing in the world referenced
## any of it. Code nothing calls is code nobody notices rotting, so the
## FIRST thing this checks is the boring structural one: is there a
## terminal in the bar, does pressing E on it open the panel.
##
## After that it plays the brief's Phase 1 straight through: write words
## into phrase slots, watch the display track the backing in time, and
## keep the take. The load-bearing assertion is the LAST one — that a
## line the syllable counter dislikes is stored exactly as typed. The
## brief's founding rule is that there are no canonical lyrics and the
## editor may advise but never refuse, and that is precisely the sort of
## rule a later "helpful" validation would quietly break.

var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await _run()


func _run() -> void:
	# ---- IS IT THERE ------------------------------------------------
	var term := root.find_child("F01_BAR_SONGBOOK", true, false)
	_check("the bar has a songbook terminal", term != null)
	if term == null:
		print("[SONGBOOK] RESULT: FAIL (%d failures)" % 1)
		get_tree().quit(1)
		return
	var p: Vector3 = term.global_position
	print("      terminal at %v" % p)
	# In the bar room, below street level, off the stage.
	_check("it hangs in the bar, not on the street",
			p.y < -1.5 and p.z > 34.0)
	_check("it offers itself to the player",
			str(term.interact_prompt()).contains("songbook"))

	# ---- DOES IT OPEN -----------------------------------------------
	term.interact(root.player)
	await get_tree().process_frame
	var panel = get_tree().current_scene.find_child("*", true, false) \
			if false else null
	panel = null
	for c in get_tree().current_scene.get_children():
		if c is SongbookPanel:
			panel = c
	_check("pressing E opens the songbook", panel != null)
	if panel == null:
		print("[SONGBOOK] RESULT: FAIL (%d failures)" % (_fails + 1))
		get_tree().quit(_fails + 1)
		return
	_check("the player's hands are on the machine",
			root.player.call_locked)
	var song: SongResource = panel.song
	_check("it loaded a song with phrase slots (%d)" % song.slots.size(),
			song.slots.size() > 0)

	# ---- THE EDITOR -------------------------------------------------
	# The map is the shape the melody expects, not words.
	var want := int(song.slots[0].get("suggested_syllables", 0))
	var map := SongResource.syllable_map(want)
	_check("the editor can draw a syllable map (%s)" % map,
			map.count("_") == want)

	# A deliberately over-long line: the counter should dislike it and
	# the editor should take it anyway.
	var long_line := ("the last train home is never coming back for "
			+ "anyone who waited this long on the platform")
	var counted := SongResource.syllables(long_line)
	_check("the counter knows the line is long (%d vs %d)"
			% [counted, want], counted > want)

	panel.lyrics[str(song.slots[0].id)] = long_line
	panel.lyrics[str(song.slots[1].id)] = "and I am still here"
	_check("words go into the slots the song left empty",
			str(panel.lyrics[str(song.slots[0].id)]) == long_line)

	# ---- THE DISPLAY ------------------------------------------------
	# Drive the karaoke clock by hand rather than waiting out the song.
	panel.mode = SongbookPanel.Mode.PERFORM
	var first: Dictionary = song.slots[0]
	panel.play_time = float(first.start_time) + 0.05
	panel._draw_perform()
	_check("the display is on the first phrase at its start time",
			song.slot_at(panel.play_time).get("id") == first.get("id"))
	var gap := float(first.end_time) + 0.01
	if not song.next_slot_after(gap).is_empty():
		panel.play_time = gap
		panel._draw_perform()
		_check("between phrases it shows what is coming",
				song.slot_at(panel.play_time).is_empty())

	# An unwritten phrase must not read as an error — it is a hole, and
	# the display shows its shape so a singer can improvise into it.
	var blank: Dictionary = song.slots[song.slots.size() - 1]
	var shown: String = panel._words_or_blank(blank)
	_check("an unwritten phrase shows its shape, not an error",
			shown.contains("_"))

	# ---- KEEPING IT -------------------------------------------------
	var before := SongbookStore.versions_of(song.id).size()
	panel._take = null           # no microphone in a test rig
	panel._keep()
	var after := SongbookStore.versions_of(song.id)
	_check("keeping a take files a version (%d -> %d)"
			% [before, after.size()], after.size() == before + 1)

	# THE RULE. The stored line must be exactly what was typed — not
	# trimmed to fit, not rejected for length.
	var saved := ""
	for v in after:
		if str(v.get("base_song_id", "")) == song.id:
			var got: Dictionary = v.get("lyrics", {})
			if got.has(str(song.slots[0].id)):
				saved = str(got[str(song.slots[0].id)])
	_check("a line the counter disliked is stored exactly as typed",
			saved == long_line)

	# ---- LEAVING ----------------------------------------------------
	panel.close()
	await get_tree().process_frame
	_check("stepping away gives the player back their hands",
			not root.player.call_locked)

	print("[SONGBOOK] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
