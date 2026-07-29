extends Node
## Autoload "AudioEnv": builds the mix bus layout in code (no bus-layout
## asset needed) and hands out per-source panned buses to MotifRenderers.
##
## Layout:
##   Master (limiter — level-safety net)
##    ├─ Room   (reverb: the apartment's acoustic body)
##    ├─ Caller (band-limit + light distortion: a phone line)
##    └─ UI     (dry: sounds from inside the interface)

const BUS_ROOM := "Room"
const BUS_CALLER := "Caller"
const BUS_UI := "UI"


func _ready() -> void:
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)

	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.62
	reverb.wet = 0.22
	reverb.damping = 0.6
	_ensure_bus(BUS_ROOM, "Master", [reverb])

	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 280.0
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3200.0
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.12
	_ensure_bus(BUS_CALLER, "Master", [hp, lp, dist])

	_ensure_bus(BUS_UI, "Master", [])


func _ensure_bus(bus_name: String, send_to: String, effects: Array) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)
	for e in effects:
		AudioServer.add_bus_effect(idx, e)


## Per-renderer bus so each body gets its own stereo position and can be
## re-routed live (e.g. the captured loop switching speakers -> headset).
func make_source_bus(bus_name: String, send_to: String, pan: float) -> String:
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to if AudioServer.get_bus_index(send_to) != -1 else "Master")
	if absf(pan) > 0.01:
		var panner := AudioEffectPanner.new()
		panner.pan = clampf(pan, -1.0, 1.0)
		AudioServer.add_bus_effect(idx, panner)
	return bus_name


func free_source_bus(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1 and bus_name.begins_with("src_"):  # never remove Master or the shared buses
		AudioServer.remove_bus(idx)


func reroute_source_bus(bus_name: String, send_to: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1 and AudioServer.get_bus_index(send_to) != -1:
		AudioServer.set_bus_send(idx, send_to)


func set_master_mute(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)


func set_master_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(0, db)


func master_peak_db() -> float:
	return maxf(
		AudioServer.get_bus_peak_volume_left_db(0, 0),
		AudioServer.get_bus_peak_volume_right_db(0, 0)
	)
