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
## The mantle wears. Burning hours at incandescence count toward its life,
## seeded per mantle; then it breaks. A broken mantle, or a bare burner,
## burns a ragged naked flame: a fraction of the light, flickering hard, and
## loud. To renew it, open the fitting's access (slide the bracket's shade
## down, swing the lantern's street light out): a broken mantle's brittle
## ash crumbles at the touch. Close the access again with a spare mantle in
## hand and the new one is hung; it burns off with a brief flare on its first
## light. Spare mantles are single-use MaintenanceInventory ids taken from the
## workroom carton (OrisonV2MantleCarton); this fitting only consumes one.
##
## State (cock, mantle condition, hours, life, count, access position) is the
## household save's mechanism record under this node's semantic name.

signal manipulation_changed

## Below this opening the main jet is shut and only the pilot burns.
const JET_OPENS := 0.12
## Fraction of the jet at which the mantle reaches full incandescence.
const MANTLE_FULL := 0.55
const CLOCK_PERIOD := 4.0
## A naked flame gives about a sixth of a mantle's light, and yellower.
const NAKED_LIGHT := 0.16
const NAKED_COLOUR := Color(1.0, 0.70, 0.36)
## A Welsbach mantle on house gas lasted some hundreds of burning hours.
const LIFE_HOURS := Vector2(450.0, 900.0)
const MANTLE_STATES := ["intact", "broken", "bare"]
const FLARE_SECONDS := 3.0

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

## The mantle on the burner: "intact", "broken" (ash still hanging) or "bare".
var mantle_state := "intact"
var mantle_hours := 0.0
var mantle_life := 700.0
## Mantles this burner has worn; seeds the next one's life.
var mantle_number := 0
## How far the access is open: metres for a shade, radians for a door.
var access := 0.0
var access_kind := ""
var access_part: Node3D
var access_origin := Transform3D.IDENTITY
var access_axis := Vector3.DOWN
var access_travel := 0.0
var access_open_at := 0.0
var mantle_mesh: Node3D
var broken_mesh: Node3D
var flame_mesh: Node3D
var inventory: Node
## Returns the spare mantle id the player carries, or "".
var mantle_source: Callable

var _clock_factor := 1.0
var _clock_accum := INF
var _base_energy := 1.0
var _base_colour := Color.WHITE
var _held := ""
var _flare := 0.0
static var _hiss_stream: AudioStreamWAV


func configure(light_node: OmniLight3D, key_node: Node3D) -> void:
	light = light_node
	key = key_node
	_base_energy = light.light_energy
	_base_colour = light.light_color
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


## Light actually given: the mantle as the mains pressure lets it burn, or
## a naked flame's fraction of it, with a new mantle's burn-off flare.
func brightness() -> float:
	var lit := mantle() if mantle_state == "intact" else flow() * NAKED_LIGHT
	return lit * clampf(pressure, 0.0, 1.1) * (1.0 + 0.8 * _flare)


## Gas through this fitting's meter, in cubic feet an hour.
func gas_rate() -> float:
	return full_rate * flow() + pilot_rate


func held() -> bool:
	return not _held.is_empty()


## Mantle wear for `minutes` of campaign time, from the gas service's clock.
func burn(minutes: float) -> void:
	if mantle_state != "intact" or minutes <= 0.0:
		return
	mantle_hours += mantle() * minutes / 60.0
	if mantle_hours >= mantle_life:
		mantle_state = "broken"
		_apply()
		manipulation_changed.emit()


## The life of this burner's next mantle: fixed by fitting and count, so a
## reload never rerolls it.
func seeded_life(number: int) -> float:
	var roll := float(posmod(("%s:%d" % [name, number]).hash(), 10007)) / 10006.0
	return lerpf(LIFE_HOURS.x, LIFE_HOURS.y, roll)


func configure_mantle(meshes: Dictionary, kind: String, travel: float, open_at: float,
		axis: Vector3, part: Node3D) -> void:
	mantle_mesh = meshes.intact
	broken_mesh = meshes.broken
	flame_mesh = meshes.flame
	access_kind = kind
	access_part = part
	access_origin = part.transform
	access_travel = travel
	access_open_at = open_at
	access_axis = axis.normalized() if kind == "door" else Vector3.DOWN
	var area := preload("res://scripts/props/manipulation_area.gd").install(part, access_grip)
	if kind == "shade":
		# A shade is slid by its lower rim. Keep the grip off the gallery end,
		# where a hand reaching for the cock key passes beside it.
		for shape: CollisionShape3D in area.get_children():
			var box := shape.shape as BoxShape3D
			var top := shape.position.y + box.size.y * 0.5
			box.size.y *= 0.45
			shape.position.y = top - box.size.y * 0.5 - box.size.y / 0.45 * 0.55
	_apply()


func access_grip() -> Dictionary:
	var hinge := access_kind == "door"
	return {"owner": self, "part": access_part, "frame": self,
		"kind": "hinge" if hinge else "slide",
		"axis": -access_axis if hinge else Vector3.DOWN,
		"minimum": 0.0, "maximum": access_travel,
		"read": func(): return access,
		"write": func(value: float):
			if _held == "access": set_access(value),
		"owns": func(): return _held == "access",
		"begin": func():
			if not _held.is_empty(): return false
			_held = "access"
			return true,
		"end": func(): _held = ""; manipulation_changed.emit()}


## Open the access to the burner. Crossing open crumbles a broken mantle's
## ash; crossing shut again with a spare in hand hangs a new mantle.
func set_access(value: float) -> void:
	var before := access
	access = clampf(value, 0.0, access_travel)
	if access_part != null:
		if access_kind == "door":
			# Out from the lantern is the negative turn about the post, top to foot.
			access_part.transform = access_origin * Transform3D(Basis(access_axis, -access), Vector3.ZERO)
		else:
			access_part.transform = access_origin.translated(Vector3.DOWN * access)
	if before < access_open_at and access >= access_open_at and mantle_state == "broken":
		mantle_state = "bare"
	elif before >= access_open_at and access < access_open_at and mantle_state != "intact":
		_hang_new_mantle()
	_apply()


func _hang_new_mantle() -> void:
	if inventory == null or not mantle_source.is_valid():
		return
	var spare := str(mantle_source.call())
	if spare.is_empty() or not inventory.consume(spare):
		return
	mantle_number += 1
	mantle_state = "intact"
	mantle_hours = 0.0
	mantle_life = seeded_life(mantle_number)
	_flare = 1.0


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
			if _held == "cock": set_opening(angle / (PI * 0.5)),
		"owns": func(): return _held == "cock",
		"begin": func():
			if not _held.is_empty(): return false
			_held = "cock"
			return true,
		"end": func(): _held = ""; manipulation_changed.emit()}


func mechanism_snapshot() -> Dictionary:
	return {"cock": opening, "mantle": mantle_state, "hours": mantle_hours,
		"life": mantle_life, "number": mantle_number, "access": access}


## A save from before mantles wore holds the cock alone; it stays valid.
func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size() not in [1, 6]:
		return false
	if not _unit(value.get("cock"), 1.0):
		return false
	if value.size() == 1:
		return true
	return str(value.get("mantle", "")) in MANTLE_STATES and _unit(value.get("hours"), 1.0e6) \
			and _unit(value.get("life"), 1.0e6) and float(value.life) > 0.0 \
			and typeof(value.get("number")) in [TYPE_FLOAT, TYPE_INT] and int(value.number) >= 0 \
			and _unit(value.get("access"), maxf(access_travel, 0.0) + 0.0001)


static func _unit(value: Variant, top: float) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value)) \
			and float(value) >= 0.0 and float(value) <= top


func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_held = ""
	if value.size() == 6:
		mantle_state = str(value.mantle)
		mantle_hours = float(value.hours)
		mantle_life = float(value.life)
		mantle_number = int(value.number)
		access = float(value.access)
		var restoring := mantle_state
		set_access(access)
		mantle_state = restoring
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
	if mantle_state != "intact":
		# A naked flame licks and gutters: hard, quick and uneven.
		breath = 0.2 * sin(t * 9.3 + phase) + 0.12 * sin(t * 23.1 + phase * 2.3) + 0.08 * sin(t * 41.0)
	if _flare > 0.0:
		_flare = maxf(_flare - delta / FLARE_SECONDS, 0.0)
		_apply()
	light.light_energy = _base_energy * brightness() * (1.0 + breath)


func _apply() -> void:
	if key != null:
		key.rotation.y = opening * PI * 0.5
	var lit := brightness()
	var naked := mantle_state != "intact"
	if light != null:
		light.visible = lit > 0.01
		light.light_energy = _base_energy * lit
		light.light_color = NAKED_COLOUR if naked else _base_colour
	for material: StandardMaterial3D in glow:
		material.emission_energy_multiplier = maxf(float(glow[material]) * lit, pilot_glow)
	if mantle_mesh != null:
		mantle_mesh.visible = not naked
		broken_mesh.visible = mantle_state == "broken"
		flame_mesh.visible = naked and flow() > 0.01
	if hiss != null:
		# The pilot's whisper underneath, opening into the jet's roar; a
		# burner with no mantle to slow it roars louder.
		hiss.volume_db = linear_to_db(0.08 + 0.92 * flow()) - (18.0 if naked else 26.0)


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
