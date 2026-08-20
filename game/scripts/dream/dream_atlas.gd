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

## THE BUILDING DOES NOT MERELY BRANCH. IT DESCENDS.
##
## Room identity has always come from ancestry -- the ordered doors in its
## path -- but until now that ancestry had no visible phenotype. These salts
## derive a second, deliberately slow-changing genome from the same path. A
## child therefore resembles its parent, a sibling is recognisably related,
## and neither is a random decoration rolled after the room exists.
##
## They are golden vectors once shipped. They do NOT participate in room_id,
## source selection, door count or placement, so adding the visible lineage
## cannot move an existing save's rooms or alter a proven route.
const LINEAGE_ROOT_SALT := 0x2D15A53C1B91E9A7
const LINEAGE_STEP_SALT := 0x19C67D4A2E50B381
const LINEAGE_PHASE_SALT := 0x06F1A2C3
const LINEAGE_CURL_SALT := 0x03B70D51
const LINEAGE_GIRTH_SALT := 0x0712AC09
const LINEAGE_PULSE_SALT := 0x021D9E47
const LINEAGE_HAND_SALT := 0x05417E2B

enum LineageMutation {
	QUIET,
	FOLD,
	INVERT,
	DUPLICATE,
}

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


## `case_key` is the case (or the poltergeist attachment) this dream belongs
## to. Owner ruling 2026-08-18: "the structure and character of the maze and
## the poltergeist is informed by the current case/poltergeist npc attachment.
## when that changes a new start is chosen."
##
## So the case is folded into the campaign seed and the BUILDING ITSELF
## changes with it. Not a re-dressing of one maze -- a different maze, with
## different rooms in different places, because it is a different mind
## misremembering the same Orison. The campaign seed still separates one
## playthrough from another; the case separates one haunting from the next
## within it.
##
## An empty case_key leaves the seed exactly as it was, which is what keeps the
## golden vectors in DreamAtlasTest block E meaningful: they pin the building
## the seed alone names, and every case is a deterministic departure from it.
func setup(seed_hex: String, nights: int, case_key: String = "") -> void:
	var halves := DreamMazeBuilder.seed_halves(seed_hex)
	seed_hi = halves[0]
	seed_lo = halves[1]
	if not case_key.is_empty():
		var folded := fold_key(case_key)
		seed_hi = mix64(seed_hi, folded)
		seed_lo = mix64(seed_lo, folded ^ 0x5BF03635)
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


## A string folded to 64 bits, written out here for the same reason mix64 is:
## String.hash() was re-implemented from memory once in this project and
## produced confident wrong numbers for a day. A case id that hashed
## differently on two machines would build two different buildings from one
## save, and nothing would report it.
static func fold_key(text: String) -> int:
	# GDScript integers are SIGNED 64-bit and the literal has to fit. The
	# first version of this seeded with 0x9E3779B97F4A7C15 -- the 64-bit
	# golden-ratio constant, which is 1.14e19 and therefore larger than
	# int64's 9.22e18 ceiling. Godot reported "Cannot represent ... as a
	# 64-bit signed integer" and DreamAtlas stopped loading for any caller
	# that named a case, which took the dream world with it: the boundary
	# suite failed nine checks on the fractal path and the failures looked
	# like a topology problem rather than an arithmetic one. This constant is
	# the same kind of odd, high-entropy seed and it fits.
	var h := 0x165667B19E3779F9
	for i in text.length():
		h = mix64(h, text.unicode_at(i) + 0x165667B1)
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


## THE REPRODUCTIVE PATH, AS PURE DATA.
##
## The technical proposal called for child seeds derived from a parent seed
## and doorway index. That law was already latent in room_id(); this makes it
## explicit without changing room identity. The phenotype is accumulated in
## small bounded mutations along the path instead of being selected afresh
## from the final hash. That distinction is the whole effect: adjacent
## generations have family resemblance, while a long lineage can become
## unrecognisable without ever jumping there in one doorway.
##
## `pulse_hz` stays between 0.065 and 0.105 Hz -- one breath every 9.5 to
## 15.4 seconds. This is living motion, not flashing, and sits far below any
## photosensitive-risk frequency. Chirality can reverse, but the camera never
## does: the mutation belongs to her body, not the player's vestibular frame.
func lineage(path: PackedInt32Array) -> Dictionary:
	var root := mix64(mix64(seed_hi, seed_lo), LINEAGE_ROOT_SALT)
	var genome := root
	var phase := aspect(root, LINEAGE_PHASE_SALT) * TAU
	var curl := lerpf(0.34, 0.72, aspect(root, LINEAGE_CURL_SALT))
	var girth := lerpf(0.032, 0.052, aspect(root, LINEAGE_GIRTH_SALT))
	var pulse_hz := lerpf(0.073, 0.093, aspect(root,
			LINEAGE_PULSE_SALT))
	var handedness := -1 if aspect(root, LINEAGE_HAND_SALT) < 0.5 else 1
	var mutation := LineageMutation.QUIET
	for generation in path.size():
		var door := int(path[generation])
		var child := mix64(genome, LINEAGE_STEP_SALT
				+ door * 0x101 + (generation + 1) * 0x1F3)
		var turn := aspect(child, LINEAGE_PHASE_SALT)
		var bend := aspect(child, LINEAGE_CURL_SALT)
		var swell := aspect(child, LINEAGE_GIRTH_SALT)
		var tempo := aspect(child, LINEAGE_PULSE_SALT)
		var hand := aspect(child, LINEAGE_HAND_SALT)
		phase = fposmod(phase + lerpf(-0.34, 0.34, turn), TAU)
		curl = clampf(curl + lerpf(-0.055, 0.055, bend), 0.22, 0.86)
		girth = clampf(girth + lerpf(-0.0035, 0.0035, swell),
				0.026, 0.064)
		pulse_hz = clampf(pulse_hz + lerpf(-0.003, 0.003, tempo),
				0.065, 0.105)
		if hand < 0.13:
			handedness *= -1
		if hand < 0.13:
			mutation = LineageMutation.INVERT
		elif hand < 0.31:
			mutation = LineageMutation.DUPLICATE
		elif hand < 0.58:
			mutation = LineageMutation.FOLD
		else:
			mutation = LineageMutation.QUIET
		genome = child
	var parent_path := path.duplicate()
	if not parent_path.is_empty():
		parent_path.remove_at(parent_path.size() - 1)
	return {
		"genome_id": genome,
		"root_id": root,
		"generation": path.size(),
		"has_parent": not path.is_empty(),
		"parent_room_id": room_id(parent_path) if not path.is_empty() else 0,
		"birth_door": int(path[path.size() - 1]) if not path.is_empty() else -1,
		"phase": phase,
		"curl": curl,
		"girth": girth,
		"pulse_hz": pulse_hz,
		"handedness": handedness,
		"mutation": mutation,
	}


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
		# The phenotype is additive. Nothing in topology or placement reads it,
		# which keeps this visual grammar from becoming a save migration.
		"lineage": lineage(path),
	}


## WHERE THE PLAYER WAKES. Derived from the campaign seed and an ANCHOR index,
## so a reload puts them back in the same place.
##
## Owner ruling 2026-08-18 fixes what the anchor counts, and it is not nights:
## "each new game start at a random seed location in the maze until a case is
## solved and a new start position is chosen." The anchor is therefore the
## number of cases the campaign has resolved. A new game starts somewhere the
## seed picked; that place holds for as long as the case does; solving one
## moves it.
##
## Keying it to nights instead would have moved the player on every re-entry,
## which is the opposite of the intent -- a passage retried is the same
## passage, and waking somewhere new each attempt would make the one place the
## player could have come to know the least stable thing in the building.
##
## This also settles the collision between DreamMazeRoot's "every rebuild
## starts at D00" and this file's "there is no entrance". There is no
## entrance; there is a place the seed put you this case.
##
## THE ARITHMETIC BELOW IS A GOLDEN VECTOR. Only the MEANING of the argument
## changed with the ruling. Touching the mix would move every existing save's
## waking room with no error.
func spawn_path(anchor: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var h := mix64(mix64(seed_hi, seed_lo), anchor * 0x9E37 + 17)
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
