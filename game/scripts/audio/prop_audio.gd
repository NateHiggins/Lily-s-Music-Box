class_name PropAudio
extends RefCounted
## Curated recorded sound bank. The prototype's runtime sine/noise waveform
## generators were removed: a missing key is now silence plus a warning, never
## an invented test tone leaking into the shipped soundscape.

const RECORDED := {
	"ambient_city_loop":
		"res://assets/audio/freesound/processed/beds/ambient_city_night.ogg",
	"ambient_building_loop":
		"res://assets/audio/freesound/processed/beds/ambient_building_radiators.ogg",
	"ambient_basement_loop":
		"res://assets/audio/freesound/processed/beds/ambient_basement_elevator.ogg",
	"ambient_roof_loop":
		"res://assets/audio/freesound/processed/beds/ambient_roof_storm_city.ogg",
	"basement_stairs":
		"res://assets/audio/freesound/processed/events/stairs_footsteps.ogg",
	"door_squeak":
		"res://assets/audio/freesound/processed/events/door_squeak.wav",
	"radiator_whistle":
		"res://assets/audio/freesound/processed/events/radiator_whistle.ogg",
	"distant_rain_people":
		"res://assets/audio/freesound/processed/events/distant_rain_people_train.ogg",
	"power_down":
		"res://assets/audio/freesound/processed/events/electric_power_down.wav",
	"water_droplets":
		"res://assets/audio/freesound/processed/events/water_droplets.wav",
	"hail_window":
		"res://assets/audio/freesound/processed/events/hail_window.ogg",
	"streetlamp_buzz_loop":
		"res://assets/audio/freesound/processed/props/streetlamp_buzz.ogg",
	"rain_on_metal":
		"res://assets/audio/freesound/processed/props/rain_on_metal.ogg",
	"sink_water":
		"res://assets/audio/freesound/processed/props/sink_water.ogg",
	"shower_water":
		"res://assets/audio/freesound/processed/props/shower_water.ogg",
	"elevator_machine_loop":
		"res://assets/audio/freesound/processed/beds/ambient_basement_elevator.ogg",
	"knock":
		"res://assets/audio/freesound/processed/mechanical/pipe_knock.ogg",
	"tick":
		"res://assets/audio/freesound/processed/mechanical/metal_tick.ogg",
	"thud":
		"res://assets/audio/freesound/processed/mechanical/building_thud.ogg",
	"bell":
		"res://assets/audio/freesound/processed/mechanical/elevator_bell.ogg",
	"pop":
		"res://assets/audio/freesound/processed/mechanical/appliance_pop.ogg",
	"creak":
		"res://assets/audio/freesound/processed/mechanical/timber_creak.ogg",
	"whistle_loop":
		"res://assets/audio/freesound/processed/mechanical/pressure_whistle_loop.ogg",
	"breath":
		"res://assets/audio/freesound/processed/mechanical/distant_breath.ogg",
	"vocal":
		"res://assets/audio/freesound/processed/mechanical/operator_whistle.ogg",
	"murmur_loop":
		"res://assets/audio/freesound/processed/mechanical/line_murmur_loop.ogg",
	"hum_loop":
		"res://assets/audio/freesound/processed/mechanical/mechanical_hum_loop.ogg",
	"buzz_loop":
		"res://assets/audio/freesound/processed/mechanical/electrical_buzz_loop.ogg",
	"agitate_loop":
		"res://assets/audio/freesound/processed/mechanical/washer_agitate_loop.ogg",
}
static var _cache: Dictionary = {}
static var _warned: Dictionary = {}


static func get_stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	if not RECORDED.has(key):
		if not _warned.has(key):
			push_warning("PropAudio: unknown recorded key %s" % key)
			_warned[key] = true
		return null
	var path: String = RECORDED[key]
	if not ResourceLoader.exists(path):
		if not _warned.has(key):
			push_warning("PropAudio: recorded source missing for %s: %s" %
					[key, path])
			_warned[key] = true
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis and key.ends_with("_loop"):
		stream.loop = true
	elif stream is AudioStreamWAV and key.ends_with("_loop"):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cache[key] = stream
	return stream


static func clear_cache() -> void:
	_cache.clear()
