extends "res://tests/orison_v2_lift_joinery_test.gd"
## Actual retained tie caps, imported slots, fixed plates and original walls.
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok,message)

func _shell_faces(shell: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for part in shell.get_children():
		if part is MeshInstance3D: faces.append_array(part.transform*part.mesh.get_faces())
	return faces

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production heating initializes with fitted ties")
	if world.player==null:
		world.free()
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var root: Node3D = world.adapter.root
	var owner := root.get_node("RadiatorTiePlates")
	var plate_poses: Array[Transform3D] = []
	var plate_faces := PackedVector3Array()
	var batches := 0
	for floor in owner.get_children():
		for draw: MultiMeshInstance3D in floor.get_children():
			check(draw.get_child_count()==0,"wall fitting adds no collision or service owner")
			check(draw.material_override==MatLib.get_mat(str(draw.name)),"existing catalogue finish on imported fitting")
			var mesh := draw.multimesh.mesh as ArrayMesh
			check(mesh!=null,"Blender plate and anchors use actual imported triangles")
			var arrays: Array = mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			check(points.size()>8 and uv.size()==points.size() and normals.size()==points.size() and tangents.size()==points.size()*4,"active UV, normal and tangent arrays cover each imported vertex")
			var mapped := true
			for i in points.size():
				mapped = mapped and points[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
				var tangent := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				mapped = mapped and tangent.is_finite() and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001
			check(mapped,"finite unit normals and orthogonal exported tangent basis")
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var metres := indices.size()>=3
			var ratio := 0.0
			for triangle in range(0,indices.size(),3):
				for edge in 3:
					var a := indices[triangle+edge]
					var b := indices[triangle+(edge+1)%3]
					var length := points[a].distance_to(points[b])
					var texture := uv[a].distance_to(uv[b])
					metres = metres and texture<=length+.00005
					if length>.01: ratio=maxf(ratio,texture/length)
			check(metres and absf(ratio-1)<.005,"metre UV scale survives compressed import precision")
			if str(draw.name)=="cast_iron":
				plate_faces = mesh.get_faces()
				for i in draw.multimesh.instance_count: plate_poses.append(draw.multimesh.get_instance_transform(i))
			batches += 1
	check(owner.get_child_count()==3 and batches==9 and plate_poses.size()==6,"six surveyed gaps fitted in three floor partitions and nine draws")
	check(not is_finite(_mesh_distance(plate_faces,Vector3(0,0,-.04),Vector3.BACK)),"slotted plate has a real central opening")
	check(is_finite(_mesh_distance(plate_faces,Vector3(.033,.02,-.04),Vector3.BACK)),"positive control meets the actual plate flange")
	for pose in plate_poses:
		var distance := _mesh_distance(plate_faces,Vector3(.033,.02,.04),Vector3.FORWARD)
		check(is_finite(distance) and absf(distance-.04)<.001,"actual back flange lies on its wall datum")
		var query := PhysicsRayQueryParameters3D.create(root.to_global(pose*Vector3(.033,.02,-.04)),root.to_global(pose*Vector3(.033,.02,.04)),1,[world.player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and str(hit.collider.get_parent().name).begins_with("Wall"),"plate is anchored against an existing physical wall")
		if not hit.is_empty(): check(absf((pose.affine_inverse()*root.to_local(hit.position)).z)<.001,"imported back flange and wall collision share a datum")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	var ties := 0
	var feeds := 0
	var fitted := 0
	for record: Dictionary in source.installed:
		var radiator := world.adapter.resolve(str(record.id)) as RadiatorProp
		check(radiator._balance==world.heat_balance,"original shared heat authority retained")
		var excluded: Array[RID] = [world.player.get_rid(),radiator.get_node("InstalledRadiatorCollision").get_rid()]
		var floor_query := PhysicsRayQueryParameters3D.create(radiator.to_global(Vector3(-.67,-.70,0)),radiator.to_global(Vector3(-.67,-.90,0)),1,excluded)
		var floor_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(floor_query)
		check(not floor_hit.is_empty() and str(floor_hit.collider.get_parent().name)=="Floor","retained one-pipe feed terminates at its existing floor slab")
		feeds += 1
		var faces := _shell_faces(radiator._shell)
		var half := float(radiator.section_count-1)*RadiatorProp.SECTION_PITCH*.5
		var poses := [-1.0,0.0,1.0] if str(record.unit) in ["2A","3A","4B"] else [radiator.pitch_toward_supply]
		for pitch: float in poses:
			radiator.set_pitch(pitch)
			for side in [-1.0,1.0]:
				var x: float = half*.55*float(side)
				var start := Vector3(x,.58,.12)
				var cap := _mesh_distance(faces,start,Vector3.BACK)
				check(is_finite(cap) and cap>.02,"actual retained tie has a closed outer cap")
				var query := PhysicsRayQueryParameters3D.create(radiator._shell.to_global(start),radiator._shell.to_global(start+Vector3.BACK*.40),1,excluded)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty(),"actual brace ray finds its existing wall")
				if hit.is_empty() or not is_finite(cap): continue
				var wall_distance := start.distance_to(radiator._shell.to_local(hit.position))
				check(cap>=wall_distance-.001,"tie reaches wall without a floating termination")
				if str(record.unit) in ["2A","3A","4B"]:
					check(absf(cap-wall_distance-.004)<.001,"corrected tie embeds 4 mm through its wall plate at every pitch pose")
					var at := root.to_local(radiator._shell.to_global(start+Vector3.BACK*cap))
					var matching := false
					for pose in plate_poses:
						var local := pose.affine_inverse()*at
						if absf(local.z-.004)>.001 or Vector2(local.x,local.y).length()>.03: continue
						matching = true
						for offset: Vector3 in [Vector3.RIGHT*.009,Vector3.LEFT*.009,Vector3.UP*.009,Vector3.DOWN*.009]:
							var ray_start := Vector3(local.x,local.y,-.04)+offset
							check(not is_finite(_mesh_distance(plate_faces,ray_start,Vector3.BACK)),"actual plate slot clears the pitched rod perimeter")
					check(matching,"pitched retained rod meets its fixed imported wall plate")
					fitted += 1
				ties += 1
	check(feeds==18 and ties==48 and fitted==18,"all feeds and 36 ties inspected; six corrected ties also cover three pitch poses")
	# Build only the legacy cast shell: no world, schedule or gameplay owner.
	var legacy := RadiatorProp.new()
	legacy.section_count = 7
	legacy._shell = Node3D.new()
	legacy.add_child(legacy._shell)
	legacy._build_sections(RadiatorProp.IRON_DARK)
	var old_faces := _shell_faces(legacy._shell)
	var legacy_half := 6*RadiatorProp.SECTION_PITCH*.5
	for side in [-1.0,1.0]:
		var distance := _mesh_distance(old_faces,Vector3(legacy_half*.55*float(side),.58,.12),Vector3.BACK)
		check(is_finite(distance) and absf(distance-.07)<.001,"unconfigured legacy shell retains its original 190 mm tie span")
	legacy.free()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	for unit: String in ["2A","3A","4B"]:
		var radiator := world.adapter.resolve("F0"+unit[0]+"_"+unit[1]+"_RADIATOR_01") as RadiatorProp
		radiator.set_pitch(.35)
		var half := float(radiator.section_count-1)*RadiatorProp.SECTION_PITCH*.5
		camera.global_position = radiator.to_global(Vector3(half*.55+.20,-.06,.13))
		camera.look_at(radiator.to_global(Vector3(half*.55,-.17,.25)))
		await shot(unit+"_fitted_tie")
	print("RADIATOR WALL TIES: checks=%d feeds=%d ties=%d pitched_fitted_ties=%d batches=%d failures=%d" % [checks,feeds,ties,fitted,batches,failures.size()])
	world.shutdown_for_tests()
	world.free()
	await get_tree().create_timer(.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
