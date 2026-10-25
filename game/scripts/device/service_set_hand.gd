extends RefCounted
## The carried pass supplies hits; the ordinary player hand owns every grab.
var carrier: ServiceSetCarrier
var printer: Node3D
var controls: Dictionary={}
var _feed_angle:=0.
var _feed_detent:=0
var last_hit: Dictionary={}

func _init(owner: ServiceSetCarrier) -> void:
	carrier=owner;printer=carrier.device.teletype
	controls={"lamp":printer.lamp_switch,"radio":printer.radio_switch,
		"cover":printer.service_cover,"focus":printer.focus_wheel}
	for i in printer.feed_wheels.size():controls["feed"+str(i)]=printer.feed_wheels[i]
	# One private physics world, shared by hover and click. Fixed mesh stock
	# occludes rear controls; no extra screen-space hit rectangles or scans.
	for key: String in controls:
		var part: Node3D=controls[key]
		preload("res://scripts/props/manipulation_area.gd").install(part,descriptor.bind(key))
	for draw: MeshInstance3D in printer.find_children("*","MeshInstance3D",true,false):
		var movable:=false
		for part: Node3D in controls.values():
			if part==draw or part.is_ancestor_of(draw):movable=true;break
		if movable or draw.mesh==null:continue
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		var collision:=CollisionShape3D.new();collision.shape=draw.mesh.create_trimesh_shape()
		draw.add_child(body);body.add_child(collision)

func enabled() -> bool:
	return is_instance_valid(carrier._player) and carrier._player.inspecting() and carrier._player.inspect_owner==carrier and carrier.reading and not carrier._capture_hidden

func find_target() -> Dictionary:
	if not enabled():return {}
	var rect:=carrier._device_rect.get_global_rect()
	var pixel:=carrier.get_viewport().get_mouse_position()
	if not rect.has_point(pixel):return {}
	var local: Vector2=(pixel-rect.position)/rect.size*Vector2(carrier._pass_view.size)
	var camera:=carrier._pass_cam
	var origin:=camera.project_ray_origin(local)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(local)*2.1)
	query.collide_with_areas=true
	var hit:=carrier._pass_view.world_3d.direct_space_state.intersect_ray(query)
	last_hit=hit
	if hit.is_empty() or not hit.collider.has_method("manipulation_target"):return {}
	var target: Dictionary=hit.collider.manipulation_target(hit)
	if not target.is_empty():target.hit_position=hit.position
	return target

func descriptor(key: String) -> Dictionary:
	var part: Node3D=controls[key]
	var low:=0.;var high:=1.85;var axis:=Vector3.RIGHT;var gesture:=Vector2.DOWN
	if key in ["lamp","radio"]:low=-.4;high=.4;axis=Vector3.BACK
	elif key=="focus":low=carrier.READING_NEAR;high=carrier.READING_FAR;axis=Vector3.RIGHT
	elif key.begins_with("feed"):low=-TAU;high=TAU;axis=Vector3.RIGHT;gesture=Vector2.UP
	return {"owner":carrier,"part":part,"frame":part.get_parent(),"kind":"hinge",
		"axis":axis,"minimum":low,"maximum":high,"gesture_travel_px":160.,"gesture_screen_axis":gesture,
		"view_camera":carrier._pass_cam,"unobstructed_hold":true,"interaction_valid":enabled,
		"read":read.bind(key),"write":write.bind(key),"begin":begin.bind(key),"end":end,
		"change_origin":func()->Vector3:return carrier._player.global_position}

func begin(key: String) -> bool:
	if not enabled() or printer.hand_control!=null:return false
	printer.hand_control=controls[key]
	if printer._controls_motion:
		printer._controls_motion.kill()
		printer._aerial.scale.y=1. if carrier.radio_is_powered() else .14
	if key=="cover" and printer._cover_motion:printer._cover_motion.kill()
	if key=="focus" and printer._focus_motion:printer._focus_motion.kill()
	if key.begins_with("feed"):
		_feed_angle=0.;_feed_detent=0
	return true

func end() -> void:
	printer.hand_control=null

func read(key: String) -> float:
	if key in ["lamp","radio"]:return controls[key].rotation.z
	if key=="cover":return printer.service_cover.rotation.x
	if key=="focus":return carrier.reading_distance
	return _feed_angle

func write(value: float,key: String) -> void:
	if not enabled() or printer.hand_control!=controls[key] or not is_finite(value):return
	if key in ["lamp","radio"]:
		controls[key].rotation.z=value
		if key=="lamp":
			if carrier.device.lamp_enabled!=(value<0.):carrier._player.set_lamp_enabled(value<0.)
		else:
			if carrier.device.radio_powered!=(value<0.):carrier.set_radio_powered(value<0.)
			# Seating the live radio contact can answer an existing call.
			# The service-round owner remains the only answer authority.
			if value<-.35 and is_instance_valid(carrier._service_round) and carrier._service_round.has_method("has_incoming_call") and carrier._service_round.has_incoming_call():carrier._service_round.answer_incoming_call()
	elif key=="cover":
		printer.service_cover.rotation.x=value;printer.service_open=value>.9
	elif key=="focus":
		carrier.reading_distance=value
		printer.focus_wheel.rotation.x=inverse_lerp(carrier.READING_FAR,carrier.READING_NEAR,value)*TAU
	else:
		var delta:=value-_feed_angle;_feed_angle=value
		if not printer._reviewing:
			# First movement reviews the physical copy; merely grabbing does
			# not stop printing or change the current paper.
			printer._reviewing=true;printer._show_copy()
		for wheel: Node3D in printer.feed_wheels:wheel.rotate_x(delta)
		printer.platen.rotate_x(delta)
		var detent:=int(value/(PI*.5))
		if detent!=_feed_detent:
			printer.turn_page(signi(detent-_feed_detent));_feed_detent=detent
