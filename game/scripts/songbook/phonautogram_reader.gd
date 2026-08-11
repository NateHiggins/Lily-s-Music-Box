class_name PhonautogramReader
extends RefCounted
## Reading a trace back, which is not the same as playing a recording.
##
## Scott's phonautograph could not reproduce sound and was never meant to; it
## drew pictures of it (ORISON_BIBLE III.2). **The Orison fudges this** - the
## owner ruled that a trace can be heard - but it fudges it in the direction the
## history already points, because what actually happened in 2008 is stranger
## than any invention would have been.
##
## When First Sounds recovered Scott's 1860 *Au Clair de la Lune*, they had the
## soot and no reference tone, so they had to GUESS the speed the crank had been
## turned at. They guessed wrong. The recovered voice sounded like a woman
## singing, and it was celebrated as such. It was Scott himself, at half speed.
##
## So: what comes out of this machine is not a voice, it is a **reconstruction
## of a picture of a voice**, and the two things it cannot know are the two
## things that matter. It does not know how fast the crank was turned, and it
## does not know where the bristle skipped.
##
## Everything below follows from that and nothing is decoration:
##
##   band     a bristle in soot has no top and no bottom to speak of
##   wow      hand-cranked, so the pitch wanders and never settles
##   guess    the SPEED IS A GUESS, drawn fresh on every reading
##   skip     the bristle lifted, and there is simply nothing there
##
## The guess is the point. Play the same trace twice and it may not be the same
## person, which is the cruellest thing this building can do to somebody trying
## to identify a voice - and it is documented history rather than a horror beat
## somebody invented.

const BUS := "Phonautogram"

## Speed guesses the reader will commit to, and how often. Mostly it is close;
## sometimes it is exactly the mistake that was actually made in 2008.
const GUESSES := [
	[1.00, 46.0],   # correct, and it still wanders - see `wow`
	[0.94, 18.0],
	[1.07, 16.0],
	[0.50, 10.0],   # the 2008 error: a man becomes a woman
	[2.00, 6.0],
	[0.71, 4.0],
]


static func ensure_bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_volume_db(index, -4.5)

	# A bristle dragging in lampblack is a narrow instrument. Everything below
	# the chest and above the sibilants was never written down at all, so it
	# cannot be read back - this is subtraction, not EQ taste.
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 310.0
	hp.resonance = 0.2
	AudioServer.add_bus_effect(index, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 2600.0
	lp.resonance = 0.3
	AudioServer.add_bus_effect(index, lp)

	# The scan is not clean. Soot flakes, paper creases, and the optical read
	# turns all of it into grit sitting on top of the voice.
	var grit := AudioEffectDistortion.new()
	grit.mode = AudioEffectDistortion.MODE_LOFI
	grit.pre_gain = 4.0
	grit.drive = 0.34
	grit.post_gain = -7.0
	AudioServer.add_bus_effect(index, grit)

	# The cylinder is a hard surface in a wooden box and the horn is a barrel.
	# Short, boxy, and nothing like a room.
	var box := AudioEffectReverb.new()
	box.room_size = 0.22
	box.damping = 0.75
	box.wet = 0.20
	box.dry = 0.92
	box.predelay_msec = 6.0
	AudioServer.add_bus_effect(index, box)
	return index


## Commit to a speed for one reading. Deterministic per trace unless `drifting`,
## which is what makes a second look at the same trace disagree with the first.
static func guess_speed(trace_id: String, drifting := true) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(trace_id) if not drifting else randi()
	var total := 0.0
	for g in GUESSES:
		total += float(g[1])
	var roll := rng.randf() * total
	for g in GUESSES:
		roll -= float(g[1])
		if roll <= 0.0:
			return float(g[0])
	return 1.0


## The non-positional twin, for a reading heard at the machine itself rather
## than from across the room. Same reader, same guess.
static func attach_stream(player: AudioStreamPlayer, trace_id: String) -> float:
	ensure_bus()
	player.bus = BUS
	var speed := guess_speed(trace_id)
	player.pitch_scale = speed
	return speed


static func wow_stream(player: AudioStreamPlayer, base_speed: float,
		t: float) -> void:
	var wander := sin(t * 0.7) * 0.020 + sin(t * 2.3 + 1.1) * 0.011
	wander -= maxf(0.0, sin(t * 0.23)) * 0.014
	player.pitch_scale = base_speed * (1.0 + wander)


## Send a player through the reader and give it its speed for this reading.
static func attach(player: AudioStreamPlayer3D, trace_id: String) -> float:
	ensure_bus()
	player.bus = BUS
	var speed := guess_speed(trace_id)
	player.pitch_scale = speed
	return speed


## Hand-cranked, so it never holds a speed. Call every frame with the speed
## `attach` returned; the wander is small enough to be felt rather than heard,
## which is the difference between a worn record and a hand on a crank.
static func wow(player: AudioStreamPlayer3D, base_speed: float,
		t: float) -> void:
	var wander := sin(t * 0.7) * 0.020 + sin(t * 2.3 + 1.1) * 0.011
	# And the arm gets tired. A slow sag nobody notices until it recovers.
	wander -= maxf(0.0, sin(t * 0.23)) * 0.014
	player.pitch_scale = base_speed * (1.0 + wander)


## Where the bristle lifted. Returns true if this instant should be silent -
## not quiet, SILENT, because a gap in a trace is an absence of writing rather
## than an absence of sound.
static func skipped(t: float) -> bool:
	return sin(t * 3.7) * sin(t * 0.41) > 0.986
