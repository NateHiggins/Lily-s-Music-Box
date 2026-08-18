class_name DreamAtlas
extends RefCounted
## THE FRACTAL ORISON — a building that does not close, remembered wrong.
##
## Owner ruling 2026-08-17, replacing the ten-module ring: "the fractal is the
## dream world. it contains multitudes." A persistent, convoluted Orison
## "being actively forgotten and misremembered by the ghosts that inhabit it",
## entered at a random point each time the player dreams.
##
## ─────────────────────────────────────────────────────────────────────────
## THE THREE IDEAS THIS RESTS ON
##
## 1. IDENTITY COMES FROM THE PATH, NOT FROM A POSITION.
##    A room is named by the sequence of doors taken to reach it, folded into
##    a 64-bit hash. Walk left-left-right from the entrance and you always
##    arrive at the same room, in this campaign, forever. The building is
##    therefore infinite, deterministic and needs no storage: it is a pure
##    function of (campaign seed, path).
##
## 2. GEOMETRY IS PLACED LOCALLY, AND THE BUILDING NEVER CLOSES.
##    Each room is positioned relative to the door you came through. Nothing
##    reconciles a room with one built elsewhere, so walking a loop does NOT
##    return you to where you started — you arrive somewhere with the same
##    name and a different place.
##
##    That is not a limitation being tolerated. It is the thesis. A remembered
##    building has no consistent floor plan, because memory does not store one;
##    it stores rooms and the feeling of going between them. The Orison of the
##    dream is exactly as coherent as a memory of a building, which is to say
##    locally perfect and globally impossible — the brief's own words, from
##    before any of this: "the route makes architectural sense one room at a
##    time and cannot possibly make sense as a building."
##
## 3. MISREMEMBERING IS NOT RANDOMNESS.
##    Noise gives procedural soup. Memory fails in a small number of specific,
##    nameable ways, and implementing THOSE is what makes the maze read as a
##    mind failing rather than as a generator running. Each room draws its
##    faults from `FAULTS` below, deeper as it decays.
##
## ─────────────────────────────────────────────────────────────────────────
## WHY THERE IS NO SAVE FILE
##
## Decay is a function of (seed, room id, dreams_had) and nothing is stored at
## all. The alternative — a visited-room map — grows without bound across a
## campaign and would have to be pruned by some rule the player cannot see.
## A pure function cannot leak, cannot corrupt a save, and reconstructs
## identically on any machine. The cost is that the building cannot remember
## the player specifically, only how many nights have passed; that is a trade
## worth taking, and it is also the better fiction. The house is not forgetting
## YOU. It is just forgetting.

## The source rooms. The N2 catalog is not retired by this — it becomes the
## vocabulary the fractal speaks, which is what keeps its measured provenance
## meaningful. Every room in an infinite building is still a real Orison space.
const CATALOG_PATH := "res://data/dream_module_catalog.json"

## How many doors a room may offer. Three is the number that makes a building
## feel branching without making it a hub: two reads as a corridor, four reads
## as a lobby, and a player facing three unmarked doors has to choose rather
## than proceed.
const MIN_DOORS := 2
const MAX_DOORS := 4

## HOW MEMORY FAILS. Ordered by how early in a room's decay it appears — a
## barely-forgotten room repeats itself; a thoroughly forgotten one is a blank
## with a door in it.
enum Fault {
	NONE,
	## THE CORRIDOR YOU ALREADY WALKED. The room is a near-copy of the one
	## before it, differing in one detail you cannot name. You notice on the
	## second repeat, and the noticing is the horror: you have been walking
	## the same twenty metres for a while.
	REPETITION,
	## TWO ROOMS AT ONCE. A bathroom with a kitchen's window; a stairwell with
	## a bedroom's skirting. Both are real Orison rooms and neither belongs to
	## the other. Memory conflates, and conflation reads as WRONG far faster
	## than invention does.
	CONFLATION,
	## SCALE DRIFT. The right room at the wrong size — a corridor at eleven
	## tenths, a doorway at four fifths. Never enough to measure by eye, always
	## enough to walk wrong. Rooms you knew well drift the most, because you
	## have rehearsed them the most.
	SCALE,
	## CONFABULATION. The gap filled with something plausible that was never
	## there: a door where the plan has none, a room the building could not
	## contain. This is the only fault that ADDS space, so it is what makes the
	## building larger than the building.
	CONFABULATION,
	## RECURSION. The room contains a smaller copy of itself, and that copy is
	## enterable. The fractal proper. Rare, and reserved for deep decay, so it
	## reads as the building's memory finally eating its own tail.
	RECURSION,
	## BLANKING. Detail gone. Geometry without dressing, doors without frames,
	## a room reduced to its dimensions. The end state of forgetting, and the
	## quietest and worst of these: nothing has been added, something has just
	## stopped being there.
	BLANKING,
}

var seed_hi := 0
var seed_lo := 0
var dreams_had := 0
var _catalog: Dictionary = {}
var _rooms: Array = []


func setup(seed_hex: String, nights: int) -> void:
	var halves := DreamMazeBuilder.seed_halves(seed_hex)
	seed_hi = halves[0]
	seed_lo = halves[1]
	dreams_had = maxi(0, nights)
	_catalog = DreamMazeBuilder.load_catalog()
	_rooms = []
	for id in (_catalog.get("modules", {}) as Dictionary):
		_rooms.append(id)
	_rooms.sort()


## A 64-bit mix, written out rather than borrowed. `String.hash()` was
## re-implemented from memory once in this project and produced confident wrong
## numbers for a day; anything this file depends on for determinism is defined
## here, in one place, where it can be tested.
static func mix64(a: int, b: int) -> int:
	var h := a ^ (b + 0x9E3779B9 + (a << 6) + (a >> 2))
	h ^= h >> 33
	h *= 0xFF51AFD7
	h ^= h >> 29
	h *= 0xC4CEB9FE
	h ^= h >> 32
	return h


## THE NAME OF A ROOM IS THE WAY YOU GOT THERE. Folding the door indices into
## the campaign seed means the same walk always arrives at the same room, and
## two different walks essentially never collide.
func room_id(path: PackedInt32Array) -> int:
	var h := mix64(seed_hi, seed_lo)
	for step in path:
		h = mix64(h, int(step) + 0x51ED2701)
	return h


## Deterministic 0..1 for one named aspect of one room. Every property below
## comes through here, so a room is a pure read rather than a rolled object.
func aspect(id: int, salt: int) -> float:
	var h := mix64(id, salt)
	return float(absi(h) % 1000003) / 1000003.0


## HOW FAR GONE THIS ROOM IS. Rises with the nights the campaign has had, and
## varies per room so the building forgets unevenly — some corners stay sharp
## for a long time, which is what makes the rotten ones legible.
func decay(id: int, depth: int) -> float:
	var personal := aspect(id, 0x0DECA9)
	# Nights compound, but with diminishing return: the first few dreams change
	# the building fast and then it settles into being wrong.
	var nights := 1.0 - pow(0.82, float(dreams_had))
	# Depth is distance from where you woke. Far rooms are less rehearsed and
	# therefore worse remembered, which also means the building degrades as you
	# push into it -- an incentive shaped like a warning.
	var far := clampf(float(depth) / 14.0, 0.0, 1.0)
	return clampf(personal * 0.45 + nights * 0.40 + far * 0.35, 0.0, 1.0)


## Which way this room is wrong. Faults arrive in decay order, so a room's
## condition can be read off its symptoms -- the building becomes learnable,
## which is the whole thesis of the passage: "I know this building, I am
## getting better at surviving it."
func fault(id: int, depth: int) -> Fault:
	var d := decay(id, depth)
	var roll := aspect(id, 0xFA0173)
	if d < 0.18:
		return Fault.NONE
	if d < 0.34:
		return Fault.REPETITION
	if d < 0.48:
		return Fault.CONFLATION if roll < 0.6 else Fault.REPETITION
	if d < 0.62:
		return Fault.SCALE if roll < 0.5 else Fault.CONFLATION
	if d < 0.78:
		return Fault.CONFABULATION if roll < 0.55 else Fault.SCALE
	if d < 0.90:
		return Fault.RECURSION if roll < 0.30 else Fault.CONFABULATION
	return Fault.BLANKING


## The full description of one room, from its path alone. Nothing here is
## stored and nothing is rolled: call it twice, get the same room.
func room(path: PackedInt32Array) -> Dictionary:
	var id := room_id(path)
	var depth := path.size()
	var d := decay(id, depth)
	var f := fault(id, depth)

	# WHICH REAL ORISON ROOM THIS IS. The catalog is the vocabulary; a room is
	# always a real space before it is a wrong one.
	var source: String = _rooms[int(aspect(id, 0x50D6CE) * _rooms.size())
			% maxi(1, _rooms.size())] if not _rooms.is_empty() else ""
	var module: Dictionary = _catalog.get("modules", {}).get(source, {})
	var footprint: Array = module.get("footprint_m", [4.0, 4.0])
	var size := Vector2(float(footprint[0]), float(footprint[1]))

	# CONFLATION borrows a second room's proportions, so the space is one real
	# room wearing another real room's shape.
	var second := ""
	if f == Fault.CONFLATION and not _rooms.is_empty():
		second = _rooms[int(aspect(id, 0xC0F1) * _rooms.size())
				% _rooms.size()]
		var other: Dictionary = _catalog.get("modules", {}).get(second, {})
		var ofp: Array = other.get("footprint_m", footprint)
		size = size.lerp(Vector2(float(ofp[0]), float(ofp[1])), 0.5)

	# SCALE DRIFT. Never more than a fifth, because past that the eye stops
	# reading it as a wrong room and starts reading it as a different one.
	var scale := 1.0
	if f == Fault.SCALE:
		scale = lerpf(0.80, 1.22, aspect(id, 0x5CA1E))
		size *= scale

	# How many ways out. CONFABULATION invents one; BLANKING has forgotten
	# where they were and leaves the minimum.
	var doors := MIN_DOORS + int(aspect(id, 0xD0025)
			* float(MAX_DOORS - MIN_DOORS + 1))
	if f == Fault.CONFABULATION:
		doors = mini(doors + 1, MAX_DOORS)
	elif f == Fault.BLANKING:
		doors = MIN_DOORS

	return {
		"id": id,
		"path": path,
		"depth": depth,
		"source": source,
		"conflated_with": second,
		"size": size,
		"scale": scale,
		"decay": d,
		"fault": f,
		"doors": doors,
		# REPETITION is carried as a flag rather than a shape: the builder
		# reproduces the PREVIOUS room's dressing, which is what makes the
		# player recognise it instead of merely seeing a similar box.
		"repeats_previous": f == Fault.REPETITION,
		# RECURSION marks the room as containing an enterable smaller copy of
		# itself. The builder decides what that costs; the atlas only says it
		# is true.
		"recursive": f == Fault.RECURSION,
		"blank": f == Fault.BLANKING,
	}


## WHERE THE PLAYER WAKES, and it is different every night. Derived from the
## seed and the night index so a reload puts them back in the same place, and
## the next dream does not.
func spawn_path(night: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var h := mix64(mix64(seed_hi, seed_lo), night * 0x9E37 + 17)
	# A handful of steps in, so the player never wakes at a root they could
	# come to recognise as an entrance. There is no entrance.
	var steps := 3 + int(absi(h) % 5)
	for i in steps:
		h = mix64(h, i + 1)
		# EACH DOOR INDEX MUST EXIST IN THE ROOM IT LEAVES. Rooms carry 2 to 4
		# doors, so picking blindly from 0..MAX_DOORS-1 can name a fourth door
		# in a two-door room -- a path to a room reachable only through a
		# doorway that was never built. It would have surfaced as a player
		# waking somewhere the walk cannot reproduce, which is the one thing
		# this design cannot afford to get wrong.
		var here := room(out)
		out.append(absi(h) % maxi(1, int(here.doors)))
	return out


## The path reached by leaving `path` through door `door_index`. Walking back
## the way you came is NOT guaranteed to return you anywhere: see the note at
## the top about the building not closing.
static func step(path: PackedInt32Array, door_index: int) -> PackedInt32Array:
	var out := path.duplicate()
	out.append(door_index)
	return out


static func fault_name(f: Fault) -> String:
	match f:
		Fault.REPETITION: return "REPETITION"
		Fault.CONFLATION: return "CONFLATION"
		Fault.SCALE: return "SCALE"
		Fault.CONFABULATION: return "CONFABULATION"
		Fault.RECURSION: return "RECURSION"
		Fault.BLANKING: return "BLANKING"
		_: return "NONE"
