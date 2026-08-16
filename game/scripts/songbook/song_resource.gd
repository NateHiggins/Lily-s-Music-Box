class_name SongResource
extends RefCounted
## One backing composition and the empty shapes a vocal can occupy.
##
## The brief's data architecture, minus the parts Phase 1 has no use for
## yet: id, tempo, key, sections, and the phrase slots that are the whole
## point. A slot is a hole in the arrangement with a start, an end, a
## suggested syllable count and a melodic shape — never a lyric. There
## are deliberately no canonical words for any song in the Songbook.
##
## `suggested` is the operative word in suggested_syllables. Per the
## brief's LYRIC WRITING rule the editor may hint that a line is long or
## short and may never prevent it; the only mode that refuses a line is
## STRICT METER, which the player has to choose (Addendum A.2).

const DIR := "res://data/songbook"

var id := ""
var title := ""
var genre := ""
var bpm := 84.0
var key := ""
var duration := 0.0
var chords: Array = []
var sections: Array = []       # [{name, start_time, end_time}]
var slots: Array = []          # [{id, section, start_time, end_time, ...}]
## TASKS.md G1a: the one too-fast varispeed every published version of this
## song is reconstructed at. Tuned per song in data (Music Bible §5: ×1.335
## is the center; two tracks are specced at ×1.414); always > 1.0 — the
## documented 2008 error was a too-fast reading, never a slow one.
var return_ratio := 1.335


static func load_song(song_id: String) -> SongResource:
	var path := "%s/%s.json" % [DIR, song_id]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("songbook: no such song " + path)
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("songbook: unparseable song " + path)
		return null
	var song := SongResource.new()
	song.id = str(data.get("id", song_id))
	song.title = str(data.get("title", song_id))
	song.genre = str(data.get("genre", ""))
	song.bpm = float(data.get("bpm", 84.0))
	song.key = str(data.get("key", ""))
	song.duration = float(data.get("duration", 0.0))
	song.chords = data.get("chords", [])
	song.sections = data.get("sections", [])
	song.slots = data.get("phrase_slots", [])
	song.return_ratio = maxf(1.001, float(data.get("return_ratio", 1.335)))
	return song


## Every song file that ships. One, for now, and the brief is emphatic
## about not expanding past it until the slice works.
static func catalog() -> Array:
	var found: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return found
	for f in dir.get_files():
		var name := str(f)
		# Exported projects rename .json to .json.remap; ask for the stem.
		if name.ends_with(".remap"):
			name = name.substr(0, name.length() - 6)
		if name.ends_with(".json"):
			found.append(name.substr(0, name.length() - 5))
	found.sort()
	return found


func slot_at(t: float) -> Dictionary:
	for s in slots:
		if float(s.start_time) <= t and t < float(s.end_time):
			return s
	return {}


func next_slot_after(t: float) -> Dictionary:
	var best: Dictionary = {}
	for s in slots:
		var st := float(s.start_time)
		if st <= t:
			continue
		if best.is_empty() or st < float(best.start_time):
			best = s
	return best


func section_at(t: float) -> String:
	for s in sections:
		if float(s.start_time) <= t and t < float(s.end_time):
			return str(s.name)
	return ""


## Rough syllable count — vowel groups, with the silent trailing "e"
## dropped and a floor of one per word. It is wrong on "fire" and
## "rhythm" and every name anyone has ever invented, which is why it
## only ever advises. STRICT METER uses the same number, so the mode is
## at least consistently wrong with itself.
static func syllables(line: String) -> int:
	var total := 0
	for raw in line.strip_edges().to_lower().split(" ", false):
		var word := ""
		for ch in raw:
			if (ch >= "a" and ch <= "z") or ch == "'":
				word += ch
		if word == "":
			continue
		var count := 0
		var prev_vowel := false
		for i in word.length():
			var ch := word[i]
			var is_vowel: bool = ch in ["a", "e", "i", "o", "u", "y"]
			if is_vowel and not prev_vowel:
				count += 1
			prev_vowel = is_vowel
		if word.ends_with("e") and count > 1 and not word.ends_with("le"):
			count -= 1
		total += maxi(1, count)
	return total


## The editor's blank shape for a slot: one underscore per suggested
## syllable, grouped in fours so a long line stays countable by eye.
static func syllable_map(n: int) -> String:
	var parts: Array[String] = []
	var run := ""
	for i in n:
		run += "_ "
		if (i + 1) % 4 == 0:
			parts.append(run.strip_edges())
			run = ""
	if run != "":
		parts.append(run.strip_edges())
	return "  -  ".join(parts)
