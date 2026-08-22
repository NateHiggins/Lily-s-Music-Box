class_name DreamFieldController
extends Node3D
## THE DREAM FIELD (DREAM_FIELD_DIRECTION §1, §16, §17).
##
## The antagonist's infinite body failing to fit into three dimensions. Its
## real state is not a mesh: it is a procedural field with a hidden fourth
## coordinate, `dream_w`. This node owns that state, keeps a handful of
## lobes alive near the player, ADVANCES `dream_w` rather than translating
## anything, and hands the one `DreamFieldState` to everything that draws.
##
## Because the slice coordinate moves and the lobes do not, the visible
## anatomy changes topology in place: a lobe swells out of nothing, splits,
## becomes a ring, collapses to islands and is gone — never travelling. A
## thing that appears on both sides of a wall at once is not moving through
## the wall; it is a single body whose cross-section happens to meet our
## space twice.
##
## It is coupled to the tentacle (§14) and to the living field: the
## organism's own body tells the controller where it is near our slice, so
## the field's lobes sit where the creature actually is.

signal lobe_surfaced(index: int, centre: Vector3, radius: float)
signal lobe_withdrew(index: int, centre: Vector3)

const LobeScript := preload("res://scripts/dream/field/dream_field_state.gd")
## How fast the slice coordinate drifts, in metres of w per second. Slow:
## a lobe's whole life should take several seconds.
const W_DRIFT := 0.115
## Lobes are re-seeded around the player at this cadence.
const RESEED_S := 3.0
const MAX_LOBES := 8

var state: DreamFieldState
var enabled := true
var player: Node3D = null
## Where the organism actually is, so the field's anatomy sits on it rather
## than floating in the room. Set by ApartmentEncroachment.
var living_field = null
var storey_rect := Vector4(-13.9, -9.9, 13.9, 9.9)
var floor_y := 0.0

var _rng := RandomNumberGenerator.new()
var _reseed_clock := 0.0
var _present := []
var _clock := 0.0
var lobes_surfaced := 0


func setup(seed_v: int, rect: Vector4, y: float) -> void:
	name = "DreamFieldController"
	enabled = OS.get_environment("DREAM_FIELD") != "0"
	_rng.seed = seed_v
	state = LobeScript.new()
	state.seed = float(seed_v % 997) * 0.01
	storey_rect = rect
	floor_y = y
	_present.resize(MAX_LOBES)
	for i in MAX_LOBES:
		_present[i] = false
	_seed_lobes(Vector3((rect.x + rect.z) * 0.5, y + 1.4, (rect.y + rect.w) * 0.5))


## Lobes are placed ON the organism where there is one, and otherwise in the
## volume around the player — the body is near our slice where its own
## growth is, not at random.
func _seed_lobes(around: Vector3) -> void:
	state.clear_lobes()
	var anchors: Array = []
	if living_field != null and living_field.nodes.size() > 0:
		for i in mini(living_field.nodes.size(), 3):
			anchors.append(living_field.nodes[i])
	while anchors.size() < 3:
		anchors.append(around + Vector3(_rng.randf_range(-2.2, 2.2),
				_rng.randf_range(-0.6, 1.4), _rng.randf_range(-2.2, 2.2)))
	var kinds := [DreamFieldState.KIND_MASS, DreamFieldState.KIND_TUBE,
			DreamFieldState.KIND_TOROID, DreamFieldState.KIND_FOLD]
	for i in MAX_LOBES:
		var a: Vector3 = anchors[i % anchors.size()]
		var centre := a + Vector3(_rng.randf_range(-1.1, 1.1),
				_rng.randf_range(-0.5, 0.9), _rng.randf_range(-1.1, 1.1))
		var radius := _rng.randf_range(0.35, 1.25)
		# The w offsets are SPREAD, so at any moment some lobes are fully in
		# our space, some are just surfacing and most are elsewhere.
		var w_offset := state.dream_w + _rng.randf_range(-2.2, 2.6)
		state.add_lobe(centre, radius, kinds[_rng.randi() % kinds.size()], w_offset,
				_rng.randf_range(0.55, 1.0), _rng.randf_range(0.0, 40.0))


func _physics_process(delta: float) -> void:
	if not enabled or state == null:
		return
	_clock += delta
	# ADVANCE THE SLICE. Nothing translates; the cross-section changes.
	state.dream_w += W_DRIFT * delta
	# The lobes that just entered or left our space, so the rest of the
	# system can incarnate matter and start residue on the way in, and
	# begin withdrawal on the way out.
	for i in state.lobes.size():
		var here := state.lobe_present(i)
		if here != _present[i]:
			_present[i] = here
			var l: Dictionary = state.lobes[i]
			if here:
				lobes_surfaced += 1
				lobe_surfaced.emit(i, l.centre, float(l.radius))
			else:
				lobe_withdrew.emit(i, l.centre)
	_reseed_clock += delta
	if _reseed_clock >= RESEED_S:
		_reseed_clock = 0.0
		var around := global_position
		if player != null and is_instance_valid(player):
			around = (player as Node3D).global_position
		# Re-seed only the lobes that are currently nowhere near our slice,
		# so nothing ever pops out of or into existence on screen.
		_reseed_absent(around)


func _reseed_absent(around: Vector3) -> void:
	var kinds := [DreamFieldState.KIND_MASS, DreamFieldState.KIND_TUBE,
			DreamFieldState.KIND_TOROID, DreamFieldState.KIND_FOLD]
	for i in state.lobes.size():
		if state.lobe_present(i):
			continue
		var l: Dictionary = state.lobes[i]
		var anchor := around
		if living_field != null and living_field.nodes.size() > 0:
			anchor = living_field.nodes[_rng.randi() % living_field.nodes.size()]
		l.centre = anchor + Vector3(_rng.randf_range(-1.6, 1.6),
				_rng.randf_range(-0.6, 1.2), _rng.randf_range(-1.6, 1.6))
		l.radius = _rng.randf_range(0.35, 1.25)
		l.kind = kinds[_rng.randi() % kinds.size()]
		# Put it back BEHIND the current slice so it will surface again.
		l.w_offset = state.dream_w + _rng.randf_range(1.6, 3.4)
		l.intensity = _rng.randf_range(0.55, 1.0)
		l.seed = _rng.randf_range(0.0, 40.0)
		_present[i] = false


## The tentacle and the field share clocks (§14): the controller is told,
## rather than inventing its own, so the whole organism beats together.
func couple(pulse: float, breath: float, attention: float, contact: float,
		instability: float) -> void:
	if state == null:
		return
	state.pulse_phase = pulse
	state.breath_phase = breath
	state.attention = attention
	state.contact_activity = contact
	state.phase_instability = instability


func apply_to(m: ShaderMaterial) -> void:
	if state != null:
		state.apply(m)


## Facts for the contract.
func census() -> Dictionary:
	var present := 0
	var radii := 0.0
	for i in state.lobes.size():
		if state.lobe_present(i):
			present += 1
			radii += state.slice_radius(float(state.lobes[i].radius),
					float(state.lobes[i].w_offset))
	return {"lobes": state.lobes.size(), "present": present, "dream_w": state.dream_w,
			"surfaced": lobes_surfaced, "slice_radius_total": radii}
