extends Node3D
## Visit-local presentation. WorkOrders, saves and mechanisms are read-only.
signal phase_changed(phase: int)
enum Phase { DORMANT, EMERGING, OBSERVING, INTERFERING, CONTACT_ALARM, COORDINATED_RETREAT, PURPLE_HAZE, CLEARED }
const MODEL = "res://assets/dream/tentacle_gang/gang_normal.glb"
const Area = preload("res://scripts/props/manipulation_area.gd")
const TissueAudio = preload("res://scripts/dream/entity/tentacle_gang_audio.gd")
var phase := Phase.DORMANT
var elapsed := 0.0
var age := 0.0
var target: Node3D
var player: Node3D
var optical_field: RefCounted
var root: Node3D
var limbs: Array[Node3D] = []
var contacts: Array[Area3D] = []
var materials: Array[ShaderMaterial] = []
var haze: FogVolume
var haze_material: ShaderMaterial
var droplets: GPUParticles3D
var droplet_material: ShaderMaterial
var contact_count := 0
var contact_point := Vector3.INF
var touched_limb := -1
var history: Array[int] = [Phase.DORMANT]
var _held := -1
var _pressure := 0.0
var seed_value := 0
var sounds: Array[WeakRef] = []
var limb_materials: Array = []
var reach_offsets: Array[Vector3] = []
var apparatus_contacts := 0
var apparatus_contact_events := 0
var contact_diagnostics: Array[Dictionary] = []
var _contact_due := 0.0
var _sound_mask := 0

func _tissue_sound(kind: int, point: Vector3) -> void:
	if _sound_mask & (1 << kind): return
	_sound_mask |= 1 << kind
	sounds.append(weakref(TissueAudio.emit_at(self,point,kind,seed_value+kind)))

func start(mechanism: Node3D, observer: Node3D, anchor: Transform3D,
		seed_id: int, shared_field: RefCounted = null) -> bool:
	if phase != Phase.DORMANT or not is_instance_valid(mechanism) or not is_instance_valid(observer): return false
	target = mechanism
	player = observer
	optical_field = shared_field
	seed_value = seed_id
	global_transform = anchor
	root = Node3D.new()
	root.name = "SharedBuriedMass"
	add_child(root)
	var packed := load(MODEL) as PackedScene
	if packed == null:
		cleanup()
		return false
	var root_scene := load("res://assets/dream/tentacle_gang/gang_root.glb") as PackedScene
	if root_scene == null:
		cleanup()
		return false
	var reservoir := root_scene.instantiate() as Node3D
	root.add_child(reservoir)
	_dress(reservoir,0.0)
	var count := 3 + posmod(seed_id, 5)
	for index in count:
		var limb := packed.instantiate() as Node3D
		limb.name = "Limb%d" % index
		var contact_name: String = ["CONTACT_Probe","CONTACT_Disk","CONTACT_Brush"][index%3]
		for role in ["CONTACT_Probe","CONTACT_Disk","CONTACT_Brush"]:
			var unused := limb.find_child(role,true,false)
			if role != contact_name and unused != null: unused.free()
		root.add_child(limb)
		var angle := TAU * float(index) / count
		limb.position = Vector3(cos(angle)*.12, -.035, sin(angle)*.12)
		limb.rotation.y = angle
		if index>0:
			var toward: Vector3 = to_local(target.global_position)-limb.position
			limb.rotation.y = atan2(-toward.z,toward.x)
		limb.scale = Vector3.ONE * (.72 + .055*index)
		limbs.append(limb)
		limb_materials.append(_dress(limb,angle))
		reach_offsets.append(Vector3.ZERO)
		# Only the physically represented distal pad is operable. No body blocker.
		var pad := limb.find_child(contact_name, true, false) as Node3D
		if pad != null:
			var area := Area.install(pad, func(): return grip(index))
			contacts.append(area)
	_set_phase(Phase.EMERGING)
	return true

func _dress(body: Node3D, angle: float) -> Array[ShaderMaterial]:
	var dressed: Array[ShaderMaterial] = []
	for draw: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var family := "tissue"
		if str(draw.name).begins_with("MEMBRANE"): family = "membrane"
		if str(draw.name).begins_with("OCELLUS"): family = "eye"
		if str(draw.name).begins_with("PRESSURE") or str(draw.name).begins_with("STATOCYST"): family = "medium"
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/tentacle_gang_%s.gdshader" % family)
		material.set_shader_parameter("limb_phase", angle)
		material.set_shader_parameter("balance_grain",1.0 if str(draw.name).begins_with("GOLD_statolith") else 0.0)
		material.set_meta("gang_pad",str(draw.name).begins_with("TIP_"))
		material.set_shader_parameter("mineral", 1.0 if str(draw.name).begins_with("GOLD") else 0.0)
		material.set_shader_parameter("pigment_cup",1.0 if str(draw.name).begins_with("PIGMENT") else 0.0)
		material.set_shader_parameter("nerve_tissue",1.0 if str(draw.name).begins_with("NERVE") or str(draw.name).begins_with("GANGLION") or str(draw.name).begins_with("CILIUM") else 0.0)
		var map_family := "membrane" if family == "medium" else family
		for channel in ["albedo","normal","roughness"]:
			material.set_shader_parameter(channel+"_map",load("res://assets/dream/tentacle_gang/%s_%s.png" % [map_family,channel]))
		draw.material_override = material
		draw.set_meta(&"lamp_optical_receiver",true)
		draw.layers = 1 << 17
		# Transmitting interfaces cannot cast opaque native shadow silhouettes
		# over their own interior. Dense organs still occlude one another.
		if family in ["membrane","medium","eye"] or str(draw.name).begins_with("CILIUM"):
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		materials.append(material)
		dressed.append(material)
		if optical_field != null: optical_field.bind_material(material)
	return dressed

func _physics_process(delta: float) -> void:
	if phase != Phase.INTERFERING or _held != -1 or not is_instance_valid(target): return
	_contact_due -= delta
	if _contact_due > 0: return
	_contact_due = .2
	apparatus_contacts = 0
	contact_diagnostics.clear()
	var space := get_world_3d().direct_space_state
	for index in range(1,contacts.size()):
		var limb := limbs[index]
		var shape := contacts[index].get_child(0) as CollisionShape3D
		var tip := shape.global_position
		var aim := target.global_position
		aim.y = tip.y
		if tip.distance_to(aim)<.01: continue
		var ray := PhysicsRayQueryParameters3D.create(tip,aim+(aim-tip).normalized()*.12)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.collider != target and not target.is_ancestor_of(hit.collider)):
			contact_diagnostics.append({"limb":index,"reason":"no_apparatus_hit","hit":"none" if hit.is_empty() else str(hit.collider.get_path())})
			continue
		var radius: float = ((shape.shape as BoxShape3D).size*shape.global_basis.get_scale()).length()*.5
		var contact: Vector3 = hit.position+hit.normal*radius
		var wanted: Vector3 = reach_offsets[index]+limb.global_basis.inverse()*(contact-tip)
		wanted.y = 0.0
		if wanted.length()>.18:
			contact_diagnostics.append({"limb":index,"reason":"beyond_extension","distance":wanted.length()})
			continue
		var next := reach_offsets[index].move_toward(wanted,.015)
		var shift := limb.global_basis*(next-reach_offsets[index])
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = shape.shape
		clearance.transform = shape.global_transform.translated(shift)
		clearance.exclude = [hit.rid]
		var blocked := false
		for other in space.intersect_shape(clearance,8):
			if other.collider != target and not target.is_ancestor_of(other.collider): blocked = true
		if blocked:
			contact_diagnostics.append({"limb":index,"reason":"blocked"})
			continue
		reach_offsets[index] = next
		var pad := contacts[index].get_parent() as Node3D
		pad.position.x = next.x
		pad.position.z = next.z
		for material: ShaderMaterial in limb_materials[index]:
			if not bool(material.get_meta("gang_pad",false)): material.set_shader_parameter("reach_offset",next)
		var remaining := shape.global_position.distance_to(contact)
		contact_diagnostics.append({"limb":index,"reason":"approaching","remaining":remaining})
		if remaining<.018:
			apparatus_contacts += 1
			apparatus_contact_events += 1

func grip(index: int) -> Dictionary:
	if index < 0 or index >= contacts.size() or phase not in [Phase.OBSERVING, Phase.INTERFERING]: return {}
	var part := contacts[index].get_parent() as Node3D
	return {"owner":self,"part":part,"frame":part,"kind":"slider",
		"axis":Vector3.DOWN,"minimum":0.0,"maximum":.012,"motion_scale":.1,
		"read":func(): return _pressure,
		"write":func(value: float):
			if _held == index:
				_pressure = clampf(value,0,.012)
				part.position.y = -_pressure
				if _pressure > .002:
					var point: Vector3 = contacts[index].get_child(0).global_position
					if player.get("_grab") != null and player._grab.active():
						point = part.to_global(player._grab.contact)
					_contact(index,point),
		"owns":func(): return _held == index,
		"begin":func():
			if _held != -1 or phase not in [Phase.OBSERVING, Phase.INTERFERING]: return false
			_held = index
			_pressure = 0.0
			return true,
		"end":func(): _held = -1; _pressure = 0.0; part.position.y = 0.0}

func _contact(index: int, point: Vector3) -> void:
	if phase not in [Phase.OBSERVING, Phase.INTERFERING] or contact_count != 0: return
	contact_count = 1
	touched_limb = index
	contact_point = point
	_tissue_sound(TissueAudio.Motif.MINERAL,point)
	_set_phase(Phase.CONTACT_ALARM)

func _process(delta: float) -> void:
	if phase in [Phase.DORMANT, Phase.CLEARED]: return
	if not is_instance_valid(target) or not is_instance_valid(player):
		cleanup()
		return
	elapsed += delta
	age += delta
	match phase:
		Phase.EMERGING:
			if elapsed >= 2.2: _set_phase(Phase.OBSERVING)
		Phase.OBSERVING:
			if elapsed >= .5: _tissue_sound(TissueAudio.Motif.CREAK,global_position+Vector3.UP*.3)
			if elapsed >= 1.4: _set_phase(Phase.INTERFERING)
		Phase.CONTACT_ALARM:
			if elapsed >= .2: _tissue_sound(TissueAudio.Motif.CHAMBER,global_position)
			if elapsed >= .42:
				_held = -1
				for area in contacts: area.collision_layer = 0
				_tissue_sound(TissueAudio.Motif.SUCTION,global_position)
				_set_phase(Phase.COORDINATED_RETREAT)
		Phase.COORDINATED_RETREAT:
			if elapsed >= 2.4:
				_release_body()
				_make_haze()
				_set_phase(Phase.PURPLE_HAZE)
		Phase.PURPLE_HAZE:
			if elapsed >= 5.5: cleanup()
	if phase == Phase.CLEARED: return
	var growth := clampf(elapsed/2.2,0,1) if phase == Phase.EMERGING else 1.0
	var retreat := clampf(elapsed/2.4,0,1) if phase == Phase.COORDINATED_RETREAT else 0.0
	var lamp_rate := 0.0
	var presentation: Node = player.get("lamp_presentation")
	if is_instance_valid(presentation): lamp_rate = float(presentation.state.intensity_rate)
	if phase in [Phase.OBSERVING,Phase.INTERFERING] and _held == -1:
		# Only real exposed observations: lamp pose and the held part's pose.
		var attention: Vector3 = player.global_position+Vector3.UP
		var lamp: Light3D = player.get("flashlight")
		if is_instance_valid(lamp): attention = lamp.global_position
		for index in limbs.size():
			var limb := limbs[index]
			var aim: Vector3 = attention if index==0 else target.global_position
			if index>0 and player.get("_grab") != null and player._grab.active():
				aim = player._grab.target.part.global_position
			var local_aim := to_local(aim)-limb.position
			var wanted := atan2(-local_aim.z,local_aim.x)
			limb.rotation.y = lerp_angle(limb.rotation.y,wanted,delta*.35)
	for material in materials:
		material.set_shader_parameter("organ_time",age)
		material.set_shader_parameter("growth",growth)
		material.set_shader_parameter("retreat",retreat)
		material.set_shader_parameter("alarm",elapsed/.42 if phase == Phase.CONTACT_ALARM else -1.0)
		material.set_shader_parameter("lamp_rate",lamp_rate)
	if haze_material != null:
		haze_material.set_shader_parameter("haze_age",elapsed)
		haze_material.set_shader_parameter("lamp_rate",lamp_rate)

func _make_haze() -> void:
	haze = FogVolume.new()
	haze.name = "TemporarySeamExhalation"
	haze.size = Vector3(.9,.65,.9)
	haze.position.y = .24
	haze_material = ShaderMaterial.new()
	haze_material.shader = load("res://shaders/tentacle_gang_haze.gdshader")
	haze.material = haze_material
	if optical_field != null: optical_field.bind_material(haze_material)
	add_child(haze)
	droplets = GPUParticles3D.new()
	droplets.name = "FiniteSeamDroplets"
	droplets.amount = 24
	droplets.lifetime = 3.8
	droplets.one_shot = true
	droplets.explosiveness = .65
	droplets.local_coords = false
	droplets.layers = 1 << 17
	droplets.position.y = .035
	droplets.visibility_aabb = AABB(Vector3(-.6,-.2,-.6),Vector3(1.2,1,1.2))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = .13
	motion.direction = Vector3.UP
	motion.spread = 42
	motion.initial_velocity_min = .04
	motion.initial_velocity_max = .12
	motion.gravity = Vector3(0,-.025,0)
	droplets.process_material = motion
	var mesh := QuadMesh.new()
	mesh.size = Vector2(.008,.008)
	droplet_material = ShaderMaterial.new()
	droplet_material.shader = preload("res://shaders/lamp_optical_dust.gdshader")
	mesh.material = droplet_material
	droplets.draw_pass_1 = mesh
	if optical_field != null: optical_field.bind_material(droplet_material)
	add_child(droplets)
	droplets.emitting = true

func _release_body() -> void:
	for material in materials:
		if optical_field != null: optical_field.unbind_material(material)
	materials.clear()
	limb_materials.clear()
	reach_offsets.clear()
	contacts.clear()
	limbs.clear()
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	root = null

func cleanup() -> void:
	_held = -1
	for reference in sounds:
		var sound: AudioStreamPlayer3D = reference.get_ref()
		if is_instance_valid(sound):
			sound.stop()
			remove_child(sound)
			sound.queue_free()
	sounds.clear()
	_release_body()
	if haze_material != null and optical_field != null: optical_field.unbind_material(haze_material)
	if droplet_material != null and optical_field != null: optical_field.unbind_material(droplet_material)
	if is_instance_valid(droplets):
		droplets.emitting = false
		remove_child(droplets)
		droplets.queue_free()
	droplets = null
	droplet_material = null
	if is_instance_valid(haze):
		remove_child(haze)
		haze.queue_free()
	haze = null
	haze_material = null
	optical_field = null
	target = null
	player = null
	_set_phase(Phase.CLEARED)

func _set_phase(value: int) -> void:
	if phase == value: return
	phase = value
	elapsed = 0.0
	history.append(value)
	match phase:
		Phase.EMERGING: _tissue_sound(TissueAudio.Motif.ADHESION,global_position)
		Phase.OBSERVING: _tissue_sound(TissueAudio.Motif.FLUID,global_position+Vector3.UP*.25)
		Phase.INTERFERING: _tissue_sound(TissueAudio.Motif.CILIA,global_position+Vector3.UP*.45)
		Phase.PURPLE_HAZE: _tissue_sound(TissueAudio.Motif.EXHALE,global_position)
	phase_changed.emit(value)

func _exit_tree() -> void:
	cleanup()
