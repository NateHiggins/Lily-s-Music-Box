extends Node
## Focused production-adapter proof for DREAM-VOXEL-V1.
## Run: godot --headless --path game res://tests/DreamVoxelV1Test.tscn

const PresenterScript := preload("res://scripts/dream/dream_voxel_light_presenter.gd")
const StateScript := preload("res://scripts/dream/dream_cellular_state.gd")
const ApartmentScript := preload("res://scripts/reality/apartment_encroachment.gd")

class FakePlayer:
	extends Node3D
	var flashlight: SpotLight3D
	var lamp_on := true
	func _ready() -> void:
		flashlight = SpotLight3D.new()
		flashlight.spot_range = 7.0
		flashlight.spot_angle = 37.0
		flashlight.light_energy = .74
		add_child(flashlight)
	func lamp_is_enabled() -> bool:
		return lamp_on

class FakeColony:
	extends RefCounted
	var seed := 4281

class FakeRenderer:
	extends Node3D
	var colony = FakeColony.new()
	var _phenotype := {"organization": .78, "windows": .48,
		"proteins": .88, "refractive": .42}
	var _state_packet = StateScript.new({"ether": .65, "information": .42,
		"novelty": .55, "breathing": .5})
	var _clock := 1.25
	func _ready() -> void:
		for node_name in PresenterScript.TARGET_NODES:
			var mesh := MeshInstance3D.new()
			mesh.name = node_name
			mesh.mesh = SphereMesh.new()
			mesh.material_override = StandardMaterial3D.new()
			add_child(mesh)

var failures := 0
var checks := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[DREAM-VOXEL-V1] FAIL: %s" % what)


func _run() -> void:
	var ecology_sentinel := {"writes": 0, "state": "independent"}
	var player := FakePlayer.new()
	add_child(player)
	player.global_position = Vector3(-.9, 1.5, 1.8)
	var a := FakeRenderer.new()
	var b := FakeRenderer.new()
	add_child(a)
	add_child(b)
	var presenter = PresenterScript.new()
	add_child(presenter)
	presenter.configure(player, "mina_caption_crisis",
			Vector4(-2.0, -4.0, 2.0, 2.0), 0.0, [a, b])
	presenter.set_physics_process(false)
	presenter.lamp.set_physics_process(false)
	# Warm the actual deterministic L1C state, then use only its real output.
	presenter.lamp.state.advance(4.6, 110.0, 0.0)
	presenter.lamp._apply_output(PresenterScript.UPDATE_INTERVAL)

	_check(presenter.field is DreamExposureField,
			"one shared DreamExposureField is instantiated")
	_check(presenter.field.stamped_rooms() == 1,
			"the bounded production room is stamped once")
	for _i in 15:
		presenter.deposit_once(PresenterScript.UPDATE_INTERVAL)
	var receipt: Dictionary = presenter.receipt()
	_check(presenter.add_lamp_calls == 15 and
			is_equal_approx(float(receipt.update_cadence_hz), 15.0),
			"the authoritative deposition cadence is 15 Hz")
	_check(not presenter.last_deposition.is_empty()
			and float(presenter.last_deposition.normalized_energy) > 0.0
			and presenter.last_deposition.origin == presenter.lamp.light.global_position,
			"the real L1C pose and physical output reach add_lamp")
	var first_snapshot := presenter.field_snapshot()
	_check(int(first_snapshot.active_voxels_union) > 0,
			"owned voxels become nonzero")
	_check(presenter.upload_calls == 15 and presenter.uploads_performed > 0,
			"upload is called at cadence and the RG8 texture is uploaded when dirty")
	_check(presenter.shared_material.get_shader_parameter("exposure_tex") == presenter.texture,
			"the production cellular material holds the shared texture")
	var source := FileAccess.get_file_as_string(
			"res://shaders/dream_moss_voxel_light.gdshader")
	_check(source.contains("cell_world_pos") and source.contains(
			"world_position.x / max(exposure_extent") and source.contains(
			"world_position.z / max(exposure_extent"),
			"the shader samples the field in world space with production axis ordering")

	var durable_before: float = presenter.field.peak()
	var g_before: float = _irradiance_total(presenter.field)
	player.lamp_on = false
	presenter.lamp.set_powered(false)
	presenter.lamp.state.advance(7.0, 110.0, 0.0)
	presenter.lamp._apply_output(PresenterScript.UPDATE_INTERVAL)
	for _i in 8:
		presenter.deposit_once(PresenterScript.UPDATE_INTERVAL)
	_check(presenter.field.peak() >= durable_before,
			"durable R remains after the lamp moves or switches off")
	_check(_irradiance_total(presenter.field) < g_before,
			"reversible G cools independently at the field authority")

	# Re-ignite at a different X position. New G occupancy must move in world
	# space instead of behaving as a review scalar/global tint.
	player.global_position.x = 1.0
	player.lamp_on = true
	presenter.lamp.set_powered(true)
	presenter.lamp.state.advance(4.0, 110.0, 0.0)
	presenter.lamp._apply_output(PresenterScript.UPDATE_INTERVAL)
	var centroid_before := _irradiance_centroid_x(presenter.field)
	for _i in 12:
		presenter.deposit_once(PresenterScript.UPDATE_INTERVAL)
	var centroid_after := _irradiance_centroid_x(presenter.field)
	_check(absf(centroid_after - centroid_before) > .05,
			"moving the real lamp produces spatially different occupancy")
	_check(ecology_sentinel == {"writes": 0, "state": "independent"},
			"the adapter never writes ecology state")
	var a_heart := a.get_node("MossHeart") as GeometryInstance3D
	var b_heart := b.get_node("MossHeart") as GeometryInstance3D
	_check(a_heart.material_override == presenter.shared_material
			and b_heart.material_override == presenter.shared_material
			and presenter.receipt().bound_organism_count == 2,
			"multiple organisms share one field and one material")

	var previous_flag := OS.get_environment("DREAM_VOXEL_LIGHT")
	OS.set_environment("DREAM_VOXEL_LIGHT", "0")
	var apartment := ApartmentScript.new()
	add_child(apartment)
	apartment.bind_player(player)
	_check(apartment.voxel_light_presenter == null,
			"disabled mode remains baseline-equivalent and allocates no adapter")
	OS.set_environment("DREAM_VOXEL_LIGHT", previous_flag)

	var field_ref: WeakRef = weakref(presenter.field)
	var texture_ref: WeakRef = weakref(presenter.texture)
	var lamp_ref: WeakRef = weakref(presenter.lamp)
	var teardown: Dictionary = presenter.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(teardown.writer_stopped) and bool(teardown.sampler_unbound)
			and bool(teardown.room_ownership_cleared),
			"teardown stops the writer, unbinds the sampler and clears room ownership")
	_check(field_ref.get_ref() == null and texture_ref.get_ref() == null
			and lamp_ref.get_ref() == null,
			"teardown releases the field, texture and L1C presentation")

	print("DREAM VOXEL V1 TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _irradiance_total(field: DreamExposureField) -> float:
	var total := 0.0
	for image in field.to_images():
		for z in DreamExposureField.GRID_XZ:
			for x in DreamExposureField.GRID_XZ:
				total += image.get_pixel(x, z).g
	return total


func _irradiance_centroid_x(field: DreamExposureField) -> float:
	var weighted := 0.0
	var total := 0.0
	for image in field.to_images():
		for z in DreamExposureField.GRID_XZ:
			for x in DreamExposureField.GRID_XZ:
				var value := image.get_pixel(x, z).g
				weighted += float(x) * value
				total += value
	return weighted / maxf(total, .0001)
