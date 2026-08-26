extends Node

var failed := 0


func _ready() -> void:
	var source := FileAccess.get_file_as_string(
			"res://scripts/ui/songbook_panel.gd")
	var consent_start := source.find("func _show_mic_consent()")
	var clap_start := source.find("func _show_clap()")
	var consent_body := source.substr(consent_start, clap_start - consent_start)
	_check(consent_start >= 0 and clap_start > consent_start,
			"consent is a distinct state before clap calibration")
	_check(not consent_body.contains("MicRecorder.new")
			and not consent_body.contains("begin_clap_check")
			and source.substr(clap_start).contains("MicRecorder.new"),
			"notice itself cannot open or record the microphone")
	_check(source.contains("1  use microphone     2  not this time")
			and source.contains("Mode.MIC_CONSENT:\n\t\t\tif key == KEY_1:")
			and source.contains("elif key == KEY_2:\n\t\t\t\t_start_perform()"),
			"player can affirm or perform without recording")
	_check(source.count("_show_mic_consent()") == 3,
			"both recording routes pass through the one notice owner")
	print("[SONGBOOK MIC CONSENT] %s" % (
			"PASS 4/4" if failed == 0 else "FAIL %d/4" % failed))
	get_tree().quit(0 if failed == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS ", label)
	else:
		failed += 1
		print("  FAIL ", label)
