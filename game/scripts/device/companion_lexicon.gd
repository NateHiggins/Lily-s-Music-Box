extends RefCounted
## Only words whose recorded interval reached this listener enter the campaign.
## Source ids are stable authored node ids. Nothing in this ledger grants story facts.
const PATH := "res://data/device/companion_speech.json"
const PRACTICE := ["confident", "retry", "recover", "correct", "introduce", "offer"]
static var _takes: Dictionary = {}
static var _lines: Dictionary = {}
static var _by_word: Dictionary = {}
var heard: Dictionary = {}

static func _load_bank() -> void:
	if not _takes.is_empty(): return
	var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for take: Dictionary in bank.takes:
		var source := str(take.id)
		_takes[source] = take
		for mark: Array in take.words:
			if not _by_word.has(mark[0]): _by_word[mark[0]] = {}
			_by_word[mark[0]][source] = true
	for line: Dictionary in bank.lines:
		_lines[line.id] = line.requires

static func matched_take(source: String, speaker: String, copy: String) -> Dictionary:
	_load_bank()
	var take: Dictionary = _takes.get(source, {})
	if take.is_empty() or take.speaker != speaker or take.text_sha256 != copy.sha256_text(): return {}
	return {"stream":take.stream, "words":take.words}

static func line_ids() -> Array:
	_load_bank()
	return _lines.keys()

static func permits(word: String, source: String) -> bool:
	_load_bank()
	return _by_word.get(word, {}).has(source)

static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() > 2048: return false
	for word: Variant in value:
		if word is not String or value[word] is not String or not permits(word, value[word]): return false
	return true

func learn(word: String, source: String) -> bool:
	if heard.has(word) or not permits(word, source): return false
	heard[word] = source
	return true

func can_say(line: String) -> bool:
	_load_bank()
	if not _lines.has(line): return false
	for word: String in _lines[line]:
		if not heard.has(word): return false
	return true

func practice() -> String:
	for line: String in PRACTICE:
		if can_say(line): return line
	for word: String in ["hello", "yes", "no", "oh", "help", "here", "okay", "again", "try", "can", "am", "will", "i"]:
		if can_say(word): return word
	return ""
