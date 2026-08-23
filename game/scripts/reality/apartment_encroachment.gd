class_name ApartmentEncroachment
extends Node
## THE DREAM REACHING INTO A CASE'S FLAT (design/DREAM_ENCROACHMENT_BRIEF.md,
## decision 3). Presentation only: it owns no case state, no save key, no
## collision, no light and no new draw. It reads each case's state from
## RealityState and sets one `intensity` on the case unit's wall-finish
## surfaces and beachhead prop, so the flat feels the encroachment before the
## player ever sleeps and settles when the case resolves.
##
## What it touches, per case with shipped plates:
##   - every baked wall-finish quad on the unit's storey whose footprint meets
##     the unit rect takes `wall_encroachment.gdshader` carrying the SAME
##     finish maps plus the case's first three substance plates; the shader
##     clips the creep to the unit rect, so a perimeter quad shared with the
##     neighbour only changes inside this flat;
##   - the unit's authored anomaly prop (the case's beachhead) takes the first
##     plate on its body once intensity passes BEACHHEAD_AT.
##
## Intensity comes from the case's stage, lifted by manifestation_intensity
## and held to a residue once resolved. ENCROACH=0 disables the pass;
## ENCROACH_FORCE="mina:0.8,peter:0.3" pins intensities for frames and tests.

## Since 2026-08-22 the encroachment is a STATE of the one layered surface
## (orison_surface_cutout with the `encroachment` group), built through
## SurfacePass.surface_for with the finish class's own recipe; the former
## wall_encroachment.gdshader is kept as the reference of the grammar.
const SurfacePassScript := preload("res://scripts/building/surface_pass.gd")
const LivingFieldScript := preload("res://scripts/reality/living_field.gd")
const DreamTentacleScript := preload("res://scripts/dream/entity/dream_tentacle_controller.gd")
const DreamTentacleDebugScript := preload("res://scripts/dream/entity/dream_tentacle_debug.gd")
const DreamFieldScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const DreamTendrilScript := preload("res://scripts/dream/field/dream_surface_tendrils.gd")
const DreamHeroScript := preload("res://scripts/dream/entity/dream_hero_tentacle.gd")
const DreamMarginScript := preload("res://scripts/dream/margin/dream_margin_controller.gd")
const DreamResidueScript := preload("res://scripts/dream/dream_residue.gd")
const DreamCritterScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const DreamDirectorScript := preload("res://scripts/dream/dream_ecology_director.gd")
## §31 — what keeps three independent systems from producing incoherent noise.
var ecology: DreamEcologyDirector = null
## Level 3: the animals that live on what the Dream has reached.
var critters: DreamCritterController = null
## What the creature leaves on everything it touches (saliva direction).
var residue: DreamResidue = null
const DreamPalpRendererScript := preload("res://scripts/dream/margin/dream_palp_renderer.gd")
## Level 2 of the ecology: the field's distributed sensory edge.
var margin: DreamMarginController = null
var palp_renderer: DreamPalpRenderer = null
## The modelled Blender creature, once the owner's ruling made it the hero.
var hero: DreamHeroTentacle = null
## DF-13: many small limbs where the field's cross-section meets matter.
var surface_tendrils: DreamSurfaceTendrils = null
## DF-1: the antagonist's body failing to fit into three dimensions. The
## living field is its growth; this is its cross-section.
var dream_field: DreamFieldController = null
var _tentacle_debug: CanvasLayer = null
const PROFILES_PATH := "res://data/dream_profiles.json"
const PLATE_ROOT := "res://assets/dream/incarnations"
const BEACHHEAD_AT := 0.3
const RESIDUE := 0.2
## Case -> unit and incarnation. The unit is where the resident lives; the
## incarnation names the plate bundle the dream already ships for the case.
## `grammar` is the shape the creep takes in the one surface's encroachment
## group (design/SIX_INCARNATIONS.md §a per case); the tints are the case's
## substance and its metal.
const CASES := {
	"mina_caption_crisis": {"unit": "2A", "incarnation": "mina", "profile": "mina_release_print",
			"grammar": 0, "ink": Color(0.20, 0.19, 0.30), "gilt": Color(0.86, 0.66, 0.30)},
	"peter_form_corridor": {"unit": "4A", "incarnation": "peter", "profile": "peter_release_print",
			"grammar": 1, "ink": Color(0.14, 0.13, 0.24), "gilt": Color(0.78, 0.58, 0.28)},
	"juno_feedback_tetris": {"unit": "2C", "incarnation": "juno", "profile": "juno_release_print",
			"grammar": 2, "ink": Color(0.16, 0.13, 0.11), "gilt": Color(0.62, 0.56, 0.30)},
	"mae_contradictory_antiques": {"unit": "6C", "incarnation": "mae", "profile": "mae_release_print",
			"grammar": 3, "ink": Color(0.10, 0.09, 0.09), "gilt": Color(0.80, 0.60, 0.30)},
	"cal_memory_radio": {"unit": "5B", "incarnation": "cal", "profile": "cal_release_print",
			"grammar": 4, "ink": Color(0.30, 0.18, 0.08), "gilt": Color(0.90, 0.62, 0.22)},
	"omar_unrepairable": {"unit": "3B", "incarnation": "omar", "profile": "omar_release_print",
			"grammar": 5, "ink": Color(0.16, 0.17, 0.19), "gilt": Color(0.72, 0.66, 0.52)},
}
const STAGE_INTENSITY := {
	"unseen": 0.0, "active": 0.35, "recognized": 0.6, "integration_ready": 0.85,
	"stabilized": 0.45, "resolved": RESIDUE, "reopened": 0.9,
}

var enabled := true
## case_id -> Array of {"mesh": MeshInstance3D, "surface": int, "material": ShaderMaterial}
var surfaces: Dictionary = {}
## case_id -> {"node": Node, "originals": {MeshInstance3D: Material}}
var beachheads: Dictionary = {}
var intensities: Dictionary = {}
## case_id -> {"rect": Vector4, "floor_y": float, "floor_node": Node}
var units: Dictionary = {}
## case_id -> Array of {"mesh": MeshInstance3D, "material": ShaderMaterial, "shared": Material}
## The props inside the flat that wear the layered surface, each given its
## own copy with the case's states on it (owner ruling 2026-08-21: "it
## should reach the props").
var prop_rows: Dictionary = {}
var props_reached := 0
## floor_id -> LivingField (design/LIVING_FIELD_BRIEF.md §5): ONE organism
## per storey with a source per case on it, sampled by every layered
## surface on the storey. LIVING=0 disables. case_id -> source index.
var fields: Dictionary = {}
var field_source: Dictionary = {}
## floor_id -> Array of OmniLight3D: the lights the organism throws (§5c).
var field_lights: Dictionary = {}
## Every surface material on a storey the field was bound to (for refresh).
var storey_materials: Dictionary = {}
const STOREY_RECT := Vector4(-13.9, -9.9, 13.9, 9.9)
const PALETTE_INDEX := {"mina_caption_crisis": 0, "peter_form_corridor": 1,
		"juno_feedback_tetris": 2, "mae_contradictory_antiques": 3,
		"cal_memory_radio": 4, "omar_unrepairable": 5}
const LIGHT_RANGE_M := 2.6
const LIGHT_ENERGY := 0.9
## The dream tentacles (design/DREAM_TENTACLE_BRIEF.md): up to this many
## per storey, out of the organism where its body is strongest, spaced.
const TENTACLES_PER_STOREY := 2
const TENTACLE_COOLDOWN_S := 8.0
const TENTACLE_MIN_BODY := 0.45
## floor_id -> Array of DreamTentacle
var tentacles: Dictionary = {}
var _tentacle_cooldown: Dictionary = {}
var _tentacle_candidates: Dictionary = {}
var _props_ready := false
var tentacles_spawned := 0
var _forced: Dictionary = {}
var _plates: Dictionary = {}
var _substance_keys: Dictionary = {}


func build(layout: Dictionary, floor_nodes: Dictionary, witnesses: Node = null) -> int:
	name = "ApartmentEncroachment"
	enabled = OS.get_environment("ENCROACH") != "0"
	_parse_forced(OS.get_environment("ENCROACH_FORCE"))
	if not enabled:
		print("[ENCROACH] disabled by ENCROACH=0")
		return 0
	_read_substance_keys()
	var total := 0
	for case_id in CASES:
		var spec: Dictionary = CASES[case_id]
		var unit := str(spec.unit)
		var inc := str(spec.incarnation)
		if not _substance_keys.has(inc):
			continue
		var rooms := _unit_rooms(layout, unit)
		if rooms.is_empty():
			continue
		var floor_id := str(rooms[0].floor)
		var floor_node: Node = floor_nodes.get(floor_id)
		if floor_node == null:
			continue
		var rect := _union_rect(rooms)
		var floor_y := float(rooms[0].z)
		var plates := _plates_for(inc)
		if plates.is_empty():
			continue
		units[case_id] = {"rect": rect, "floor_y": floor_y, "floor_node": floor_node}
		var rows: Array = []
		for node in floor_node.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not mi.name.contains("_finish_"):
				continue
			var aabb := _world_aabb(mi)
			if aabb.size == Vector3.ZERO:
				continue
			if not _aabb_meets_rect(aabb, rect, 0.30):
				continue
			for s in mi.mesh.get_surface_count():
				var original := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if original == null or original.albedo_texture == null:
					continue
				var material := _material_for(original, plates, rect, floor_y)
				material.set_shader_parameter("grammar", int(spec.get("grammar", 0)))
				var ink: Color = spec.get("ink", Color(0.20, 0.19, 0.30))
				var gilt: Color = spec.get("gilt", Color(0.86, 0.66, 0.30))
				material.set_shader_parameter("ink_tint", Vector3(ink.r, ink.g, ink.b))
				material.set_shader_parameter("gilt_tint", Vector3(gilt.r, gilt.g, gilt.b))
				if OS.get_environment("ENCROACH_DEBUG_VIEW") == "1":
					material.set_shader_parameter("debug_view", 5)
				mi.set_surface_override_material(s, material)
				rows.append({"mesh": mi, "surface": s, "material": material})
		surfaces[case_id] = rows
		total += rows.size()
		var beachhead := _find_beachhead(witnesses, floor_node, case_id)
		if beachhead != null:
			beachheads[case_id] = {"node": beachhead, "originals": {}}
		if OS.get_environment("LIVING") != "0":
			var field = fields.get(floor_id)
			if field == null:
				field = LivingFieldScript.new()
				field.configure(STOREY_RECT, floor_y, floor_id.hash())
				fields[floor_id] = field
				_bind_storey(floor_node, floor_id, field)
			var source := Vector3((rect.x + rect.z) * 0.5, floor_y + 1.0, (rect.y + rect.w) * 0.5)
			if beachhead != null and beachhead is Node3D:
				source = (beachhead as Node3D).global_position
			field_source[case_id] = field.add_source(source, int(PALETTE_INDEX.get(case_id, 0)))
			for row in rows:
				_bind_living(row.material as ShaderMaterial, floor_id)
	# DF-1 (design/DREAM_FIELD_DIRECTION.md): one field controller for the
	# building, seeded on the storey the cases live on, and told where the
	# organism actually is so its lobes sit on the body rather than in the
	# air.
	if OS.get_environment("DREAM_FIELD") != "0":
		dream_field = DreamFieldScript.new()
		add_child(dream_field)
		var seed_floor := ""
		for case_id in units:
			seed_floor = _floor_of(case_id)
			break
		# Seed the field on a case's own flat, not the storey's centre: the
		# body is where the cases are.
		var seed_at := Vector3.INF
		if units.size() > 0:
			var u0: Dictionary = units.values()[0]
			var ur: Vector4 = u0.rect
			seed_at = Vector3((ur.x + ur.z) * 0.5, float(u0.floor_y) + 1.3,
					(ur.y + ur.w) * 0.5)
		dream_field.setup("dreamfield".hash(), STOREY_RECT,
				float(units.values()[0].floor_y) if units.size() > 0 else 0.0, seed_at)
		if fields.size() > 0:
			dream_field.living_field = fields.values()[0]
		var root_node := get_parent()
		if root_node != null and ("player" in root_node):
			dream_field.player = root_node.player
		# DF-13: the shelved procedural limb, at a tenth the size and a
		# hundred at a time — one body meeting our space in many places.
		if OS.get_environment("DREAM_TENDRILS") != "0":
			surface_tendrils = DreamTendrilScript.new()
			add_child(surface_tendrils)
			surface_tendrils.setup(dream_field, "tendrils".hash())
		# THE RESIDUE. Anything that touches a surface feeds this.
		residue = DreamResidueScript.new()
		add_child(residue)
		residue.setup("residue".hash())
		residue.field = dream_field
		# THE MARGIN (ecology architecture §4): the Dream field does not end
		# in a shader fade, it ends in appendages.
		if OS.get_environment("DREAM_MARGIN") != "0":
			margin = DreamMarginScript.new()
			add_child(margin)
			margin.setup(dream_field, "margin".hash())
			palp_renderer = DreamPalpRendererScript.new()
			add_child(palp_renderer)
			palp_renderer.setup(margin)
		# THE CRITTERS (§14). They use the margin as habitat, so they come
		# after it.
		if OS.get_environment("DREAM_CRITTERS") != "0":
			critters = DreamCritterScript.new()
			add_child(critters)
			critters.setup(dream_field, "critters".hash())
			critters.margin = margin
			critters.residue = residue
		# THE MODELLED HERO. Until now the Blender creature was an asset
		# nothing instantiated: one reference in the whole project, in the
		# test that probes it. It stands in the case flat, wearing the shared
		# Dream material stack and reading its anatomy from its own masks.
		if OS.get_environment("DREAM_HERO") == "1" and seed_at != Vector3.INF:
			hero = DreamHeroScript.new()
			add_child(hero)
			# FIND A REAL WALL. A hand-picked offset put the root inside the
			# plaster with its membrane buried, and would land somewhere
			# different in every flat. Cast outward from the case's own centre
			# and take the first surface: the creature comes out of whatever
			# the room actually has.
			var here := seed_at + Vector3(0.0, -0.35, 0.0)
			var space: PhysicsDirectSpaceState3D = get_viewport().find_world_3d().direct_space_state
			var found := false
			for step in 12:
				var ang := float(step) / 12.0 * TAU
				var dir := Vector3(cos(ang), 0.0, sin(ang))
				var q := PhysicsRayQueryParameters3D.create(here, here + dir * 6.0)
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					continue
				var nrm: Vector3 = (hit.normal as Vector3).normalized()
				if absf(nrm.y) > 0.5:
					continue
				hero.setup("hero".hash(), (hit.position as Vector3) + nrm * 0.04, nrm)
				found = true
				break
			if not found:
				hero.setup("hero".hash(), here, Vector3(-1.0, 0.10, 0.0))
			hero.field = dream_field
			var rn := get_parent()
			if rn != null and ("player" in rn):
				hero.watch = rn.player
			# §28: the hero gets the richest transformation.
			if residue != null:
				hero.touched.connect(func(where: Vector3, nrm: Vector3):
					residue.lay(where, nrm, 0.16, 1.0, 3.6))
			# §11 — the hero joins the margin's society as a high-priority
			# member, rather than being a special effect dropped into it.
			if margin != null:
				margin.hero = hero
			if critters != null:
				critters.hero = hero
				hero.critters = critters
		# §31 — the director sees all three levels, so it comes last.
		ecology = DreamDirectorScript.new()
		add_child(ecology)
		ecology.setup("ecology".hash())
		ecology.margin = margin
		ecology.critters = critters
		ecology.hero = hero
		ecology.field = dream_field
		# §13 — the player changing the world is what the ecology notices.
		# The director connects itself once the player exists; doing it here
		# ran before the player was built and quietly connected nothing.
		if margin != null:
			margin.director = ecology
		if critters != null:
			critters.director = ecology
	if RealityState.has_signal("state_changed") and not RealityState.state_changed.is_connected(refresh):
		RealityState.state_changed.connect(refresh)
	refresh()
	print("[ENCROACH] %d finish surfaces across %d case flats, %d beachheads"
			% [total, surfaces.size(), beachheads.size()])
	return total


## Re-read every case's state and push intensities. Cheap; called on commit.
## The organism's clock. Each active case's field steps at its own rate and
## its texture is shared by every material bound to it; only the pulse
## phase is pushed per tick.
func _physics_process(delta: float) -> void:
	for case_id in field_source:
		var floor_id := _floor_of(case_id)
		if fields.has(floor_id):
			fields[floor_id].set_source_intensity(int(field_source[case_id]),
					float(intensities.get(case_id, 0.0)))
	# Only the player's storey ticks (LIVING_ALL=1 ticks every storey): the
	# organism elsewhere waits, which is what a field costing a few
	# milliseconds a frame has to do in a building with seven storeys.
	var active := _player_floor()
	var tick_all := OS.get_environment("LIVING_ALL") == "1"
	for floor_id in fields:
		var field = fields[floor_id]
		if not field.alive() and field.steps > 0:
			continue
		if not tick_all and not active.is_empty() and str(floor_id) != active:
			continue
		if field.tick(delta):
			var phase: float = field.pulse_phase()
			for m in storey_materials.get(floor_id, []):
				if is_instance_valid(m):
					(m as ShaderMaterial).set_shader_parameter("living_pulse", phase)
			_place_lights(floor_id, field)
			_tend_tentacles(floor_id, field, delta)
	# §14: the tentacle does not drive the field; they share clocks, so the
	# whole organism beats together.
	if dream_field != null:
		var pulse := 0.0
		var breath := 0.0
		var attn := 0.0
		var contact := 0.0
		var instab := 0.0
		for fid in tentacles:
			for t in tentacles[fid]:
				if is_instance_valid(t):
					pulse = t.pulse_phase
					breath = t.breath_phase
					attn = maxf(attn, float(t.behavior.interest))
					contact = maxf(contact, float(t.grip))
					instab = maxf(instab, 1.0 if t._slice_left > 0.0 else 0.0)
		dream_field.couple(pulse, breath, attn, contact, instab)


## The storey the player stands on, by the floors the cases told us about.
func _player_floor() -> String:
	var root := get_parent()
	if root == null or not ("player" in root) or root.player == null:
		return ""
	var y: float = (root.player as Node3D).global_position.y
	for case_id in units:
		var unit: Dictionary = units[case_id]
		var fy := float(unit.floor_y)
		if y >= fy - 0.3 and y < fy + 3.4:
			var floor_node: Node = unit.floor_node
			return floor_node.name if floor_node != null else ""
	return ""


func _floor_of(case_id: String) -> String:
	var unit: Dictionary = units.get(case_id, {})
	var floor_node: Node = unit.get("floor_node")
	return floor_node.name if floor_node != null else ""


## §5c: up to three OmniLights per storey at the organism's strongest nodes,
## in the source's ink, energy from the body. No shadows; range bounded.
func _place_lights(floor_id: String, field) -> void:
	var lights: Array = field_lights.get(floor_id, [])
	while lights.size() < 3:
		var light := OmniLight3D.new()
		light.name = "LivingLight%d" % lights.size()
		light.omni_range = LIGHT_RANGE_M
		light.shadow_enabled = false
		light.light_energy = 0.0
		light.visible = false
		add_child(light)
		lights.append(light)
	field_lights[floor_id] = lights
	for i in 3:
		var light: OmniLight3D = lights[i]
		if i < field.nodes.size():
			var ink := _palette()[clampi(int(field.node_source[i]), 0, 5)]
			light.global_position = field.nodes[i]
			light.light_color = Color(ink.x * 1.6, ink.y * 1.6, ink.z * 1.8)
			light.light_energy = LIGHT_ENERGY * float(field.node_strength[i])
			light.visible = true
		else:
			light.visible = false


func _palette() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.resize(6)
	for case_id in PALETTE_INDEX:
		var ink: Color = CASES[case_id].get("ink", Color(0.2, 0.19, 0.3))
		out[int(PALETTE_INDEX[case_id])] = Vector3(ink.r, ink.g, ink.b)
	return out


## §5a: every layered material on the storey binds the storey's field —
## walls, finishes, floors, trims (surface overrides) and the props
## (material overrides; shared MatLib materials get a per-storey copy).
func _bind_storey(floor_node: Node, floor_id: String, field) -> void:
	var bound: Array = storey_materials.get(floor_id, [])
	for node in floor_node.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var over := mi.material_override as ShaderMaterial
		if over != null and over.shader != null \
				and over.shader.resource_path.get_file().begins_with("orison_surface"):
			if not over.has_meta("living_storey"):
				over = over.duplicate() as ShaderMaterial
				over.set_meta("living_storey", floor_id)
				mi.material_override = over
			_bind_living(over, floor_id)
			bound.append(over)
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null or m.shader == null \
					or not m.shader.resource_path.get_file().begins_with("orison_surface"):
				continue
			if m.has_meta("living_storey") and str(m.get_meta("living_storey")) != floor_id:
				m = m.duplicate() as ShaderMaterial
				mi.set_surface_override_material(s, m)
			m.set_meta("living_storey", floor_id)
			_bind_living(m, floor_id)
			bound.append(m)
	storey_materials[floor_id] = bound
	print("[ENCROACH] living field on %s binds %d materials" % [floor_id, bound.size()])


func _bind_living(m: ShaderMaterial, floor_id: String) -> void:
	if m == null or not fields.has(floor_id):
		return
	var field = fields[floor_id]
	m.set_shader_parameter("has_living", true)
	m.set_shader_parameter("living_tex", field.texture())
	m.set_shader_parameter("living_origin", field.origin)
	m.set_shader_parameter("living_size", field.size_m)
	m.set_shader_parameter("living_palette", _palette())
	m.set_shader_parameter("has_living_palette", true)
	m.set_shader_parameter("living_amount", 1.0)
	if not storey_materials.has(floor_id):
		storey_materials[floor_id] = []
	if not (storey_materials[floor_id] as Array).has(m):
		(storey_materials[floor_id] as Array).append(m)


func refresh() -> void:
	for case_id in surfaces:
		var value := intensity_for(case_id)
		intensities[case_id] = value
		for row in surfaces[case_id]:
			(row.material as ShaderMaterial).set_shader_parameter("intensity", value)
		_apply_beachhead(case_id, value)
		_apply_prop_states(case_id, value)


## THE STATES REACH THE PROPS. Every script-built prop inside the flat whose
## draw wears the layered surface (SurfacePass, after its deferred sweep)
## takes its own copy of that material with the case's states on it:
## corruption (the dream's flesh) and gilding rising with the intensity,
## grime and moisture under them. Idempotent; called after the prop sweep
## and again whenever the governor's lever re-applies the tier. Props whose
## draw is not layered (colour-only standards, glass) are left alone.
func reach_props(root: Node) -> int:
	if not enabled:
		return 0
	props_reached = 0
	for case_id in units:
		var unit: Dictionary = units[case_id]
		var rect: Vector4 = unit.rect
		var floor_y: float = unit.floor_y
		var rows: Array = []
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not (mi.material_override is ShaderMaterial):
				continue
			var shader_path := ""
			if (mi.material_override as ShaderMaterial).shader != null:
				shader_path = (mi.material_override as ShaderMaterial).shader.resource_path
			if not shader_path.get_file().begins_with("orison_surface"):
				continue
			if (mi.material_override as ShaderMaterial).has_meta("encroachment_case"):
				if str(mi.material_override.get_meta("encroachment_case")) == case_id:
					rows.append({"mesh": mi, "material": mi.material_override,
							"shared": mi.material_override.get_meta("encroachment_shared")})
				continue
			var aabb := _world_aabb(mi)
			if aabb.size == Vector3.ZERO:
				continue
			if aabb.position.y > floor_y + 3.6 or aabb.end.y < floor_y - 0.2:
				continue
			if not _aabb_meets_rect(aabb, rect, 0.0):
				continue
			var shared: Material = mi.material_override
			var own := (shared as ShaderMaterial).duplicate() as ShaderMaterial
			own.set_meta("encroachment_case", case_id)
			own.set_meta("encroachment_shared", shared)
			own.set_shader_parameter("mask_proc_scale", 2.4)
			own.set_shader_parameter("mask2_threshold", Vector4(0.55, 0.58, 0.46, 0.55))
			own.set_shader_parameter("mask2_softness", Vector4(0.15, 0.14, 0.30, 0.15))
			own.set_shader_parameter("mask_threshold", Vector4(0.72, 0.50, 0.60, 0.50))
			own.set_shader_parameter("mask_softness", Vector4(0.08, 0.30, 0.22, 0.25))
			# A batched draw spans the storey: the states show only inside the flat.
			own.set_shader_parameter("state_rect", rect)
			own.set_shader_parameter("state_y", Vector2(floor_y - 0.2, floor_y + 3.6))
			_bind_living(own, _floor_of(case_id))
			mi.material_override = own
			rows.append({"mesh": mi, "material": own, "shared": shared})
			if OS.get_environment("ENCROACH_DEBUG") == "1" and rows.size() <= 12:
				print("[ENCROACH]   %s reaches %s (%s)" % [case_id, mi.get_path(), aabb])
		prop_rows[case_id] = rows
		props_reached += rows.size()
		if OS.get_environment("ENCROACH_DEBUG") == "1":
			print("[ENCROACH]   %s: %d prop draws" % [case_id, rows.size()])
		_apply_prop_states(case_id, intensities.get(case_id, intensity_for(case_id)))
	print("[ENCROACH] %d prop draws reached across %d case flats" % [props_reached, prop_rows.size()])
	# The tentacles may come out now: the objects they explore exist.
	_tentacle_candidates.clear()
	_props_ready = true
	# §5a: the organism goes anywhere on the storey, so every layered prop on
	# the storey binds its field — not only those inside a flat.
	for floor_id in fields:
		var unit_floor: Node = null
		for case_id in units:
			if _floor_of(case_id) == floor_id:
				unit_floor = units[case_id].floor_node
				break
		if unit_floor != null:
			_bind_storey(unit_floor, floor_id, fields[floor_id])
	return props_reached


func _apply_prop_states(case_id: String, value: float) -> void:
	if not prop_rows.has(case_id):
		return
	var rise := smoothstep(0.5, 1.0, value)
	for row in prop_rows[case_id]:
		var m := row.material as ShaderMaterial
		if not is_instance_valid(row.mesh) or (row.mesh as MeshInstance3D).material_override != m:
			continue
		m.set_shader_parameter("mask_amount", Vector4(0.0, 0.35 * value, 0.25 * value, 0.0))
		m.set_shader_parameter("mask2_amount", Vector4(0.0, 0.5 * rise, 0.85 * value, 0.0))


## The rule, in one place: stage sets the floor, manifestation lifts it,
## resolution leaves a residue. ENCROACH_FORCE wins for frames and tests.
func intensity_for(case_id: String) -> float:
	if _forced.has(case_id):
		return float(_forced[case_id])
	var state: Dictionary = RealityState.case_state(case_id)
	if state.is_empty():
		return 0.0
	var stage := str(state.get("stage", "unseen"))
	var base := float(STAGE_INTENSITY.get(stage, 0.0))
	var manifest := clampf(float(state.get("manifestation_intensity", 0.0)), 0.0, 1.0)
	var value := maxf(base, base * 0.5 + manifest * 0.5) if base > 0.0 else manifest * 0.3
	if bool(state.get("resolved", false)) and not bool(state.get("recurrence_pending", false)):
		value = minf(value, RESIDUE)
	return clampf(value, 0.0, 1.0)


func _parse_forced(spec: String) -> void:
	_forced.clear()
	for entry in spec.split(",", false):
		var bits := entry.strip_edges().split(":")
		if bits.size() != 2:
			continue
		for case_id in CASES:
			if str(CASES[case_id].incarnation) == bits[0] or case_id == bits[0]:
				_forced[case_id] = clampf(bits[1].to_float(), 0.0, 1.0)


func _read_substance_keys() -> void:
	var f := FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var profiles: Dictionary = parsed.get("profiles", {})
	for profile_id in profiles:
		var presentation: Dictionary = (profiles[profile_id] as Dictionary).get("presentation", {})
		var inc := str(presentation.get("incarnation_id", ""))
		var keys: Array = presentation.get("substance_keys", [])
		if not inc.is_empty() and keys.size() >= 3 and bool(presentation.get("production_enabled", false)):
			_substance_keys[inc] = keys


func _plates_for(inc: String) -> Dictionary:
	if _plates.has(inc):
		return _plates[inc]
	var keys: Array = _substance_keys.get(inc, [])
	var out := {}
	var slots := ["a", "b", "c"]
	for i in 3:
		var key := str(keys[i])
		var albedo := load("%s/%s/%s/albedo.png" % [PLATE_ROOT, inc, key]) as Texture2D
		var normal := load("%s/%s/%s/normal.png" % [PLATE_ROOT, inc, key]) as Texture2D
		if albedo == null:
			return {}
		out[slots[i] + "_albedo"] = albedo
		if normal != null:
			out[slots[i] + "_normal"] = normal
	_plates[inc] = out
	return out


func _material_for(original: BaseMaterial3D, plates: Dictionary, rect: Vector4,
		floor_y: float) -> ShaderMaterial:
	# The finish class's shipping recipe (self-detail, the standing age) plus
	# the encroachment group: the same surface, one more state.
	var recipe: Dictionary = {}
	for cls in SurfacePassScript.CLASSES:
		if str(cls.key) == "finish":
			recipe = (cls.recipe as Dictionary).duplicate()
	recipe["has_encroachment"] = true
	recipe["unit_rect"] = rect
	recipe["floor_y"] = floor_y
	recipe["intensity"] = 0.0
	for key in plates:
		recipe["plate_" + key] = plates[key]
	return SurfacePassScript.surface_for(original, recipe)


## The case's authored anomaly prop: the beachhead takes the first plate.
func _find_beachhead(witnesses: Node, floor_node: Node, case_id: String) -> Node:
	var scopes: Array = []
	if witnesses != null:
		scopes.append(witnesses)
	scopes.append(floor_node)
	for scope in scopes:
		for node in (scope as Node).find_children("*", "", true, false):
			if not ("case_ids" in node):
				continue
			var ids: Variant = node.get("case_ids")
			if ids is Array and (ids as Array).has(case_id):
				return node
	return null


func _apply_beachhead(case_id: String, value: float) -> void:
	if not beachheads.has(case_id):
		return
	var entry: Dictionary = beachheads[case_id]
	var node: Node = entry.node
	if not is_instance_valid(node):
		return
	var originals: Dictionary = entry.originals
	var inc := str(CASES[case_id].incarnation)
	var plates := _plates_for(inc)
	var want := value >= BEACHHEAD_AT and plates.has("a_albedo")
	var body := _largest_mesh(node)
	if body == null:
		return
	if want and not originals.has(body):
		originals[body] = body.material_override
		var m := StandardMaterial3D.new()
		var base := body.material_override as BaseMaterial3D
		m.albedo_color = base.albedo_color if base != null else Color.WHITE
		m.albedo_texture = plates["a_albedo"]
		if plates.has("a_normal"):
			m.normal_enabled = true
			m.normal_texture = plates["a_normal"]
			m.normal_scale = 0.5
		m.roughness = 0.62
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(3.0, 3.0, 3.0)
		body.material_override = m
	elif not want and originals.has(body):
		body.material_override = originals[body]
		originals.erase(body)


static func _largest_mesh(node: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_volume := -1.0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var v := mi.mesh.get_aabb().get_volume()
		if v > best_volume:
			best_volume = v
			best = mi
	return best


static func _unit_rooms(layout: Dictionary, unit: String) -> Array:
	var out: Array = []
	for fl in layout.get("floors", []):
		for room in fl.get("rooms", []):
			if str(room.get("unit", "")) == unit:
				out.append({"rect": room.rect, "floor": fl.id, "z": fl.z})
	return out


## Union of the unit's room rects, in Godot world axes: x0, z0, x1, z1.
static func _union_rect(rooms: Array) -> Vector4:
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for room in rooms:
		var r: Array = room.rect
		x0 = minf(x0, float(r[0]))
		y0 = minf(y0, float(r[1]))
		x1 = maxf(x1, float(r[2]))
		y1 = maxf(y1, float(r[3]))
	# layout y is north; Godot z = -y.
	return Vector4(x0, -y1, x1, -y0)


static func _aabb_meets_rect(aabb: AABB, rect: Vector4, slack: float) -> bool:
	return aabb.end.x >= rect.x - slack and aabb.position.x <= rect.z + slack \
			and aabb.end.z >= rect.y - slack and aabb.position.z <= rect.w + slack


static func _world_aabb(mi: MeshInstance3D) -> AABB:
	var local := mi.get_aabb()
	var xf := mi.global_transform
	var result := AABB(xf * local.position, Vector3.ZERO)
	for i in 8:
		result = result.expand(xf * local.get_endpoint(i))
	return result


## --- the dream tentacles -----------------------------------------------------


func _tend_tentacles(floor_id: String, field, delta: float) -> void:
	if OS.get_environment("TENTACLE") == "0" or not _props_ready:
		return
	var live: Array = []
	for t in tentacles.get(floor_id, []):
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			live.append(t)
	tentacles[floor_id] = live
	var cool := float(_tentacle_cooldown.get(floor_id, 0.0)) - delta
	_tentacle_cooldown[floor_id] = cool
	if live.size() >= TENTACLES_PER_STOREY or cool > 0.0:
		return
	# Where: the strongest node of the organism not already claimed; forced
	# cases (TENTACLE_FORCE=1) come out at their source at once.
	var at := Vector3.ZERO
	var src := -1
	if OS.get_environment("TENTACLE_FORCE") == "1":
		for case_id in field_source:
			if _floor_of(case_id) != floor_id or not _forced.has(case_id):
				continue
			var s_index := int(field_source[case_id])
			var claimed := false
			for t in live:
				if int(t.source_index) == s_index:
					claimed = true
			if claimed:
				continue
			at = field.sources[s_index].position
			src = s_index
			break
	if src < 0:
		for i in field.nodes.size():
			if float(field.node_strength[i]) < TENTACLE_MIN_BODY:
				continue
			var p: Vector3 = field.nodes[i]
			var near := false
			for t in live:
				if (t.anchor as Vector3).distance_to(p) < 2.0:
					near = true
			if near:
				continue
			at = p
			src = int(field.node_source[i])
			break
	if src < 0:
		return
	var hit := _nearest_surface(at)
	var forced_anchor := OS.get_environment("TENTACLE_ANCHOR").split(",", false)
	if forced_anchor.size() == 6:
		hit = {"position": Vector3(forced_anchor[0].to_float(), forced_anchor[1].to_float(), forced_anchor[2].to_float()),
				"normal": Vector3(forced_anchor[3].to_float(), forced_anchor[4].to_float(), forced_anchor[5].to_float()).normalized(),
				"collider_name": "forced"}
	if hit.is_empty():
		_tentacle_cooldown[floor_id] = TENTACLE_COOLDOWN_S * 0.5
		return
	var root := get_parent()
	var who: Node3D = null
	if root != null and ("player" in root) and root.player != null:
		who = root.player as Node3D
	var tentacle := DreamTentacleScript.new()
	add_child(tentacle)
	tentacle.setup(field, src, hit.position, hit.normal, who,
			_candidates_for(floor_id, hit.position), tentacles_spawned * 7919 + floor_id.hash())
	live.append(tentacle)
	tentacles[floor_id] = live
	tentacles_spawned += 1
	if _tentacle_debug == null and (OS.get_environment("TENTACLE_DEBUG") == "1" or OS.has_feature("editor")):
		_tentacle_debug = DreamTentacleDebugScript.new()
		_tentacle_debug.name = "DreamTentacleDebug"
		add_child(_tentacle_debug)
		_tentacle_debug.setup(self)
	_tentacle_cooldown[floor_id] = TENTACLE_COOLDOWN_S
	if OS.get_environment("ENCROACH_DEBUG") == "1":
		print("[TENTACLE] %s: out of %s at %s (target %s)" % [floor_id, str(hit.collider_name),
				hit.position, tentacle.target_name])


## The nearest surface to a field point: six short rays. The organism lives
## on surfaces, so one of them is close.
func _nearest_surface(p: Vector3) -> Dictionary:
	var world: World3D = get_viewport().find_world_3d() if get_viewport() != null else null
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return {}
	var best: Dictionary = {}
	var best_d := INF
	for dir in [Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
		var query := PhysicsRayQueryParameters3D.create(p, p + dir * 1.3)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var d: float = (hit.position as Vector3).distance_to(p)
		# It comes out of walls by preference: a floor or a table top only when
		# no wall is near (the pool on the floor is the exception that earns it).
		if absf(float((hit.normal as Vector3).y)) > 0.7:
			d += 0.7
		if d < best_d:
			best_d = d
			best = {"position": hit.position, "normal": hit.normal,
					"collider_name": hit.collider.name if hit.collider else ""}
	return best


## What a tentacle may touch on this storey: every mesh with bounds, read
## once per storey (props exist a second after the building) and filtered
## near the anchor at spawn.
func _candidates_for(floor_id: String, near: Vector3) -> Array:
	if not _tentacle_candidates.has(floor_id):
		var rows: Array = []
		var unit_floor: Node = null
		var floor_y := 0.0
		for case_id in units:
			if _floor_of(case_id) == floor_id:
				unit_floor = units[case_id].floor_node
				floor_y = float(units[case_id].floor_y)
				break
		var roots: Array = []
		if unit_floor != null:
			roots.append(unit_floor)
		var storey_roots: Array = []
		for case_id in units:
			storey_roots.append(units[case_id].floor_node)
		var building := get_parent()
		if building != null:
			for child in building.get_children():
				if child is Node3D and child != unit_floor and not (child in storey_roots):
					roots.append(child)
				# The props themselves, by their own bounds: their meshes may be
				# batched into a storey draw, but the object is still an object.
				if child is FunctionalProp and child.has_method("dream_target_profile"):
					var local: AABB = child._visual_bounds()
					if local.size != Vector3.ZERO:
						var xf: Transform3D = (child as Node3D).global_transform
						var wb := AABB(xf * local.position, Vector3.ZERO)
						for i in 8:
							wb = wb.expand(xf * local.get_endpoint(i))
						if wb.position.y <= floor_y + 3.4 and wb.end.y >= floor_y - 0.2:
							rows.append({"aabb": wb, "name": child.name, "node": child})
		for r in roots:
			for node in (r as Node).find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.mesh == null or not mi.visible:
					continue
				var lname := mi.name.to_lower()
				if lname.contains("_walls") or lname.contains("_finish_") or lname.contains("floor") \
						or lname.contains("ceiling") or lname.contains("stair"):
					continue
				var aabb := _world_aabb(mi)
				if aabb.size == Vector3.ZERO or aabb.position.y > floor_y + 3.4 or aabb.end.y < floor_y - 0.2:
					continue
				# The object the mesh belongs to, for its Dream target profile.
				var owner_node: Node = mi
				while owner_node != null and not owner_node.has_method("dream_target_profile") \
						and owner_node != r:
					owner_node = owner_node.get_parent()
				var prop_node: Node3D = owner_node if (owner_node != null and owner_node.has_method("dream_target_profile")) else null
				rows.append({"aabb": aabb, "name": mi.name, "node": prop_node})
		_tentacle_candidates[floor_id] = rows
	var out: Array = []
	for row in _tentacle_candidates[floor_id]:
		var aabb: AABB = row.aabb
		if aabb.get_center().distance_to(near) < 3.5:
			out.append(row)
	return out
