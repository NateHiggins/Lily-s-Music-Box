class_name DreamEcologyDirector
extends Node
## THE ECOLOGY'S WEATHER, AND ITS ONE MOMENT OF ONE-MINDEDNESS
## (ecology architecture §13, §31, §32, §33, §40).
##
## Two jobs, and §33 insists they stay separate:
##
## **The area state biases probabilities.** It does not drive animations and it
## does not synchronise anybody. During `FORAGING` there is more contact and
## more critter activity; during `WATCHING` there is less locomotion and more
## sensory orientation. Everyone still decides for themselves.
##
## **Global attention overrides local intent, and almost never happens.**
##
##     "Twenty procedural palps are doing different things. Several critters
##      are moving independently. Hero Tentacle is examining an object. A
##      sudden meaningful stimulus occurs. At the same instant: procedural tips
##      orient, critters stop or turn, hero eye fixes... Hold. Then autonomy
##      returns asynchronously."
##
## §40 makes the transition itself the acceptance test — *"the sudden
## transition from independent ecology to coordinated reaction should be
## immediately legible"* — so the two halves are built to be opposites. The
## snap is instantaneous and total; the release is staggered per individual,
## because a coordinated release would read as a machine switching off rather
## than as attention lapsing.
##
##     "This should be one of the most important reveals in the game: the
##      ecosystem may be one mind."

enum State { DORMANT, CURIOUS, FORAGING, SOCIAL, WATCHING, STARTLED,
		WITHDRAWING, HIGH_ATTENTION, INCARNATING }

## Transient communication vocabulary shared by the ecology's organelles.
## These are identity and chemistry, not instructions: the director stores
## packets but never decides who understands them or what an answer means.
enum SrcClass { HERO_LIMB, PROC_LIMB, PALP, BRANCH, CILIA, FAUNA,
		ARCHITECTURE, INCARNATION, HAZARD }
enum Fn { PROBE, RECOGNIZE, PULSE, SECRETE, REPAIR, TRANSPORT, ALLOCATE,
		REJECT, INHIBIT }
enum Chem { ELECTRIC, SECRETION, MINERAL, VASCULAR, ALARM, MECHANICAL }
enum Carrier { NONE, IMPULSE, SCRAPE, HUM }
enum Substrate { ANY, FLOOR, WALL, PIPE }

const FUNCTION_NAMES := ["probe", "recognize", "pulse", "secrete", "repair",
		"transport", "allocate", "reject", "inhibit"]
const SIGNAL_CAP := 32
const CellularAudioScript := preload(
		"res://scripts/dream/dream_cellular_audio_pool.gd")
const MossColonyScript := preload("res://scripts/dream/dream_moss_colony.gd")

const STATE_NAMES := ["dormant", "curious", "foraging", "social", "watching",
		"startled", "withdrawing", "high_attention", "incarnating"]

signal attention_seized(at: Vector3)
signal attention_released()

var margin = null
var critters = null
var hero = null
var field: DreamFieldController = null

var state: int = State.CURIOUS
var state_clock := 0.0
## Where everything is looking, while it is looking.
var attending := Vector3.INF
var attention_clock := 0.0
## The hold, before autonomy starts coming back.
const HOLD_S := 1.9

var _rng := RandomNumberGenerator.new()
var _released := 0
## Who has already been taken by this event. Needed because the margin keeps
## growing during it, and an appendage that emerges while the whole ecology is
## staring at something should be staring at it too -- a single palp going
## about its own business in the middle of the reveal breaks the entire beat.
var _seized: Dictionary = {}
var _signal_ring: Array[Dictionary] = []
var _signal_head := 0
var _signal_clock := 0.0
var _signals_emitted := 0
var _signals_evicted := 0
var _signals_by_function: Dictionary = {}
## One presentation pool belongs to this encroachment, not to any organelle.
## It only consumes already-published cellular facts and cannot feed the ring.
var cellular_audio: DreamCellularAudioPool = null
## DREAM-ECOLOGY-E1: one transient colony record per existing LivingField
## source. This director owns coordination/signals; LivingField still owns the
## physical body and stain, and no colony data enters RealityState/save data.
var moss_colonies: Dictionary = {}


func setup(seed_v: int) -> void:
	name = "DreamEcologyDirector"
	add_to_group("attention_dream")
	if cellular_audio == null:
		cellular_audio = CellularAudioScript.new()
		add_child(cellular_audio)
	cellular_audio.setup()
	_rng.seed = seed_v
	_signal_ring.clear()
	for _i in SIGNAL_CAP:
		_signal_ring.append({
			"live": false, "src_id": -1, "src_class": SrcClass.ARCHITECTURE,
			"function": Fn.PROBE, "at": Vector3.ZERO, "radius": 0.0,
			"strength": 0.0, "family": Chem.ELECTRIC, "sign": 1.0,
			"born": 0.0, "life": 0.0, "affinity": -1,
			"carrier": Carrier.NONE, "direction": Vector3.ZERO,
			"speed": 0.0, "substrate": Substrate.ANY,
		})
	_signal_head = 0
	_signal_clock = 0.0
	_signals_emitted = 0
	_signals_evicted = 0
	_signals_by_function.clear()
	moss_colonies.clear()


func register_moss_colony(source_id: int, seed_value: int, at := Vector3.INF):
	if moss_colonies.has(source_id):
		return moss_colonies[source_id]
	var colony = MossColonyScript.new()
	colony.configure(source_id, seed_value)
	if at != Vector3.INF:
		colony.seed_at(at)
	moss_colonies[source_id] = colony
	return colony


func moss_colony(source_id: int):
	return moss_colonies.get(source_id)


## A cilium's completed physical sample becomes the existing typed signal and
## the same observation is deposited in moss memory. It cannot touch case/save
## authority through this narrow vocabulary.
func receive_cilium_sample(source_id: int, cilium_id: int, target_id: String,
		at: Vector3, observation: Dictionary) -> float:
	var colony = moss_colony(source_id)
	if colony == null:
		return 0.0
	var value: float = colony.remember_target(target_id, observation)
	emit_signal_packet(cilium_id, SrcClass.CILIA, Fn.PROBE, at, 0.65,
			clampf(value, 0.05, 1.0), Chem.VASCULAR, 1.0, 1.6, source_id)
	return value


func disturb_colony(source_id: int, amount: float, reason: String, at: Vector3) -> bool:
	var colony = moss_colony(source_id)
	if colony == null:
		return false
	colony.disturb(amount, reason)
	emit_signal_packet(source_id, SrcClass.HAZARD, Fn.INHIBIT, at, 4.0,
			amount, Chem.ALARM, -1.0, 3.0, source_id)
	seize_attention(at)
	return true


func attention_active() -> bool:
	return attending != Vector3.INF


## §32 — states modify probabilities. This is the whole of their effect.
func bias() -> Dictionary:
	match state:
		State.DORMANT:
			return {"move": 0.35, "contact": 0.2, "social": 0.3, "orient": 0.4}
		State.FORAGING:
			return {"move": 1.15, "contact": 1.6, "social": 1.2, "orient": 0.9}
		State.SOCIAL:
			return {"move": 0.9, "contact": 0.8, "social": 1.8, "orient": 0.9}
		State.WATCHING:
			return {"move": 0.45, "contact": 0.5, "social": 0.7, "orient": 1.7}
		State.STARTLED:
			return {"move": 1.4, "contact": 0.2, "social": 0.4, "orient": 1.3}
		State.WITHDRAWING:
			return {"move": 0.8, "contact": 0.15, "social": 0.5, "orient": 0.6}
		State.HIGH_ATTENTION:
			return {"move": 0.3, "contact": 0.6, "social": 0.6, "orient": 2.0}
		State.INCARNATING:
			return {"move": 1.0, "contact": 1.4, "social": 1.0, "orient": 1.1}
	return {"move": 1.0, "contact": 1.0, "social": 1.0, "orient": 1.0}


func state_name() -> String:
	return STATE_NAMES[state]


func _process(delta: float) -> void:
	_signal_clock += delta
	state_clock += delta
	_since_last += delta
	if not _listening or not _mechanical_listening:
		_try_listen()
	if attending != Vector3.INF:
		_run_attention(delta)
		return
	# The area drifts between states on its own slow clock. Nothing here
	# commands an animation; it only changes how likely things are.
	if state_clock > _rng.randf_range(14.0, 34.0):
		state_clock = 0.0
		var options := [State.CURIOUS, State.FORAGING, State.SOCIAL,
				State.WATCHING, State.DORMANT]
		state = options[_rng.randi() % options.size()]


## A FIXED, REUSED SIGNAL BED. No save record, no global attention, no route.
## Expired slots are preferred; only a completely occupied bed overwrites its
## oldest packet. The packet dictionaries themselves are never replaced.
func emit_signal_packet(src_id: int, src_class: int, function: int, at: Vector3,
		radius: float, strength: float, family: int, sign: float, life: float,
		affinity: int = -1) -> void:
	if _signal_ring.is_empty():
		setup(int(_rng.seed))
	var slot_i := -1
	for offset in SIGNAL_CAP:
		var candidate := (_signal_head + offset) % SIGNAL_CAP
		var packet: Dictionary = _signal_ring[candidate]
		if not bool(packet.live) or _signal_clock >= float(packet.born) + float(packet.life):
			slot_i = candidate
			break
	if slot_i < 0:
		# With insertions advancing the head, it is also the oldest live slot.
		# Ties keep ring order instead of depending on a dictionary scan.
		slot_i = _signal_head
		_signals_evicted += 1
	var slot: Dictionary = _signal_ring[slot_i]
	slot.live = true
	slot.src_id = src_id
	slot.src_class = src_class
	slot.function = function
	slot.at = at
	slot.radius = maxf(0.0, radius)
	slot.strength = maxf(0.0, strength)
	slot.family = family
	slot.sign = signf(sign) if not is_zero_approx(sign) else 0.0
	slot.born = _signal_clock
	slot.life = maxf(0.001, life)
	slot.affinity = affinity
	slot.carrier = Carrier.NONE
	slot.direction = Vector3.ZERO
	slot.speed = 0.0
	slot.substrate = Substrate.ANY
	_signal_head = (slot_i + 1) % SIGNAL_CAP
	_signals_emitted += 1
	_signals_by_function[function] = int(_signals_by_function.get(function, 0)) + 1
	if cellular_audio != null and family != Chem.MECHANICAL:
		cellular_audio.present_signal(src_class, function, family, at, strength)


## Physical contact enters the bounded signal bed but crosses its substrate
## at finite speed instead of appearing throughout its radius at once.
func emit_mechanical_packet(src_id: int, at: Vector3, radius: float,
		strength: float, carrier: int, direction: Vector3, life: float,
		substrate: int, speed: float) -> void:
	emit_signal_packet(src_id, SrcClass.ARCHITECTURE, Fn.PULSE, at, radius,
			strength, Chem.MECHANICAL, 1.0, life)
	var slot_i := (_signal_head - 1 + SIGNAL_CAP) % SIGNAL_CAP
	var slot: Dictionary = _signal_ring[slot_i]
	slot.carrier = clampi(carrier, Carrier.NONE, Carrier.HUM)
	slot.direction = direction.normalized() \
			if direction.length_squared() > 0.0001 else Vector3.ZERO
	slot.speed = maxf(0.01, speed)
	slot.substrate = clampi(substrate, Substrate.ANY, Substrate.PIPE)


## Fills storage supplied by the caller. Receptors own affinity and response;
## this query knows only whether two spatial ranges overlap.
func signals_near(at: Vector3, radius: float, out: Array) -> int:
	out.clear()
	for packet in _signal_ring:
		if not bool(packet.live):
			continue
		if _signal_clock >= float(packet.born) + float(packet.life):
			packet.live = false
			continue
		var packet_radius := float(packet.radius)
		if int(packet.family) == Chem.MECHANICAL:
			var travelled := maxf(0.0, _signal_clock - float(packet.born)) \
					* float(packet.speed)
			packet_radius = minf(packet_radius, travelled)
		if at.distance_to(packet.at) <= maxf(0.0, radius) + packet_radius:
			out.append(packet)
	return out.size()


func signal_time() -> float:
	return _signal_clock


func signal_census() -> Dictionary:
	var live := 0
	for packet in _signal_ring:
		if bool(packet.live) and _signal_clock < float(packet.born) + float(packet.life):
			live += 1
	var named := {}
	for key in _signals_by_function:
		var idx := int(key)
		var label: String = FUNCTION_NAMES[idx] \
				if idx >= 0 and idx < FUNCTION_NAMES.size() else str(idx)
		named[label] = int(_signals_by_function[key])
	return {"live": live, "capacity": SIGNAL_CAP, "emitted": _signals_emitted,
			"evicted": _signals_evicted, "by_function": named}


## WHAT THE PLAYER DID, AND WHETHER IT WAS WORTH NOTICING.
##
## Owner direction: fire this whenever the player modifies the environment --
## opens a door, fixes something. §40 pulls the other way: the reveal must
## stay rare enough to remain meaningful. Both are satisfied by a floor on how
## often it can happen rather than by ignoring some interactions: every
## modification is noticed, but the ecology cannot snap to attention while it
## is already attending, and will not do so twice inside a cooldown.
##
## A door opened ten times in ten seconds is one event, not ten. That is also
## how attention works in an animal.
const RESEIZE_GAP_S := 22.0
var _since_last := RESEIZE_GAP_S
## The encroachment is built before the player exists, so connecting there
## silently did nothing. The director finds the player itself and connects
## once, whenever it turns up.
var _listening := false
var _mechanical_listening := false


func on_world_modified(where: Vector3, _what: String) -> void:
	if attending != Vector3.INF:
		return                       # already looking; nothing to seize
	if _since_last < RESEIZE_GAP_S:
		return
	_since_last = 0.0
	seize_attention(where)


func on_mechanical_stimulus(where: Vector3, carrier_name: StringName,
		strength: float, direction: Vector3, duration: float,
		substrate_name: StringName) -> void:
	var carrier: int = {&"impulse": Carrier.IMPULSE,
			&"scrape": Carrier.SCRAPE, &"hum": Carrier.HUM}.get(
			carrier_name, Carrier.NONE)
	if carrier == Carrier.NONE:
		return
	var substrate: int = {&"floor": Substrate.FLOOR,
			&"wall": Substrate.WALL, &"pipe": Substrate.PIPE}.get(
			substrate_name, Substrate.ANY)
	var propagation := 5.4 if carrier == Carrier.IMPULSE else \
			(3.2 if carrier == Carrier.SCRAPE else 2.1)
	emit_mechanical_packet(0, where, maxf(0.5, duration * propagation), strength,
			carrier, direction, maxf(0.35, duration + 0.45), substrate, propagation)


## Connect to the player's own account of what it has changed, once it
## exists. Retried rather than assumed, because build order put the
## encroachment first and the connection quietly never happened.
func _try_listen() -> void:
	# Walk up rather than search by name: this node is a child of the
	# encroachment, which is a child of the building root. A find_child by
	# name found nothing and failed silently, which is the same bug as before
	# wearing a different hat.
	var player = null
	var probe: Node = self
	for _step in 4:
		probe = probe.get_parent()
		if probe == null:
			break
		if "player" in probe and probe.get("player") != null:
			player = probe.get("player")
			break
	if player == null:
		return
	if player.has_signal("world_modified"):
		if not player.world_modified.is_connected(on_world_modified):
			player.world_modified.connect(on_world_modified)
		_listening = true
	if player.has_signal("mechanical_stimulus"):
		if not player.mechanical_stimulus.is_connected(on_mechanical_stimulus):
			player.mechanical_stimulus.connect(on_mechanical_stimulus)
		_mechanical_listening = true


## §13 — EVERYTHING, AT ONCE.
##
## Called for a stimulus worth the whole ecology's notice.
func seize_attention(at: Vector3) -> void:
	attending = at
	attention_clock = 0.0
	_released = 0
	_seized.clear()
	state = State.HIGH_ATTENTION
	# THE SNAP. Instantaneous and total: no easing, no per-individual delay,
	# because the legibility of the whole beat is that it is simultaneous.
	if margin != null:
		for p in margin.palps:
			_take(p, at)
	if critters != null:
		for c in critters.critters:
			_take_critter(c, at)
	if hero != null and is_instance_valid(hero):
		hero.attention_override = at
	attention_seized.emit(at)


func _take(p: Dictionary, at: Vector3) -> void:
	p.attend_override = at
	# The director owns this override now; §22's local look must not release
	# it out from under the event.
	p.local_look = false
	p.look_left = 0.0
	p.act = DreamPalpBehavior.Act.WATCH
	p.act_clock = 0.0
	p.act_left = HOLD_S + 4.0
	_seized["p%d" % int(p.id)] = true


func _take_critter(c: Dictionary, at: Vector3) -> void:
	c.attend_override = at
	c.moving = false
	_seized["c%d" % int(c.id)] = true


## Anything born mid-event joins it. Until this existed the margin spawned a
## palp during the reveal and it carried on probing a skirting board while
## seventy-one others stared at the same point.
func _sweep_newcomers() -> void:
	if margin != null:
		for p in margin.palps:
			if not _seized.has("p%d" % int(p.id)):
				_take(p, attending)
	if critters != null:
		for c in critters.critters:
			if not _seized.has("c%d" % int(c.id)):
				_take_critter(c, attending)


## Autonomy returns ASYNCHRONOUSLY. §13 is explicit about it, and it is the
## half that makes the event read as attention rather than as a switch: a
## coordinated release would look like a machine being turned off.
func _run_attention(delta: float) -> void:
	attention_clock += delta
	if attention_clock < HOLD_S:
		_sweep_newcomers()
		return
	if margin != null:
		for p in margin.palps:
			if p.get("attend_override", Vector3.INF) == Vector3.INF:
				continue
			# Each individual lets go on its own schedule, and a curious one
			# holds on longer than a jumpy one.
			var own: float = HOLD_S + float(p.traits.curiosity) * 2.6 \
					+ float(p.traits.startle_threshold) * 1.4
			if attention_clock > own:
				p.attend_override = Vector3.INF
				p.act_left = 0.0
				_released += 1
	if critters != null:
		for c in critters.critters:
			if c.get("attend_override", Vector3.INF) == Vector3.INF:
				continue
			var own: float = HOLD_S + float(c.morph.curiosity) * 3.0 \
					+ float(c.morph.startle) * 1.8
			if attention_clock > own:
				c.attend_override = Vector3.INF
				_released += 1
	if attention_clock > HOLD_S + 5.6:
		if hero != null and is_instance_valid(hero):
			hero.attention_override = Vector3.INF
		attending = Vector3.INF
		state = State.CURIOUS
		state_clock = 0.0
		attention_released.emit()


## Facts for the contract.
func census() -> Dictionary:
	var held := 0
	if margin != null:
		for p in margin.palps:
			if p.get("attend_override", Vector3.INF) != Vector3.INF:
				held += 1
	if critters != null:
		for c in critters.critters:
			if c.get("attend_override", Vector3.INF) != Vector3.INF:
				held += 1
	var colony_rows := {}
	var colony_ids := moss_colonies.keys()
	colony_ids.sort()
	for source_id in colony_ids:
		colony_rows[str(source_id)] = moss_colonies[source_id].census()
	return {"state": state_name(), "attending": attending != Vector3.INF,
			"ready_to_seize": _since_last >= RESEIZE_GAP_S,
			"still_held": held, "released": _released,
			"attention_clock": snappedf(attention_clock, 0.01),
			"signals": signal_census(), "moss_colonies": colony_rows,
			"cellular_audio": cellular_audio.census() \
					if cellular_audio != null else {}}
