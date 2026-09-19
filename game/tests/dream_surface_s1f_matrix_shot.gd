extends Node3D
## Bounded Forward+ closure sheets.  This harness stages public deterministic
## ecology facts and photographs the production renderers; it owns no runtime
## simulation, targeting, cleanup, narrative, or persistence authority.

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer = preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const LivingField = preload("res://scripts/reality/living_field.gd")
const Tentacle = preload("res://scripts/dream/entity/dream_tentacle_controller.gd")
const Critters = preload("res://scripts/dream/critters/dream_critter_controller.gd")
const CritterGenerator = preload("res://scripts/dream/critters/dream_critter_generator.gd")
const CritterSpecies = preload("res://scripts/dream/critters/dream_critter_species.gd")

var camera: Camera3D
var colony
var renderer
var field
var tentacles: Array = []
var out_dir := ""
var frames := 0
var failures := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty() or not out_dir.is_absolute_path():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.009, 0.018)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.23, 0.19, 0.28)
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment; add_child(world)
	camera = Camera3D.new(); camera.fov = 34.0; add_child(camera); camera.make_current()
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-54, -32, 0)
	key.light_color = Color(0.82, 0.76, 0.96); key.light_energy = 1.45; add_child(key)
	var back := OmniLight3D.new(); back.position = Vector3(-0.5, 0.65, -0.7)
	back.light_color = Color(0.34, 0.10, 0.52); back.light_energy = 3.1; back.omni_range = 3.0; add_child(back)
	var floor := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(4.0, 3.0)
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color(0.09, 0.075, 0.11); floor_mat.roughness = 0.82
	floor.mesh = plane; floor.material_override = floor_mat; add_child(floor)
	field = LivingField.new(); field.configure(Vector4(-2, -1.5, 2, 1.5), 0.0, 76123)
	var source: int = field.add_source(Vector3.ZERO, 0)
	field.plant(Vector4(-0.6, -0.6, 0.6, 0.6), source, 0.8, 30)
	colony = Colony.new(); colony.configure(source, 76123); colony.seed_at(Vector3.ZERO)
	renderer = Renderer.new(); add_child(renderer); renderer.setup(colony)


func _run() -> void:
	match OS.get_environment("S1F_MATRIX_MODE"):
		"s2e_review": await _s2e_review()
		"s2d_review": await _s2d_review()
		"s2d_graybox": await _s2d_graybox()
		"s2_review": await _s2_review()
		"tentacles": await _tentacle_matrix()
		"crystal": await _crystal_matrix()
		_: await _cellular_matrix()
	print("[S1F MATRIX] PASS %d -> %s" % [frames, out_dir])
	await _teardown()
	get_tree().quit(failures)


func _s2e_review() -> void:
	colony.register_route("feed_main","s2e",[Vector3.ZERO,Vector3(.15,0,.03),Vector3(.31,0,.10),Vector3(.50,0,.16),Vector3(.72,0,.11)])
	colony.register_route("feed_split","s2e",[Vector3(.15,0,.03),Vector3(.23,0,-.09),Vector3(.08,0,-.29),Vector3(.04,0,-.55)])
	colony.register_route("feed_loop","s2e",[Vector3(-.48,0,.34),Vector3(-.30,0,.19),Vector3(-.16,0,.08),Vector3(.02,0,.01),Vector3(.18,0,.08)])
	await _stage_mature()
	renderer._proteins.visible=false; renderer._ether.visible=false
	renderer._cilia.visible=false; renderer._cilia_carpet.visible=false
	renderer._heart.visible=false; renderer._network.visible=false
	renderer._sheet.material_override=renderer._heart_material
	_stage_fused_channels()
	camera.position=Vector3(.94,.58,1.08); camera.look_at(Vector3(0,.035,0))
	await _capture("01_fused_mature_moss_macro",24)
	_stage_embedded_gate()
	camera.position=Vector3(.34,.17,.43); camera.look_at(Vector3(0,.018,0))
	await _capture("02_embedded_gate_directional_cargo",18)
	_stage_organized_interior()
	camera.position=Vector3(.04,.28,.67); camera.look_at(Vector3(0,.045,0))
	await _capture("03_backlit_organized_internal_physiology",24)


func _s2d_graybox() -> void:
	_neutralize_stage()
	for _i in 12: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	colony.register_route("feeding_a", "gray", [Vector3.ZERO,Vector3(.22,0,.05),Vector3(.48,0,.16),Vector3(.72,0,.11)])
	colony.register_route("feeding_b", "gray", [Vector3.ZERO,Vector3(-.20,0,.12),Vector3(-.46,0,.34)])
	colony.register_route("feeding_c", "gray", [Vector3.ZERO,Vector3(-.05,0,-.27),Vector3(.04,0,-.55)])
	await _stage_mature()
	for material in [renderer._heart_material,renderer._network_material,renderer._protein_material]:
		material.set_shader_parameter("cellular_grayscale",true)
	renderer._cilia.visible=false; renderer._cilia_carpet.visible=false
	renderer._proteins.visible=false; renderer._ether.visible=false
	camera.position=Vector3(.92,.62,1.08); camera.look_at(Vector3(0,.045,0))
	await _capture("01_moss_silhouette",20)
	renderer._cilia_carpet.visible=true
	camera.position=Vector3(.48,.22,.55); camera.look_at(Vector3(0,.055,0))
	await _capture("02_cilia_silhouette",16)
	renderer.visible=false
	await _stage_modality_row()
	camera.position=Vector3(0,1.55,2.40); camera.look_at(Vector3(0,.22,0))
	await _capture("03_modality_silhouettes",20)


func _s2d_review() -> void:
	for _i in 12: colony.spawn(Colony.OrganismClass.CILIUM,Vector3.ZERO)
	colony.register_route("feeding_a","review",[Vector3.ZERO,Vector3(.16,0,.03),Vector3(.31,0,.10),Vector3(.49,0,.16),Vector3(.72,0,.11)])
	colony.register_route("feeding_b","review",[Vector3.ZERO,Vector3(-.16,0,.08),Vector3(-.30,0,.19),Vector3(-.48,0,.34)])
	colony.register_route("feeding_c","review",[Vector3.ZERO,Vector3(-.03,0,-.15),Vector3(-.10,0,-.32),Vector3(.04,0,-.55)])
	await _stage_mature()
	renderer._proteins.visible=false; renderer._ether.visible=false
	renderer._cilia.visible=false; renderer._cilia_carpet.visible=false
	camera.position=Vector3(.92,.57,1.05); camera.look_at(Vector3(0,.045,0))
	await _capture("01_mature_moss_macro",22)
	renderer._cilia_carpet.visible=true
	camera.position=Vector3(.46,.20,.52); camera.look_at(Vector3(0,.055,0))
	await _capture("02_dense_cilia_macro",18)
	_stage_gate_sequence()
	camera.position=Vector3(.36,.29,.39); camera.look_at(Vector3(0,.075,0))
	await _capture("03_membrane_gate_cargo_sequence",20)
	renderer.visible=false
	await _stage_modality_row()
	camera.position=Vector3(0,1.55,2.40); camera.look_at(Vector3(0,.22,0))
	await _capture("04_six_modalities_grayscale",22)
	for tentacle in tentacles: tentacle.visible=false
	renderer.set_process(true)
	renderer.visible=true; renderer._heart.visible=true; renderer._sheet.visible=true
	renderer._network.visible=true; renderer._proteins.visible=false
	renderer._cilia.visible=false; renderer._cilia_carpet.visible=false; renderer._ether.visible=true
	renderer._heart_material.set_shader_parameter("tissue_alpha",.52)
	renderer._network_material.set_shader_parameter("tissue_alpha",.62)
	renderer._network.position.y=-.028
	_set_moss_optics(3)
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_energy=.20
		elif child is Light3D:
			child.light_energy=.42
	for _i in 45: renderer._process(1.0/60.0)
	camera.position=Vector3(.02,.31,.66); camera.look_at(Vector3(0,.045,0))
	await _capture("05_backlit_internal_physiology",24)
	_set_moss_optics(0)
	await _capture_orison_room()


func _stage_gate_sequence() -> void:
	renderer.set_process(false)
	renderer._cilia_carpet.visible=false; renderer._proteins.visible=true
	renderer._ether.visible=true; renderer._network.visible=false; renderer._sheet.visible=false
	renderer._proteins.multimesh.visible_instance_count=7
	for i in 7:
		var basis:=Basis.IDENTITY.scaled(Vector3.ONE*(2.8 if i==0 else .62))
		var at:=Vector3(0,.085,0) if i==0 else Vector3(cos(float(i-1)*TAU/6.0)*.095,.078,sin(float(i-1)*TAU/6.0)*.095)
		renderer._proteins.multimesh.set_instance_transform(i,Transform3D(basis,at))
	renderer._ether.multimesh.visible_instance_count=9
	for i in 9:
		var progress:=float(i)/8.0
		var at:=Vector3(lerpf(-.27,.27,progress),.105+.018*sin(progress*PI),.0)
		var scale:=.28+.15*sin(progress*PI)
		renderer._ether.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),at))


func _clear_s2e_stage() -> void:
	for child in get_children():
		if child.is_in_group("s2e_stage"): child.queue_free()


func _stage_material(color: Color, emission := Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=color; material.roughness=.48; material.metallic=.05
	if color.a < .99:
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_ALWAYS
	if emission != Color.BLACK:
		material.emission_enabled=true; material.emission=emission; material.emission_energy_multiplier=.7
	return material


func _stage_mesh(mesh: PrimitiveMesh, at: Vector3, material: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); node.mesh=mesh; node.position=at; node.scale=scale
	node.material_override=material; node.add_to_group("s2e_stage"); add_child(node)
	return node


func _stage_tube(a: Vector3,b: Vector3,radius: float,material: Material) -> MeshInstance3D:
	var mesh:=CylinderMesh.new(); mesh.top_radius=radius*.72; mesh.bottom_radius=radius
	mesh.height=a.distance_to(b); mesh.radial_segments=12; mesh.rings=2
	var node:=_stage_mesh(mesh,(a+b)*.5,material)
	var axis:=(b-a).normalized(); var side:=axis.cross(Vector3.FORWARD)
	if side.length_squared()<.01: side=axis.cross(Vector3.RIGHT)
	side=side.normalized(); node.basis=Basis(side,axis,side.cross(axis).normalized())
	return node


func _stage_embedded_gate() -> void:
	_clear_s2e_stage(); renderer.set_process(false); renderer.visible=false
	var tissue:=_stage_material(Color(.38,.16,.34,.58))
	var protein:=_stage_material(Color(.58,.31,.56,1.0),Color(.12,.03,.10))
	var cargo:=_stage_material(Color(.24,.70,.66,.92),Color(.10,.42,.38))
	# A membrane slab makes the crossing depth explicit; the annular complex
	# penetrates its full thickness and the raised collar seals tissue to protein.
	var membrane:=CylinderMesh.new(); membrane.top_radius=.27; membrane.bottom_radius=.27
	membrane.height=.055; membrane.radial_segments=48; membrane.rings=3
	_stage_mesh(membrane,Vector3.ZERO,tissue,Vector3(1.35,1.0,.82))
	var pore:=TorusMesh.new(); pore.inner_radius=.050; pore.outer_radius=.108
	pore.rings=28; pore.ring_segments=16
	_stage_mesh(pore,Vector3(0,.003,0),protein,Vector3(1.0,1.45,1.0))
	var collar:=TorusMesh.new(); collar.inner_radius=.105; collar.outer_radius=.142
	collar.rings=32; collar.ring_segments=12
	_stage_mesh(collar,Vector3(0,.030,0),tissue,Vector3(1.0,.45,1.0))
	# Receptor jaws identify the capture side without decorative satellite rings.
	for sx in [-1.0,1.0]:
		var jaw:=SphereMesh.new(); jaw.radius=.042; jaw.height=.075; jaw.radial_segments=16; jaw.rings=8
		_stage_mesh(jaw,Vector3(sx*.073,.078,0),protein,Vector3(.78,1.0,1.15))
	# Four ghosted time samples: outside, receptor capture, pore, cytosolic release.
	var cargo_steps := [Vector3(-.16,.145,-.025),Vector3(-.060,.080,-.012),Vector3(0,.002,0),Vector3(.380,.015,.02)]
	for i in cargo_steps.size():
		var sphere:=SphereMesh.new(); sphere.radius=.027+float(i)*.002; sphere.height=sphere.radius*2.0
		sphere.radial_segments=16; sphere.rings=8
		_stage_mesh(sphere,cargo_steps[i],cargo,Vector3.ONE*(.78+float(i)*.09))
		if i<cargo_steps.size()-1: _stage_tube(cargo_steps[i],cargo_steps[i+1],.005,cargo)


func _stage_fused_channels() -> void:
	_clear_s2e_stage()
	var channel:=_stage_material(Color(.24,.57,.54,.72),Color(.03,.15,.14))
	# A tapered anastomosing graph: the left fork rejoins near the heart, then
	# divides again to feed two advancing fans. It sits barely under the skin.
	var segments := [
		[Vector3(-.55,.030,.31),Vector3(-.35,.035,.20),.011],
		[Vector3(-.55,.028,.31),Vector3(-.32,.030,.08),.008],
		[Vector3(-.35,.035,.20),Vector3(-.12,.040,.06),.014],
		[Vector3(-.32,.030,.08),Vector3(-.12,.040,.06),.009],
		[Vector3(-.12,.040,.06),Vector3(.12,.038,.04),.017],
		[Vector3(.12,.038,.04),Vector3(.34,.028,.13),.013],
		[Vector3(.34,.028,.13),Vector3(.66,.014,.12),.008],
		[Vector3(.12,.038,.04),Vector3(.04,.026,-.20),.011],
		[Vector3(.04,.026,-.20),Vector3(.04,.012,-.53),.006],
		[Vector3(.34,.028,.13),Vector3(.28,.022,-.08),.007],
		[Vector3(.28,.022,-.08),Vector3(.04,.026,-.20),.006]
	]
	for segment in segments:
		var tube:=_stage_tube(segment[0],segment[1],segment[2],channel)
		tube.position.y-=.014


func _stage_organized_interior() -> void:
	_clear_s2e_stage(); renderer.visible=true; renderer.set_process(false)
	renderer._heart.visible=false; renderer._sheet.visible=true; renderer._network.visible=false
	renderer._proteins.visible=false; renderer._ether.visible=false
	renderer._cilia.visible=false; renderer._cilia_carpet.visible=false
	renderer._network_material.set_shader_parameter("tissue_alpha",.30)
	_set_moss_optics(3)
	var nucleus_mat:=_stage_material(Color(.26,.52,.58,.92),Color(.06,.20,.22))
	var vacuole_mat:=_stage_material(Color(.42,.64,.68,.52))
	var channel_mat:=_stage_material(Color(.30,.72,.63,.78),Color(.05,.28,.22))
	var fiber_mat:=_stage_material(Color(.72,.48,.56,.75))
	var cargo_mat:=_stage_material(Color(.78,.78,.48,.96),Color(.36,.30,.08))
	var nucleus:=SphereMesh.new(); nucleus.radius=.105; nucleus.height=.19; nucleus.radial_segments=24; nucleus.rings=12
	_stage_mesh(nucleus,Vector3(-.08,.055,.00),nucleus_mat,Vector3(1.28,.88,.95))
	for record in [[Vector3(.20,.040,.03),.060],[Vector3(-.27,.028,.12),.038],[Vector3(.08,.022,-.20),.046],[Vector3(.34,.018,.13),.027]]:
		var vac:=SphereMesh.new(); vac.radius=record[1]; vac.height=record[1]*2.0; vac.radial_segments=18; vac.rings=9
		_stage_mesh(vac,record[0],vacuole_mat,Vector3(1.18,.82,.94))
	var routes := [[Vector3(-.43,.022,.20),Vector3(-.22,.030,.10),Vector3(.00,.026,.08),Vector3(.22,.020,.03),Vector3(.44,.012,.13)],
		[Vector3(-.02,.024,.08),Vector3(.06,.018,-.10),Vector3(.10,.012,-.33)],
		[Vector3(.17,.020,.04),Vector3(.29,.015,-.08),Vector3(.48,.010,-.13)]]
	for route in routes:
		for i in route.size()-1: _stage_tube(route[i],route[i+1],.012-float(i)*.0015,channel_mat)
	for fiber in [[Vector3(-.48,.050,-.06),Vector3(.34,.045,-.22)],[Vector3(-.33,.035,.25),Vector3(.42,.032,.18)],[Vector3(-.18,.060,-.29),Vector3(.31,.052,.28)]]:
		_stage_tube(fiber[0],fiber[1],.0035,fiber_mat)
	# A bright cargo chain follows the main channel, with unequal spacing making
	# its inward pulse direction readable in the still frame.
	var cargo_points := [Vector3(-.38,.038,.18),Vector3(-.27,.041,.125),Vector3(-.13,.038,.09),Vector3(.04,.034,.072),Vector3(.24,.028,.045)]
	for i in cargo_points.size():
		var ves:=SphereMesh.new(); ves.radius=.012+float(i)*.0015; ves.height=ves.radius*2.0; ves.radial_segments=14; ves.rings=7
		_stage_mesh(ves,cargo_points[i],cargo_mat)
	for child in get_children():
		if child is WorldEnvironment: child.environment.ambient_light_energy=.13
		elif child is Light3D: child.light_energy=.34


func _capture_orison_room() -> void:
	# Production Orison geometry, furnishing, and normal building lights. The
	# organism remains the same production renderer, simply staged on 2A's floor.
	for child in get_children():
		if child is WorldEnvironment:
			child.environment=null
		elif child is Light3D or (child is MeshInstance3D and child.mesh is PlaneMesh):
			child.visible=false
	renderer.visible=false
	OS.set_environment("DAYNIGHT","0")
	var orison=load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(orison)
	await get_tree().create_timer(3.5).timeout
	var room_at:=Vector3(-11.25,3.23,5.35)
	var room_colony=Colony.new(); room_colony.configure(991,76123); room_colony.seed_at(room_at)
	for _i in 10: room_colony.spawn(Colony.OrganismClass.CILIUM,room_at)
	room_colony.phase=Colony.Phase.COMPLEX; room_colony.maturity=1.0; room_colony.extent=1.25
	room_colony.ether_reserve=.88; room_colony.ether_production=.31; room_colony.connected_ether_volume=1.8; room_colony.stored_information=6.0
	room_colony.register_route("room_feed_a","room",[room_at,room_at+Vector3(.25,0,.08),room_at+Vector3(.62,0,.15)])
	room_colony.register_route("room_feed_b","room",[room_at,room_at+Vector3(-.20,0,.10),room_at+Vector3(-.48,0,.28)])
	var room_renderer=Renderer.new(); add_child(room_renderer); room_renderer.setup(room_colony)
	room_renderer.scale=Vector3.ONE*.62
	room_renderer._cilia.visible=false
	for _i in 45: room_renderer._process(1.0/60.0)
	if orison.get("player") != null: orison.get("player").visible=false
	_hide_capture_ui(orison)
	camera.position=Vector3(-9.75,4.12,3.60); camera.look_at(room_at+Vector3(0,.10,0)); camera.make_current()
	await _capture("06_colony_in_furnished_orison_room",30)


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control:
		node.visible=false
	for child in node.get_children(): _hide_capture_ui(child)


func _neutralize_stage() -> void:
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.background_color=Color(.08,.08,.08)
			child.environment.ambient_light_color=Color(.55,.55,.55)
			child.environment.ambient_light_energy=.75
		elif child is Light3D:
			child.light_color=Color.WHITE
			child.light_energy=1.15
		elif child is MeshInstance3D and child.mesh is PlaneMesh:
			var gray:=StandardMaterial3D.new(); gray.albedo_color=Color(.22,.22,.22); gray.roughness=.9
			child.material_override=gray


func _s2_review() -> void:
	# Exactly six canonical images. This deliberately stops before the full
	# closure matrix so silhouette and physiology can be judged first.
	for _i in 12: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	colony.register_route("artery_e", "review", [Vector3.ZERO, Vector3(.32,.01,.04), Vector3(.76,.0,.12)])
	colony.register_route("artery_w", "review", [Vector3.ZERO, Vector3(-.30,.01,.14), Vector3(-.72,.0,.31)])
	colony.register_route("artery_n", "review", [Vector3.ZERO, Vector3(.06,.01,-.34), Vector3(.20,.0,-.70)])
	colony.reports = 7
	await _stage_mature()
	camera.position = Vector3(.92,.58,1.00); camera.look_at(Vector3(0,.05,0))
	await _capture("01_mature_moss_macro", 20)
	camera.position = Vector3(.48,.23,.55); camera.look_at(Vector3(0,.07,0))
	await _capture("02_dense_rooted_cilia", 16)
	# The membrane is viewed almost edge-on here: half-submerged rings and
	# slits must read as gates through tissue, never beads laid on top.
	renderer._cilia.visible = false; renderer._cilia_carpet.visible = false
	renderer._heart.visible = false
	camera.position = Vector3(.30,.25,.31); camera.look_at(Vector3(0,.045,0))
	await _capture("03_embedded_protein_gate", 18)
	renderer._heart.visible = true
	renderer.visible = false
	await _stage_modality_row()
	camera.position = Vector3(0,1.65,2.45); camera.look_at(Vector3(0,.20,0))
	await _capture("04_six_modalities_grayscale", 24)
	for tentacle in tentacles: tentacle.visible = false
	renderer.visible = true; renderer._cilia.visible = true; renderer._cilia_carpet.visible = true
	_set_moss_optics(3)
	camera.position = Vector3(-.06,.36,.88); camera.look_at(Vector3(0,.045,0))
	await _capture("05_backlit_internal_physiology", 20)
	_set_moss_optics(0)
	camera.position = Vector3(3.15,1.72,3.35); camera.look_at(Vector3(0,.05,0))
	await _capture("06_gameplay_distance_colony", 12)


func _stage_mature() -> void:
	colony.phase = Colony.Phase.COMPLEX; colony.maturity = 1.0; colony.extent = 1.45
	colony.ether_reserve = .94; colony.ether_production = .36; colony.connected_ether_volume = 2.3
	colony.stored_information = 7.2; colony.disturbance = 0.0; colony.collapse_progress = 0.0
	renderer._refresh(true)
	for _i in 60: renderer._process(1.0 / 60.0)


func _set_moss_optics(mode: int) -> void:
	for material in [renderer._heart_material, renderer._network_material, renderer._protein_material]:
		material.set_shader_parameter("optics_mode", mode)


func _stage_modality_row() -> void:
	var purposes := [Colony.OrganismClass.PALPATOR, Colony.OrganismClass.SUCKER_SAMPLER,
		Colony.OrganismClass.MANIPULATOR, Colony.OrganismClass.VIBRATION_LISTENER,
		Colony.OrganismClass.OCULAR_EXAMINER, Colony.OrganismClass.RELAY_TENDRIL]
	for i in purposes.size():
		var x := -1.25 + float(i) * .50
		var anchor := Vector3(x,0,0)
		var record: Dictionary = colony.spawn(purposes[i], anchor)
		var target := anchor + Vector3(0,.58,.14)
		var candidate := {"aabb":AABB(target-Vector3.ONE*.08,Vector3.ONE*.16),"name":"review_target_%d"%i,"node":null}
		var tentacle = Tentacle.new(); add_child(tentacle)
		tentacle.setup(field, colony.source_id, anchor, Vector3.UP, null, [candidate], 8800+i)
		for _step in 240: tentacle._tick(1.0/60.0)
		tentacle.bind_ecology(colony, record, purposes[i])
		# Pose the existing production spine into a neutral comparison stance;
		# only the production shader is responsible for modality anatomy.
		for joint in 16:
			var t := float(joint) / 15.0
			tentacle.rig.pos[joint] = anchor + Vector3(.035*sin(t*PI*1.4+i), t*.62, .05*sin(t*PI))
			tentacle.rig.side[joint] = Vector3.RIGHT
			tentacle._spine_prev[joint] = tentacle.rig.pos[joint]
		tentacle.grow = 1.0
		tentacle.set_process(false); tentacle._push_uniforms()
		tentacle._material.set_shader_parameter("cellular_grayscale", true)
		tentacles.append(tentacle)


func _cellular_matrix() -> void:
	camera.position = Vector3(0.72, 0.48, 0.82); camera.look_at(Vector3(0, 0.08, 0))
	# One fixed subject/camera, with only public state facts changing.
	await _state("shared_01_previous_control", Colony.Phase.SEEDED, 0.18, 0.12, 0.0, 0.0)
	await _state("shared_02_neutral_membrane", Colony.Phase.TENDING, 0.42, 0.36, 0.2, 0.0)
	await _state("shared_03_phase_boundary", Colony.Phase.EXPLORING, 0.58, 0.48, 0.35, 0.0)
	await _state("shared_04_dic_directional", Colony.Phase.NETWORKED, 0.72, 0.62, 0.48, 0.0)
	await _state("shared_05_backlit_physiology", Colony.Phase.COMPLEX, 0.90, 0.84, 0.72, 0.0)
	renderer.present_report(Vector3(0.55, 0.10, 0.0), 1.0)
	await _state("shared_06_active_transport", Colony.Phase.COMPLEX, 1.0, 0.92, 1.0, 0.0)
	await _state("shared_07_disturbance", Colony.Phase.DISTURBED, 0.78, 0.42, 0.82, 0.28)
	await _state("shared_08_senescence", Colony.Phase.WITHERING, 0.42, 0.16, 1.0, 0.82)

	camera.position = Vector3(0.42, 0.24, 0.46); camera.look_at(Vector3(0, 0.045, 0))
	await _state("pioneer_01_thin_advancing_membrane", Colony.Phase.SEARCHING, 0.05, 0.08, 0.0, 0.0)
	await _state("pioneer_02_pseudopodial_edge", Colony.Phase.SEEDED, 0.14, 0.15, 0.05, 0.0)
	await _state("pioneer_03_edge_directed_flow", Colony.Phase.TENDING, 0.24, 0.26, 0.16, 0.0)
	await _state("pioneer_04_sparse_receptors", Colony.Phase.TENDING, 0.30, 0.31, 0.22, 0.0)
	await _state("pioneer_05_adhesion_plaques", Colony.Phase.EXPLORING, 0.38, 0.38, 0.28, 0.0)
	camera.position = Vector3(2.6, 1.75, 3.0); camera.look_at(Vector3.ZERO)
	await _state("pioneer_06_gameplay_phase_halo", Colony.Phase.EXPLORING, 0.38, 0.38, 0.28, 0.0)

	camera.position = Vector3(0.46, 0.30, 0.52); camera.look_at(Vector3(0, 0.06, 0))
	for i in 8: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	colony.register_route("radial_a", "a", [Vector3.ZERO, Vector3(0.35,0,0.05), Vector3(0.62,0,0.18)])
	colony.register_route("radial_b", "b", [Vector3.ZERO, Vector3(-0.28,0,0.18), Vector3(-0.55,0,0.30)])
	await _state("moss_01_membrane_folds", Colony.Phase.NETWORKED, 0.78, 0.74, 0.45, 0.0)
	await _state("moss_02_breathing_vacuoles", Colony.Phase.COMPLEX, 0.92, 0.90, 0.52, 0.0)
	await _state("moss_03_radial_transport", Colony.Phase.COMPLEX, 0.94, 0.92, 0.82, 0.0)
	renderer.present_report(Vector3(0.58,0.08,0.16), 1.0); await _capture("moss_04_report_rosette")
	await _capture("moss_05_rooted_ciliary_garden")
	await _state("moss_06_information_accumulation", Colony.Phase.COMPLEX, 1.0, 0.95, 1.0, 0.0)
	await _state("moss_07_low_ether", Colony.Phase.COMPLEX, 0.92, 0.08, 0.78, 0.0)
	await _state("moss_08_disturbance", Colony.Phase.DISTURBED, 0.80, 0.34, 0.74, 0.30)
	await _state("moss_09_senescence", Colony.Phase.WITHERING, 0.55, 0.12, 0.92, 0.78)
	await _state("moss_10_residue_transition", Colony.Phase.STAINED, 0.20, 0.0, 1.0, 1.0)

	# Fixed-camera protein sequence; count/organization follow information,
	# report, contact and senescence facts in the production renderer.
	camera.position = Vector3(0.31, 0.18, 0.34); camera.look_at(Vector3(0,0.05,0))
	await _state("proteins_01_confined_diffusion", Colony.Phase.NETWORKED, 0.7, 0.65, 0.18, 0.0)
	await _state("proteins_02_temporary_clustering", Colony.Phase.COMPLEX, 0.85, 0.75, 0.72, 0.0)
	renderer.present_report(Vector3(0.28,0.05,0), 0.55); await _capture("proteins_03_gate_opening")
	await _capture("proteins_04_compartment_hop")
	colony.disturbance = 0.45; renderer.present_report(Vector3(0.18,0.05,0.16), 0.85); await _capture("proteins_05_contact_recruitment")
	colony.reports = 8; renderer.present_report(Vector3(-0.22,0.05,0.12), 1.0); await _capture("proteins_06_reporting_reorganization")
	await _state("proteins_07_senescent_misclustering", Colony.Phase.WITHERING, 0.48, 0.10, 1.0, 0.88)

	await _state("senescence_01_ciliary_decoherence", Colony.Phase.DISTURBED, 0.72, 0.35, 0.75, 0.22)
	await _state("senescence_02_transport_arrest", Colony.Phase.WITHERING, 0.65, 0.25, 0.85, 0.42)
	await _state("senescence_03_protein_misclustering", Colony.Phase.WITHERING, 0.58, 0.18, 1.0, 0.58)
	await _state("senescence_04_cytoplasmic_slowdown", Colony.Phase.WITHERING, 0.48, 0.12, 1.0, 0.70)
	await _state("senescence_05_vacuole_failure", Colony.Phase.WITHERING, 0.38, 0.08, 1.0, 0.82)
	await _state("senescence_06_membrane_clouding", Colony.Phase.WITHERING, 0.28, 0.04, 1.0, 0.92)
	await _state("senescence_07_conduction_failure", Colony.Phase.STAINED, 0.15, 0.0, 1.0, 1.0)
	await _capture("senescence_08_pigment_coagulation")
	await _capture("senescence_09_ghost_network")
	await _state("senescence_10_authorized_cleanup", Colony.Phase.CLEARED, 0.0, 0.0, 0.0, 1.0)


func _state(label: String, phase: int, maturity: float, ether: float,
		information: float, collapse: float) -> void:
	colony.phase = phase; colony.maturity = maturity; colony.extent = 0.18 + maturity * 1.3
	colony.ether_reserve = ether; colony.ether_production = ether * 0.35
	colony.connected_ether_volume = ether * 2.2; colony.stored_information = information * 8.0
	colony.disturbance = 0.75 if phase == Colony.Phase.DISTURBED else 0.0
	colony.collapse_progress = collapse
	renderer._refresh(true)
	await _capture(label)


func _tentacle_matrix() -> void:
	renderer.visible = false
	var purposes := [
		["tactile", Colony.OrganismClass.PALPATOR],
		["chemical", Colony.OrganismClass.SUCKER_SAMPLER],
		["thermal", Colony.OrganismClass.MANIPULATOR],
		["vibrational", Colony.OrganismClass.VIBRATION_LISTENER],
		["optical", Colony.OrganismClass.OCULAR_EXAMINER],
		["electrical", Colony.OrganismClass.RELAY_TENDRIL],
	]
	colony.maturity = 1.0; colony.ether_reserve = 1.0; colony.phase = Colony.Phase.COMPLEX
	for i in purposes.size():
		var purpose: int = purposes[i][1]
		var record: Dictionary = colony.spawn(purpose, Vector3.ZERO)
		var tentacle = Tentacle.new(); add_child(tentacle)
		var target := Vector3(0.75, 0.18, 0.0)
		var candidate := {"aabb": AABB(target-Vector3.ONE*0.12,Vector3.ONE*0.24),"name":"evidence_target","node":null}
		tentacle.setup(field, colony.source_id, Vector3.ZERO, Vector3.RIGHT, null, [candidate], 7700 + i)
		# Let the production emergence/orientation owner establish full anatomy
		# before binding the evidence ecology packet and freezing simulation.
		for _step in 180: tentacle._tick(1.0 / 60.0)
		tentacle.bind_ecology(colony, record, purpose)
		tentacle.set_process(false)
		tentacle._push_uniforms()
		tentacles.append(tentacle)
		for other in tentacles: other.visible = other == tentacle
		camera.position = Vector3(1.05, 0.58, 1.05); camera.look_at(Vector3(0.34,0.12,0))
		await _capture("%s_01_silhouette" % purposes[i][0], 24)
		camera.position = Vector3(0.58, 0.30, 0.52); camera.look_at(Vector3(0.28,0.10,0))
		await _capture("%s_02_surface_macro" % purposes[i][0], 18)
		tentacle.exploration_state = tentacle.ExplorationState.SURFACE_CONTACT
		tentacle.grip = 0.8; tentacle.exchange_flash = 0.65
		tentacle._push_uniforms()
		await _capture("%s_03_active_sensing" % purposes[i][0], 18)
		tentacle.ecology_record.information = 1.0
		tentacle.exploration_state = tentacle.ExplorationState.INFORMATION_RETURN
		tentacle._push_uniforms()
		await _capture("%s_04_internal_report_transport" % purposes[i][0], 18)
		camera.position = Vector3(3.2, 1.65, 3.3); camera.look_at(Vector3(0.3,0.12,0))
		await _capture("%s_05_gameplay_distance" % purposes[i][0], 8)


func _crystal_matrix() -> void:
	renderer.visible = false
	var controller = Critters.new(); add_child(controller); controller.setup(null, 78119)
	var morph: Dictionary = CritterGenerator.generate(CritterSpecies.Kind.CRYSTAL_LISTENER, 78119)
	morph.length = 0.16; morph.wide = 0.16; morph.tall = 0.14; morph.feelers = 12; morph.crystal = 0.95
	var crystal := {"id":1,"morph":morph,"pos":Vector3(0,0.09,0),"up":Vector3.UP,
		"fwd":Vector3.FORWARD,"gait":0.0,"alive":1.0,"moving":false,"leg_state":[],
		"support_legs":0,"leg_root_gap_max":0.0,"twin":false,"spin":0.0,"photo":{},
		"photo_side":0.0,"mechanical":{"response":0.0,"carrier":0,"age":99.0,"direction":Vector3.ZERO,"received":0},
		"fold_leg":0,"fold":0.0,"unfold":0.0,"manipulator_deploy":0.0,
		"information_pulse":0.0,"ecology_repeat_count":0}
	controller.critters.append(crystal); controller._push()
	camera.position = Vector3(0.46,0.28,0.52); camera.look_at(Vector3(0,0.08,0))
	await _capture("crystal_01_grown_membrane_mineral")
	await _capture("crystal_02_ordered_protein_lattice")
	crystal.mechanical.response = 0.75; crystal.mechanical.carrier = 2; crystal.mechanical.age = 0.15; controller._push()
	await _capture("crystal_03_resonance_node_cilia")
	crystal.spin = 1.2; controller._push(); await _capture("crystal_04_internal_standing_wave")
	crystal.unfold = 0.65; controller._push(); await _capture("crystal_05_birefringent_response")
	crystal.mechanical.carrier = 1; crystal.mechanical.response = 1.0; controller._push(); await _capture("crystal_06_frequency_signal_band")
	crystal.information_pulse = 1.0; controller._push(); await _capture("crystal_07_information_return")
	camera.position = Vector3(2.8,1.4,3.0); camera.look_at(Vector3(0,0.08,0)); await _capture("crystal_08_gameplay_distance")


func _capture(label: String, settle_frames := 8) -> void:
	for _i in settle_frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(label + ".png"))
	if error == OK: frames += 1
	else: failures += 1


func _teardown() -> void:
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and is_instance_valid(tentacle._probe):
			tentacle._probe.free(); tentacle._probe = null
	for child in get_children():
		if is_instance_valid(child): child.free()
	tentacles.clear(); renderer = null; colony = null; field = null; camera = null
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
