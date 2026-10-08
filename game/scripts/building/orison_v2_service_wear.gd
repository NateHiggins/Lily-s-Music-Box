extends RefCounted
## Inferred residue at actual wet-work heights, independent of live water state.
## Uses the existing opaque mask shader; never adds water, faults or decals.

static func apply(actor: Node3D) -> void:
	var lo := Vector3.ZERO
	var hi := Vector3.ZERO
	var keys: Array[String] = []
	var handled := false
	if actor is LaundryAirerProp:
		lo=Vector3(-.63,.735,-.28); hi=Vector3(.63,.805,.28)
		keys=["zinc_liner"]
	elif actor is WasherProp:
		lo=Vector3(-.32,.765,-.32); hi=Vector3(.32,.817,.32)
		keys=["zinc_liner"]
	elif actor is TapProp:
		if actor.fixture=="shower":
			lo=Vector3(-.09,.009,-.09); hi=Vector3(.09,.045,.09)
		elif actor.fixture=="bath_sink":
			lo=Vector3(-.10,.675,-.095); hi=Vector3(.10,.708,.055)
		else: return
		keys=["enamel","porcelain","porcelain_fixture"]
	elif str(actor.get_meta("v2_native_domestic_variant","")) in ["DomesticObject03","DomesticObject12"]:
		var bounds:=AABB()
		for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if draw.mesh==null: continue
			bounds=bounds.merge(actor.global_transform.affine_inverse()*draw.global_transform*draw.mesh.get_aabb())
		lo=bounds.position-Vector3(.005,0,.005);hi=bounds.end+Vector3(.005,.002,.005)
		lo.y=hi.y-.045
		keys=["timber","wood_dark"]
		handled=true
	else: return
	var lower := Vector3(INF,INF,INF)
	var upper := Vector3(-INF,-INF,-INF)
	for x in [lo.x,hi.x]:
		for y in [lo.y,hi.y]:
			for z in [lo.z,hi.z]:
				var point := actor.to_global(Vector3(x,y,z))
				lower=lower.min(point); upper=upper.max(point)
	var changed := 0
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null: continue
		for index in draw.mesh.get_surface_count():
			var original: Material = draw.get_active_material(index)
			if original==null or not original.has_meta("v2_owner_finish"): continue
			var identity: String = str(original.get_meta("v2_owner_finish"))
			if identity.get_slice("/",1) not in keys: continue
			var material: ShaderMaterial
			if original is StandardMaterial3D:
				material=SurfacePass.surface_for(original,{"pigment_variation":.99,"relief_mul":0.})
			elif original is ShaderMaterial:
				material=original.duplicate() as ShaderMaterial
			else: continue
			material.set_shader_parameter("state_rect",Vector4(lower.x,lower.z,upper.x,upper.z))
			material.set_shader_parameter("state_y",Vector2(lower.y,upper.y))
			material.set_shader_parameter("state_edge_m",.012)
			material.set_shader_parameter("mask_amount",Vector4(0,0,0,.23) if handled else Vector4(0,.16,0,0))
			material.set_shader_parameter("mask_threshold",Vector4(.40,.38,.40,.40))
			material.set_shader_parameter("mask_softness",Vector4(.25,.28,.25,.25))
			material.set_shader_parameter("mask_proc_scale",18.)
			material.set_shader_parameter("grime_color",Vector3(.73,.71,.64))
			material.set_shader_parameter("grime_rough",.76)
			material.set_shader_parameter("grime_in_cavities",0.)
			if handled:
				material.set_shader_parameter("wear_on_crests",.15)
				material.set_shader_parameter("wear_rough",.43)
			material.set_meta("v2_owner_finish",identity)
			material.set_meta("v2_local_residue",true)
			if draw.material_override!=null: draw.material_override=material
			else: draw.set_surface_override_material(index,material)
			changed+=1
	if changed>0: actor.set_meta("v2_local_residue_slots",changed)
