extends Node3D
## Nearby prepared actor/hour/transaction-anchor diagnostic, not installed commerce/save proof.
const ActorPatch := preload("res://scripts/building/orison_v2_arcade_actor_projection.gd")
const Hours := preload("res://scripts/building/passage_hours_director.gd")
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Carrier := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
class Host extends "res://scripts/building/orison_v2_passage_region.gd":
	func _ready() -> void: pass
var failures: Array[String] = []
var observations: Array = []
var checks := 0
var logger = preload("res://tests/guide_bell_error_capture.gd").new()
var host: Host
var service: MaintenanceShopService
var hours: PassageHoursDirector
var projected: Dictionary
var output := ""
var original: Dictionary
var original_text := ""
var original_graph: Dictionary
var old_mouse: int
var camera: Camera3D

func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);print("ARCADE ACTOR FAIL: ",label)
	return ok
func _ready() -> void:run.call_deferred()

func _legacy(layout: Dictionary) -> void:
	var legacy := Hours.new();add_child(legacy);legacy.set_process(false)
	var specs: Array = legacy._shopfront_specs(layout)
	var expected: Array[Transform3D] = []
	for spec: Dictionary in specs:legacy._append_closed_lattice(spec,expected)
	var batch := legacy._build_grille_batch("UnchangedSideBayControl",specs,false)
	var exact := batch.multimesh.instance_count == expected.size()
	for index: int in expected.size(): exact = exact and batch.multimesh.get_instance_transform(index).is_equal_approx(expected[index])
	check(exact,"all original side-bay grille placements unchanged")
	legacy.free()

func _bounds() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_actor_projection.json"))
	for row: Dictionary in fixture.anchors:
		var family := "hardware_stock" if row.cell == "shop_hardware_paint" else "news_fittings"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/"+family+".json"))
		check(str(data.asset) == "res://"+str(row.native_source.asset).trim_prefix("game/") and FileAccess.get_sha256(str(data.asset)) == str(row.native_source.asset_sha256),"exact admitted native transaction asset bytes")
		var native := (load(str(data.asset)) as PackedScene).instantiate() as Node3D
		var identity := str(row.id).trim_suffix("_top")+"__countertop"
		var draw := native.find_child(identity,true,false) as MeshInstance3D
		if check(draw != null,"actual loaded transaction countertop " + identity):
			var helper := Carrier.new()
			var pose: Transform3D = helper._matrix(row.delta_transform)*helper._relative(draw,native)
			var bounds := pose*draw.mesh.get_aabb()
			var record: Dictionary = row.target_record
			var rect: Array = record.rect
			var expected := AABB(Vector3(rect[0],record.z0,-rect[3]),Vector3(float(rect[2])-float(rect[0]),record.h,float(rect[3])-float(rect[1])))
			check(bounds.position.distance_to(expected.position)<.00005 and bounds.end.distance_to(expected.end)<.00005,"projected transaction anchor matches actual native top bounds")
			observations.append({"kind":"native_transaction_bounds","id":row.id,"low":[bounds.position.x,bounds.position.y,bounds.position.z],"high":[bounds.end.x,bounds.end.y,bounds.end.z]})
		native.free()
	var counter := service.counter("hardware_paint")
	check(counter != null,"existing V2 maintenance service counter mounted")
	if counter != null:
		var record: Dictionary
		for floor: Dictionary in projected.floors:
			if floor.id != "F01":continue
			for item: Dictionary in floor.furniture:
				if item.id == "storm_shop_hardware_paint_counter_top":record=item
		var r: Array = record.rect
		var local := GameBoot.b2g([(float(r[0])+float(r[2]))*.5,(float(r[1])+float(r[3]))*.5,float(record.z0)+float(record.h)+MaintenanceShopService.REACH_H*.5])
		check(counter.global_position.distance_to(host.to_global(local))<.00001,"existing counter adapter applies final Vantry frame exactly once")
	var stand := host._actors.get_node_or_null("NewsStand") as NewsRackProp
	check(stand != null and stand.hours == hours,"real newspaper control uses existing hours authority")

func _state(minute: float,closed: bool) -> void:
	hours.apply_for_minute(minute)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(hours.is_after_hours()==closed,"ordinary authored hours state " + str(minute))
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_door_frames.json"))
	for row: Dictionary in frames.frames:
		if not bool(row.paired):continue
		var matrix: Transform3D = Carrier.new()._matrix(row.frame_transform)
		var centre := matrix*Vector3(float(row.width)*.5,.95,-.16)
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.8
		query.shape=capsule;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,host.to_global(centre));query.margin=.001
		var hits := get_world_3d().direct_space_state.intersect_shape(query,16)
		var gate_hit := hits.any(func(hit: Dictionary)->bool:return hit.collider == hours._barrier)
		check(gate_hit == (closed and row.cell != "shop_hardware_paint"),"actual relocated grille collision/hour policy " + str(row.cell))
	for spec: Dictionary in hours.shop_specs:
		var suffix := str(spec.id).trim_prefix("SITE_SHOP_HOURS_")
		for prefix: String in Hours.SHOP_LIGHT_PREFIXES:
			var lamp := host._actors.get_node_or_null(NodePath(prefix+suffix)) as LightFixtureProp
			if lamp == null:continue
			var expected := 1.0
			if closed and str(spec.trade) != Hours.NIGHT_SERVICE_TRADE:
				expected=float(Hours.NIGHT_SECURITY_GAIN.get(str(spec.trade),0)) if prefix == Hours.NIGHT_SECURITY_FIXTURE else 0.0
			check(is_equal_approx(lamp._state_gain,expected) and lamp.powered == (expected>0),"existing per-trade light policy follows moved marker " + str(lamp.name))
	var stand := host._actors.get_node("NewsStand") as NewsRackProp
	check(stand.shuttered()==closed,"newspaper shutter state retained")
	for frame: int in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():check(get_viewport().get_texture().get_image().save_png(output.path_join("hours_"+str(int(minute))+".png"))==OK,"actual projected hours frame")

func run() -> void:
	OS.add_logger(logger);output=OS.get_environment("SHOT_DIR")
	if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
	original=RealityState.data;original_text=JSON.stringify(original,"",true,true);original_graph=AcousticGraphData.nodes.duplicate(true);old_mouse=Input.mouse_mode
	if not check(RealityState.begin_preview_campaign(self),"isolated campaign"):get_tree().quit(1);return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ActorPatch.DATA))
	var source_text := FileAccess.get_file_as_string(ActorPatch.SOURCE)
	var layout: Dictionary = JSON.parse_string(source_text)
	_legacy(layout)
	for kind: String in ["missing","duplicate","nonspatial","nonfinite","source","anchor_authority"]:
		var bad := spec.duplicate(true)
		match kind:
			"missing":bad.markers.pop_back()
			"duplicate":bad.markers[1]=bad.markers[0]
			"nonspatial":bad.markers[0].patch.energy=0
			"nonfinite":bad.markers[0].patch.pos[0]=INF
			"source":bad.source_sha256_lf="changed"
			"anchor_authority":bad.anchors[0].patch.price_cents=0
		var refused := ActorPatch.new();check(refused.prepare(bad).is_empty() and not refused.errors.is_empty(),"reject authority/coverage mutation " + kind)
	var helper := ActorPatch.new();projected=helper.prepare(spec)
	if not check(not projected.is_empty(),"same-ID spatial projection admitted " + str(helper.errors)):get_tree().quit(1);return
	var input_text := JSON.stringify(spec,"",true,true)
	var scratch := helper.prepare(spec)
	for floor: Dictionary in scratch.floors:
		if floor.id != "F01":continue
		for marker: Dictionary in floor.markers:
			if marker.id == spec.markers[0].id:marker.pos[0]+=100
		for item: Dictionary in floor.furniture:
			if item.id == spec.anchors[0].id:item.rect[0]-=100
	check(JSON.stringify(spec,"",true,true)==input_text,"returned layout does not share mutable marker/anchor arrays with intake")
	check(helper.prepare(spec)==projected,"repeat preparation returns exact independent spatial state")
	service=preload("res://scripts/game/v2_maintenance_shop_service.gd").new();add_child(service);service.setup(null,null)
	check(service.is_valid(),"existing stock definitions valid")
	host=Host.new();host.name="PreparedActorHost";host.position.z=-9.795;add_child(host)
	host.source_layout=projected;host.shop_service=service;host._actors=Node3D.new();host._actors.name="PassageActors";host.add_child(host._actors)
	var identities := PackedStringArray()
	for row: Dictionary in spec.markers:identities.append(str(row.id))
	host._mount_markers(projected,identities)
	check(host._signs.size()==11 and host.doors.is_empty(),"existing marker factory mounts only eleven same-ID signs and39lights")
	var lamps := 0
	for actor: Node in host._actors.get_children():
		if actor is LightFixtureProp:lamps+=1
	check(lamps==39,"all39original fixture actors retained")
	hours=Hours.new();host._actors.add_child(hours);hours.build(host._actors,projected,[]);hours.set_process(false)
	host.finish=PassageFinishPass.new();host.finish.hours_director=hours;host._actors.add_child(host.finish)
	for sign_prop: ShopSignProp in host._signs:sign_prop.bind_hours_director(hours)
	host._mount_counters();check(host._mount_news_stand(),"existing newspaper stand factory mounted")
	_bounds()
	var shell_loader := Shell.new();var shell := shell_loader.prepare(JSON.parse_string(FileAccess.get_file_as_string(Shell.DATA)))
	if check(shell != null,"actual prepared shell admitted"):host.add_child(shell)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.05,.06,.08);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.18;add_child(env)
	camera=Camera3D.new();host.add_child(camera);camera.fov=75
	var target := Vector3.ZERO
	for record: Dictionary in hours.shop_specs:
		if record.trade == "hardware":target=record.position
	camera.look_at_from_position(host.to_global(Vector3(target.x,1.65,target.z-6)),host.to_global(Vector3(target.x,1.4,target.z)));camera.make_current()
	await _state(750,false);await _state(180,true);await _state(750,false)
	check(FileAccess.get_file_as_string(ActorPatch.SOURCE)==source_text,"immutable fabrication bytes unchanged")
	host.free();host=null;service.free();service=null
	for frame: int in 4:await get_tree().process_frame
	check(AcousticGraphData.nodes==original_graph,"all original acoustic positions restored")
	check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,original) and JSON.stringify(original,"",true,true)==original_text,"exact campaign restored")
	Input.mouse_mode=old_mouse
	check(logger.errors.is_empty(),"no engine/teardown errors")
	OS.remove_logger(logger)
	if not output.is_empty():FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Prepared same-ID marker factory/hour/light/transaction-anchor diagnostic only; no installed service purchase/save/residency/art acceptance","checks":checks,"failures":failures,"engine_errors":logger.errors,"observations":observations},"\t"))
	print("ARCADE ACTOR RESULT: %d checks / %d failures" % [checks,failures.size()]);get_tree().quit(0 if failures.is_empty() else 1)
