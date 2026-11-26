extends Node
## Standalone audio-data bench. No microphone, campaign, media files or audio
## device. The controlled global draws belong only to this test process.
const Synth := preload("res://scripts/songbook/song_synth.gd")
const OBSERVER_SEED := 870523
const BETWEEN_RENDERS := 37
const FRAMES := 3276000  # 52 four-beat bars at 84 BPM and 22,050 Hz.
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	print("[SONGBOOK BACKING] ", label, " = ", ok)
	if not ok:
		failures.append(label)
		push_error(label)


func _run() -> void:
	if get_tree().current_scene != self:
		push_warning("Run SongbookBackingTest as its own scene.")
		return
	_check(Synth.current_arrangement("track_018") == Synth.ARRANGEMENT_V1
			and Synth.current_arrangement("another_song").is_empty()
			and Synth.render("unknown_revision").is_empty(), "version selection refuses an unavailable backing")
	seed(OBSERVER_SEED)
	var expected := PackedInt64Array()
	for i in BETWEEN_RENDERS + 2:
		expected.append(randi())
	seed(OBSERVER_SEED)
	var observed := PackedInt64Array()
	observed.append(randi())
	var first := Synth.render()
	for i in BETWEEN_RENDERS:
		observed.append(randi())
	var second := Synth.render(Synth.ARRANGEMENT_V1)
	observed.append(randi())
	_check(observed == expected, "neither independent render advances or resets the surrounding random sequence")
	var seconds := float(FRAMES) / 22050.0
	_check(is_equal_approx(float(first.get("length", 0.0)), seconds)
			and is_equal_approx(float(second.get("length", 0.0)), seconds), "the arrangement still spans all 52 bars")
	for stem: String in ["backing", "guide"]:
		var a := first.get(stem) as AudioStreamWAV
		var b := second.get(stem) as AudioStreamWAV
		if a == null or b == null:
			_check(false, "both renders return " + stem)
			continue
		_check(a != b and a.format == AudioStreamWAV.FORMAT_16_BITS and b.format == a.format
				and a.mix_rate == 22050 and b.mix_rate == a.mix_rate and not a.stereo and not b.stereo
				and is_equal_approx(a.get_length(), seconds) and is_equal_approx(b.get_length(), seconds),
				stem + " remains independent mono 16-bit PCM at the original rate and duration")
		var pcm := a.data
		_check(pcm.size() == FRAMES * 2 and pcm == b.data and pcm.slice(0, 1024).count(0) < 1024,
				stem + " contains audible samples and reproduces every byte")
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(pcm)
		print("[SONGBOOK BACKING] ", stem, " PCM SHA256 ", digest.finish().hex_encode())
	if first.get("backing") is AudioStreamWAV and first.get("guide") is AudioStreamWAV:
		_check(first.backing.data != first.guide.data, "the separate melody guide differs from the instrumental")
	print("[SONGBOOK BACKING] RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
