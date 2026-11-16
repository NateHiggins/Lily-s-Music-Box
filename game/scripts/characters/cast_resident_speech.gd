extends Node
## A resident on a rebuilt body moves its mouth while its own authored line is on the dialogue panel (order
## w9189b10b24ac: the face controller wired to dialogue; attention already follows the conversation). The same
## restrained jaw fallback the bar staff use (harukiya_cast.gd): no sound or text is generated, and hidden text
## never keeps a mouth moving.

var body: Node
var resident_id := ""
var _conversations: Object
var _speaker_label := ""
var _talking := false
var _clock := 0.0


func _ready() -> void:
	var node := get_parent()
	while node != null and not ("conversations" in node):
		node = node.get_parent()
	if node == null or not (node.get("conversations") is Object):
		set_process(false)
		return
	_conversations = node.get("conversations")
	var trees: Variant = _conversations.get("trees")
	if trees is Dictionary and (trees as Dictionary).has(resident_id):
		_speaker_label = str(((trees as Dictionary)[resident_id] as Dictionary).get("meta", {}).get("speaker_default", "")).strip_edges().to_upper()
	if _conversations.has_signal("conversation_started"):
		_conversations.connect("conversation_started", _on_started)
		_conversations.connect("conversation_ended", _on_ended)
	var dialogue: Variant = _conversations.get("dialogue")
	if dialogue is Object and (dialogue as Object).has_signal("node_shown"):
		(dialogue as Object).connect("node_shown", _on_node_shown)


func _on_started(id: String, _entry: String) -> void:
	if id != resident_id:
		return
	_talking = true
	if is_instance_valid(body):
		body.express("interest", 0.5)
	_on_node_shown("")


func _on_ended(id: String) -> void:
	if id != resident_id:
		return
	_talking = false
	if is_instance_valid(body):
		body.stop_speaking()
		body.express("neutral", 0.0)


func _on_node_shown(_node: String) -> void:
	if not _talking or not is_instance_valid(body) or _conversations == null:
		return
	var dialogue: Object = _conversations.get("dialogue")
	if dialogue == null:
		return
	var line: Dictionary = dialogue.displayed_line()
	var words := str(line.get("text", "")).strip_edges()
	var voice := str(line.get("speaker", "")).strip_edges().to_upper()
	if words.replace(".", "").strip_edges().is_empty() or _speaker_label.is_empty() or not voice.begins_with(_speaker_label):
		body.stop_speaking()
		return
	body.speak_untimed(clampf(float(words.length()) / 18.0, 1.0, 12.0))


func _process(delta: float) -> void:
	# The panel may close between nodes without ending the conversation: a hidden line stops the mouth.
	_clock += delta
	if _clock < 0.25:
		return
	_clock = 0.0
	if _talking and is_instance_valid(body) and _conversations != null:
		var dialogue: Object = _conversations.get("dialogue")
		if dialogue != null and dialogue.has_method("attention_active") and not dialogue.attention_active():
			body.stop_speaking()
