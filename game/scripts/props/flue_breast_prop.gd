class_name FlueBreastProp
extends FunctionalProp
## The sealed 1912 stove-pipe thimble on the room face of the C-stack
## chimney breast.  The masonry belongs to the Blender floor; this prop owns
## only the removable iron fitting and the damage made where heat met plaster.
##
## The flue is still the building's fast acoustic path.  A propagated knock
## reaches this loose closure before the floor radiator answers, but the plate
## moves only enough for its shadow edge to betray it.  Sound carries the beat;
## movement is the evidence a player may notice afterward.

@export var unit := "5C"

const CENTRE_Y := 1.44
const IRON := Color(0.34, 0.33, 0.31)
const SOOT := Color(0.19, 0.17, 0.15)

var _cap: Node3D
var _knock: AudioStreamPlayer3D
var _draft: AudioStreamPlayer3D
var _settle: Tween
var _inspection_tap: AudioStreamPlayer3D
var _held := false
var _pose_amount := 0.0


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "sealed 1912 thimble", "properties": {"unit": "5C"}}]


func warehouse_rotation_y() -> float:
	# The authored front is local -Z so the room fitting projects away from
	# the breast.  Turn that face toward the shed's common viewing aisle.
	return PI


func _build_visual() -> void:
	var fixed: Node3D=preload("res://assets/props/flue_breast_fitting.glb").instantiate()
	fixed.name="FixedThimble"
	add_child(fixed)
	_cap=fixed.get_node("ClosurePlate")
	_cap.reparent(self,true)
	for draw: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var key: String="soot" if draw.name=="SootHalo" else "iron_neutral"
		var material:=smat(key,_soot_tint() if key=="soot" else _iron_tint()).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false
		material.uv2_triplanar=false
		material.uv1_scale=Vector3.ONE
		material.normal_enabled=true
		material.normal_scale=.15 if key=="soot" else .25
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.set_meta("v2_surface_stock",key)
		if key=="soot":
			material.vertex_color_use_as_albedo=true
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			var body:=StaticBody3D.new()
			body.name="NativeContact"
			var shape:=CollisionShape3D.new()
			shape.shape=draw.mesh.create_trimesh_shape()
			body.add_child(shape)
			draw.add_child(body)
		draw.material_override=material
	_knock = make_emitter("knock", -12.0)
	_knock.pitch_scale = 0.62  # muffled through a full masonry stack
	_draft = make_emitter("hum_loop", -60.0, true)
	_draft.pitch_scale = 0.35
	_draft.max_distance = 10.0
	_inspection_tap = make_emitter("tick", -21.0)
	_inspection_tap.pitch_scale = 0.58


## The cursor follows the loose closure, not the fixed masonry or halo.
func _build_primary_interaction() -> void:
	preload("res://scripts/props/manipulation_area.gd").install(_cap,closure_grip)


func interact_prompt() -> String:
	return ""


func closure_grip() -> Dictionary:
	# This loose plate slips axially while rocking; it is not pinned to a
	# hinge. Project the hand along its measured centre travel, then retain
	# the original coupled translation/rotation in set_knock_pose().
	var travel:=Vector3(.002,-.001,-.003)
	return {"owner":self,"part":_cap,"frame":self,"kind":"slide",
		"axis":travel.normalized(),"minimum":0.0,"maximum":travel.length(),
		"read":func():return _pose_amount*travel.length(),
		"begin":func():
			if _held or RealityState.save_write_blocked:return false
			if _settle and _settle.is_valid():_settle.kill()
			_held=true
			return true,
		"owns":func():return _held,
		"write":func(value: float):
			if _held:set_knock_pose(value/travel.length()),
		"end":func():
			_held=false
			if not is_inside_tree():return
			if _settle and _settle.is_valid():_settle.kill()
			_settle=create_tween()
			_settle.tween_method(set_knock_pose,_pose_amount,0.0,.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)}


func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(.14,1.52,-.55)),"at":to_global(Vector3(0,CENTRE_Y,-.085)),"fov":50.0}


func inspection_started() -> void:
	_inspection_tap.play()


func interact(_player: Node) -> Dictionary:
	if _inspection_tap:
		_inspection_tap.play()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("flue", {
		"masonry_state": "PLASTER SEALED / SOOT BLOOM PRESENT",
		"thimble_state": "CAST-IRON RINGS / CLOSURE SEATED",
		"draft_state": "RESONANCE PRESENT / NO OPEN ROOM PATH",
	})


func _start_normal_function() -> void:
	state = PState.OPERATING
	_draft_loop()


func _draft_loop() -> void:
	# Five random timers launched in one frame could still cluster.  A floor-
	# derived first delay makes the ordinary building quiet by construction;
	# later breaths keep enough drift not to become a metronome.
	var floor_no := int(unit.left(1)) if unit.length() >= 1 else 5
	await get_tree().create_timer(3.0 + float(floor_no) * 2.7, false).timeout
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(24.0, 48.0), false).timeout
		if not is_inside_tree() or state != PState.OPERATING:
			continue
		# This is resonance through an imperfect century-old closure, not an
		# open pipe into the room.  Six decibels below the inherited swell.
		create_tween().tween_property(_draft, "volume_db", -32.0, 1.7)
		await get_tree().create_timer(2.4, false).timeout
		if is_inside_tree():
			create_tween().tween_property(_draft, "volume_db", -60.0, 2.2)


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_knock.volume_db = -12.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_knock.pitch_scale = clampf(0.62 * pow(2.0, pitch * 0.1 / 12.0), 0.5, 0.8)
	_knock.play()
	# The conductor keeps sounding, but never takes the plate out of a hand.
	if _held:return
	if _settle and _settle.is_valid():
		_settle.kill()
	_settle = create_tween()
	_settle.tween_method(set_knock_pose, 0.0,
			clampf(0.55 + accent * 0.45, 0.0, 1.0), 0.055)
	_settle.tween_method(set_knock_pose,
			clampf(0.55 + accent * 0.45, 0.0, 1.0), 0.0, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Stable inspection/test pose.  The first two-millimetre attempt changed
## pixels but did not read in paired standing-distance renders.  Spinning a
## round plate was equally invisible, so the final three-millimetre settle
## rocks on one lip and lets its annular shadow betray the movement.
func set_knock_pose(amount: float) -> void:
	if not _cap:
		return
	var a := clampf(amount, 0.0, 1.0)
	_pose_amount=a
	# A loose bayonet closure also slips within its ring.  Two millimetres of
	# lateral error leaves the final concentric circles subtly wrong after the
	# sound, which reads more reliably than axial travel alone.
	_cap.position.x = 0.002 * a
	_cap.position.y = CENTRE_Y - 0.001 * a
	_cap.position.z = -0.083 - 0.003 * a
	_cap.rotation.x = deg_to_rad(1.60 * a)
	_cap.rotation.z = deg_to_rad(0.40 * a)


func visible_mesh_count() -> int:
	return find_children("*", "MeshInstance3D", true, false).size()


func _iron_tint() -> Color:
	match unit:
		"2C": return Color(0.78, 0.76, 0.72)
		"3C": return Color(0.66, 0.65, 0.62)
		"4C": return Color(0.73, 0.69, 0.63)
		"6C": return Color(0.62, 0.61, 0.58)
		_: return Color(0.70, 0.68, 0.64)


func _soot_tint() -> Color:
	match unit:
		"3C": return Color(0.78, 0.72, 0.66)
		"6C": return Color(0.62, 0.58, 0.54)
		_: return Color(0.70, 0.65, 0.60)
