extends "res://tests/harukiya_entry_visual.gd"
## Focused optical-owner checks on the actual nearby bar; no gameplay claim.
var tuning_fixture: LightFixtureProp
var original_tuning: Dictionary = {}
var original_color: Color
var original_emission: Color
var tuning_owned := false
var tuning_tested := false
var support_tested := false

func capture(label: String, settle: bool=true) -> void:
	if not tuning_tested and rig != null and bar != null:
		await _exercise_tuning()
	await super.capture(label,settle)
	if bar == null: return
	var rows: Array = bar.destination.spec.get("lighting",[])
	check(rows.size()==13,"thirteen authored optical fixtures")
	var seen: Dictionary = {};var cones := 0;var observed: Array = []
	for row: Dictionary in rows:
		var id: String = str(row.id)
		check(not seen.has(id),"distinct optical fixture "+id);seen[id]=true
		var fixture := bar.actors.get_node_or_null(id) as LightFixtureProp
		if not check(fixture!=null and fixture.light!=null,"actual optical actor/source "+id): continue
		check(fixture.global_position.is_finite() and fixture.light.global_position.is_finite(),"finite optical source "+id)
		var gain: float = float(HarukiyaStateDirector.FIXTURE_STATES.get(id,HarukiyaStateDirector.DEFAULT)[bar.hours._state])
		check(fixture.powered==(gain>0.0) and is_equal_approx(fixture._state_gain,gain),"hours/power authority "+id)
		var beam: SpotLight3D = fixture.get("pool") as SpotLight3D
		if row.has("target"):
			cones+=1
			if not check(beam!=null,"actual cone "+id): continue
			var target: Vector3 = bar.actors.to_global(GameBoot.b2g(row.target))
			check(target.is_finite() and beam.global_position.is_finite(),"finite beam target "+id)
			check(not fixture.light.shadow_enabled,"spill never allocates shadow "+id)
			check(not beam.shadow_enabled or (fixture.powered and fixture._target_scale>.001),"beam shadow respects enabled budget "+id)
			if settle and bar.hours._state==HarukiyaStateDirector.BarState.CLOSED and fixture._state_gain==0.0:
				check(absf(beam.light_energy)<.001 and absf(fixture.light.light_energy)<.001,"closed settled optical energy zero "+id)
			observed.append({"id":id,"beam":beam.global_transform,"target":target,"beam_energy":beam.light_energy,"spill_energy":fixture.light.light_energy,"beam_shadow":beam.shadow_enabled})
		else:
			check(beam==null,"noncone profile retains original source "+id)
			if settle and bar.hours._state==HarukiyaStateDirector.BarState.CLOSED and fixture._state_gain==0.0: check(absf(fixture.light.light_energy)<.001,"closed settled lamp energy zero "+id)
	check(cones==9,"nine actual authored cones")
	if not support_tested: _support_check();support_tested=true
	if not shots.is_empty():shots[-1].lighting_checks=observed

func _exercise_tuning() -> void:
	tuning_tested=true
	tuning_fixture=bar.actors.get_node_or_null("F01_BAR_LT_POOL") as LightFixtureProp
	if not check(tuning_fixture!=null and tuning_fixture.get("pool")!=null,"live tuning cone owner"):return
	original_tuning=rig.fixture_tuning(tuning_fixture)
	original_color=tuning_fixture.light.light_color;original_emission=tuning_fixture._bulb_mat.emission
	tuning_owned=true
	var changes: Dictionary={"range":3.7,"temperature":3100.0,"attenuation":1.7,"source_size":.19,"shadow_opacity":.67}
	for key: String in changes:rig.set_fixture_tuning(tuning_fixture,key,float(changes[key]))
	await wait_seconds(.4)
	var beam: SpotLight3D=tuning_fixture.get("pool") as SpotLight3D
	check(is_equal_approx(beam.spot_range,3.7) and is_equal_approx(beam.spot_attenuation,1.7),"live range/attenuation reaches cone")
	check(beam.light_color.is_equal_approx(rig._temperature_color(3100.0)),"live temperature reaches cone")
	check(is_equal_approx(beam.light_size,.19) and is_equal_approx(beam.shadow_opacity,rig.shadow_opacity*.67),"live size/shadow opacity reaches cone")
	_restore_tuning()
	await wait_seconds(.4)
	check(beam.light_color.is_equal_approx(original_color) and is_equal_approx(beam.spot_range,float(original_tuning.range)),"original cone tuning restored before capture")

func _restore_tuning() -> void:
	if not tuning_owned:return
	if is_instance_valid(rig) and is_instance_valid(tuning_fixture):
		for key: String in original_tuning:rig.set_fixture_tuning(tuning_fixture,key,float(original_tuning[key]))
		# Original authored RGB need not exactly invert the rig Kelvin estimate.
		tuning_fixture.light.light_color=original_color
		tuning_fixture._bulb_mat.emission=original_emission
	tuning_owned=false

func _support_check() -> void:
	var geometry: Node3D=bar.get_node("RetainedBarGeometry")
	var saved: Dictionary=geometry.get_meta("harukiya_fixture_mount_relocations",{})
	check(saved.has("F01_BAR_LT_DECK2"),"gallery relocation custody metadata")
	if saved.has("F01_BAR_LT_DECK2"):
		check(saved.F01_BAR_LT_DECK2.source_at==[3.92,-32.05,-1.3] and saved.F01_BAR_LT_DECK2.at==[.52,-34.2,1.8],"gallery exact authored rigid translation")
	var mounts_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bar_fixture_mounts.json"))
	var packed: PackedScene=load(str(mounts_data.asset)) as PackedScene
	if not check(packed!=null,"original mount model available for transform comparison"):return
	var pristine: Node3D=packed.instantiate() as Node3D
	var exclude: Array[RID]=[];var found := 0
	for draw: MeshInstance3D in geometry.get_node("BarFixtureMounts").find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("bar_fixture_mount_part","")) in ["F01_BAR_LT_DECK2__brass_dull","F01_BAR_LT_DECK2__iron_blackened"]:
			found+=1
			var identity: String=str(draw.get_meta("bar_fixture_mount_part",""))
			var matches: Array=pristine.find_children(identity,"MeshInstance3D",true,false)
			if check(matches.size()==1,"unique original support transform "+identity):
				var original: MeshInstance3D=matches[0]
				var expected_pose: Transform3D=original.transform
				expected_pose.origin+=GameBoot.b2g([.52,-34.2,1.8])-GameBoot.b2g([3.92,-32.05,-1.3])
				check(draw.transform.is_equal_approx(expected_pose),"actual rigid native support transform "+identity)
			for body: CollisionObject3D in draw.find_children("*","CollisionObject3D",true,false):exclude.append(body.get_rid())
	pristine.free()
	check(found==2,"both actual native gallery support parts")
	var query:=PhysicsRayQueryParameters3D.create(bar.to_global(GameBoot.b2g([.55,-34.2,1.8])),bar.to_global(GameBoot.b2g([.66,-34.2,1.8])))
	query.exclude=exclude
	var hit: Dictionary=bar.get_world_3d().direct_space_state.intersect_ray(query)
	var expected: Vector3=bar.to_global(GameBoot.b2g([.6,-34.2,1.8]))
	check(not hit.is_empty() and (hit.position as Vector3).distance_to(expected)<.008,"gallery bearing meets real wall excluding own mounts")
	if not shots.is_empty():shots[-1].gallery_support={"expected":expected,"hit_position":hit.get("position"),"collider_path":str(hit.collider.get_path()) if hit.has("collider") else "","excluded_bodies":exclude.size()}

func finish() -> void:
	_restore_tuning()
	await super.finish()
