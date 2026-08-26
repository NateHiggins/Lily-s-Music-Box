extends Node

const NetworkScript := preload("res://scripts/building/house_telephone_network.gd")
const BoardScript := preload("res://scripts/props/house_switchboard_prop.gd")
const HouseEnglishScript := preload("res://scripts/language/house_english.gd")
var failures := 0
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  [%s] %s" % ["telephone ok" if ok else "TELEPHONE FAIL", label])
	if not ok: failures += 1


func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/house_telephones.json"))
	_check(int(catalog.year) == 1928 and catalog.endpoints.size() == 4,
			"the first census names four distinct endpoint roles")
	var endpoint_ids: Dictionary = {}
	var extensions: Dictionary = {}
	for endpoint in catalog.endpoints:
		endpoint_ids[endpoint.id] = true
		extensions[endpoint.extension] = true
		_check(catalog.sources.has(endpoint.source),
				"%s names a documented source" % endpoint.id)
		_check(str(endpoint.location) != "" and str(endpoint.role) != "",
				"%s names physical location and role" % endpoint.id)
	_check(endpoint_ids.size() == catalog.endpoints.size()
			and extensions.size() == catalog.endpoints.size(),
			"endpoint identities and extensions are unique")
	var network: Node = NetworkScript.new(); add_child(network)
	_check(NetworkScript.LineState.keys() == ["IDLE", "ASKING", "ANSWERED", "CARRYING"],
			"PHONE-A exposes no unreachable line state")
	for endpoint in catalog.endpoints:
		_check(network.call("register_endpoint", endpoint),
				"register unique endpoint %s" % endpoint.id)
	_check(not network.call("register_endpoint", catalog.endpoints[0]),
			"duplicate endpoint and extension refuse")
	var board: Node = BoardScript.new(); board.call("bind_line", network); add_child(board)
	await get_tree().process_frame
	var before := JSON.stringify(RealityState.data)
	var events: Array[String] = []
	network.line_changed.connect(func(line: Dictionary): events.append("state:%s" % line.state))
	network.endpoint_answered.connect(func(id: String): events.append("answer:%s" % id))
	network.line_connected.connect(func(id: String, trunk: String):
		events.append("connect:%s:%s" % [id, trunk]))
	network.line_released.connect(func(_line: Dictionary): events.append("release"))
	network.endpoint_unanswered.connect(func(id: String): events.append("missed:%s" % id))
	_check(not network.call("answer", "house_board"), "idle cannot be answered")
	_check(not network.call("carry", "outside_trunk"), "idle cannot be carried")
	_check(not network.call("release", "house_board"), "idle cannot be released")
	_check(network.call("request", "apt_4b"), "a known endpoint may ask once")
	var first_sequence := int((network.call("snapshot") as Dictionary).sequence)
	_check(not network.call("expire_unanswered", first_sequence + 1),
			"a stale or future timer cannot clear an asking line")
	_check(not network.call("request", "apt_3d"), "a second call cannot overlap the first")
	_check(not network.call("carry", "outside_trunk"), "an asking line cannot skip answer")
	_check(not network.call("release", "house_board"),
			"the board cannot erase a call it has not answered")
	_check((board.call("interact") as Dictionary).accepted, "the board answers the asking line")
	_check(not network.call("answer", "house_board"), "the same call cannot be answered twice")
	_check(not network.call("request", "apt_3d"), "an answered line remains physically busy")
	_check((board.call("interact") as Dictionary).accepted, "the answered line enters one trunk")
	_check(not network.call("carry", "second_trunk"), "one call cannot enter two trunks")
	_check(not network.call("release", "stranger"), "a stranger cannot release another hand's cord")
	_check((board.call("interact") as Dictionary).accepted, "the answering hand releases to idle")
	_check(str((network.call("snapshot") as Dictionary).state) == "IDLE",
			"the ordinary chain returns completely idle")
	_check(JSON.stringify(RealityState.data) == before,
			"ordinary line operation writes no persistent fact")
	_check(events == ["state:ASKING", "answer:apt_4b", "state:ANSWERED",
			"state:CARRYING", "connect:apt_4b:outside_trunk", "state:IDLE", "release"],
			"one ordinary call emits one deterministic neutral event chain")
	events.clear()
	_check(network.call("request", "apt_3d"), "a second ordinary endpoint may ask")
	var missed_sequence := int((network.call("snapshot") as Dictionary).sequence)
	_check(network.call("expire_unanswered", missed_sequence),
			"the matching unanswered appearance expires cleanly")
	_check(events == ["state:ASKING", "state:IDLE", "missed:apt_3d"],
			"unanswered is stated once and returns to idle")
	var semantic_line := {"endpoint":"4B", "state":"CARRYING",
			"trunk":"outside_trunk"}
	_check(HouseEnglishScript.render_line(semantic_line, "house")
			== "A answered. B carries 4B on outside trunk.",
			"House English names the physical A-to-B custody")
	_check(HouseEnglishScript.render_line(semantic_line, "plain")
			== "Operator B carries 4B through outside trunk.",
			"plain language explains the identical semantic record")
	var source := FileAccess.get_file_as_string(
			"res://scripts/building/house_telephone_network.gd")
	_check(not source.contains("WorkOrders") and not source.contains("RealityCases")
			and not source.contains("commit("), "the line cannot author story state")
	print("[HOUSE TELEPHONE] RESULT: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
