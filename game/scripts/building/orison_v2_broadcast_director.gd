extends Node
## The station's programme director in V2 (Lily, v1r_broadcast_director_20261109:
## "Import it as the programme behind the V2 radios").
##
## V1's director ran one television feed: thirty-seven clips it shuffled, a
## card break every third programme, and a hand it could put on the
## transmission. V2's station is the house broadcast every household set joins
## (OrisonV2Broadcast), so the director stands behind that. After every third
## record it breaks the running order for a card: an advertisement, a piece of
## house trivia or a station identification, in V1's own words. And when a
## poltergeist takes the transmission (Intrusions' tv_infect asks
## `world.broadcast`), it takes every wireless in the building at once: each
## set switches itself on and its programme sinks and wavers until it is let go.
##
## The thirty-seven clips were films for V1's sets. They are not imported:
## the apartment projectors and the clips go (Lily, v2_projectors_removal_20261110),
## and a tent in the street will show a new film.

signal card_shown(lines: Array)

const Broadcast := preload("res://scripts/audio/orison_v2_broadcast.gd")
const V2Radio := preload("res://scripts/building/orison_v2_radio_prop.gd")
const CARD_EVERY := 3
const CARD_SECONDS := 3.6

const IDENTS := [
	["ORISON", "CHANNEL 4"], ["STAY TUNED", ""],
	["WE'LL BE", "RIGHT BACK"], ["DO NOT ADJUST", "YOUR SET"],
]
const ADVERTS := [
	["PLEASE STAY", "ON THE LINE"],
	["SILENCE DOES NOT", "REQUIRE ANNOTATION"],
	["SOME THINGS ARE", "NOT REPAIRABLE"],
	["GOOD ENOUGH", "CAN HOLD"],
	["NOT EVERY ALARM", "IS YOURS"],
	["DEPARTURE", "IS A DECISION"],
	["CONTRADICTION", "IS SURVIVABLE"],
]
const TRIVIA := [
	["THE ORISON'S BOILER HAS BURNED", "CONTINUOUSLY SINCE 1927"],
	["THE LIGHT COURT RISES", "SEVEN STOREYS UNBROKEN"],
	["OUR SWITCHBOARD ANSWERS", "AT EVERY HOUR"],
	["THE BRASS TREE WAS COMMISSIONED", "FOR THE OPENING"],
	["EIGHTEEN HOMES", "ONE ADDRESS"],
	["THE ELEVATOR HAS NEVER", "ONCE BEEN LATE"],
]

## The market's week on the air (ruling plate_lead_crash_20261120: the crash is
## in the background, a radio bulletin among it). The station reads the day's
## market news on the evening of the day, a morning ahead of the Record, so on
## these days every other card is the bulletin. Figures follow the papers.
const BULLETINS := {
	"1929-10-24": ["STOCKS BREAK AT THE OPENING", "THE TICKER RUNS NINETY MINUTES LATE"],
	"1929-10-25": ["PRICES HOLD ON THE FLOOR", "MR. HOOVER SAYS BUSINESS IS SOUND"],
	"1929-10-26": ["A QUIET SATURDAY SESSION", "BROKERS ASK MARGIN BY MONDAY"],
	"1929-10-28": ["THE AVERAGE FALLS 38 POINTS", "NO BANKERS' SUPPORT ON THE FLOOR"],
	"1929-10-29": ["SIXTEEN MILLION SHARES SOLD", "THE AVERAGE FALLS 30 MORE"],
	"1929-10-30": ["THE AVERAGE RISES 28 POINTS", "THE EXCHANGE TO CLOSE FRIDAY"],
	"1929-10-31": ["THREE HOURS' TRADING FROM NOON", "THE AVERAGE RISES 15"],
	"1929-11-01": ["THE EXCHANGE IS CLOSED TODAY", "BROKERS' CLERKS AT THE ACCOUNTS"],
	"1929-11-02": ["THE EXCHANGE IS CLOSED TODAY", "BROKERS' CLERKS AT THE ACCOUNTS"],
}

var radios: Array[Node] = []
var possessed := false
var card_lines: Array = []
var cards_shown := 0

var _rng := RandomNumberGenerator.new()
var _in_break := false
var _possess_clock := 0.0


## `props` are the household props the runtime already collected; the director
## keeps the wirelesses among them.
func setup(props: Array) -> void:
	_rng.randomize()
	for prop: Variant in props:
		if is_instance_valid(prop) and prop.get_script() == V2Radio:
			radios.append(prop)
	Broadcast.break_every = CARD_EVERY
	Broadcast.break_seconds = CARD_SECONDS
	print("[STATION] %d wirelesses; a card every %d records" % [radios.size(), CARD_EVERY])


func _process(delta: float) -> void:
	var breaking := bool(Broadcast.now_playing().get("break", false))
	if breaking and not _in_break:
		_show_card()
	elif not breaking and _in_break:
		card_lines = []
		Broadcast.card = ""
	_in_break = breaking
	if possessed:
		_possess_clock += delta
		for radio in radios:
			if is_instance_valid(radio):
				radio.possession_waver(_possess_clock)


## A card: an advert, house trivia or an ident, weighted toward the strange
## ones as V1 weighted them. A set on the air carries its words.
## In the market's week, every other card is the day's bulletin.
func _show_card() -> void:
	var bulletin := bulletin_for(_today())
	if not bulletin.is_empty() and cards_shown % 2 == 0:
		card_lines = bulletin.duplicate()
	else:
		var roll := _rng.randf()
		var pool: Array = ADVERTS if roll < 0.45 else (TRIVIA if roll < 0.8 else IDENTS)
		card_lines = (pool[_rng.randi() % pool.size()] as Array).filter(
				func(line: String) -> bool: return line != "")
	Broadcast.card = " ".join(card_lines)
	cards_shown += 1
	card_shown.emit(card_lines)


## The market bulletin the station reads on a civil day ("YYYY-MM-DD"); empty on other days.
static func bulletin_for(date: String) -> Array:
	return (BULLETINS.get(date, []) as Array)


## The campaign's civil day, from the clock's saved state.
func _today() -> String:
	var now := CampaignClock.new().local_datetime()
	return "" if now.is_empty() else "%04d-%02d-%02d" % [int(now.year), int(now.month), int(now.day)]


# ------------------------------------------------------------ the hand

## A poltergeist takes every wireless in the building at once, for a while.
func possess(seconds := 12.0) -> void:
	if possessed:
		return
	possessed = true
	_possess_clock = 0.0
	for radio in radios:
		if is_instance_valid(radio):
			radio.set_possessed(true)
	print("[STATION] possessed for %.0f s" % seconds)
	await get_tree().create_timer(seconds).timeout
	release()


## Lets every set go: each wireless is as its listener left it.
func release() -> void:
	if not possessed:
		return
	possessed = false
	for radio in radios:
		if is_instance_valid(radio):
			radio.set_possessed(false)


func any_powered() -> bool:
	for radio in radios:
		if is_instance_valid(radio) and bool(radio.powered):
			return true
	return false


func stats() -> Dictionary:
	var on := 0
	for radio in radios:
		if is_instance_valid(radio) and bool(radio.powered):
			on += 1
	return {"sets": radios.size(), "on": on,
			"possessed": possessed, "card": not card_lines.is_empty(), "cards_shown": cards_shown}


func _exit_tree() -> void:
	release()
	Broadcast.break_every = 0
	Broadcast.break_seconds = 0.0
	Broadcast.card = ""
