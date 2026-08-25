extends Node3D
## LC-6C: the modelled hero consumes the shared stage language without a
## second encounter clock, and a cross-sectional death leaves one bounded,
## visit-local sheath in the existing residue draw.

const HeroScript := preload("res://scripts/dream/entity/dream_hero_tentacle.gd")
const ResidueScript := preload("res://scripts/dream/dream_residue.gd")
const Lifecycle := preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var checks := 0
var failures := 0


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[LC6C] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var hero: DreamHeroTentacle = HeroScript.new()
	add_child(hero)
	hero.setup("lc6c_hero".hash(), Vector3.ZERO, Vector3.FORWARD)
	hero.grow = 1.0
	var residue: DreamResidue = ResidueScript.new()
	add_child(residue)
	residue.setup("lc6c_memory".hash())
	residue.set_process(false)
	hero.lifecycle_shed.connect(func(where: Vector3, normal: Vector3,
			generation: int, reproduction: int):
		residue.lay_memory(where, normal, generation, reproduction))
	await get_tree().process_frame

	var nodes_before := _node_count(hero)
	var meshes_before := hero.meshes.size()
	var materials_before := hero.materials.size()
	var state_expect := {
		hero.State.MEMBRANE_BULGE: Lifecycle.Stage.FOLDED,
		hero.State.EMERGING: Lifecycle.Stage.BUD,
		hero.State.ORIENTING: Lifecycle.Stage.JUVENILE,
		hero.State.SEEKING: Lifecycle.Stage.MATURE,
		hero.State.TOUCHING: Lifecycle.Stage.EXCHANGE,
		hero.State.WITHDRAW: Lifecycle.Stage.SENESCENT,
		hero.State.CROSS_SECTION_WITHDRAW: Lifecycle.Stage.SHED,
		hero.State.ABSENT: Lifecycle.Stage.STAIN,
	}
	var all_stages := true
	for state_v in state_expect:
		hero.state = int(state_v)
		all_stages = all_stages and hero.lifecycle_stage() == int(state_expect[state_v])
	_check("approved encounter states cover all eight shared stages", all_stages)

	hero.state = hero.State.TOUCHING
	hero.set_process(false)
	for mat in hero.materials:
		mat.set_shader_parameter("lifecycle_stage", float(hero.lifecycle_stage()))
	var exchange_on_wire := true
	for mat in hero.materials:
		exchange_on_wire = exchange_on_wire and is_equal_approx(
				float(mat.get_shader_parameter("lifecycle_stage")),
				float(Lifecycle.Stage.EXCHANGE))
	_check("every existing hero surface receives the same stage", exchange_on_wire)
	_check("lifecycle posture never changes anatomy scale",
			Lifecycle.anatomy_scale(Lifecycle.Stage.FOLDED) == 1.0
			and Lifecycle.anatomy_scale(Lifecycle.Stage.SHED) == 1.0)

	# MBIO-4: the event begins only when the existing addressed secretion is
	# emitted, then one normalized clock names every visible phase.
	var margin := DreamMarginController.new()
	var director := DreamEcologyDirector.new()
	add_child(margin)
	margin.set_process(false)
	margin.set_physics_process(false)
	add_child(director)
	director.setup(6404)
	margin.director = director
	hero.margin = margin
	var emitted_before := int(director.signal_census().emitted)
	hero._emit_contact_signal(Vector3(0.0, 0.5, 0.0))
	_check("addressed secretion starts exactly one bounded membrane event",
			hero.secretion_events == 1 and hero.secretion_stage() == "bleb"
			and int(director.signal_census().emitted) == emitted_before + 1)
	var secretion_order: Array[String] = []
	for phase in [0.10, 0.32, 0.64, 0.90]:
		hero.secretion_phase = phase
		secretion_order.append(hero.secretion_stage())
	_check("bleb, neck, release and uptake share one ordered clock",
			secretion_order == ["bleb", "neck", "release", "uptake"])
	hero.secretion_phase = 0.64
	for mat in hero.materials:
		mat.set_shader_parameter("secretion_phase", hero.secretion_phase)
	var secretion_on_wire := true
	for mat in hero.materials:
		secretion_on_wire = secretion_on_wire and is_equal_approx(
				float(mat.get_shader_parameter("secretion_phase")), 0.64)
	_check("every existing hero surface receives the same secretion phase",
			secretion_on_wire)

	hero._exchanged_this_life = true
	hero._complete_lifecycle()
	var first := residue.census()
	_check("addressed cross-morph exchange selects pansexual recruitment",
			hero.lifecycle_reproduction == Lifecycle.Reproduction.PANSEXUAL)
	_check("death is counted before a successor and lays one memory",
			hero.lifecycle_deaths == 1 and hero.lifecycle_births == 0
			and hero.lifecycle_stains == 1 and int(first.memories) == 1)
	residue._process(10000.0)
	_check("the empty sheath survives time for the current visit",
			int(residue.census().memories) == 1)
	hero._complete_lifecycle()
	_check("repeat shedding at one root coalesces into one bounded sheath",
			int(residue.census().memories) == 1)

	hero.state = hero.State.RETURNING
	hero.state_clock = 2.0
	hero.slice_close = 0.01
	hero._behave(0.1)
	_check("a permitted return recruits one same-function generation",
			hero.lifecycle_births == 1 and hero.lifecycle_generation == 1)
	hero._exchanged_this_life = false
	hero._complete_lifecycle()
	_check("without exchange the next local section is honestly quiescent",
			hero.lifecycle_reproduction == Lifecycle.Reproduction.QUIESCENT)
	_check("the lifecycle adds no node, mesh, collision, light or save owner",
			_node_count(hero) == nodes_before and hero.meshes.size() == meshes_before
			and hero.materials.size() == materials_before
			and _descendants_of_type(hero, CollisionObject3D) == 0
			and _descendants_of_type(hero, Light3D) == 0
			and not RealityState.persistence_enabled)
	_finish()


func _node_count(root: Node) -> int:
	var total := 1
	for child in root.get_children():
		total += _node_count(child)
	return total


func _descendants_of_type(root: Node, type) -> int:
	var total := 0
	for child in root.get_children():
		if is_instance_of(child, type):
			total += 1
		total += _descendants_of_type(child, type)
	return total


func _finish() -> void:
	print("[LC6C] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
