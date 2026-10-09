extends RefCounted
## Final dossier finishes on existing native owners. Geometry and state remain
## source-owned; the original material is retained for exact construction QA.
const Finishes = preload("res://scripts/building/orison_v2_owner_finishes.gd")
const Component = preload("res://shaders/orison_owner_component.gdshader")
var finish: RefCounted
var tank_bands := {}

func apply(world: Node) -> void:
	finish=Finishes.new()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_tanks.json"))
	for row: Dictionary in fixture.original_records:
		if str(row.id).ends_with("_wband"): tank_bands[str(row.id).trim_suffix("_wband")]=Vector2(row.p0[2],row.p1[2])
	var root: Node3D=world.adapter.root
	for name: String in ["FrontFacade","RoofMembrane","RoofBaseFlashings","RoofBulkheadCaps","FittedRoofCoping"]:
		var model:=root.get_node_or_null(name) as Node3D
		if model!=null: _apply(model,"facade" if name=="FrontFacade" else "roof",model)
	var door: Node3D=world.adapter.resolve("F01_DOOR_06").get_node("F01_DOOR_06_Leaf")
	_apply(door.native_leaf,"facade",door.native_leaf)
	for name: String in ["RooftopTanks","RooftopAerials"]:
		var model:=world.get_node("CityShells").get_node(name) as Node3D
		_apply(model,"skyline",model)
	for fan: Node in root.find_children("*","Node3D",true,false):
		if fan is ExhaustFanProp: _apply(fan,"roof",fan)
	var lift: OrisonElevator=world.elevator
	# Cab wall fields, joinery, original gate and controls stay on the car.
	# Transparent, emissive and already-specialized optical owners are skipped.
	_apply(lift._cabin,"lift",lift._cabin)

func _apply(owner: Node3D,group: String,frame: Node3D) -> void:
	var count:=0
	for draw: Node in owner.find_children("*","GeometryInstance3D",true,false):
		if not draw.is_visible_in_tree(): continue
		var source: Material=draw.material_override
		if source==null or source is not StandardMaterial3D: continue
		var tuned: Material=finish.material_for(source,group)
		if tuned==source: continue
		var tag:=str(tuned.get_meta("v2_owner_finish",""))
		var key:=tag.get_slice("/",1)
		# Immutable reference and snapshot make geometry checks independent from
		# the installed finish, without dropping their original-map assertions.
		draw.set_meta("v2_building_source",source)
		draw.set_meta("v2_building_source_state",[source.albedo_color,source.roughness,source.normal_scale,source.uv1_scale,source.albedo_texture,source.normal_texture,source.roughness_texture])
		var bands:=PackedVector4Array([Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO])
		var special:=false
		if group=="facade" and key=="limestone":
			bands[0]=Vector4(2.30,2.60,.12,.10)
			bands[1]=Vector4(.28,.45,.10,.04)
			special=true
		elif group=="skyline" and key=="tank_staves":
			var identity:=str(draw.name).get_slice("__",0)
			if tank_bands.has(identity):
				var band: Vector2=tank_bands[identity]
				bands[0]=Vector4(band.x-.14,band.x,.20,.07)
				special=true
		elif group=="lift" and key=="oak_quartered":
			bands[0]=Vector4(.15,.28,.12,.04)
			bands[1]=Vector4(.85,.98,.15,.05)
			special=draw is MeshInstance3D
		elif group=="roof" and key=="roof_bitumen": special=true
		# These native cab parts carry metre UVs; world projection would slide
		# through their grain during lift travel. Never change shared MatLib.
		if group=="lift" and str(draw.name) in ["CabJoinery","RearEnamel"]:
			tuned=tuned.duplicate()
			if tuned is ShaderMaterial: tuned.set_shader_parameter("uv_mode",0)
			else: tuned.uv1_triplanar=false
		if special:
			var shaded: ShaderMaterial
			if tuned is ShaderMaterial: shaded=tuned.duplicate()
			else: shaded=SurfacePass.surface_for(tuned,{"pigment_variation":.62,"relief_mul":0.})
			shaded.shader=Component
			shaded.set_shader_parameter("component_from_mesh",frame.global_transform.affine_inverse()*draw.global_transform)
			shaded.set_shader_parameter("component_bands",bands)
			shaded.set_shader_parameter("component_bond_colors",source.vertex_color_use_as_albedo)
			shaded.set_shader_parameter("component_roof",key=="roof_bitumen")
			shaded.set_shader_parameter("component_polish",group=="lift")
			if key=="tank_staves": shaded.set_shader_parameter("component_tone",.98+float(str(draw.name).get_slice("__",0).hash()%5)*.01)
			shaded.set_meta("v2_owner_finish",tag)
			tuned=shaded
		draw.material_override=tuned
		draw.set_meta("v2_building_finish",group)
		count+=1
	if count>0:
		owner.set_meta("v2_building_finish_group",group)
		owner.set_meta("v2_building_finish_slots",count)
