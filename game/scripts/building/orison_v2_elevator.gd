extends RefCounted
## Adapt the production car/door/input owner to the installed V2 shaft.

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> OrisonElevator:
	var shaft: Dictionary = {}
	for record: Dictionary in layout.risers:
		if record.id == "PASSENGER_LIFT_SHAFT": shaft = record
	if shaft.is_empty(): return null
	var stops := {}
	for landing: Dictionary in layout.lift_landings:
		if landing.shaft != shaft.id: continue
		for level: Dictionary in layout.levels:
			if level.id == landing.level: stops[level.id] = float(level.y)
	# B1 is a real passenger stop as well as the separate boiler stair.
	for level: Dictionary in layout.levels:
		if level.id == "B1": stops[level.id] = float(level.y)
	if stops.size() != 7: return null
	var lift := OrisonElevator.new()
	lift.name = "PassengerElevator"
	lift.rotation.y = PI
	adapter.root.add_child(lift)
	var center_x := (float(shaft.rect[0])+float(shaft.rect[2]))*.5
	var center_z := float(shaft.rect[1])+OrisonElevator.FRONT_Z
	# setup uses plan (x,-z) and creates sync-to-physics bodies. Establish
	# the final parent transform before those bodies cache their transforms.
	lift.setup({"shaft":[center_x-1.2,-center_z-1.1,center_x+1.2,-center_z+1.1], "cabin":[1.55,2.2],
		"stops":stops, "door_w":.91})
	if not _refine_landing_frames(lift):
		lift.queue_free();return null
	_refine_landing_panels(lift)
	_refine_cab_handrails(lift)
	_refine_cab_joinery(lift)
	_refine_cab_lamp(lift)
	var mirror := preload("res://scripts/building/orison_v2_lift_mirror.gd").new()
	mirror.mount(lift)
	var indicator := preload("res://scripts/building/orison_v2_lift_indicator.gd").new()
	indicator.mount(lift)
	var cab_controls := preload("res://scripts/building/orison_v2_cab_controls.gd").new()
	cab_controls.name = "CabControls"
	lift.add_child(cab_controls)
	cab_controls.mount(lift)
	var gate_visual := preload("res://scripts/building/orison_v2_lift_gate.gd").new()
	gate_visual.name = "ArticulatedGate"
	gate_visual.mount(lift)
	var controls := preload("res://scripts/building/orison_v2_lift_controls.gd").new()
	controls.name = "LandingControls"
	lift.add_child(controls)
	if not controls.mount(lift,layout):
		lift.queue_free()
		return null
	# Only the old translucent reservation is retired. Authored shaft walls,
	# pit, landing aprons and the production moving door colliders remain.
	var reservation := adapter.resolve(str(shaft.id)) as Node3D
	if reservation != null: reservation.visible = false
	for landing: Dictionary in layout.lift_landings:
		if landing.shaft != shaft.id: continue
		var frame := adapter.resolve(str(landing.id)) as Node3D
		if frame != null: frame.visible = false
	return lift


func _refine_cab_lamp(lift: OrisonElevator) -> void:
	var model := (preload("res://assets/props/lift_ceiling_lamp.glb") as PackedScene).instantiate()
	for part in model.get_children():
		if part is MeshInstance3D:
			part.material_override=lift._dome if part.name=="OpalBowl" else lift._cab_lamp_parts[1].material_override
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for old: MeshInstance3D in lift._cab_lamp_parts: old.hide()
	lift._cabin.add_child(model)
	lift._cab_lamp_visual=model


func _refine_cab_joinery(lift: OrisonElevator) -> void:
	var model := (preload("res://assets/props/lift_joinery.glb") as PackedScene).instantiate()
	(model.find_child("CabJoinery",true,false) as MeshInstance3D).material_override=lift._cab_panel_visuals[0].material_override
	(model.find_child("RearEnamel",true,false) as MeshInstance3D).material_override=lift._cab_wall_finish
	for old: MeshInstance3D in lift._cab_panel_visuals: old.hide()
	lift._cabin.add_child(model)
	lift._cab_joinery=model


func _refine_cab_handrails(lift: OrisonElevator) -> void:
	var assembly := (preload("res://assets/props/lift_handrails.glb") as PackedScene).instantiate()
	var brass := lift._cab_handrails[0].material_override
	for old: MeshInstance3D in lift._cab_handrails: old.hide()
	for part in assembly.get_children():
		if part is MeshInstance3D: part.material_override = brass
	lift._cabin.add_child(assembly)
	lift._cab_rail_visual = assembly


func _refine_landing_panels(lift: OrisonElevator) -> void:
	var library := (preload("res://assets/props/lift_panels.glb") as PackedScene).instantiate()
	var meshes := {
		"w":(library.find_child("PanelWest",true,false) as MeshInstance3D).mesh,
		"e":(library.find_child("PanelEast",true,false) as MeshInstance3D).mesh}
	var kick_mesh := (library.find_child("KickPlate",true,false) as MeshInstance3D).mesh
	library.free()
	for level: String in lift.stop_order:
		for side: String in ["w","e"]:
			var body := lift._doors[level][side] as AnimatableBody3D
			var parts: Dictionary = lift._panel_visuals[body]
			(parts.skin as MeshInstance3D).mesh = meshes[side]
			(parts.kick as MeshInstance3D).mesh = kick_mesh
			var glass := parts.glass as MeshInstance3D
			var pane := BoxMesh.new()
			pane.size = Vector3(.108,.318,.006)
			glass.mesh = pane
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _refine_landing_frames(lift: OrisonElevator) -> bool:
	var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/lift_frame_mitres.json"))
	if decoded is not Dictionary or decoded.get("schema_version")!=1:return false
	var data: Dictionary=decoded
	if float(data.jamb_width)!=.09 or float(data.head_width)!=.14 or str(data.catalog_key)!="brass":return false
	var library: PackedScene=load(str(data.asset)) as PackedScene
	if library==null:return false
	var model:=library.instantiate()
	var meshes: Dictionary={}
	for row: Dictionary in data.parts:
		var draw:=model.find_child(str(row.name),true,false) as MeshInstance3D
		if draw==null or draw.mesh==null or draw.mesh.get_faces().size()!=int(row.triangles)*3 or meshes.has(str(row.member)):
			model.free();return false
		meshes[str(row.member)]=draw.mesh
	model.free()
	if meshes.size()!=3 or not meshes.has("west") or not meshes.has("east") or not meshes.has("head"):return false
	# Validate every original opening before replacing any visual. Moving
	# panels and shaft interlocks retain their original owners and collision.
	for level: String in lift.stop_order:
		var head:=lift._landing_frames[level]["head"] as MeshInstance3D
		var size: Vector3=(head.mesh as BoxMesh).size
		var clear_height: float=head.position.y-size.y*.5-float(lift.stops[level])
		if not is_equal_approx(size.x-.18,float(data.width)) or not is_equal_approx(clear_height,float(data.height)) or not is_equal_approx(size.z,float(data.depth)):return false
	var material:=MatLib.get_mat(str(data.catalog_key),Color(.62,.52,.28)).duplicate() as StandardMaterial3D
	material.uv1_triplanar=false
	material.uv1_scale=Vector3.ONE/float(MatLib.SETS[str(data.catalog_key)][3])
	material.normal_enabled=true
	material.normal_scale=.35
	for level: String in lift.stop_order:
		for member: String in ["west","east","head"]:
			var frame:=lift._landing_frames[level][member] as MeshInstance3D
			frame.mesh=meshes[member];frame.scale=Vector3.ONE;frame.rotation=Vector3.ZERO
			frame.position=Vector3(0,float(lift.stops[level]),OrisonElevator.FRONT_Z)
			frame.material_override=material
			frame.set_meta("native_lift_mitre_member",member)
	lift.set_meta("v2_lift_frame_mitre_stock",meshes)
	return true
