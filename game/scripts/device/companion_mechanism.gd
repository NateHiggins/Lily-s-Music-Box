extends Node3D
## Native accessory animator. Radio, lamp, print and work state stay on `device`.
## Created explicitly by a companion presentation; no production autoload.
signal keyboard_settled(open: bool)
const DATA := "res://data/device/service_companion_v2.json"
const KEY_TRAVEL:=.0014
var typing_arm:Node
var _closed_keyboard_hold:WeakRef
var temporal_register:Node
var feed_replacement_draws:Array[MeshInstance3D]=[]
var _automatic_key:=-1
var _automatic_depth:=0.0
var device: ServiceSetProp
var model: Node3D
var keyboard: Node3D
var keyboard_carriage: Node3D
var _keyboard_home := Vector3.ZERO
var _keyboard_retraction := 0.0
var _stay_half_span := .094
var latch: Node3D
var keys: MultiMeshInstance3D
var key_legends: Node3D
var display: Node3D
var glazing: MeshInstance3D
var glazing_film: ShaderMaterial
var _glass_inside := 0.0
var _glass_outside := 0.0
var failures: Array[String] = []
var keyboard_requested := false
var keyboard_open := 0.0
var propulsion := 1.0
var motion_intensity := 1.0
var _opening_degrees := 90.0
var _key_names: Array[String] = []
var _key_homes: Array[Transform3D] = []
var _depressions: Array[float] = []
var _key_draws: Array[GeometryInstance3D] = []
var _key_instances: Array[int] = []
var _key_labels: Array[Label3D] = []
var _rotors: Array[Node3D] = []
var _stays: Dictionary = {}
var _latch_sound: AudioStreamPlayer3D
var _key_sound: AudioStreamPlayer3D
var _settled := true
var _last_latched := true
var _rotor_angle := 0.0
var _display_clock := 0.0
var face_emotion:="" # Transient presentation, set only by the carrier's input owner.
var reaction_player: Node
var _reaction_clock := 0.0
var profile_callbacks := false
var callback_records: Array[Dictionary] = []

func build() -> bool:
	var packed := load("res://assets/props/service_companion_v2.glb") as PackedScene
	if packed == null: return _fail("Companion native scene is not imported")
	device = ServiceSetProp.new()
	device.model_scene = packed
	device.stock_applier = preload("res://scripts/device/companion_stock.gd").apply
	device.phosphor_stock = true
	add_child(device)
	if not device.presentation_ready: return _fail("Original radio/printer presentation failed to bind")
	model = device.teletype.model
	if not _install_feed_knobs():return _fail("Native feed-knob replacement refused")
	# Excited phosphor marks are opaque, so put their masked glyphs into the opaque
	# scene before the reading glass samples it. Keep ordinary depth testing.
	for label: Label3D in [device.teletype.ink, device.teletype.heading, device.teletype.footer]:
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	keyboard = model.find_child("CompanionKeyboard", true, false)
	latch = model.find_child("CompanionKeyboardLatch", true, false)
	if keyboard == null or latch == null: return _fail("Companion keyboard pivots missing")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var hinge: Array = data.keyboard_hinge
	if keyboard.position.distance_to(Vector3(hinge[0], hinge[1], hinge[2])) > .00001:
		return _fail("Companion hinge datum differs from native source")
	_opening_degrees = float(data.keyboard_open_degrees)
	_keyboard_home = keyboard.position
	_keyboard_retraction = float(data.get("keyboard_retraction_m", 0.0))
	_stay_half_span = float(data.keyboard_stay_half_span_m)
	if not is_finite(_stay_half_span) or _stay_half_span < .05 or _stay_half_span > .10:
		return _fail("Keyboard support span is invalid")
	keyboard_carriage = model.find_child("CompanionKeyboardCarriage", true, false)
	if keyboard_carriage == null or not is_equal_approx(_keyboard_retraction, .045):
		return _fail("Retracting keyboard carriage datum missing")
	if not is_equal_approx(_opening_degrees, 90.0): return _fail("Unsupported keyboard stop")
	var blank := model.find_child("CompanionKeyBlank__CompanionKeys", true, false) as MeshInstance3D
	if blank == null or blank.mesh == null: return _fail("Reusable native keycap missing")
	keys = MultiMeshInstance3D.new()
	keys.name = "KeyboardKeycaps"
	keys.layers = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	keys.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	keys.multimesh = MultiMesh.new()
	keys.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	keys.multimesh.mesh = blank.mesh
	keys.multimesh.instance_count = 40
	keys.material_override = blank.get_active_material(0)
	keyboard.add_child(keys)
	key_legends = Node3D.new()
	key_legends.name = "PhysicalKeyLegends"
	keyboard.add_child(key_legends)
	blank.hide()
	for record: Dictionary in data.keys:
		var socket := model.find_child(str(record.name), true, false) as Node3D
		if socket == null: return _fail("Key socket missing: " + str(record.name))
		var point: Array = record.point
		var expected := Vector3(point[0], point[1], point[2])
		var actual: Vector3 = model.to_local(socket.global_position)
		if actual.distance_to(expected) > .00001: return _fail("Key socket drift: " + str(record.name))
		var template := model.find_child(str(record.template) + "__CompanionKeys", true, false) as MeshInstance3D
		if template == null: return _fail("Native key size missing: " + str(record.template))
		var size: Array = record.size
		var bounds: Vector3 = template.mesh.get_aabb().size
		if absf(bounds.x - float(size[0])) > .00001 or absf(bounds.y - float(size[1])) > .00001 or bounds.z < float(size[2]):
			return _fail("Native key dimensions differ: " + str(record.name))
		template.hide()
		var home := Transform3D(Basis.IDENTITY, keyboard.to_local(socket.global_position))
		_key_names.append(str(record.character))
		_key_homes.append(home)
		_depressions.append(0.0)
		if str(record.template) == "CompanionKeyBlank":
			_key_draws.append(keys)
			_key_instances.append(_key_homes.size() - 1)
		else:
			var special := MeshInstance3D.new()
			special.name = str(record.character) + "Key"
			special.set_meta("companion_instanced_key", true)
			special.mesh = template.mesh
			special.material_override = template.get_active_material(0)
			special.layers = keys.layers
			special.cast_shadow = keys.cast_shadow
			keyboard.add_child(special)
			_key_draws.append(special)
			_key_instances.append(-1)
		var legend := Label3D.new()
		legend.name = "KeyLegend%02d" % _key_labels.size()
		legend.text = str(record.character)
		legend.font = TelegramStyle.BODY_FONT
		legend.font_size = 48
		legend.pixel_size = .0001 if legend.text.length() == 1 else .000065
		legend.modulate = Color(.82, .77, .60)
		legend.outline_size = 0
		legend.shaded = true
		legend.no_depth_test = false
		legend.layers = keys.layers
		legend.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		key_legends.add_child(legend)
		_key_labels.append(legend)
		_set_key_transform(_key_homes.size() - 1, home)
	if _key_homes.size() != 43: return _fail("Expected 43 independent key sockets")
	for label: String in ["Port", "Starboard"]:
		for segment: String in ["Upper", "Lower"]:
			var name := label + "KeyboardStay" + segment
			var part := model.find_child(name, true, false) as Node3D
			if part == null: return _fail("Keyboard stay missing: " + name)
			_stays[name] = part
	for name: String in ["LiftRotorPort", "LiftRotorStarboard"]:
		var rotor := model.find_child(name, true, false) as Node3D
		if rotor == null: return _fail("Lift rotor missing: " + name)
		_rotors.append(rotor)
	_latch_sound = _sound("pop", -30.0)
	_key_sound = _sound("tick", -29.0)
	display = preload("res://scripts/device/companion_tile_display.gd").new()
	keyboard.add_child(display)
	if not display.build(model): return _fail("Flip-tile display could not bind")
	display.set_expression("content", 0.0, true)
	reaction_player = preload("res://scripts/device/companion_face_player.gd").new()
	add_child(reaction_player)
	if not reaction_player.configure(display, func() -> float: return _reaction_clock): return _fail("Face reaction library refused")
	glazing = model.find_child("ShellStudy__ShellGlass", true, false) as MeshInstance3D
	if glazing == null: return _fail("Formed reading glass missing")
	var water := MatLib.get_mat("water_clear") as StandardMaterial3D
	glazing_film = ShaderMaterial.new()
	glazing_film.shader = preload("res://shaders/v2_glass_film.gdshader")
	glazing_film.resource_name = "companion_reading_glass_film"
	glazing_film.render_priority = 1
	glazing_film.set_shader_parameter("albedo_tex", water.albedo_texture)
	glazing_film.set_shader_parameter("rough_tex", water.roughness_texture)
	glazing_film.set_shader_parameter("normal_tex", water.normal_texture)
	glazing_film.set_shader_parameter("water_uv_scale", Vector2(water.uv1_scale.x, water.uv1_scale.y))
	glazing_film.set_shader_parameter("glass_size", Vector2(.137, .096))
	glazing_film.set_shader_parameter("pane_center", glazing.mesh.get_aabb().get_center())
	glazing_film.set_shader_parameter("edge_wear", .025)
	glazing_film.set_shader_parameter("inside_wet", 0.0)
	glazing_film.set_shader_parameter("outside_wet", 0.0)
	glazing.material_overlay = glazing_film
	_apply_keyboard()
	set_process(true)
	return true

func set_glass_moisture(inside: float, outside: float) -> void:
	# Presentation receives humidity/rain from the world owner; it does not
	# invent weather, run another environmental scan or own a wetness timer.
	if glazing_film == null or not is_finite(inside) or not is_finite(outside): return
	inside = clampf(inside, 0.0, 1.0)
	outside = clampf(outside, 0.0, 1.0)
	if _glass_inside != inside:
		glazing_film.set_shader_parameter("inside_wet", inside)
	if _glass_outside != outside:
		glazing_film.set_shader_parameter("outside_wet", outside)
	_glass_inside = inside
	_glass_outside = outside

## Replace manufactured draws only; teletype/feed-hand retain the original
## wheel pivots, rotation and paper-motion references in the original frame.
func _install_feed_knobs() -> bool:
	var source:=load("res://assets/props/companion_feed_knobs.glb") as PackedScene
	if source==null:return false
	var replacement:=source.instantiate()
	var valid:=true
	for name:String in ["FeedWheel0","FeedWheel1"]:
		var old:=model.find_child(name,true,false) as Node3D
		var proposed:=replacement.find_child(name,true,false) as Node3D
		valid=valid and old!=null and proposed!=null and old.transform.is_equal_approx(proposed.transform)
	var key_material:Material
	for draw:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			if draw.mesh.surface_get_material(surface).resource_name=="CompanionKeys":key_material=draw.get_active_material(surface)
	if key_material==null:replacement.free();return false
	var swaps:Array=[]
	for draw:MeshInstance3D in replacement.find_children("*","MeshInstance3D",true,false):
		var lookup:=str(draw.name).replace("__CompanionKeys","__Steel")
		var old:=model.find_child(lookup,true,false) as MeshInstance3D
		if old==null or not old.transform.is_equal_approx(draw.transform) or old.mesh.get_surface_count()!=draw.mesh.get_surface_count():valid=false;break
		swaps.append([old,draw.mesh,key_material if str(draw.name).ends_with("__CompanionKeys") else old.get_active_material(0)])
	if valid and swaps.size()==5:
		for swap:Array in swaps:
			var old:MeshInstance3D=swap[0]
			old.mesh=swap[1];old.set_surface_override_material(0,swap[2]);feed_replacement_draws.append(old)
	else:valid=false
	replacement.free()
	return valid

func hold_keyboard_closed(owner:Node) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or (typing_arm!=null and typing_arm.active()):return false
	if _closed_keyboard_hold!=null and is_instance_valid(_closed_keyboard_hold.get_ref()) and _closed_keyboard_hold.get_ref()!=owner:return false
	_closed_keyboard_hold=weakref(owner);request_keyboard(false)
	return true

func release_keyboard_hold(owner:Node) -> void:
	if _closed_keyboard_hold!=null and _closed_keyboard_hold.get_ref()==owner:_closed_keyboard_hold=null

func request_keyboard(open: bool) -> void:
	if open and _closed_keyboard_hold!=null:
		if is_instance_valid(_closed_keyboard_hold.get_ref()):return
		_closed_keyboard_hold=null
	if typing_arm!=null and typing_arm.active():
		if not open:typing_arm.cancel(false)
		return # Only automated_keyboard may change travel during an arm cycle.
	if keyboard_requested == open: return
	keyboard_requested = open
	_settled = false

## Only the current physical arm may withdraw the keyboard without cancelling
## its own return. Human requests retain the normal cancellation path.
func automated_keyboard(owner:Node,open:bool) -> void:
	if owner!=typing_arm:return
	if keyboard_requested!=open:keyboard_requested=open;_settled=false

func typing_ready() -> bool:
	return keyboard_requested and keyboard_open >= .999 and failures.is_empty()

func play_reaction(id: String) -> bool:
	if reaction_player == null or not face_emotion.is_empty() or not device.radio_powered or device.teletype.printing or keyboard_open > .05: return false
	return reaction_player.request(id)

func pulse_key(character: String) -> void:
	if not typing_ready(): return
	var key_name := "SPACE" if character == " " else character.to_upper()
	var index := _key_names.find(key_name)
	if index < 0: return
	_depressions[index] = 1.0
	if not _key_sound.playing: _key_sound.play()

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec() if profile_callbacks else 0
	_advance_mechanism(delta)
	if profile_callbacks:
		callback_records.append({"process_frame":Engine.get_process_frames(), "start_usec":started, "end_usec":Time.get_ticks_usec()})
		if callback_records.size() > 4096: callback_records.pop_front()

func _advance_mechanism(delta: float) -> void:
	if keyboard == null or not failures.is_empty(): return
	display.set_process(device.radio_powered and not display.settled())
	_reaction_clock += maxf(0.0, delta)
	if reaction_player != null and not reaction_player.current.is_empty() and (not device.radio_powered or device.teletype.printing or keyboard_requested):
		reaction_player.cancel(device.radio_powered and not keyboard_requested)
	if typing_arm!=null:typing_arm.advance_idle_case(delta)
	var clear:bool=typing_arm==null or typing_arm.keyboard_case_clear()
	var target := 1.0 if keyboard_requested and clear else 0.0
	var previous := keyboard_open
	keyboard_open = move_toward(keyboard_open, target, delta / .24)
	if previous != keyboard_open: _apply_keyboard()
	if not _settled and is_equal_approx(keyboard_open, target) and (not keyboard_requested or clear):
		_settled = true
		keyboard_settled.emit(keyboard_requested)
	var active := clampf(propulsion, 0.0, 2.0)
	_rotor_angle = fposmod(_rotor_angle + delta * lerpf(0.0, 75.0, active * .5), TAU)
	for index in _rotors.size():
		_rotors[index].rotation.y = _rotor_angle * (-1.0 if index == 0 else 1.0)
	_display_clock += delta
	if _display_clock >= .12 and device.radio_powered and not keyboard_requested and keyboard_open <= .05 and not display.illustration_active:
		_display_clock = fmod(_display_clock, .12)
		var blink:=fposmod(_reaction_clock,4.7)>=4.46
		var gaze:int=[0,1,0,-1][floori(_reaction_clock/2.8)%4]
		var emotion:String=face_emotion if not face_emotion.is_empty() else "speaking" if device.teletype.printing else "content"
		if device.teletype.printing:
			var cadence: Array[float] = [.1, .7, .3, 1.0, .45, .15]
			display.set_expression(emotion, cadence[floori(float(device.teletype.printed_characters) * .5) % cadence.size()],false,blink,gaze)
		else: display.set_expression(emotion,0.0,false,blink,gaze)
	for index in _depressions.size():
		if _depressions[index] <= 0.0: continue
		_depressions[index] = move_toward(_depressions[index], 0.0, delta * 10.0)
		var pose := _key_homes[index]
		if index==_automatic_key:_depressions[index]=_automatic_depth
		pose.origin.z += KEY_TRAVEL * _depressions[index]
		_set_key_transform(index, pose)

func key_transform(index: int) -> Transform3D:
	var draw: GeometryInstance3D = _key_draws[index]
	if draw is MultiMeshInstance3D: return draw.multimesh.get_instance_transform(_key_instances[index])
	return (draw as MeshInstance3D).transform

func automated_key(owner:Node,character:String,depth:float) -> void:
	if owner!=typing_arm or not is_finite(depth):return
	if _automatic_key>=0:
		_depressions[_automatic_key]=0
		_set_key_transform(_automatic_key,_key_homes[_automatic_key])
	_automatic_key=_key_names.find(character);_automatic_depth=clampf(depth,0,1)
	if _automatic_key>=0:
		_depressions[_automatic_key]=_automatic_depth
		var pose:Transform3D=_key_homes[_automatic_key]
		pose.origin.z+=KEY_TRAVEL*_automatic_depth
		_set_key_transform(_automatic_key,pose)

func _set_key_transform(index: int, pose: Transform3D) -> void:
	var draw: GeometryInstance3D = _key_draws[index]
	if draw is MultiMeshInstance3D: draw.multimesh.set_instance_transform(_key_instances[index], pose)
	else: (draw as MeshInstance3D).transform = pose
	_key_labels[index].transform = pose * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0, -.00225))

func _apply_keyboard() -> void:
	var ease := smoothstep(0.0, 1.0, keyboard_open)
	keyboard.rotation.x = deg_to_rad(_opening_degrees) * ease
	# Clear the closed case before pulling the pin/knuckles along their bearers.
	# Reversal extends the carriage before folding the keyboard against its latch.
	var retraction := _keyboard_retraction * smoothstep(.65, 1.0, keyboard_open)
	keyboard.position = _keyboard_home - Vector3(0, 0, retraction)
	keyboard_carriage.position.z = -retraction
	key_legends.visible = keyboard_open > .55
	latch.rotation.z = -.65 * smoothstep(0.0, .12, keyboard_open)
	var latched := keyboard_open < .01
	if latched != _last_latched:
		_last_latched = latched
		if _latch_sound != null: _latch_sound.play()
	for label: String in ["Port", "Starboard"]:
		var x := -_stay_half_span if label == "Port" else _stay_half_span
		var anchor := Vector3(x, -.084, .042)
		var attachment: Vector3 = keyboard.transform * Vector3(x, .016, -.006)
		var difference := attachment - anchor
		var distance := difference.length()
		if distance >= .1:
			_fail("Keyboard support exceeds two-link travel")
			return
		var perpendicular := Vector3(0, -difference.z, difference.y).normalized()
		var elbow := (anchor + attachment) * .5 + perpendicular * sqrt(.05 * .05 - distance * distance * .25)
		_set_link(label + "KeyboardStayUpper", anchor, elbow)
		_set_link(label + "KeyboardStayLower", elbow, attachment)

func _set_link(name: String, start: Vector3, end: Vector3) -> void:
	var link: Node3D = _stays[name]
	link.position = start
	link.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))

func _sound(key: String, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = PropAudio.get_stream(key)
	player.volume_db = volume
	player.max_distance = 3.0
	add_child(player)
	return player

func _fail(message: String) -> bool:
	failures.append(message)
	push_error(message)
	set_process(false)
	return false
