class_name LoopVoiceManifest
extends RefCounted
## Approved voice takes for the loop's performed lines (loop voice pilot, doc408; Codex's runtime handoff
## 2026-11-26). A take is found only by the speaking resident AND the SHA-256 of the exact line on screen, so an
## edited line can never play stale audio. The released manifest (RELEASE) ships empty until Lily accepts takes;
## a pilot or test may load another manifest file in the same format. Any fault refuses the whole file: the
## loop then plays silently, exactly as before.
##
## Format (Codex's packer, schema 1): {"schema_version": 1, "entries": [{"owner_resident_id", "text_sha256",
## "audio", "cues", "seconds", "speaker_segments": {..} or [{"profile_id", "start", "end", "start_char",
## "end_char"}]}]}. `audio` and `cues` are res:// paths; a manifest kept outside the project (the pilot case)
## resolves a missing res:// file to the same file name beside the manifest.

const RELEASE := "res://data/voice/loop_voice_takes.json"

var errors: Array[String] = []
var _takes: Dictionary = {}
var _base := ""


static func digest(text: String) -> String:
	return text.replace("\r\n", "\n").sha256_text()


static func load_from(path: String) -> LoopVoiceManifest:
	var manifest := LoopVoiceManifest.new()
	manifest._load(path)
	return manifest


func count() -> int:
	return _takes.size()


## The take for `actor` saying exactly `line`, or {} (silence).
func take_for(actor: String, line: String) -> Dictionary:
	return _takes.get(actor + "|" + digest(line), {})


func _load(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return # No manifest is no takes, not an error.
	_base = path.get_base_dir()
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary or int((document as Dictionary).get("schema_version", 0)) != 1:
		_refuse("manifest is not schema 1: " + path)
		return
	var entries: Variant = (document as Dictionary).get("entries", (document as Dictionary).get("takes", []))
	if not entries is Array:
		_refuse("manifest entries are not a list")
		return
	var found := {}
	for row: Variant in entries:
		var take := _take(row)
		if take.is_empty():
			return
		var key := str(take.actor) + "|" + str(take.text_sha256)
		if found.has(key) and str(found[key].audio) != str(take.audio):
			_refuse("two different takes for one actor and line: " + key)
			return
		found[key] = take
	_takes = found


func _take(row: Variant) -> Dictionary:
	if not row is Dictionary:
		_refuse("a take is not an object")
		return {}
	var actor := str(row.get("owner_resident_id", row.get("actor", "")))
	var sha := str(row.get("text_sha256", ""))
	if actor.is_empty() or not sha.length() == 64 or not sha.is_valid_hex_number():
		_refuse("a take lacks an actor or a 64-hex text digest")
		return {}
	var audio := _resolve(str(row.get("audio", "")))
	if audio.is_empty():
		_refuse("missing audio for " + actor + " " + sha.left(12))
		return {}
	var segments: Array = []
	var raw: Variant = row.get("speaker_segments", [])
	for segment: Variant in (raw if raw is Array else [raw]):
		if not segment is Dictionary:
			_refuse("a speaker segment is not an object")
			return {}
		segments.append(segment)
	var last_end := -1.0
	for segment: Dictionary in segments:
		var start := float(segment.get("start", -1.0))
		var end := float(segment.get("end", -1.0))
		if start < last_end - 0.0001 or end <= start or int(segment.get("end_char", 0)) <= int(segment.get("start_char", 0)):
			_refuse("speaker segments out of order for " + actor + " " + sha.left(12))
			return {}
		last_end = end
	return {"actor": actor, "text_sha256": sha, "audio": audio, "cues": _resolve(str(row.get("cues", ""))),
			"seconds": float(row.get("seconds", 0.0)), "segments": segments, "line_id": str(row.get("line_id", ""))}


func _resolve(path: String) -> String:
	if path.is_empty():
		return ""
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		return path
	if _base.is_empty():
		return ""
	for folder: String in [_base, _base.path_join("packed")]:  # the packer's case keeps takes in packed/
		var beside := folder.path_join(path.get_file())
		if FileAccess.file_exists(beside):
			return beside
	return ""


func _refuse(reason: String) -> void:
	_takes.clear()
	errors.append(reason)
	push_warning("Loop voice manifest refused (the loop stays silent): " + reason)
