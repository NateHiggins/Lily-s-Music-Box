class_name MicRecorder
extends Node
## Microphone capture, and the one calibration the system cannot do
## without.
##
## Every machine puts a different delay between "the game played a
## sound" and "the microphone heard it" — driver buffer, USB interface,
## bluetooth, the lot. Uncorrected, every recorded vocal sits late
## against the backing by an amount that varies per player, and a
## Songbook full of them is a Songbook where nothing lines up with
## anything. So the brief makes it diegetic and does it once:
##
##   MIC CHECK — clap when the screen flashes.
##
## We flash, we listen, we find the transient, and the difference is
## stored for good. Never a per-recording nudge, which is a setting
## nobody can judge and everybody gets wrong.

signal calibrated(offset_ms: float)
signal recording_finished(stream: AudioStreamWAV)

const SETTINGS_KEY := "songbook_latency_ms"
const CLAP_WINDOW := 1.6        # seconds of listening after the flash
const CLAP_FLOOR := 0.16        # amplitude that counts as a clap

var offset_ms := 0.0
var available := false

var _rec: AudioEffectRecord
var _mic_player: AudioStreamPlayer
var _listening := false
var _listen_started := 0.0
var _flash_at := 0.0


func _ready() -> void:
	_rec = BarPA.ensure_mic_bus()
	BarPA.ensure_bus()
	offset_ms = float(GameBoot.settings.get(SETTINGS_KEY, 0.0))
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = BarPA.MIC_BUS
	add_child(_mic_player)
	# An input device the OS will not give us is a fact, not a failure:
	# the Songbook stays usable, it just cannot record you.
	available = ProjectSettings.get_setting(
			"audio/driver/enable_input", false)
	if not available:
		push_warning("songbook: audio input disabled; playback only")


func start_input() -> void:
	if available and not _mic_player.playing:
		_mic_player.play()


func stop_input() -> void:
	if _mic_player.playing:
		_mic_player.stop()


## ---- calibration ----------------------------------------------------

func begin_clap_check() -> bool:
	if not available:
		return false
	start_input()
	_rec.set_recording_active(false)
	_rec.set_recording_active(true)
	_listening = true
	_listen_started = Time.get_ticks_msec() / 1000.0
	_flash_at = _listen_started
	return true


func _process(_delta: float) -> void:
	if not _listening:
		return
	if Time.get_ticks_msec() / 1000.0 - _listen_started < CLAP_WINDOW:
		return
	_listening = false
	var stream := _rec.get_recording()
	_rec.set_recording_active(false)
	var found := _first_transient(stream)
	if found < 0.0:
		# No clap heard. Leave the stored value alone rather than
		# writing a zero over a good calibration from last week.
		calibrated.emit(-1.0)
		return
	offset_ms = clampf(found * 1000.0, 0.0, 400.0)
	GameBoot.settings[SETTINGS_KEY] = offset_ms
	if GameBoot.has_method("save_settings"):
		GameBoot.save_settings()
	calibrated.emit(offset_ms)


## Seconds from the start of the capture to the first sample that is
## clearly louder than the room. Returns -1 when nothing is.
static func _first_transient(stream: AudioStreamWAV) -> float:
	if stream == null or stream.data.is_empty():
		return -1.0
	var data := stream.data
	var step := 2 * (2 if stream.stereo else 1)
	var frames := data.size() / step
	for i in frames:
		var s := data.decode_s16(i * step) / 32768.0
		if absf(s) >= CLAP_FLOOR:
			return float(i) / float(stream.mix_rate)
	return -1.0


## ---- performance capture --------------------------------------------

func start_recording() -> bool:
	if not available:
		return false
	start_input()
	_rec.set_recording_active(false)
	_rec.set_recording_active(true)
	return true


## Stops, trims the measured latency off the head so the vocal lands
## where it was sung rather than where it arrived, and hands back a
## dry stream. Colour is the PA's job, later.
func stop_recording() -> AudioStreamWAV:
	if not _rec.is_recording_active():
		return null
	var stream := _rec.get_recording()
	_rec.set_recording_active(false)
	stop_input()
	if stream and offset_ms > 0.0:
		stream = _trim_head(stream, offset_ms / 1000.0)
	recording_finished.emit(stream)
	return stream


static func _trim_head(stream: AudioStreamWAV,
		seconds: float) -> AudioStreamWAV:
	var step := 2 * (2 if stream.stereo else 1)
	var cut := int(seconds * stream.mix_rate) * step
	if cut <= 0 or cut >= stream.data.size():
		return stream
	var out := AudioStreamWAV.new()
	out.format = stream.format
	out.mix_rate = stream.mix_rate
	out.stereo = stream.stereo
	out.data = stream.data.slice(cut)
	return out
