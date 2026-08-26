extends Node

const SCRIPT_ROOT := "res://scripts"
const FORBIDDEN := [
	"WebSocketPeer", "PacketPeerUDP", "UDPServer", "TCPServer",
	"StreamPeerTCP", "OS.execute(", "OS.create_process(", "OS.shell_open(",
	"OS.get_unique_id(",
]
var failed := 0


func _ready() -> void:
	var corpus := _read_gd_tree(SCRIPT_ROOT)
	_check(corpus.count("HTTPRequest.new()") == 1,
			"production owns exactly one HTTP request client")
	var forbidden_hits := []
	for token in FORBIDDEN:
		if corpus.contains(token):
			forbidden_hits.append(token)
	_check(forbidden_hits.is_empty(),
			"production owns no raw socket, process, shell or device identifier API")
	_check(corpus.count("AudioStreamMicrophone.new()") == 1,
			"production owns exactly one microphone stream")
	_check(corpus.count("DisplayServer.clipboard_set(") == 1,
			"production owns exactly one clipboard writer")
	var rig := FileAccess.get_file_as_string(
			"res://scripts/building/light_rig.gd")
	_check(rig.find("if not GameBoot.developer_overlays_enabled():") >= 0
			and rig.find("if not GameBoot.developer_overlays_enabled():") <
				rig.find("DisplayServer.clipboard_set(text)"),
			"the sole clipboard writer is behind explicit developer mode")
	_check(not bool(GameBoot.settings.get("weather_network_enabled", true)),
			"network weather defaults off")
	var recorder := FileAccess.get_file_as_string(
			"res://scripts/songbook/mic_recorder.gd")
	_check(recorder.count("_mic_player.play()") == 1
			and recorder.find("_mic_player.play()") > recorder.find("func start_input()"),
			"the sole microphone play call belongs to explicit start_input")
	var readme := FileAccess.get_file_as_string("res://../distribution/README_TESTER.txt")
	# Export excludes docs and the distribution folder, so the source-project
	# path above may be unavailable under an exported test. Static source is the
	# contract here; the shipped packager separately injects this README.
	_check(readme.is_empty() or (readme.contains("NOT THIS TIME")
			and readme.contains("IP address")),
			"available tester copy names both refusal and connection metadata")
	print("[FRIENDS PRIVACY SURFACE] %s" % (
			"PASS 8/8" if failed == 0 else "FAIL %d/8" % failed))
	get_tree().quit(0 if failed == 0 else 1)


func _read_gd_tree(path: String) -> String:
	var combined := ""
	var dir := DirAccess.open(path)
	if dir == null:
		return combined
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				combined += _read_gd_tree(child)
			elif entry.ends_with(".gd"):
				combined += FileAccess.get_file_as_string(child) + "\n"
		entry = dir.get_next()
	dir.list_dir_end()
	return combined


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS ", label)
	else:
		failed += 1
		print("  FAIL ", label)
