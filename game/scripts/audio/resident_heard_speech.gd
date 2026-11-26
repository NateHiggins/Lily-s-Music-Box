extends AudioStreamPlayer
## The admitted, player-addressed conversation owns one foreground voice.
## Identical text alone cannot play a take. Speaker, node and exact copy must match.
const Lexicon = preload("res://scripts/device/companion_lexicon.gd")
var _panel: Node
var _source := ""
var _words: Array = []
var _next := 0
var _session: Node
var _campaign: Dictionary
var _since := INF

func setup(panel: Node) -> void:
	_panel = panel
	bus = &"Dialogue"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	finished.connect(_finished)
	set_process(false)

func begin(node_id: String, speaker: String, copy: String) -> void:
	cancel()
	var take: Dictionary = Lexicon.matched_take(node_id, speaker, copy)
	if take.is_empty(): return
	stream = load(str(take.stream)) as AudioStream
	if stream == null: return
	_source = node_id
	_words = take.words
	_session = get_tree().get_first_node_in_group("companion_correspondence_owner")
	_campaign = RealityState.data
	_since = 0.0 if _within_earshot() else INF
	play()
	set_process(true)

func cancel() -> void:
	stop()
	stream = null
	set_process(false)
	_source = ""
	_words = []
	_next = 0
	_since = INF
	_session = null
	_campaign = {}

func _within_earshot() -> bool:
	if not is_instance_valid(_session) or not is_same(_campaign, RealityState.data): return false
	if not _panel.attention_active() or not _session.hears_resident(_panel): return false
	for channel: String in ["Dialogue", "Voice", "Master"]:
		var index := AudioServer.get_bus_index(channel)
		if index < 0 or AudioServer.is_bus_mute(index) or AudioServer.get_bus_volume_db(index) <= -55.0: return false
	return true

func _process(_delta: float) -> void:
	if not is_same(_campaign, RealityState.data) or not _panel.attention_active():
		cancel()
		return
	# Use the sound cursor, including output latency. No wall-clock or text-speed estimates.
	if playing and not stream_paused:
		_advance(maxf(0.0, get_playback_position() - AudioServer.get_output_latency()))

func _advance(seconds: float) -> void:
	if not _within_earshot():
		_since = INF
	elif is_inf(_since):
		_since = seconds
	while _next < _words.size() and float(_words[_next][2]) <= seconds:
		var mark: Array = _words[_next]
		_next += 1
		if _since <= float(mark[1]):
			_session.hear_resident_word(str(mark[0]), _source, _panel)

func _finished() -> void:
	if stream != null: _advance(stream.get_length())
	cancel()
