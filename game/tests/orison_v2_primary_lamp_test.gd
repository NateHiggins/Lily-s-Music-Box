extends Node
## Matched real-world night captures with room fixtures switched off. Measures
## rendered light contribution, not a constant-only brightness assertion.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var world: OrisonV2RuntimeRoot
var failures: Array[String] = []
var directory: String
var metrics: Array[Dictionary] = []

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if DisplayServer.get_name() == "headless" or directory.is_empty():
		push_error("Primary lamp comparison needs windowed captures")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	world = Runtime.instantiate()
	add_child(world)
	if world.startup_failed:
		get_tree().quit(2)
		return
	var player := world.player
	var air := world.get_node("LampAtmosphere")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.camera.make_current()
	var fixtures_off := 0
	for fixture: Node in world.find_children("*","Node",true,false):
		if fixture is LightFixtureProp:
			fixture.set_powered(false)
			fixtures_off += 1
	_check(fixtures_off >= 128,"room fixtures switched off for lamp-only comparison")
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var profile: float = player._lamp_base_energy
	_check(is_equal_approx(profile,24.0) and is_equal_approx(player.flashlight.spot_range,12.0),
			"primary light output and usable throw mounted")
	for station: Dictionary in [
		{"id":"home","at":Vector3(-11.4,0,-5.8),"look":Vector3(-14.7,1.0,-6.0)},
		{"id":"roof","at":Vector3(-11.5,19.2,1.8),"look":Vector3(-11.5,20.0,4.0)},
		{"id":"basement","at":Vector3(-4.5,-3.2,-1.5),"look":Vector3(-8,-2.2,-1.5)}]:
		player.global_position = world.adapter.root.to_global(station.at)
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(world.adapter.root.to_global(station.look))
		player.set_lamp_enabled(true)
		await get_tree().create_timer(1.0).timeout
		player.set_process(false)
		world.service_set_carrier.set_process(false)
		air.driver.state.configure(0x28A11CE,true)
		air.driver.state.advance(2.0)
		var levels := {}
		for energy: float in [0.0,1.5,4.2,profile]:
			player.set_lamp_base_energy(energy)
			air.driver.apply_output()
			await get_tree().create_timer(.5).timeout
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.save_png(directory.path_join(station.id+"_"+str(energy).replace(".","_")+".png"))
			levels[str(energy)] = _luminance(image)
		_check(air.field.ready and air.field.failed.is_empty() and air.field.enabled,
				"live voxel lamp in "+station.id)
		var gain: float = levels[str(profile)]-levels[str(0.0)]
		var old_gain: float = levels[str(1.5)]-levels[str(0.0)]
		metrics.append({"station":station.id,"luminance":levels,"gain":gain,"old_gain":old_gain})
		# Two percent linear scene luminance is a conservative lower bound for
		# this crop, which includes unlit ceiling and the dark washer metal.
		_check(gain > .02 and gain > old_gain*1.15,"brighter useful rendered beam in "+station.id)
		player.set_process(true)
		world.service_set_carrier.set_process(true)
	player.set_lamp_base_energy(profile)
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t",true,true))
	world.shutdown_for_tests()
	world.free()
	print("PRIMARY LAMP: ",metrics," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _luminance(image: Image) -> float:
	var total := 0.0
	var samples := 0
	# Central gameplay surface, excluding the held instrument and edge UI.
	for y in range(int(image.get_height()*.25),int(image.get_height()*.65),4):
		for x in range(int(image.get_width()*.30),int(image.get_width()*.70),4):
			var c := image.get_pixel(x,y).srgb_to_linear()
			total += c.r*.2126+c.g*.7152+c.b*.0722
			samples += 1
	return total/maxi(1,samples)

func _check(ok: bool,label: String) -> void:
	print("PRIMARY LAMP: ",label," = ",ok)
	if not ok: failures.append(label)
