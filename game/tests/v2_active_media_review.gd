extends "res://tests/orison_v2_apartment_batch_test.gd"
## Reuse existing support, reach, control and decoder tests in one real world.
var retained: Array[WeakRef] = []

func _ready() -> void:
	pass # This validator is called by the composed surface sweep.

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	_authoring_proof = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_authoring_proof.json"))
	_check_household_radios(world, retained)
	await _check_projectors(world, retained)
	_check_ac_supplies(world)
	for radio: Node in world.find_children("DomesticRadio_*", "Node3D", true, false):
		if not radio is DomesticRadioProp: continue
		check(radio.has_meta("v2_native_active_receiver"), "active receiver uses native stock")
		for draw: MeshInstance3D in radio.find_children("*", "MeshInstance3D", true, false):
			check(draw.mesh is ArrayMesh and draw.has_meta("native_active_radio_part"), "receiver has no prototype visible stock")
	for unit in ["2A", "3B", "4B"]:
		var prop := world.adapter.resolve(unit+"_tv") as ProjectorProp
		check(prop != null and prop.get_meta("v2_native_active_projector",false), "projector uses native machine stock")
		if prop == null: continue
		check(prop.glass.mesh is ArrayMesh and prop.glass.get_meta("native_projector_lens",false), "original lens owner has fitted native optics")
		check(prop._spin.size() == 8, "original eight reel motions retained")
		for disc in prop._spin:
			check(disc.mesh is ArrayMesh and disc.basis.y.normalized().dot(Vector3.LEFT)>.999, "native reel keeps original spindle axis and rotation direction")
	await _capture_media(world)
	return {"checks":checks,"failures":failures.duplicate()}

func _check_ac_supplies(world: OrisonV2RuntimeRoot) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/media_ac_supply.json"))
	check(data.installations.size()==10,"seven AC receivers and three projectors have fitted supply")
	for row: Dictionary in data.installations:
		var appliance := world.adapter.resolve(str(row.id)) as Node3D
		var support := world.adapter.resolve(str(row.support)) as Node3D
		var ref: WeakRef=appliance.get_meta("v2_media_ac_supply",null)
		check(ref!=null,"AC appliance has a supply owner")
		if ref==null: continue
		var root := ref.get_ref() as Node3D
		check(root!=null and root.get_parent()==support,"AC route remains in original furniture frame")
		if root==null: continue
		retained.append(ref)
		check(root.get_child_count()==4,"lead gland clip and receptacle are present")
		for draw: MeshInstance3D in root.get_children():
			check(draw.mesh is ArrayMesh,"AC supply uses native UV stock")
			retained.append(weakref(draw))
		var outlet := root.get_node("FloorReceptacle") as MeshInstance3D
		var query := PhysicsRayQueryParameters3D.create(outlet.global_position+Vector3.UP*.015,outlet.global_position-Vector3.UP*.025)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and abs(hit.position.y-outlet.global_position.y)<.001 and hit.normal.y>.99,"floor receptacle bears on actual installed floor")

func _capture_media(world: OrisonV2RuntimeRoot) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	var camera := Camera3D.new(); camera.fov=50; world.add_child(camera)
	world.player.carried_device.set_capture_hidden(true)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_radios.json"))
	for record: Dictionary in source.receivers:
		var unit := str(record.unit)
		var radio := world.adapter.resolve("DomesticRadio_"+unit) as DomesticRadioProp
		var stance := world.adapter.resolve("DomesticRadio_"+unit+"_STANCE") as Node3D
		if radio == null or stance == null: continue
		camera.global_position=stance.global_position+Vector3.UP*1.41
		camera.look_at(radio.to_global(Vector3(0,.15,0)),Vector3.UP);camera.make_current()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("media_radio_"+unit+".png"))
	for unit in ["2A", "3B", "4B"]:
		var prop := world.adapter.resolve(unit+"_tv") as ProjectorProp
		var stance := world.adapter.resolve(unit+"_tv_STANCE") as Node3D
		if prop == null or stance == null: continue
		var was_on := prop.player_on
		if not was_on: prop.interact(world.player)
		camera.global_position=stance.global_position+Vector3.UP*1.41
		camera.look_at(prop.to_global(Vector3(0,.25,0)),Vector3.UP);camera.make_current()
		await get_tree().create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("media_projector_"+unit+".png"))
		if not was_on: prop.interact(world.player)
	camera.free();world.player.camera.make_current()

func validate_after_teardown() -> Dictionary:
	for ref in retained: check(ref.get_ref() == null, "media owner/control/decoder retires with original support")
	return {"checks":checks,"failures":failures.duplicate()}
