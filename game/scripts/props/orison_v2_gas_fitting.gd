class_name OrisonV2GasFitting
extends Node3D
## One gas light: its plug cock, burner, mantle and bypass pilot.
## Design: design/V2_ENTRY_VESTIBULE_2026-10-24.md §1.
##
## The cock is the only control (RUL-013). Grab its flat key and turn it a
## quarter turn about the plug: across the pipe is shut, in line is open.
## Between them the main jet opens progressively. An inverted burner of the
## period carries a bypass, so a pilot burns even with the cock shut and the
## mantle relights from it when the cock opens again. The mantle saturates
## well before the cock is fully open, as a Welsbach mantle does.
##
## A fitting on a clockwork controller (the street lantern) burns only between
## its dusk and dawn, by the same table as the city's street lamps.
##
## Supply pressure comes from the house gas service (OrisonV2GasService): the
## evening peak draws the mains down and every mantle dims with it. The
## service's meter reads gas_rate() from every fitting.
##
## State is the cock's opening alone; the household save owns it through
## mechanism_snapshot(), under this node's semantic name.

signal manipulation_changed

## Below this opening the main jet is shut and only the pilot burns.
const JET_OPENS := 0.12
## Fraction of the jet at which the mantle reaches full incandescence.
const MANTLE_FULL := 0.55
const CLOCK_PERIOD := 4.0

var opening := 1.0
## Relative mains pressure from the gas service; 1.0 is the works' nominal.
var pressure := 1.0
## Cubic feet an hour at a full jet, and the bypass pilot's own small burn.
var full_rate := 3.0
var pilot_rate := 0.15
var clock := false
var dusk: Array = []
var dawn: Array = []
## Tests may pin the clock instead of reading the campaign.
var clock_override: Dictionary = {}
var light: OmniLight3D
var key: Node3D
## Lit surfaces: material -> its full-mantle emission energy.
var glow: Dictionary = {}
## Emission that stays on a lit surface from the pilot alone.
var pilot_glow := 0.0
var hiss: AudioStreamPlayer3D

var _clock_factor := 1.0
var _clock_accum := INF
var _base_energy := 1.0
var _held := false
static var _hiss_stream: AudioStreamWAV


func configure(light_node: OmniLight3D, key_node: Node3D) -> void:
	light = light_node
	key = key_node
	_base_energy = light.light_energy
	hiss = AudioStreamPlayer3D.new()
	hiss.name = "Hiss"
	hiss.stream = _hiss()
	hiss.bus = "World"
	hiss.unit_size = 0.5
	hiss.max_distance = 4.0
	hiss.position = light.position
	add_child(hiss)
	preload("res://scripts/props/manipulation_area.gd").install(key, cock_grip)
	_apply()


func _ready() -> void:
	if hiss != null and not hiss.playing:
		hiss.play()


## How much gas reaches the mantle, 0..1, after the cock and any controller.
func flow() -> float:
	return clampf((opening - JET_OPENS) / (1.0 - JET_OPENS), 0.0, 1.0) * _clock_factor


## How incandescent the mantle is, 0..1, before the mains pressure.
func mantle() -> float:
	return clampf(flow() / MANTLE_FULL, 0.0, 1.0)


## Light actually given: the mantle as the mains pressure lets it burn.
func brightness() -> float:
	return mantle() * clampf(pressure, 0.0, 1.1)


## Gas through this fitting's meter, in cubic feet an hour.
func gas_rate() -> float:
	return full_rate * flow() + pilot_rate


func held() -> bool:
	return _held


func set_pressure(value: float) -> void:
	pressure = value
	_apply()


func set_opening(value: float) -> void:
	opening = clampf(value, 0.0, 1.0)
	_apply()


func cock_grip() -> Dictionary:
	return {"owner": self, "part": key, "frame": self, "kind": "hinge",
		"axis": Vector3.UP, "minimum": 0.0, "maximum": PI * 0.5,
		"read": func(): return opening * PI * 0.5,
		"write": func(angle: float):
			if _held: set_opening(angle / (PI * 0.5)),
		"owns": func(): return _held,
		"begin": func():
			if _held: return false
			_held = true
			return true,
		"end": func(): _held = false; manipulation_changed.emit()}


func mechanism_snapshot() -> Dictionary:
	return {"cock": opening}


func valid_mechanism(value: Variant) -> bool:
	return value is Dictionary and value.size() == 1 \
			and typeof(value.get("cock")) in [TYPE_FLOAT, TYPE_INT] \
			and is_finite(float(value.cock)) and float(value.cock) >= 0.0 and float(value.cock) <= 1.0


func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_held = false
	set_opening(float(value.cock))


func refresh_clock() -> void:
	if not clock:
		return
	var info: Dictionary = clock_override
	if info.is_empty():
		info = CampaignClock.new().day_info()
	if not bool(info.get("valid", true)):
		return
	_clock_factor = OrisonV2StreetTraffic.lamp_factor(info, dusk, dawn)
	_apply()


func _process(delta: float) -> void:
	_clock_accum += delta
	if clock and _clock_accum >= CLOCK_PERIOD:
		_clock_accum = 0.0
		refresh_clock()
	# A mantle on house gas never quite holds still: a slow breathing with the
	# supply pressure and a faint quick waver, a few percent either way.
	var t := Time.get_ticks_msec() * 0.001
	var phase := float(get_instance_id() % 97) * 0.13
	var breath := 0.03 * sin(t * 0.9 + phase) + 0.015 * sin(t * 6.7 + phase * 1.7)
	light.light_energy = _base_energy * brightness() * (1.0 + breath)


func _apply() -> void:
	if key != null:
		key.rotation.y = opening * PI * 0.5
	var lit := brightness()
	if light != null:
		light.visible = lit > 0.01
		light.light_energy = _base_energy * lit
	for material: StandardMaterial3D in glow:
		material.emission_energy_multiplier = maxf(float(glow[material]) * lit, pilot_glow)
	if hiss != null:
		# The pilot's whisper underneath, opening into the jet's roar.
		hiss.volume_db = linear_to_db(0.08 + 0.92 * flow()) - 26.0


## A soft broadband hiss, forged once and shared, looped.
static func _hiss() -> AudioStreamWAV:
	if _hiss_stream != null:
		return _hiss_stream
	var rate := 22050
	var n := rate * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 1912
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0
	for i in n:
		var white := rng.randf() * 2.0 - 1.0
		# Take off the lowest rumble: gas through a jet is air, not engine.
		low += (white - low) * 0.08
		var s := int(clampf((white - low) * 0.5 * 9000.0, -32000.0, 32000.0))
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	_hiss_stream = AudioStreamWAV.new()
	_hiss_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_hiss_stream.mix_rate = rate
	_hiss_stream.data = data
	_hiss_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hiss_stream.loop_end = n
	return _hiss_stream
