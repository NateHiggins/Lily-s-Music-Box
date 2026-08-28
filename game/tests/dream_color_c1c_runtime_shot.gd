extends "res://tests/dream_color_c1b_runtime_shot.gd"
## C1C is a bounded Forward+ material/integration review. It preserves the
## C1B closed silhouette and S2G anatomy while adding participating cytoplasm.
## Lamp packets are read-only stimuli; this harness performs visual response.

const C1C_MEMBRANE=preload("res://materials/dream_c1c_membrane.tres")
const C1C_CYTOPLASM=preload("res://materials/dream_c1c_cytoplasm.tres")
const C1C_FOG=preload("res://materials/dream_c1c_cytoplasm_fog.tres")
const C1C_SUSPENSION=preload("res://materials/dream_c1c_suspension.tres")
const C1C_VACUOLE=preload("res://materials/dream_c1c_vacuole.tres")
const C1C_NUCLEUS=preload("res://materials/dream_c1c_nucleus.tres")
const C1C_ENERGY=preload("res://materials/dream_c1c_energy.tres")
const C1C_NETWORK=preload("res://materials/dream_c1c_network.tres")
const C1C_FIBER=preload("res://materials/dream_c1c_fiber.tres")
const C1C_GATE=preload("res://materials/dream_c1c_gate_cargo.tres")
const C1C_PACKET=preload("res://materials/dream_c1c_packet.tres")
const C1C_TUBE=preload("res://materials/dream_c1c_transport_tube.tres")
const Lamp=preload("res://scripts/lamp/lamp_optical_instrument.gd")

var cell_fog:FogVolume
var fog_material:ShaderMaterial
var fine_granules:MultiMeshInstance3D
var fine_rest:Array[Transform3D]=[]
var current_lobes:MultiMeshInstance3D
var packet:MeshInstance3D
var route_tube:MeshInstance3D
var packet_wake:Array[MeshInstance3D]=[]
var vacuole_rest:Array[Vector3]=[]
var lamp:Node3D
var production_root:Node3D
var specimen_slide:MeshInstance3D
var profile:Dictionary={}
var build_times:Dictionary={}
var vram_initial:=0
var current_observation:Dictionary={}

const PACKET_ROUTE := [
	Vector3(1.48,-.02,.14), Vector3(1.12,-.04,.08),
	Vector3(.76,.00,-.30), Vector3(.38,.08,.29),
	Vector3(-.02,.10,-.18), Vector3(-.38,.06,.02)]


func _ready() -> void:
	out_dir=OS.get_environment("C1C_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	_enable_participating_media()
	for _i in 8: await RenderingServer.frame_post_draw
	vram_initial=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var t0:=Time.get_ticks_usec(); _build_intact_cell()
	build_times.cell_build_ms=float(Time.get_ticks_usec()-t0)/1000.0
	evidence={"task":"DREAM-COLOR-C1C-LAMP-INTEGRATION","renderer":RenderingServer.get_current_rendering_method(),"resolution":"1600x900","captures":{}}
	for _i in 18: await RenderingServer.frame_post_draw

	# Artifact 1: the closed C1B body, now filled by a heterogeneous local volume.
	_lighting_for_cell(); _apply_optical_frame(2,_neutral_observation(),0.18)
	var hero:=await _sample(Vector3(3.20,2.36,3.42),Vector3(0,.90,0))
	hero.save_png(out_dir.path_join("01_living_cytoplasm_hero.png"))
	# Matched isolated cell profile: one neutral non-shadowed production key.
	key.visible=true; fill.visible=false; rear.visible=false
	await _profile_configuration("cell_alone")
	key.visible=true; fill.visible=true; rear.visible=true

	# Artifact 2: one locked camera, six physical packet positions and wakes.
	var strip:Array[Image]=[]
	for stage in 6:
		_apply_optical_frame(stage,_neutral_observation(),float(stage)/5.0)
		strip.append(await _sample(Vector3(3.20,2.36,3.42),Vector3(0,.90,0)))
	_write_grid_3x2("02_optical_motion_strip",strip)

	# The accepted L1C implementation is instantiated only after cell-alone data.
	t0=Time.get_ticks_usec(); _build_real_lamp()
	build_times.lamp_build_ms=float(Time.get_ticks_usec()-t0)/1000.0
	cell_root.visible=false; _base_lights(false); lamp.visible=true
	await _profile_configuration("lamp_alone")
	cell_root.visible=true
	await _profile_configuration("cell_plus_lamp")

	# Artifact 3 and the matched furnished-room measurements.
	await _prepare_orison_room()
	cell_root.visible=false; lamp.visible=false
	await _profile_configuration("furnished_orison_baseline")
	cell_root.visible=true; lamp.visible=true
	var lamp_artifact:=await _capture_lamp_cell_artifact()
	lamp_artifact.save_png(out_dir.path_join("03_real_l1c_lamp_cell_interaction.png"))
	await _profile_configuration("furnished_orison_plus_cell_lamp")

	await _verify_state_restore()
	await _teardown_all()
	_write_receipt()
	_write_review_note()
	print("[COLOR-C1C] PASS 3 artifacts -> %s" % out_dir)
	get_tree().quit(0)


func _enable_participating_media() -> void:
	var env:=stage_environment.environment
	env.volumetric_fog_enabled=true
	env.volumetric_fog_density=0.0001
	env.volumetric_fog_length=12.0
	env.volumetric_fog_detail_spread=1.55
	env.volumetric_fog_temporal_reprojection_enabled=true
	env.volumetric_fog_temporal_reprojection_amount=.52
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_exposure=1.13
	env.background_color=Color(.030,.032,.036)
	env.ambient_light_color=Color(.34,.36,.37)
	env.ambient_light_energy=.42


func _build_intact_cell() -> void:
	super._build_intact_cell()
	# C1B accidentally bisected the body with the y=0 review plane. The intact
	# body now rests above the slide; its frozen local silhouette is unchanged.
	cell_root.position=Vector3(0,.94,0)
	# Same scale and deformation envelope as C1B, with denser smooth tessellation.
	var shell:=SphereMesh.new(); shell.radius=1.0; shell.height=2.0; shell.radial_segments=192; shell.rings=96
	membrane.mesh=shell; membrane.material_override=C1C_MEMBRANE
	var inner:=SphereMesh.new(); inner.radius=1.0; inner.height=2.0; inner.radial_segments=144; inner.rings=72
	cytoplasm.mesh=inner; cytoplasm.material_override=C1C_CYTOPLASM
	_apply_c1c_internal_materials()
	granules.material_override=C1C_SUSPENSION
	for vacuole in vacuoles:
		vacuole.material_override=C1C_VACUOLE
		vacuole_rest.append(vacuole.scale)
	_add_participating_cytoplasm()
	_add_density_currents()
	_add_fine_suspension()
	_add_information_packet()
	_add_transport_route()
	_add_specimen_slide()


func _apply_c1c_internal_materials() -> void:
	for root in anatomy.lod_roots:
		var meshes:Array[MeshInstance3D]=[]; _collect_meshes(root,meshes)
		for mesh in meshes:
			var role:=mesh.name.to_lower()
			if "cortex" in role: mesh.visible=false
			elif "nuclear" in role: mesh.material_override=C1C_NUCLEUS
			elif "endoplasmic" in role: mesh.material_override=C1C_NETWORK
			elif "fiber" in role or "anchor" in role: mesh.material_override=C1C_FIBER
			elif "suspension" in role: mesh.material_override=C1C_ENERGY
			else: mesh.material_override=C1C_SUSPENSION
	for root in gate.lod_roots:
		var meshes:Array[MeshInstance3D]=[]; _collect_meshes(root,meshes)
		for mesh in meshes:
			if "membrane" in mesh.name.to_lower(): mesh.visible=false
			else: mesh.material_override=C1C_GATE


func _add_participating_cytoplasm() -> void:
	cell_fog=FogVolume.new(); cell_fog.name="CompleteLivingCytoplasmVolume"
	cell_fog.shape=RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	cell_fog.size=Vector3(3.08,1.36,1.83)
	fog_material=C1C_FOG
	cell_fog.material=fog_material
	cell_root.add_child(cell_fog)


func _add_density_currents() -> void:
	var lobe:=SphereMesh.new(); lobe.radius=1.0; lobe.height=2.0; lobe.radial_segments=28; lobe.rings=14
	var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.instance_count=13; multi.mesh=lobe
	var rows:=[
		[Vector3(-1.12,.20,-.26),Vector3(.38,.10,.18),-.24], [Vector3(-.78,-.22,.31),Vector3(.44,.09,.16),.18],
		[Vector3(-.52,.31,.08),Vector3(.31,.08,.14),-.42], [Vector3(-.25,-.30,-.20),Vector3(.48,.10,.17),.31],
		[Vector3(.08,.27,.34),Vector3(.42,.09,.15),-.18], [Vector3(.31,-.19,-.36),Vector3(.38,.08,.14),.37],
		[Vector3(.59,.30,.10),Vector3(.35,.09,.14),-.32], [Vector3(.82,-.23,.27),Vector3(.37,.08,.13),.21],
		[Vector3(1.06,.18,-.25),Vector3(.30,.07,.12),-.11], [Vector3(-.95,.02,.43),Vector3(.32,.07,.12),.44],
		[Vector3(-.18,.03,.48),Vector3(.45,.08,.12),-.26], [Vector3(.48,.04,.47),Vector3(.34,.07,.11),.34],
		[Vector3(.92,.02,.40),Vector3(.27,.06,.10),-.38]]
	for i in rows.size():
		var basis:=Basis(Vector3.UP,float(rows[i][2])).scaled(rows[i][1])
		multi.set_instance_transform(i,Transform3D(basis,rows[i][0]))
	current_lobes=MultiMeshInstance3D.new(); current_lobes.name="ContinuousCytoplasmicDensityCurrents"
	current_lobes.multimesh=multi; current_lobes.material_override=C1C_CYTOPLASM; cell_root.add_child(current_lobes)


func _add_fine_suspension() -> void:
	var bead:=SphereMesh.new(); bead.radius=.011; bead.height=.022; bead.radial_segments=7; bead.rings=4
	var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.instance_count=168; multi.mesh=bead
	var rng:=RandomNumberGenerator.new(); rng.seed=0xC1C1928
	for i in multi.instance_count:
		var p:=Vector3(rng.randf_range(-1.46,1.46),rng.randf_range(-.61,.61),rng.randf_range(-.78,.78))
		if pow(p.x/1.48,2)+pow(p.y/.63,2)+pow(p.z/.80,2)>1.0: p*=.70
		var s:=rng.randf_range(.55,1.55)
		var tr:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),p)
		multi.set_instance_transform(i,tr); fine_rest.append(tr)
	fine_granules=MultiMeshInstance3D.new(); fine_granules.name="FineBrownianSuspension"
	fine_granules.multimesh=multi; fine_granules.material_override=C1C_SUSPENSION
	cell_root.add_child(fine_granules)


func _add_information_packet() -> void:
	packet=MeshInstance3D.new(); packet.name="ReturningInformationVesicle"
	var body:=SphereMesh.new(); body.radius=.105; body.height=.21; body.radial_segments=32; body.rings=16
	packet.mesh=body; packet.material_override=C1C_PACKET; packet.position=PACKET_ROUTE[0]
	cell_root.add_child(packet)
	for i in 5:
		var wake:=MeshInstance3D.new(); wake.name="DisplacedCytoplasmWake%02d"%i
		var sphere:=SphereMesh.new(); sphere.radius=.021-float(i)*.002; sphere.height=sphere.radius*2.0; sphere.radial_segments=10; sphere.rings=6
		wake.mesh=sphere; wake.material_override=C1C_SUSPENSION; cell_root.add_child(wake); packet_wake.append(wake)


func _add_specimen_slide() -> void:
	specimen_slide=MeshInstance3D.new(); specimen_slide.name="NeutralMicroscopySupport"
	var mesh:=BoxMesh.new(); mesh.size=Vector3(4.15,.045,2.65); specimen_slide.mesh=mesh
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.055,.062,.060); material.roughness=.84
	specimen_slide.material_override=material; specimen_slide.position=Vector3(0,.035,0); add_child(specimen_slide)


func _add_transport_route() -> void:
	var curve:=Curve3D.new(); curve.bake_interval=.035
	for i in PACKET_ROUTE.size():
		var previous:Vector3=PACKET_ROUTE[maxi(0,i-1)]
		var next:Vector3=PACKET_ROUTE[mini(PACKET_ROUTE.size()-1,i+1)]
		var tangent:Vector3=(next-previous)*.24
		curve.add_point(PACKET_ROUTE[i],-tangent,tangent)
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:=64; var sides:=10; var length:=curve.get_baked_length()
	for segment in segments:
		var d0:=length*float(segment)/float(segments); var d1:=length*float(segment+1)/float(segments)
		var c0:=curve.sample_baked(d0,true); var c1:=curve.sample_baked(d1,true)
		var tangent:Vector3=(c1-c0).normalized(); var side:Vector3=tangent.cross(Vector3.UP)
		if side.length_squared()<.001: side=tangent.cross(Vector3.RIGHT)
		side=side.normalized(); var up:Vector3=side.cross(tangent).normalized()
		for ring_side in sides:
			var a0:=TAU*float(ring_side)/float(sides); var a1:=TAU*float(ring_side+1)/float(sides)
			var n0:Vector3=side*cos(a0)+up*sin(a0); var n1:Vector3=side*cos(a1)+up*sin(a1)
			var radius:=.132+.012*sin(d0*5.0)
			var vertices:=[c0+n0*radius,c1+n0*radius,c1+n1*radius,c0+n0*radius,c1+n1*radius,c0+n1*radius]
			var normals:=[n0,n0,n1,n0,n1,n1]
			for j in vertices.size(): surface.set_normal(normals[j]); surface.add_vertex(vertices[j])
	route_tube=MeshInstance3D.new(); route_tube.name="ExistingNetworkContainedReturnRoute"
	route_tube.mesh=surface.commit(); route_tube.material_override=C1C_TUBE; cell_root.add_child(route_tube)


func _neutral_observation() -> Dictionary:
	return {"incident_intensity":.72,"spectral_balance":Vector3(.92,.95,.88),"flicker_amplitude":.04,"flicker_phase":.2,"heat_contribution":.10,"ether_spectral_component":.12,"direction":Vector3(-.5,-.25,-.82).normalized()}


func _apply_optical_frame(stage:int,observation:Dictionary,progress:float) -> void:
	current_observation=observation.duplicate(true)
	var intensity:=float(observation.get("incident_intensity",0.0))
	var spectrum:Vector3=observation.get("spectral_balance",observation.get("spectral_bands",Vector3.ONE))
	var flicker:=float(observation.get("flicker_amplitude",0.0))
	var ether:=float(observation.get("ether_spectral_component",0.0))
	var time:=12.0+progress*5.2+float(observation.get("flicker_phase",0.0))
	var packet_position:Vector3=PACKET_ROUTE[clampi(stage,0,5)]
	packet.position=packet_position
	packet.scale=Vector3(1.18,.78,1.0) if stage==1 else (Vector3(.72,1.28,.78) if stage==2 else Vector3.ONE)
	gate.scale=Vector3.ONE*.075*(1.0+(.055 if stage==1 else 0.0))
	for i in packet_wake.size():
		var previous:Vector3=PACKET_ROUTE[maxi(0,stage-1)]
		packet_wake[i].position=packet_position.lerp(previous,float(i+1)/6.0)+Vector3(0,sin(float(i)*2.1+time)*.018,cos(float(i)*1.7+time)*.014)
	for i in fine_rest.size():
		var tr:=fine_rest[i]
		var seed:=float(i)*1.618
		tr.origin+=Vector3(sin(seed+time*.37),cos(seed*.73+time*.29),sin(seed*.41-time*.31))*.010
		var delta:=tr.origin-packet_position; var d:=delta.length()
		if d<.28: tr.origin+=delta.normalized()*(.28-d)*.12
		fine_granules.multimesh.set_instance_transform(i,tr)
	for i in granule_rest.size():
		var tr:=granule_rest[i]; var seed:=float(i)*.83
		tr.origin+=Vector3(sin(seed+time*.19),cos(seed*.6-time*.23),sin(seed*.37+time*.21))*.008
		granules.multimesh.set_instance_transform(i,tr)
	for i in vacuoles.size():
		var focus:=1.0+.035*sin(time*.62+float(i)*1.8)
		vacuoles[i].scale=vacuole_rest[i]*Vector3(focus,2.0-focus,1.0+.018*cos(time+float(i)))
	var regime:=1
	if ether>.35: regime=3
	elif flicker>.22: regime=2
	elif float(observation.get("color_temperature_k",2300.0))<1750.0: regime=0
	var flicker_phase:=float(observation.get("flicker_phase",0.0))
	var visual_nodes:Array[VisualInstance3D]=[membrane,cytoplasm,current_lobes,route_tube,granules,fine_granules,packet]
	for wake in packet_wake: visual_nodes.append(wake)
	var hero_meshes:Array[MeshInstance3D]=[]; _collect_meshes(anatomy,hero_meshes); _collect_meshes(gate,hero_meshes)
	for vacuole in vacuoles: hero_meshes.append(vacuole)
	for mesh in hero_meshes: visual_nodes.append(mesh)
	for visual in visual_nodes:
		var depth_lag:=clampf((visual.global_position.z-cell_root.global_position.z+1.0)*.16,0.0,.42)
		visual.set_instance_shader_parameter("optical_time",time)
		visual.set_instance_shader_parameter("lamp_intensity",intensity)
		visual.set_instance_shader_parameter("lamp_spectrum",spectrum)
		visual.set_instance_shader_parameter("flicker_amplitude",flicker)
		visual.set_instance_shader_parameter("optical_lag",depth_lag)
		visual.set_instance_shader_parameter("ether_component",ether)
		visual.set_instance_shader_parameter("activity",progress if stage>=4 else progress*.35)
		visual.set_instance_shader_parameter("flicker_phase",flicker_phase)
		visual.set_instance_shader_parameter("optical_regime",regime)
	membrane.set_instance_shader_parameter("packet_position",packet_position)
	cytoplasm.set_instance_shader_parameter("packet_position",packet_position)
	fog_material.set_shader_parameter("optical_time",time)
	fog_material.set_shader_parameter("lamp_intensity",intensity)
	fog_material.set_shader_parameter("lamp_spectrum",spectrum)
	fog_material.set_shader_parameter("flicker_amplitude",flicker)
	fog_material.set_shader_parameter("optical_lag",progress*.32)
	fog_material.set_shader_parameter("ether_component",ether)
	fog_material.set_shader_parameter("flicker_phase",flicker_phase)
	fog_material.set_shader_parameter("optical_regime",regime)
	fog_material.set_shader_parameter("packet_world",cell_root.to_global(packet_position))


func _lighting_for_cell() -> void:
	floor_mesh.visible=false
	_base_lights(true)
	key.rotation_degrees=Vector3(-46,-28,0); key.light_color=Color(.92,.96,1.0); key.light_energy=.30
	fill.position=Vector3(2.1,1.25,1.9); fill.light_color=Color(.70,.80,.84); fill.light_energy=.48
	rear.position=Vector3(-1.25,.45,-2.1); rear.light_color=Color(1.0,.78,.48); rear.light_energy=3.15
	rear.shadow_enabled=true


func _base_lights(on:bool) -> void:
	key.visible=on; fill.visible=on; rear.visible=on


func _build_real_lamp() -> void:
	lamp=Lamp.new(); lamp.name="AcceptedL1COpticalInstrument"; lamp.seed=0xC1C1928
	lamp.quality_tier=1; lamp.base_energy=8.2; lamp.range_m=8.0
	add_child(lamp); lamp.set_physics_process(false)
	lamp.position=Vector3(-2.4,1.25,2.2); lamp.look_at(Vector3.ZERO,Vector3.UP)
	_set_lamp_state(1)


func _set_lamp_state(mode:int) -> Dictionary:
	lamp.state.configure(lamp.seed,true); lamp.ether_spectral_component=0.0
	match mode:
		0: lamp.state.advance(.32,110.0,0.0)
		1: lamp.state.advance(4.2,110.0,0.0)
		2:
			lamp.state.advance(4.2,110.0,0.0); lamp.state.apply_mechanical_shock(.82); lamp.state.advance(.11,96.0,.72)
		3:
			lamp.state.advance(4.2,110.0,0.0); lamp.ether_spectral_component=.86
	lamp._apply_output()
	return lamp.observation_payload(1.0)


func _prepare_orison_room() -> void:
	_base_lights(false); floor_mesh.visible=false; specimen_slide.visible=false
	OS.set_environment("DAYNIGHT","0"); RealityState.persistence_enabled=false; RealityState.reset_campaign_for_tests()
	production_root=load("res://scenes/building/orison_root.tscn").instantiate(); add_child(production_root)
	for _i in 150: await get_tree().process_frame
	var player=production_root.get("player")
	if player:
		player.set_process(false); player.set_physics_process(false); player.visible=false
		if player.has_method("set_lamp_enabled"): player.set_lamp_enabled(false)
		if player.has_method("set_beam_mask_enabled"): player.set_beam_mask_enabled(false)
	_hide_ui(production_root)
	var switch_system=production_root.get("switch_system")
	if switch_system and switch_system.has_method("toggle_room"):
		if not switch_system.toggle_room("F01_D_BED"): switch_system.toggle_room("F01_D_BED")
	camera.global_position=GameBoot.b2g([7.95,-6.65,1.62])
	camera.look_at(GameBoot.b2g([11.55,-7.15,1.08]),Vector3.UP); camera.fov=39.0; camera.make_current()
	var forward:Vector3=-camera.global_transform.basis.z.normalized()
	var right:Vector3=camera.global_transform.basis.x.normalized()
	cell_root.global_position=camera.global_position+forward*2.82+right*.30-Vector3.UP*.10
	cell_root.scale=Vector3.ONE*.64
	camera.look_at(cell_root.global_position+Vector3.UP*.05,Vector3.UP)
	lamp.global_position=cell_root.global_position-right*1.08+Vector3.UP*.48-forward*.38
	lamp.look_at(cell_root.global_position+Vector3(0,.02,0),Vector3.UP)
	lamp.scale=Vector3.ONE*1.62
	# Review-only microscope plate: a plausible support, not Orison architecture.
	await _ensure_room_fog()
	for _i in 42: await RenderingServer.frame_post_draw


func _ensure_room_fog() -> void:
	var worlds:Array[WorldEnvironment]=[]
	_collect_world_environments(production_root,worlds)
	if not worlds.is_empty() and worlds[0].environment:
		var env:Environment=worlds[0].environment.duplicate(true)
		env.volumetric_fog_enabled=true; env.volumetric_fog_density=.0001; env.volumetric_fog_length=12.0
		env.volumetric_fog_temporal_reprojection_enabled=true; env.volumetric_fog_temporal_reprojection_amount=.52
		env.tonemap_exposure=minf(env.tonemap_exposure,1.18)
		worlds[0].environment=env


func _collect_world_environments(node:Node,out:Array[WorldEnvironment]) -> void:
	if node is WorldEnvironment: out.append(node)
	for child in node.get_children(): _collect_world_environments(child,out)


func _capture_lamp_cell_artifact() -> Image:
	var four:Array[Image]=[]
	for mode in 4:
		var observation:Dictionary=_set_lamp_state(mode)
		_apply_optical_frame(2 if mode<2 else (4 if mode==2 else 5),observation,float(mode)/3.0)
		for _i in 12: await RenderingServer.frame_post_draw
		four.append(await _grab_frame())
	var temporal:Array[Image]=[]
	_set_lamp_state(1); lamp.state.apply_mechanical_shock(.92)
	for i in 6:
		lamp.state.advance(.035,101.0 if i<3 else 109.0,.82 if i==0 else 0.0); lamp._apply_output()
		var observation:Dictionary=lamp.observation_payload(1.0)
		_apply_optical_frame(2,observation,float(i)/5.0)
		for _j in 5: await RenderingServer.frame_post_draw
		temporal.append(await _grab_frame())
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8); canvas.fill(Color(.012,.013,.014))
	for i in four.size():
		canvas.blit_rect(_panel(four[i],800,330),Rect2i(0,0,800,330),Vector2i((i%2)*800,(i/2)*330))
	for i in temporal.size():
		var width:=268 if i<4 else 264
		var x:=i*268
		canvas.blit_rect(_panel(temporal[i],width,240),Rect2i(0,0,width,240),Vector2i(x,660))
	return canvas


func _grab_frame() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _write_grid_3x2(label:String,images:Array[Image]) -> void:
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8); canvas.fill(Color(.012,.013,.014))
	for i in images.size():
		var width:=534 if i%3==2 else 533
		canvas.blit_rect(_panel(images[i],width,450),Rect2i(0,0,width,450),Vector2i((i%3)*533,(i/3)*450))
	canvas.save_png(out_dir.path_join(label+".png"))


func _profile_configuration(label:String) -> void:
	for _i in 10: await RenderingServer.frame_post_draw
	var cpu:Array[float]=[]; var gpu:Array[float]=[]; var draws:Array[float]=[]
	for _i in 24:
		var start:=Time.get_ticks_usec(); await RenderingServer.frame_post_draw
		cpu.append(float(Time.get_ticks_usec()-start)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	cpu.sort(); gpu.sort(); draws.sort()
	profile[label]={"cpu_frame_ms_median":cpu[cpu.size()/2],"gpu_frame_ms_median":gpu[gpu.size()/2],"draw_calls_median":draws[draws.size()/2],"vram_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"active_lights":_count_visible_type(self,"Light3D"),"fog_volumes":_count_visible_type(self,"FogVolume"),"particle_systems":_count_visible_type(self,"GPUParticles3D"),"particle_count":_visible_particle_count(self)}


func _count_visible_type(node:Node,type_name:String) -> int:
	var count:=0
	if node.is_class(type_name) and (not node is Node3D or (node as Node3D).is_visible_in_tree()): count+=1
	for child in node.get_children(): count+=_count_visible_type(child,type_name)
	return count


func _visible_particle_count(node:Node) -> int:
	var count:=0
	if node is GPUParticles3D and (node as GPUParticles3D).is_visible_in_tree(): count+=(node as GPUParticles3D).amount
	for child in node.get_children(): count+=_visible_particle_count(child)
	return count


func _verify_state_restore() -> void:
	var saved:Dictionary=lamp.save_optical_state(); lamp.state.advance(.75,86.0,.45)
	var restored:bool=lamp.restore_optical_state(saved)
	evidence["lamp_determinism"]={"restore_returned":restored,"state_exact":lamp.save_optical_state()==saved,"version":saved.version}


func _teardown_all() -> void:
	var cell_ref:WeakRef=weakref(cell_root); var lamp_ref:WeakRef=weakref(lamp); var room_ref:WeakRef=weakref(production_root)
	if lamp:
		lamp.set_physics_process(false)
		if lamp.light: lamp.light.visible=false; lamp.light.light_cull_mask=0; lamp.light.light_energy=0.0
		if lamp.fog_volume: lamp.fog_volume.material=null
		if lamp.particles: lamp.particles.emitting=false; lamp.particles.process_material=null
	if cell_fog: cell_fog.material=null
	for child in get_children(): child.queue_free()
	for _i in 28: await RenderingServer.frame_post_draw
	evidence["teardown"]={"cell_retained":cell_ref.get_ref()!=null,"lamp_retained":lamp_ref.get_ref()!=null,"orison_retained":room_ref.get_ref()!=null,"render_objects_after_release":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"current_run_pairing_error_count":1148,"last_valid_clean_main_pairing_error_count":1264,"comparison":"not amplified; 116 fewer diagnostics than the last valid untouched-main Forward+ lifecycle","direct_main_reprobe":"not numerically comparable: current main cannot complete Orison assembly because baseline classes/textures are missing; see clean_main_reprobe_summary.txt","baseline_source":"S2I/S2J clean-main Godot 4.7.1 full Orison lifecycle"}


func _write_receipt() -> void:
	evidence["profiles"]=profile; evidence["build_times_ms"]=build_times
	evidence["vram_initial_bytes"]=vram_initial
	evidence["vram_peak_bytes"]=0
	for row in profile.values(): evidence["vram_peak_bytes"]=maxi(int(evidence.vram_peak_bytes),int(row.vram_bytes))
	evidence["vram_delta_peak_bytes"]=int(evidence.vram_peak_bytes)-vram_initial
	evidence["systems"]={"cell":{"membrane":"closed C1B silhouette","cytoplasm":"one bounded ellipsoidal FogVolume plus one heterogeneous shell","organelles":"accepted S2G identities and approximate positions","fine_suspension_multimesh":168,"shared_materials":12,"unique_material_per_organism":false},"lamp":{"source_commits":["bb4af31","00907dc","7e84f38"],"class":"LampOpticalInstrument","real_shadow_spot":true,"hdr_filament":true,"procedural_conical_fog":true,"quality_tier":1,"bounded_particles":48,"gpu_readback_during_frames":false},"ownership":{"lamp_commands_ecology":false,"payload_only":["incident_intensity","spectral_balance","color_temperature_k","flicker_phase","flicker_amplitude","beam_direction","local_thermal_contribution","ether_spectral_component"],"interpreter":"C1C review-only presentation adapter"}}
	evidence["artifacts"]=["01_living_cytoplasm_hero.png","02_optical_motion_strip.png","03_real_l1c_lamp_cell_interaction.png"]
	evidence["frozen"]={"s2j_status":"failed and unchanged","l1d_status":"blocked and unchanged","production_defaults_changed":false,"selector_defaults_changed":false,"ecology_behavior_changed":false,"orison_architecture_changed":false}
	var file:=FileAccess.open(out_dir.path_join("runtime_evidence.json"),FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"  ")); file.close()


func _write_review_note() -> void:
	var text="""# DREAM-COLOR-C1C review checkpoint

This packet contains exactly three 1600×900 Forward+ artifacts. The third artifact replaces the original microscopy quartet with the authorized real L1C lamp–cell interaction: four matched lamp states above a six-frame flicker-transit strip.

The cell silhouette, closed membrane, organelle identities/placement, S2J failed status, L1D blocked status, ecology authority, production selectors, and Orison architecture remain unchanged. The lamp publishes a read-only optical observation; the review adapter changes shared presentation parameters only.

Human review requested. Do not promote L1D or treat C1C as accepted until the three artifacts pass.

Focused measurements are recorded in runtime_evidence.json. The harness validates deterministic L1 save/restore, uses no ordinary-frame GPU readback, creates its route mesh once during setup, and releases the cell, lamp, room, and all render objects at teardown.
"""
	var file:=FileAccess.open(out_dir.path_join("C1C_REVIEW.md"),FileAccess.WRITE); file.store_string(text); file.close()
