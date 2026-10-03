extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var failures: Array[String] = []
var contacts := 0
var checks := 0
var microscopic_arrises := 0

func _ready() -> void:
	call_deferred("_run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY COMPOSITION: " + label)

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	var original: Dictionary = AcousticGraphData.nodes["F01_BAR_LT_STAIR"].duplicate(true)
	for iteration in 2:
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(not world.startup_failed,"composed city starts")
		if world.startup_failed: break
		check(world.passage_region.cell_nodes.size()==13,"arcade roster stays separate from the bar")
		var street := world.exterior_cell.instance_node("STREET_ORISON_01")
		for identity in ["orison_upper_mass","orison_facade_left","orison_window_center","orison_threshold_step"]:
			check(not street.has_node(NodePath(identity)),"duplicate entry geometry removed: " + identity)
		check(world.bar_region.actors.get_node("F01_BAR_WC_SINK_01") is TapProp,"sanitary control retains its original owner")
		check(world.bar_region.actors.get_node("F01_BAR_SONGBOOK") is SongbookTerminalProp,"recording control retains its original owner")
		var fixtures := world.bar_region.hours._fixtures()
		check(fixtures.size()==18,"complete registered bar lighting roster")
		for minute in [20*60,3*60,12*60]:
			var state := HarukiyaStateDirector.state_for(minute)
			world.bar_region.hours._apply(state)
			for fixture: LightFixtureProp in fixtures:
				var expected: float = HarukiyaStateDirector.FIXTURE_STATES.get(str(fixture.name),HarukiyaStateDirector.DEFAULT)[state]
				check(is_equal_approx(fixture._state_gain,expected),"existing hours direct actual fixture: " + str(fixture.name))
		var shells := world.get_node("CityShells")
		var meshes: Array[MeshInstance3D]=[]
		for draw: MeshInstance3D in shells.find_children("*","MeshInstance3D",true,false):
			if draw.get_meta("retained_city_shell",false):meshes.append(draw)
		check(meshes.size()==84,"building and material partitions retained")
		for mesh: MeshInstance3D in meshes:
			var material := mesh.material_override as StandardMaterial3D
			check(material!=null and material.albedo_texture!=null and material.normal_texture!=null,
					"catalogued city maps reach exported geometry")
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"active metre UV channel exports")
				check(arrays[Mesh.ARRAY_NORMAL].size()==arrays[Mesh.ARRAY_VERTEX].size(),"exported normals")
				check(arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"exported tangents")
			var faces := mesh.mesh.get_faces()
			for index in range(0,faces.size(),maxi(3,int(faces.size()/9)*3)):
				var a: Vector3=faces[index];var b: Vector3=faces[index+1];var c: Vector3=faces[index+2]
				var cross := (c-a).cross(b-a)
				# Microscopic bevel-tip triangles are below structural probe
				# scale. The broad faces still check each physical partition.
				if cross.length()<.0002:
					microscopic_arrises += 1
					continue
				var normal := cross.normalized()
				var center := (a+b+c)/3.0
				var ray := PhysicsRayQueryParameters3D.create(mesh.to_global(center+normal*.015),
					mesh.to_global(center-normal*.015),1,[world.player.get_rid()])
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and mesh.to_global(center).distance_to(hit.position)<.016,
						"visible city surface has fitted physical backing")
				contacts += 1
		world.shutdown_for_tests()
		world.free()
		await get_tree().physics_frame
		check(AcousticGraphData.nodes["F01_BAR_LT_STAIR"]==original,"bar teardown restores the original acoustic frame")
	check(contacts>400,"structural contact sample covers the city partitions")
	print("CITY COMPOSITION: checks=%d contacts=%d microscopic_arrises=%d failures=%d" % [checks,contacts,microscopic_arrises,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
